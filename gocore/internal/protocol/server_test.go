package protocol

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestServerHandshakePingAndShutdown(t *testing.T) {
	rulesDir := t.TempDir()
	input := strings.Join([]string{
		helloLine(rulesDir),
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

func TestServerAcceptsAutoPlanningMode(t *testing.T) {
	input := fmt.Sprintf(`{"protocol_version":1,"type":"hello","request_id":"1","payload":{"mode":"auto","project_id":"project-1","rules_dir":%q}}`, t.TempDir()) + "\n"
	var output bytes.Buffer
	if err := NewServer(strings.NewReader(input), &output).Run(); err != nil {
		t.Fatalf("Run() rejected auto mode: %v", err)
	}
	if !strings.Contains(output.String(), `"mode":"auto"`) {
		t.Fatalf("unexpected output: %q", output.String())
	}
}

func TestServerEvaluatesRulesAndReturnsSimulatedAction(t *testing.T) {
	rulesDir := t.TempDir()
	ruleSource := `{
  "version":1,
  "metadata":{"id":"icmp","name":"ICMP","enabled":true},
  "schedule":{"interval_seconds":1},
  "match":{"event_type":"ACL_DROP_FLOOD","require_attributes":["offender_ip","interface","protocol"],"attributes":{"protocol":"icmp"}},
  "policy":{"mode":"dry-run","cooldown_seconds":60,"max_actions_per_hour":4},
  "action":{"type":"acl.deny-protocol-source","protocol":"icmp","source_from":"attributes.offender_ip","interface_from":"attributes.interface","ttl_seconds":300}
}`
	if err := os.WriteFile(filepath.Join(rulesDir, "icmp.json"), []byte(ruleSource), 0o600); err != nil {
		t.Fatal(err)
	}
	input := strings.Join([]string{
		helloLine(rulesDir),
		`{"protocol_version":1,"type":"evaluate","request_id":"2","payload":{"events":[{"schema_version":1,"event_id":"evt-1","event_type":"ACL_DROP_FLOOD","device_host":"192.0.2.1","detected_at":"2026-10-11T08:30:00Z","subject_key":"198.51.100.10","attributes":{"offender_ip":"198.51.100.10","interface":"GigabitEthernet1/0/2","protocol":"icmp"},"evidence":{},"fingerprint":"fp-1"}]}}`,
		`{"protocol_version":1,"type":"shutdown","request_id":"3"}`,
	}, "\n") + "\n"
	var output bytes.Buffer
	if err := NewServer(strings.NewReader(input), &output).Run(); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	for _, expected := range []string{`"type":"evaluate_result"`, `"action_type":"acl.deny-protocol-source"`, `"status":"simulated"`} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("output %q does not contain %q", output.String(), expected)
		}
	}
}

func helloLine(rulesDir string) string {
	return fmt.Sprintf(`{"protocol_version":1,"type":"hello","request_id":"1","payload":{"mode":"dry-run","project_id":"project-1","rules_dir":%q}}`, rulesDir)
}
