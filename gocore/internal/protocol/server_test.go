package protocol

import (
	"bytes"
	"strings"
	"testing"
)

func TestServerHandshakePingAndShutdown(t *testing.T) {
	input := strings.Join([]string{
		`{"protocol_version":1,"type":"hello","request_id":"1","payload":{"mode":"dry-run","project_id":"project-1"}}`,
		`{"protocol_version":1,"type":"ping","request_id":"2"}`,
		`{"protocol_version":1,"type":"shutdown","request_id":"3"}`,
	}, "\n") + "\n"
	var output bytes.Buffer
	if err := NewServer(strings.NewReader(input), &output).Run(); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	for _, expected := range []string{`"type":"hello_ack"`, `"type":"pong"`, `"type":"shutdown_ack"`} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("output %q does not contain %q", output.String(), expected)
		}
	}
}

func TestServerRejectsMutationMode(t *testing.T) {
	input := `{"protocol_version":1,"type":"hello","request_id":"1","payload":{"mode":"auto","project_id":"project-1"}}` + "\n"
	var output bytes.Buffer
	if err := NewServer(strings.NewReader(input), &output).Run(); err == nil {
		t.Fatal("Run() accepted auto mode")
	}
	if !strings.Contains(output.String(), "only supports dry-run") {
		t.Fatalf("unexpected output: %q", output.String())
	}
}
