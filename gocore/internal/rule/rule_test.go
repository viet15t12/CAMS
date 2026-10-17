package rule

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/viet15t12/CAMS/gocore/internal/event"
)

const fixedInterfaceRule = `{
  "version": 1,
  "metadata": {"id":"shutdown-gi0-3-on-icmp-flood","name":"Shutdown Gi0/3","enabled":true},
  "schedule": {"interval_seconds":1},
  "match": {"event_type":"ICMP_FLOOD","require_attributes":[],"attributes":{"protocol":"icmp"}},
  "policy": {"mode":"auto","cooldown_seconds":300,"max_actions_per_hour":2},
  "action": {"type":"interface.admin-state","transport":"ssh","interface":"GigabitEthernet0/3","enabled":false,"ttl_seconds":0}
}`

const icmpRule = `{
  "version": 1,
  "metadata": {"id":"mitigate-icmp-dos","name":"Mitigate ICMP DoS","enabled":true},
  "schedule": {"interval_seconds":1},
  "match": {
    "event_type":"ACL_DROP_FLOOD",
    "require_attributes":["offender_ip","interface","protocol"],
    "attributes":{"protocol":"icmp"}
  },
  "policy": {"mode":"dry-run","cooldown_seconds":300,"max_actions_per_hour":6},
  "action": {
    "type":"acl.deny-protocol-source",
    "protocol":"icmp",
    "source_from":"attributes.offender_ip",
    "interface_from":"attributes.interface",
    "ttl_seconds":300
  }
}`

const cliRuleV2 = `{
  "version": 2,
  "metadata": {"id":"configure-ospf","name":"Configure OSPF","enabled":true},
  "schedule": {"interval_seconds":1},
  "match": {"event_type":"ICMP_FLOOD","require_attributes":[],"attributes":{"protocol":"icmp"}},
  "policy": {"mode":"auto","cooldown_seconds":300,"max_actions_per_hour":2},
  "action": {
    "type":"ssh.cli",
    "transport":"ssh",
    "mode":"config",
    "commands":["router ospf 1","network 10.0.0.0 0.0.0.255 area 0"],
    "verify_commands":["show ip ospf interface brief"],
    "ttl_seconds":0
  }
}`

func TestDecodeAndEvaluateICMPRule(t *testing.T) {
	value, err := Decode(strings.NewReader(icmpRule))
	if err != nil {
		t.Fatalf("Decode() error = %v", err)
	}
	eventValue := event.Event{
		SchemaVersion: 1, EventID: "evt-1", EventType: "ACL_DROP_FLOOD",
		DeviceHost: "192.0.2.1", SubjectKey: "198.51.100.10",
		DetectedAt: "2026-10-11T08:30:00Z", Fingerprint: "fp-1",
		Attributes: json.RawMessage(`{"offender_ip":"198.51.100.10","interface":"GigabitEthernet1/0/2","protocol":"ICMP"}`),
		Evidence:   json.RawMessage(`{"events":10}`),
	}
	plans, err := Evaluate([]Rule{value}, []event.Event{eventValue})
	if err != nil {
		t.Fatalf("Evaluate() error = %v", err)
	}
	if len(plans) != 1 {
		t.Fatalf("Evaluate() returned %d plans", len(plans))
	}
	if plans[0].Status != "simulated" || plans[0].RequestRedacted["source_ip"] != "198.51.100.10" {
		t.Fatalf("unexpected plan: %#v", plans[0])
	}
}

func TestEvaluateFailsClosedWithoutIngressInterface(t *testing.T) {
	value, err := Decode(strings.NewReader(icmpRule))
	if err != nil {
		t.Fatal(err)
	}
	eventValue := event.Event{
		SchemaVersion: 1, EventID: "evt-1", EventType: "ACL_DROP_FLOOD",
		DeviceHost: "192.0.2.1", SubjectKey: "198.51.100.10",
		DetectedAt: "2026-10-11T08:30:00Z", Fingerprint: "fp-1",
		Attributes: json.RawMessage(`{"offender_ip":"198.51.100.10","protocol":"icmp"}`),
		Evidence:   json.RawMessage(`{}`),
	}
	plans, err := Evaluate([]Rule{value}, []event.Event{eventValue})
	if err != nil {
		t.Fatal(err)
	}
	if len(plans) != 0 {
		t.Fatalf("unsafe action planned without interface: %#v", plans)
	}
}

