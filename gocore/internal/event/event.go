// Package event validates the versioned automation event contract from CAMS.
package event

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"
)

const (
	SchemaVersion = 1
	MaxBytes      = 1 << 20
)

// Event is the stable machine-facing contract persisted in t13_automation_events.
type Event struct {
	SchemaVersion int             `json:"schema_version"`
	EventID       string          `json:"event_id"`
	EventType     string          `json:"event_type"`
	DeviceHost    string          `json:"device_host"`
	DetectedAt    string          `json:"detected_at"`
	SubjectKey    string          `json:"subject_key"`
	Attributes    json.RawMessage `json:"attributes"`
	Evidence      json.RawMessage `json:"evidence"`
	Fingerprint   string          `json:"fingerprint"`
}

// Decode reads exactly one event and rejects unknown fields and oversized input.
func Decode(reader io.Reader) (Event, error) {
	data, err := io.ReadAll(io.LimitReader(reader, MaxBytes+1))
	if err != nil {
		return Event{}, fmt.Errorf("read event: %w", err)
	}
	if len(data) > MaxBytes {
		return Event{}, fmt.Errorf("event exceeds %d bytes", MaxBytes)
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var value Event
	if err := decoder.Decode(&value); err != nil {
		return Event{}, fmt.Errorf("decode event: %w", err)
	}
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		if err == nil {
			return Event{}, errors.New("event input contains more than one JSON value")
		}
		return Event{}, fmt.Errorf("decode trailing event data: %w", err)
	}
	if err := value.Validate(); err != nil {
		return Event{}, err
	}
	return value, nil
}

// Validate enforces the fail-closed fields required before rule matching.
func (value Event) Validate() error {
	if value.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported schema_version %d", value.SchemaVersion)
	}
	for name, field := range map[string]string{
		"event_id": value.EventID, "event_type": value.EventType,
		"device_host": value.DeviceHost, "subject_key": value.SubjectKey,
		"fingerprint": value.Fingerprint,
	} {
		if strings.TrimSpace(field) == "" {
			return fmt.Errorf("%s is required", name)
		}
		if len(field) > 512 {
			return fmt.Errorf("%s exceeds 512 bytes", name)
		}
	}
	if _, err := time.Parse(time.RFC3339Nano, value.DetectedAt); err != nil {
		return fmt.Errorf("detected_at must be RFC3339: %w", err)
	}
	if err := validateObject("attributes", value.Attributes); err != nil {
		return err
	}
	if err := validateObject("evidence", value.Evidence); err != nil {
		return err
	}
	return nil
}

func validateObject(name string, raw json.RawMessage) error {
	if len(raw) == 0 {
		return fmt.Errorf("%s is required", name)
	}
	var value map[string]any
	if err := json.Unmarshal(raw, &value); err != nil {
		return fmt.Errorf("%s must be a JSON object: %w", name, err)
	}
	if value == nil {
		return fmt.Errorf("%s must be a JSON object", name)
	}
	return nil
}
