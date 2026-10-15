// Package protocol implements the initial fail-closed JSON Lines sidecar protocol.
package protocol

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/viet15t12/CAMS/gocore/internal/event"
	"github.com/viet15t12/CAMS/gocore/internal/rule"
)

const (
	Version      = 1
	maxLineBytes = 1 << 20
)

type request struct {
	ProtocolVersion int             `json:"protocol_version"`
	Type            string          `json:"type"`
	RequestID       string          `json:"request_id"`
	Payload         json.RawMessage `json:"payload,omitempty"`
}

type response struct {
	ProtocolVersion int    `json:"protocol_version"`
	Type            string `json:"type"`
	RequestID       string `json:"request_id,omitempty"`
	OK              bool   `json:"ok"`
	Error           string `json:"error,omitempty"`
	Mode            string `json:"mode,omitempty"`
	Payload         any    `json:"payload,omitempty"`
}

type helloPayload struct {
	Mode      string `json:"mode"`
	ProjectID string `json:"project_id"`
	RulesDir  string `json:"rules_dir"`
}

type evaluatePayload struct {
	Events []event.Event `json:"events"`
}

type evaluateResult struct {
	Actions           []rule.PlannedAction `json:"actions"`
	ProcessedEventIDs []string             `json:"processed_event_ids"`
	DeferredEventIDs  []string             `json:"deferred_event_ids"`
	RuleErrors        []rule.LoadError     `json:"rule_errors"`
	LoadedRules       int                  `json:"loaded_rules"`
}

// Server accepts lifecycle and rule evaluation messages. Device mutation is
// performed by the Python host through its app-owned session registry.
type Server struct {
	input    io.Reader
	output   io.Writer
	rulesDir string
	mode     string
	engine   *rule.Engine
}

func NewServer(input io.Reader, output io.Writer) *Server {
	return &Server{input: input, output: output, engine: rule.NewEngine()}
}

func (server *Server) Run() error {
	scanner := bufio.NewScanner(server.input)
	scanner.Buffer(make([]byte, 64*1024), maxLineBytes)
	encoder := json.NewEncoder(server.output)
	handshaken := false
	for scanner.Scan() {
		var message request
		decoder := json.NewDecoder(bytes.NewReader(scanner.Bytes()))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&message); err != nil {
			_ = encoder.Encode(errorResponse("", fmt.Sprintf("invalid request: %v", err)))
			return fmt.Errorf("decode protocol request: %w", err)
		}
		var trailing any
		if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
			_ = encoder.Encode(errorResponse(message.RequestID, "request must contain one JSON value"))
			return errors.New("request must contain one JSON value")
		}
		if message.ProtocolVersion != Version {
			_ = encoder.Encode(errorResponse(message.RequestID, "unsupported protocol_version"))
			return fmt.Errorf("unsupported protocol_version %d", message.ProtocolVersion)
		}
		if message.RequestID == "" {
			_ = encoder.Encode(errorResponse("", "request_id is required"))
			return errors.New("request_id is required")
		}
		if !handshaken && message.Type != "hello" {
			_ = encoder.Encode(errorResponse(message.RequestID, "hello is required first"))
			return errors.New("hello is required first")
		}
		switch message.Type {
		case "hello":
			if handshaken {
				_ = encoder.Encode(errorResponse(message.RequestID, "hello already completed"))
				return errors.New("duplicate hello")
			}
			payload, err := decodeHello(message.Payload)
			if err != nil {
				_ = encoder.Encode(errorResponse(message.RequestID, err.Error()))
				return err
			}
			if payload.Mode != "dry-run" && payload.Mode != "auto" {
				_ = encoder.Encode(errorResponse(message.RequestID, "mode must be dry-run or auto"))
				return fmt.Errorf("unsupported mode %q", payload.Mode)
			}
			rulesDir, err := validateRulesDirectory(payload.RulesDir)
			if err != nil {
				_ = encoder.Encode(errorResponse(message.RequestID, err.Error()))
				return err
			}
			server.rulesDir = rulesDir
			server.mode = payload.Mode
			handshaken = true
			if err := encoder.Encode(response{
				ProtocolVersion: Version, Type: "hello_ack", RequestID: message.RequestID,
				OK: true, Mode: server.mode, Payload: map[string]any{
					"service_name": "CAMS Automation Engine",
					"rule_version": rule.Version,
				},
			}); err != nil {
				return err
			}
		case "ping":
			if err := encoder.Encode(response{
				ProtocolVersion: Version, Type: "pong", RequestID: message.RequestID,
				OK: true, Mode: server.mode,
			}); err != nil {
				return err
			}
		case "evaluate":
			payload, err := decodeEvaluate(message.Payload)
			if err != nil {
				_ = encoder.Encode(errorResponse(message.RequestID, err.Error()))
				return err
			}
			rules, loadErrors, err := rule.LoadDirectory(server.rulesDir)
			if err != nil {
				_ = encoder.Encode(errorResponse(message.RequestID, err.Error()))
				return err
			}
			scheduled := rule.ScheduledResult{
				Actions:           make([]rule.PlannedAction, 0),
				ProcessedEventIDs: make([]string, 0),
				DeferredEventIDs:  make([]string, 0),
			}
			if len(loadErrors) > 0 {
				for _, value := range payload.Events {
					scheduled.DeferredEventIDs = append(scheduled.DeferredEventIDs, value.EventID)
				}
			} else {
				scheduled, err = server.engine.EvaluateScheduled(rules, payload.Events, time.Now().UTC())
				if err != nil {
					_ = encoder.Encode(errorResponse(message.RequestID, err.Error()))
					return err
				}
			}
			if err := encoder.Encode(response{
				ProtocolVersion: Version, Type: "evaluate_result", RequestID: message.RequestID,
				OK: true, Mode: server.mode, Payload: evaluateResult{
					Actions:           scheduled.Actions,
					ProcessedEventIDs: scheduled.ProcessedEventIDs,
					DeferredEventIDs:  scheduled.DeferredEventIDs,
					RuleErrors:        loadErrors,
					LoadedRules:       len(rules),
				},
			}); err != nil {
				return err
			}
		case "shutdown":
			return encoder.Encode(response{
				ProtocolVersion: Version, Type: "shutdown_ack", RequestID: message.RequestID,
				OK: true, Mode: server.mode,
			})
		default:
			_ = encoder.Encode(errorResponse(message.RequestID, "unsupported message type"))
			return fmt.Errorf("unsupported message type %q", message.Type)
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read protocol stream: %w", err)
	}
	return nil
}