func TestFixedInterfaceRulePlansAutoShutdown(t *testing.T) {
	value, err := Decode(strings.NewReader(fixedInterfaceRule))
	if err != nil {
		t.Fatal(err)
	}
	eventValue := event.Event{
		SchemaVersion: 1, EventID: "evt-icmp-flood", EventType: "ICMP_FLOOD",
		DeviceHost: "192.168.122.101", SubjectKey: "192.168.122.101",
		DetectedAt: "2026-10-15T02:45:15Z", Fingerprint: "fp-icmp-flood",
		Attributes: json.RawMessage(`{"protocol":"icmp"}`),
		Evidence:   json.RawMessage(`{"events":1}`),
	}
	plans, err := Evaluate([]Rule{value}, []event.Event{eventValue})
	if err != nil {
		t.Fatal(err)
	}
	if len(plans) != 1 {
		t.Fatalf("Evaluate() returned %d plans", len(plans))
	}
	request := plans[0].RequestRedacted
	if request["interface"] != "GigabitEthernet0/3" || request["enabled"] != false ||
		request["interface_binding"] != "literal" || request["transport"] != "ssh" ||
		request["dry_run"] != false ||
		plans[0].Mode != "auto" || plans[0].Status != "ready" {
		t.Fatalf("unexpected fixed-interface plan: %#v", plans[0])
	}
}

func TestVersion2PlansSSHCLICommands(t *testing.T) {
	value, err := Decode(strings.NewReader(cliRuleV2))
	if err != nil {
		t.Fatal(err)
	}
	eventValue := event.Event{
		SchemaVersion: 1, EventID: "evt-cli-v2", EventType: "ICMP_FLOOD",
		DeviceHost: "192.168.122.101", SubjectKey: "192.168.122.101",
		DetectedAt: "2026-10-15T02:45:15Z", Fingerprint: "fp-cli-v2",
		Attributes: json.RawMessage(`{"protocol":"icmp"}`),
		Evidence:   json.RawMessage(`{"events":1}`),
	}
	plans, err := Evaluate([]Rule{value}, []event.Event{eventValue})
	if err != nil {
		t.Fatal(err)
	}
	if len(plans) != 1 {
		t.Fatalf("Evaluate() returned %d plans", len(plans))
	}
	request := plans[0].RequestRedacted
	commands, ok := request["commands"].([]string)
	if !ok || len(commands) != 2 || commands[0] != "router ospf 1" {
		t.Fatalf("unexpected CLI commands: %#v", request["commands"])
	}
	if request["rule_version"] != 2 || request["transport"] != "ssh" ||
		request["mode"] != "config" || plans[0].ActionType != "ssh.cli" ||
		plans[0].Status != "ready" {
		t.Fatalf("unexpected version 2 plan: %#v", plans[0])
	}
}

