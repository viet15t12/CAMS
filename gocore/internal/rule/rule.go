// Package rule loads declarative CAMS automation rules and matches them
// against versioned security events. Rules may describe intent, but never an
// arbitrary RESTCONF URL, HTTP method, payload, command or SQL statement.
package rule

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/viet15t12/CAMS/gocore/internal/event"
)

const (
	Version       = 1
	MaxRuleBytes  = 256 << 10
	MaxRuleFiles  = 256
	maxIdentifier = 96
)

var identifierPattern = regexp.MustCompile(`^[a-z0-9]+(?:[._-][a-z0-9]+)*$`)

type Metadata struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
	Enabled     *bool  `json:"enabled"`
}

type Schedule struct {
	IntervalSeconds int `json:"interval_seconds"`
}

type Match struct {
	EventType         string            `json:"event_type"`
	RequireAttributes []string          `json:"require_attributes,omitempty"`
	Attributes        map[string]string `json:"attributes,omitempty"`
}

type Policy struct {
	Mode              string `json:"mode"`
	CooldownSeconds   int    `json:"cooldown_seconds"`
	MaxActionsPerHour int    `json:"max_actions_per_hour"`
}

type Action struct {
	Type          string `json:"type"`
	Protocol      string `json:"protocol,omitempty"`
	SourceFrom    string `json:"source_from,omitempty"`
	InterfaceFrom string `json:"interface_from,omitempty"`
	Enabled       *bool  `json:"enabled,omitempty"`
	TTLSeconds    int    `json:"ttl_seconds,omitempty"`
}

type Rule struct {
	Version  int      `json:"version"`
	Metadata Metadata `json:"metadata"`
	Schedule Schedule `json:"schedule"`
	Match    Match    `json:"match"`
	Policy   Policy   `json:"policy"`
	Action   Action   `json:"action"`
	Revision string   `json:"-"`
	Source   string   `json:"-"`
}

type LoadError struct {
	File  string `json:"file"`
	Error string `json:"error"`
}

type PlannedAction struct {
	EventID           string         `json:"event_id"`
	DeviceHost        string         `json:"device_host"`
	SubjectKey        string         `json:"subject_key"`
	RuleID            string         `json:"rule_id"`
	RuleRevision      string         `json:"rule_revision"`
	Mode              string         `json:"mode"`
	ActionType        string         `json:"action_type"`
	Status            string         `json:"status"`
	DedupKey          string         `json:"dedup_key"`
	CooldownSeconds   int            `json:"cooldown_seconds"`
	MaxActionsPerHour int            `json:"max_actions_per_hour"`
	RequestRedacted   map[string]any `json:"request_redacted"`
}

// ScheduledResult reports which events have been fully checked and which must
// remain pending until at least one matching rule reaches its next interval.
type ScheduledResult struct {
	Actions           []PlannedAction
	ProcessedEventIDs []string
	DeferredEventIDs  []string
}

// Engine retains only scheduling hints. Durable event/action state remains in
// SQLite on the Python side, so restarting the process is safe and dedup keys
// still prevent duplicate actions.
type Engine struct {
	lastRun   map[string]time.Time
	evaluated map[string]map[string]struct{}
}

func NewEngine() *Engine {
	return &Engine{
		lastRun:   make(map[string]time.Time),
		evaluated: make(map[string]map[string]struct{}),
	}
}