func decodeHello(raw json.RawMessage) (helloPayload, error) {
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	var payload helloPayload
	if err := decoder.Decode(&payload); err != nil {
		return helloPayload{}, fmt.Errorf("invalid hello payload: %w", err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		return helloPayload{}, errors.New("hello payload must contain one JSON value")
	}
	if payload.ProjectID == "" {
		return helloPayload{}, errors.New("project_id is required")
	}
	if payload.RulesDir == "" {
		return helloPayload{}, errors.New("rules_dir is required")
	}
	return payload, nil
}

func decodeEvaluate(raw json.RawMessage) (evaluatePayload, error) {
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	var payload evaluatePayload
	if err := decoder.Decode(&payload); err != nil {
		return evaluatePayload{}, fmt.Errorf("invalid evaluate payload: %w", err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		return evaluatePayload{}, errors.New("evaluate payload must contain one JSON value")
	}
	if len(payload.Events) > 100 {
		return evaluatePayload{}, errors.New("evaluate accepts at most 100 events")
	}
	for index, value := range payload.Events {
		if err := value.Validate(); err != nil {
			return evaluatePayload{}, fmt.Errorf("events[%d]: %w", index, err)
		}
	}
	return payload, nil
}

func validateRulesDirectory(value string) (string, error) {
	abs, err := filepath.Abs(value)
	if err != nil {
		return "", fmt.Errorf("resolve rules_dir: %w", err)
	}
	info, err := os.Lstat(abs)
	if err != nil {
		return "", fmt.Errorf("inspect rules_dir: %w", err)
	}
	if info.Mode()&os.ModeSymlink != 0 || !info.IsDir() {
		return "", errors.New("rules_dir must be a real directory")
	}
	return filepath.Clean(abs), nil
}

func errorResponse(requestID, message string) response {
	return response{
		ProtocolVersion: Version,
		Type:            "error",
		RequestID:       requestID,
		OK:              false,
		Error:           message,
		Mode:            "dry-run",
	}
}