func TestNetworkScopeMatchesOnlyDeviceHostInsideSubnet(t *testing.T) {
	scopedRule := strings.Replace(
		cliRuleV2,
		`"event_type":"ICMP_FLOOD"`,
		`"event_type":"ICMP_FLOOD","network":"192.168.122.0","subnet_mask":"255.255.255.0"`,
		1,
	)
	value, err := Decode(strings.NewReader(scopedRule))
	if err != nil {
		t.Fatal(err)
	}
	newEvent := func(id string, host string) event.Event {
		return event.Event{
			SchemaVersion: 1, EventID: id, EventType: "ICMP_FLOOD",
			DeviceHost: host, SubjectKey: host,
			DetectedAt: "2026-10-15T02:45:15Z", Fingerprint: "fp-" + id,
			Attributes: json.RawMessage(`{"protocol":"icmp"}`),
			Evidence:   json.RawMessage(`{"events":1}`),
		}
	}
	plans, err := Evaluate([]Rule{value}, []event.Event{
		newEvent("inside", "192.168.122.101"),
		newEvent("outside", "192.168.123.101"),
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(plans) != 1 || plans[0].EventID != "inside" {
		t.Fatalf("network scope planned unexpected actions: %#v", plans)
	}
}

func TestNetworkScopeRejectsIncompleteOrInvalidIPv4Subnet(t *testing.T) {
	cases := map[string]string{
		"missing subnet mask":   `"event_type":"ICMP_FLOOD","network":"192.168.122.0"`,
		"network has host bits": `"event_type":"ICMP_FLOOD","network":"192.168.122.101","subnet_mask":"255.255.255.0"`,
		"non-contiguous mask":   `"event_type":"ICMP_FLOOD","network":"192.168.122.0","subnet_mask":"255.0.255.0"`,
	}
	for name, matchFields := range cases {
		t.Run(name, func(t *testing.T) {
			candidate := strings.Replace(
				cliRuleV2,
				`"event_type":"ICMP_FLOOD"`,
				matchFields,
				1,
			)
			if _, err := Decode(strings.NewReader(candidate)); err == nil {
				t.Fatal("Decode() accepted an invalid network scope")
			}
		})
	}
}

func TestVersionContractsRejectMixedActionFields(t *testing.T) {
	badV1 := strings.Replace(
		fixedInterfaceRule,
		`"ttl_seconds":0`,
		`"ttl_seconds":0,"commands":["show clock"]`,
		1,
	)
	if _, err := Decode(strings.NewReader(badV1)); err == nil {
		t.Fatal("Decode() accepted version 2 fields in a version 1 action")
	}

	badV2 := strings.Replace(cliRuleV2, `"mode":"config"`, `"mode":"shell"`, 1)
	if _, err := Decode(strings.NewReader(badV2)); err == nil {
		t.Fatal("Decode() accepted an unsupported version 2 CLI mode")
	}

	newlineV2 := strings.Replace(
		cliRuleV2,
		`"router ospf 1"`,
		`"router ospf 1\nreload"`,
		1,
	)
	if _, err := Decode(strings.NewReader(newlineV2)); err == nil {
		t.Fatal("Decode() accepted a multi-line CLI command")
	}
}

func TestLoadDirectoryAcceptsCAMSRuleExtension(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "shutdown-icmp.rule.cams")
	if err := os.WriteFile(path, []byte(fixedInterfaceRule), 0o600); err != nil {
		t.Fatal(err)
	}
	rules, loadErrors, err := LoadDirectory(directory)
	if err != nil {
		t.Fatal(err)
	}
	if len(loadErrors) != 0 || len(rules) != 1 || rules[0].Source != "shutdown-icmp.rule.cams" {
		t.Fatalf("unexpected load result rules=%#v errors=%#v", rules, loadErrors)
	}
}

func TestDecodeRejectsArbitraryAction(t *testing.T) {
	bad := strings.Replace(icmpRule, `"acl.deny-protocol-source"`, `"network.raw"`, 1)
	if _, err := Decode(strings.NewReader(bad)); err == nil {
		t.Fatal("Decode() accepted an arbitrary network action")
	}
}

func TestScheduledEngineDefersNewEventUntilRuleInterval(t *testing.T) {
	value, err := Decode(strings.NewReader(icmpRule))
	if err != nil {
		t.Fatal(err)
	}
	newEvent := func(id string) event.Event {
		return event.Event{
			SchemaVersion: 1, EventID: id, EventType: "ACL_DROP_FLOOD",
			DeviceHost: "192.0.2.1", SubjectKey: "198.51.100.10",
			DetectedAt: "2026-10-11T08:30:00Z", Fingerprint: "fp-" + id,
			Attributes: json.RawMessage(`{"offender_ip":"198.51.100.10","interface":"GigabitEthernet1/0/2","protocol":"icmp"}`),
			Evidence:   json.RawMessage(`{}`),
		}
	}
	engine := NewEngine()
	start := time.Date(2026, 10, 11, 8, 30, 0, 0, time.UTC)
	first, err := engine.EvaluateScheduled([]Rule{value}, []event.Event{newEvent("evt-1")}, start)
	if err != nil || len(first.ProcessedEventIDs) != 1 || len(first.Actions) != 1 {
		t.Fatalf("unexpected first result %#v, error %v", first, err)
	}
	deferred, err := engine.EvaluateScheduled(
		[]Rule{value}, []event.Event{newEvent("evt-2")}, start.Add(500*time.Millisecond),
	)
	if err != nil || len(deferred.DeferredEventIDs) != 1 || len(deferred.Actions) != 0 {
		t.Fatalf("unexpected deferred result %#v, error %v", deferred, err)
	}
	ready, err := engine.EvaluateScheduled(
		[]Rule{value}, []event.Event{newEvent("evt-2")}, start.Add(time.Second),
	)
	if err != nil || len(ready.ProcessedEventIDs) != 1 || len(ready.Actions) != 1 {
		t.Fatalf("unexpected ready result %#v, error %v", ready, err)
	}
}
