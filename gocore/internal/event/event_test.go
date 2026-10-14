package event

import (
	"strings"
	"testing"
)

const validEvent = `{
  "schema_version": 1,
  "event_id": "evt-123",
  "event_type": "PORT_SECURITY_REPEAT",
  "device_host": "192.0.2.2",
  "detected_at": "2026-10-11T08:30:00.123Z",
  "subject_key": "GigabitEthernet1/1",
  "attributes": {"interface": "GigabitEthernet1/1"},
  "evidence": {"source_message_ids": [1, 2, 3]},
  "fingerprint": "abcdef"
}`

func TestDecodeValidEvent(t *testing.T) {
	value, err := Decode(strings.NewReader(validEvent))
	if err != nil {
		t.Fatalf("Decode() error = %v", err)
	}
	if value.EventType != "PORT_SECURITY_REPEAT" {
		t.Fatalf("EventType = %q", value.EventType)
	}
}

func TestDecodeRejectsUnknownVersion(t *testing.T) {
	input := strings.Replace(validEvent, `"schema_version": 1`, `"schema_version": 2`, 1)
	if _, err := Decode(strings.NewReader(input)); err == nil {
		t.Fatal("Decode() accepted an unknown schema version")
	}
}

func TestDecodeRejectsUnknownField(t *testing.T) {
	input := strings.Replace(validEvent, `"fingerprint": "abcdef"`, `"extra": true, "fingerprint": "abcdef"`, 1)
	if _, err := Decode(strings.NewReader(input)); err == nil {
		t.Fatal("Decode() accepted an unknown field")
	}
}
