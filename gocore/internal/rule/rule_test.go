package rule

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/viet15t12/CAMS/gocore/internal/event"
)

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

func TestDecodeRejectsArbitraryAction(t *testing.T) {
	bad := strings.Replace(icmpRule, `"acl.deny-protocol-source"`, `"restconf.raw"`, 1)
	if _, err := Decode(strings.NewReader(bad)); err == nil {
		t.Fatal("Decode() accepted arbitrary RESTCONF action")
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
