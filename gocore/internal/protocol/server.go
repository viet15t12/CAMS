// Package protocol implements the initial fail-closed JSON Lines sidecar protocol.
package protocol

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
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
}

type helloPayload struct {
	Mode      string `json:"mode"`
	ProjectID string `json:"project_id"`
}

// Server accepts only lifecycle messages in the foundation release. Network
// mutation remains impossible until the later executor milestone is enabled.
type Server struct {
	input  io.Reader
	output io.Writer
}

func NewServer(input io.Reader, output io.Writer) *Server {
	return &Server{input: input, output: output}
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
			if payload.Mode != "dry-run" {
				_ = encoder.Encode(errorResponse(message.RequestID, "foundation release only supports dry-run"))
				return fmt.Errorf("unsupported mode %q", payload.Mode)
			}
			handshaken = true
			if err := encoder.Encode(response{
				ProtocolVersion: Version, Type: "hello_ack", RequestID: message.RequestID,
				OK: true, Mode: "dry-run",
			}); err != nil {
				return err
			}
		case "ping":
			if err := encoder.Encode(response{
				ProtocolVersion: Version, Type: "pong", RequestID: message.RequestID,
				OK: true, Mode: "dry-run",
			}); err != nil {
				return err
			}
		case "shutdown":
			return encoder.Encode(response{
				ProtocolVersion: Version, Type: "shutdown_ack", RequestID: message.RequestID,
				OK: true, Mode: "dry-run",
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
	return payload, nil
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