func Decode(reader io.Reader) (Rule, error) {
	data, err := io.ReadAll(io.LimitReader(reader, MaxRuleBytes+1))
	if err != nil {
		return Rule{}, fmt.Errorf("read rule: %w", err)
	}
	if len(data) > MaxRuleBytes {
		return Rule{}, fmt.Errorf("rule exceeds %d bytes", MaxRuleBytes)
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var value Rule
	if err := decoder.Decode(&value); err != nil {
		return Rule{}, fmt.Errorf("decode rule: %w", err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		return Rule{}, errors.New("rule must contain exactly one JSON value")
	}
	if err := value.Validate(); err != nil {
		return Rule{}, err
	}
	canonical, err := json.Marshal(value)
	if err != nil {
		return Rule{}, fmt.Errorf("canonicalize rule: %w", err)
	}
	revision := sha256.Sum256(canonical)
	value.Revision = hex.EncodeToString(revision[:])
	return value, nil
}

func (value Rule) Validate() error {
	if value.Version != Version {
		return fmt.Errorf("unsupported rule version %d", value.Version)
	}
	if !identifierPattern.MatchString(value.Metadata.ID) || len(value.Metadata.ID) > maxIdentifier {
		return errors.New("metadata.id must be a lowercase identifier of at most 96 characters")
	}
	if strings.TrimSpace(value.Metadata.Name) == "" || len(value.Metadata.Name) > 200 {
		return errors.New("metadata.name is required and must not exceed 200 characters")
	}
	if len(value.Metadata.Description) > 2000 {
		return errors.New("metadata.description must not exceed 2000 characters")
	}
	if value.Metadata.Enabled == nil {
		return errors.New("metadata.enabled is required")
	}
	if value.Schedule.IntervalSeconds < 1 || value.Schedule.IntervalSeconds > 3600 {
		return errors.New("schedule.interval_seconds must be between 1 and 3600")
	}
	if strings.TrimSpace(value.Match.EventType) == "" || len(value.Match.EventType) > 96 {
		return errors.New("match.event_type is required")
	}
	for _, attribute := range value.Match.RequireAttributes {
		if !validAttributeName(attribute) {
			return fmt.Errorf("invalid required attribute %q", attribute)
		}
	}
	for attribute, expected := range value.Match.Attributes {
		if !validAttributeName(attribute) || strings.TrimSpace(expected) == "" {
			return fmt.Errorf("invalid attribute match %q", attribute)
		}
	}
	if value.Policy.Mode != "dry-run" {
		return errors.New("this release only accepts policy.mode dry-run")
	}
	if value.Policy.CooldownSeconds < 0 || value.Policy.CooldownSeconds > 86400 {
		return errors.New("policy.cooldown_seconds must be between 0 and 86400")
	}
	if value.Policy.MaxActionsPerHour < 1 || value.Policy.MaxActionsPerHour > 1000 {
		return errors.New("policy.max_actions_per_hour must be between 1 and 1000")
	}
	return value.Action.validate()
}

func (value Action) validate() error {
	if value.TTLSeconds < 0 || value.TTLSeconds > 86400 {
		return errors.New("action.ttl_seconds must be between 0 and 86400")
	}
	switch value.Type {
	case "acl.deny-protocol-source":
		if value.Protocol != "icmp" && value.Protocol != "tcp" && value.Protocol != "udp" && value.Protocol != "ip" {
			return errors.New("ACL action protocol must be icmp, tcp, udp or ip")
		}
		if value.SourceFrom != "attributes.offender_ip" {
			return errors.New("ACL action source_from must be attributes.offender_ip")
		}
		if value.InterfaceFrom != "attributes.interface" {
			return errors.New("ACL action interface_from must be attributes.interface")
		}
		if value.Enabled != nil {
			return errors.New("ACL action does not accept enabled")
		}
	case "interface.admin-state":
		if value.InterfaceFrom != "attributes.interface" {
			return errors.New("interface action interface_from must be attributes.interface")
		}
		if value.Enabled == nil {
			return errors.New("interface action enabled is required")
		}
		if value.SourceFrom != "" || value.Protocol != "" {
			return errors.New("interface action does not accept source_from or protocol")
		}
	default:
		return fmt.Errorf("unsupported action.type %q", value.Type)
	}
	return nil
}

func LoadDirectory(directory string) ([]Rule, []LoadError, error) {
	entries, err := os.ReadDir(directory)
	if err != nil {
		return nil, nil, fmt.Errorf("read rules directory: %w", err)
	}
	jsonFiles := make([]os.DirEntry, 0, len(entries))
	for _, entry := range entries {
		if entry.Type()&os.ModeSymlink != 0 || entry.IsDir() || strings.ToLower(filepath.Ext(entry.Name())) != ".json" {
			continue
		}
		jsonFiles = append(jsonFiles, entry)
	}
	if len(jsonFiles) > MaxRuleFiles {
		return nil, nil, fmt.Errorf("rules directory exceeds %d JSON files", MaxRuleFiles)
	}
	sort.Slice(jsonFiles, func(i, j int) bool { return jsonFiles[i].Name() < jsonFiles[j].Name() })
	rules := make([]Rule, 0, len(jsonFiles))
	loadErrors := make([]LoadError, 0)
	seen := make(map[string]string)
	for _, entry := range jsonFiles {
		path := filepath.Join(directory, entry.Name())
		file, openErr := os.Open(path)
		if openErr != nil {
			loadErrors = append(loadErrors, LoadError{File: entry.Name(), Error: openErr.Error()})
			continue
		}
		value, decodeErr := Decode(file)
		closeErr := file.Close()
		if decodeErr == nil && closeErr != nil {
			decodeErr = closeErr
		}
		if decodeErr != nil {
			loadErrors = append(loadErrors, LoadError{File: entry.Name(), Error: decodeErr.Error()})
			continue
		}
		if previous, exists := seen[value.Metadata.ID]; exists {
			loadErrors = append(loadErrors, LoadError{
				File: entry.Name(), Error: fmt.Sprintf("duplicate metadata.id already used by %s", previous),
			})
			continue
		}
		seen[value.Metadata.ID] = entry.Name()
		value.Source = entry.Name()
		rules = append(rules, value)
	}
	return rules, loadErrors, nil
}

func Evaluate(rules []Rule, events []event.Event) ([]PlannedAction, error) {
	result := make([]PlannedAction, 0)
	for _, currentEvent := range events {
		if err := currentEvent.Validate(); err != nil {
			return nil, fmt.Errorf("event %q: %w", currentEvent.EventID, err)
		}
		attributes := make(map[string]any)
		if err := json.Unmarshal(currentEvent.Attributes, &attributes); err != nil {
			return nil, fmt.Errorf("event %q attributes: %w", currentEvent.EventID, err)
		}
		for _, currentRule := range rules {
			if currentRule.Metadata.Enabled == nil || !*currentRule.Metadata.Enabled || !matches(currentRule, currentEvent, attributes) {
				continue
			}
			plan, ok := planAction(currentRule, currentEvent, attributes)
			if ok {
				result = append(result, plan)
			}
		}
	}
	return result, nil
}

// EvaluateScheduled applies each rule no more often than its declared
// interval. An event is processed only after every rule matching that event
// has run; callers should resend deferred events on the next scheduler tick.
func (engine *Engine) EvaluateScheduled(
	rules []Rule, events []event.Event, now time.Time,
) (ScheduledResult, error) {
	result := ScheduledResult{
		Actions:           make([]PlannedAction, 0),
		ProcessedEventIDs: make([]string, 0),
		DeferredEventIDs:  make([]string, 0),
	}
	ranRules := make(map[string]struct{})
	for _, currentEvent := range events {
		if err := currentEvent.Validate(); err != nil {
			return ScheduledResult{}, fmt.Errorf("event %q: %w", currentEvent.EventID, err)
		}
		attributes := make(map[string]any)
		if err := json.Unmarshal(currentEvent.Attributes, &attributes); err != nil {
			return ScheduledResult{}, fmt.Errorf("event %q attributes: %w", currentEvent.EventID, err)
		}
		complete := true
		if engine.evaluated[currentEvent.EventID] == nil {
			engine.evaluated[currentEvent.EventID] = make(map[string]struct{})
		}
		for _, currentRule := range rules {
			if currentRule.Metadata.Enabled == nil || !*currentRule.Metadata.Enabled || !matches(currentRule, currentEvent, attributes) {
				continue
			}
			ruleKey := currentRule.Metadata.ID + ":" + currentRule.Revision
			if _, already := engine.evaluated[currentEvent.EventID][ruleKey]; already {
				continue
			}
			last := engine.lastRun[ruleKey]
			interval := time.Duration(currentRule.Schedule.IntervalSeconds) * time.Second
			if !last.IsZero() && now.Sub(last) < interval {
				complete = false
				continue
			}
			if plan, ok := planAction(currentRule, currentEvent, attributes); ok {
				result.Actions = append(result.Actions, plan)
			}
			engine.evaluated[currentEvent.EventID][ruleKey] = struct{}{}
			ranRules[ruleKey] = struct{}{}
		}
		if complete {
			result.ProcessedEventIDs = append(result.ProcessedEventIDs, currentEvent.EventID)
			delete(engine.evaluated, currentEvent.EventID)
		} else {
			result.DeferredEventIDs = append(result.DeferredEventIDs, currentEvent.EventID)
		}
	}
	for ruleKey := range ranRules {
		engine.lastRun[ruleKey] = now
	}
	return result, nil
}

func matches(currentRule Rule, currentEvent event.Event, attributes map[string]any) bool {
	if currentRule.Match.EventType != currentEvent.EventType {
		return false
	}
	for _, name := range currentRule.Match.RequireAttributes {
		if strings.TrimSpace(stringValue(attributes[name])) == "" {
			return false
		}
	}
	for name, expected := range currentRule.Match.Attributes {
		if !strings.EqualFold(strings.TrimSpace(stringValue(attributes[name])), strings.TrimSpace(expected)) {
			return false
		}
	}
	return true
}

func planAction(currentRule Rule, currentEvent event.Event, attributes map[string]any) (PlannedAction, bool) {
	request := map[string]any{
		"driver":      currentRule.Action.Type,
		"device_host": currentEvent.DeviceHost,
		"dry_run":     true,
	}
	switch currentRule.Action.Type {
	case "acl.deny-protocol-source":
		source := strings.TrimSpace(stringValue(attributes["offender_ip"]))
		interfaceName := strings.TrimSpace(stringValue(attributes["interface"]))
		if source == "" || interfaceName == "" {
			return PlannedAction{}, false
		}
		request["protocol"] = currentRule.Action.Protocol
		request["source_ip"] = source
		request["interface"] = interfaceName
		request["ttl_seconds"] = currentRule.Action.TTLSeconds
	case "interface.admin-state":
		interfaceName := strings.TrimSpace(stringValue(attributes["interface"]))
		if interfaceName == "" || currentRule.Action.Enabled == nil {
			return PlannedAction{}, false
		}
		request["interface"] = interfaceName
		request["enabled"] = *currentRule.Action.Enabled
		request["ttl_seconds"] = currentRule.Action.TTLSeconds
	default:
		return PlannedAction{}, false
	}
	dedupInput := currentEvent.EventID + "\x00" + currentRule.Metadata.ID + "\x00" + currentRule.Revision
	dedup := sha256.Sum256([]byte(dedupInput))
	return PlannedAction{
		EventID: currentEvent.EventID, DeviceHost: currentEvent.DeviceHost,
		SubjectKey: currentEvent.SubjectKey, RuleID: currentRule.Metadata.ID,
		RuleRevision: currentRule.Revision, Mode: currentRule.Policy.Mode,
		ActionType: currentRule.Action.Type, Status: "simulated",
		DedupKey:          hex.EncodeToString(dedup[:]),
		CooldownSeconds:   currentRule.Policy.CooldownSeconds,
		MaxActionsPerHour: currentRule.Policy.MaxActionsPerHour,
		RequestRedacted:   request,
	}, true
}

func validAttributeName(value string) bool {
	return identifierPattern.MatchString(value) && len(value) <= maxIdentifier
}

func stringValue(value any) string {
	switch typed := value.(type) {
	case string:
		return typed
	case json.Number:
		return typed.String()
	default:
		return ""
	}
}
