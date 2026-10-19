// Package rule loads declarative CAMS automation rules and matches them
// against versioned security events. Rules may describe intent, but never an
// arbitrary URL, transport payload, CLI command or SQL statement.
package rule

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/bits"
	"net/netip"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/viet15t12/CAMS/gocore/internal/event"
)

const (
	Version             = 3
	MinVersion          = 1
	MaxRuleBytes        = 256 << 10
	MaxRuleFiles        = 256
	RuleSuffix          = ".rule.cams"
	maxIdentifier       = 96
	maxCLICommands      = 100
	maxVerifyCommands   = 20
	maxCLICommandLength = 512
	maxCLITotalLength   = 16 << 10
	maxVariables        = 16
	maxVariablePattern  = 1024
)

var identifierPattern = regexp.MustCompile(`^[a-z0-9]+(?:[._-][a-z0-9]+)*$`)
var interfacePattern = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9./_-]*$`)
var variableNamePattern = regexp.MustCompile(`^[a-z][a-z0-9_]*$`)
var identifierValuePattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.-]*$`)
var templatePattern = regexp.MustCompile(`\{\{\s*variables\.([a-z][a-z0-9_]*)\s*\}\}`)

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
	Network           string            `json:"network,omitempty"`
	SubnetMask        string            `json:"subnet_mask,omitempty"`
	RequireAttributes []string          `json:"require_attributes,omitempty"`
	Attributes        map[string]string `json:"attributes,omitempty"`
}

type Policy struct {
	Mode              string `json:"mode"`
	CooldownSeconds   int    `json:"cooldown_seconds"`
	MaxActionsPerHour int    `json:"max_actions_per_hour"`
}

type Action struct {
	Type           string   `json:"type"`
	Transport      string   `json:"transport,omitempty"`
	Protocol       string   `json:"protocol,omitempty"`
	SourceFrom     string   `json:"source_from,omitempty"`
	InterfaceFrom  string   `json:"interface_from,omitempty"`
	Interface      string   `json:"interface,omitempty"`
	Enabled        *bool    `json:"enabled,omitempty"`
	TTLSeconds     int      `json:"ttl_seconds,omitempty"`
	Mode           string   `json:"mode,omitempty"`
	Commands       []string `json:"commands,omitempty"`
	VerifyCommands []string `json:"verify_commands,omitempty"`
}

// Variable describes a typed value extracted from a Syslog row selected by
// the Python host with a parameterized SQLite query. Rules never contain SQL.
type Variable struct {
	Source       string `json:"source"`
	Pattern      string `json:"pattern"`
	CaptureGroup int    `json:"capture_group"`
	Type         string `json:"type"`
}

type Rule struct {
	Version   int                 `json:"version"`
	Metadata  Metadata            `json:"metadata"`
	Schedule  Schedule            `json:"schedule"`
	Match     Match               `json:"match"`
	Policy    Policy              `json:"policy"`
	Variables map[string]Variable `json:"variables,omitempty"`
	Action    Action              `json:"action"`
	Revision  string              `json:"-"`
	Source    string              `json:"-"`
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
	if value.Version < MinVersion || value.Version > Version {
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
	if _, err := ipv4ScopePrefix(value.Match.Network, value.Match.SubnetMask); err != nil {
		return err
	}
	if value.Policy.Mode != "dry-run" && value.Policy.Mode != "auto" {
		return errors.New("policy.mode must be dry-run or auto")
	}
	if value.Policy.CooldownSeconds < 0 || value.Policy.CooldownSeconds > 86400 {
		return errors.New("policy.cooldown_seconds must be between 0 and 86400")
	}
	if value.Policy.MaxActionsPerHour < 1 || value.Policy.MaxActionsPerHour > 1000 {
		return errors.New("policy.max_actions_per_hour must be between 1 and 1000")
	}
	if err := value.validateVariables(); err != nil {
		return err
	}
	if err := value.Action.validate(value.Version); err != nil {
		return err
	}
	if value.Version == 1 && value.Policy.Mode == "auto" && value.Action.Type != "interface.admin-state" {
		return errors.New("auto mode currently supports interface.admin-state only")
	}
	if value.Version == 1 && value.Policy.Mode == "auto" && value.Action.Transport != "ssh" {
		return errors.New("auto interface actions require transport ssh")
	}
	if value.Version == 1 && value.Policy.Mode == "auto" && value.Action.TTLSeconds != 0 {
		return errors.New("auto interface actions require ttl_seconds 0 until revert is supported")
	}
	return nil
}

func (value Action) validate(version int) error {
	if value.TTLSeconds < 0 || value.TTLSeconds > 86400 {
		return errors.New("action.ttl_seconds must be between 0 and 86400")
	}
	if version >= 2 {
		if value.Type != "ssh.cli" {
			return fmt.Errorf("rule version %d requires action.type ssh.cli", version)
		}
		if value.Transport != "ssh" {
			return fmt.Errorf("version %d CLI actions require transport ssh", version)
		}
		if value.Mode != "config" && value.Mode != "exec" {
			return fmt.Errorf("version %d action.mode must be config or exec", version)
		}
		if err := validateCLICommands(value.Commands, "action.commands", maxCLICommands, true); err != nil {
			return err
		}
		if err := validateCLICommands(value.VerifyCommands, "action.verify_commands", maxVerifyCommands, false); err != nil {
			return err
		}
		if value.TTLSeconds != 0 {
			return fmt.Errorf("version %d CLI actions require ttl_seconds 0", version)
		}
		if value.Protocol != "" || value.SourceFrom != "" || value.InterfaceFrom != "" ||
			value.Interface != "" || value.Enabled != nil {
			return fmt.Errorf("version %d CLI action contains version 1 fields", version)
		}
		return nil
	}
	if value.Mode != "" || len(value.Commands) != 0 || len(value.VerifyCommands) != 0 {
		return errors.New("rule version 1 action contains version 2 fields")
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
		if value.Transport != "" {
			return errors.New("ACL action does not accept transport")
		}
	case "interface.admin-state":
		literalInterface := strings.TrimSpace(value.Interface)
		if (value.InterfaceFrom != "") == (literalInterface != "") {
			return errors.New("interface action requires exactly one of interface_from or interface")
		}
		if value.InterfaceFrom != "" && value.InterfaceFrom != "attributes.interface" {
			return errors.New("interface action interface_from must be attributes.interface")
		}
		if literalInterface != "" && (len(literalInterface) > 128 || !interfacePattern.MatchString(literalInterface)) {
			return errors.New("interface action interface is invalid")
		}
		if value.Transport != "" && value.Transport != "ssh" {
			return errors.New("interface action transport must be ssh")
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

func (value Rule) validateVariables() error {
	if value.Version < 3 {
		if len(value.Variables) != 0 {
			return errors.New("rule versions 1 and 2 do not accept variables")
		}
		return nil
	}
	if len(value.Variables) == 0 || len(value.Variables) > maxVariables {
		return fmt.Errorf("rule version 3 requires between 1 and %d variables", maxVariables)
	}
	for name, variable := range value.Variables {
		if !variableNamePattern.MatchString(name) || len(name) > maxIdentifier {
			return fmt.Errorf("invalid variable name %q", name)
		}
		if variable.Source != "sqlite.syslog_message.message" &&
			variable.Source != "sqlite.syslog_message.raw_message" {
			return fmt.Errorf("variable %q has unsupported source", name)
		}
		if variable.Pattern == "" || len(variable.Pattern) > maxVariablePattern {
			return fmt.Errorf("variable %q pattern is required and must not exceed %d characters", name, maxVariablePattern)
		}
		compiled, err := regexp.Compile(variable.Pattern)
		if err != nil {
			return fmt.Errorf("variable %q pattern: %w", name, err)
		}
		if variable.CaptureGroup < 1 || variable.CaptureGroup > compiled.NumSubexp() {
			return fmt.Errorf("variable %q capture_group must identify a regex capture", name)
		}
		if variable.Type != "interface" && variable.Type != "ipv4" && variable.Type != "identifier" {
			return fmt.Errorf("variable %q type must be interface, ipv4 or identifier", name)
		}
	}
	used := make(map[string]struct{})
	for _, command := range append(append([]string(nil), value.Action.Commands...), value.Action.VerifyCommands...) {
		matches := templatePattern.FindAllStringSubmatch(command, -1)
		withoutTemplates := templatePattern.ReplaceAllString(command, "")
		if strings.Contains(withoutTemplates, "{{") || strings.Contains(withoutTemplates, "}}") {
			return errors.New("version 3 commands contain an invalid variable template")
		}
		for _, match := range matches {
			name := match[1]
			if _, ok := value.Variables[name]; !ok {
				return fmt.Errorf("version 3 command references undefined variable %q", name)
			}
			used[name] = struct{}{}
		}
	}
	if len(used) == 0 {
		return errors.New("rule version 3 requires at least one variable reference in commands")
	}
	return nil
}

func validateCLICommands(commands []string, label string, maximum int, required bool) error {
	if required && len(commands) == 0 {
		return fmt.Errorf("%s must contain at least one command", label)
	}
	if len(commands) > maximum {
		return fmt.Errorf("%s must not contain more than %d commands", label, maximum)
	}
	total := 0
	for index, command := range commands {
		normalized := strings.TrimSpace(command)
		if normalized == "" || len(normalized) > maxCLICommandLength ||
			strings.ContainsAny(command, "\r\n\x00") {
			return fmt.Errorf(
				"%s[%d] must be one non-empty CLI line of at most %d characters",
				label, index, maxCLICommandLength,
			)
		}
		total += len(normalized)
	}
	if total > maxCLITotalLength {
		return fmt.Errorf("%s exceeds %d total characters", label, maxCLITotalLength)
	}
	return nil
}

func LoadDirectory(directory string) ([]Rule, []LoadError, error) {
	entries, err := os.ReadDir(directory)
	if err != nil {
		return nil, nil, fmt.Errorf("read rules directory: %w", err)
	}
	ruleFiles := make([]os.DirEntry, 0, len(entries))
	for _, entry := range entries {
		lowerName := strings.ToLower(entry.Name())
		if entry.Type()&os.ModeSymlink != 0 || entry.IsDir() ||
			(!strings.HasSuffix(lowerName, RuleSuffix) && filepath.Ext(lowerName) != ".json") {
			continue
		}
		ruleFiles = append(ruleFiles, entry)
	}
	if len(ruleFiles) > MaxRuleFiles {
		return nil, nil, fmt.Errorf("rules directory exceeds %d rule files", MaxRuleFiles)
	}
	sort.Slice(ruleFiles, func(i, j int) bool { return ruleFiles[i].Name() < ruleFiles[j].Name() })
	rules := make([]Rule, 0, len(ruleFiles))
	loadErrors := make([]LoadError, 0)
	seen := make(map[string]string)
	for _, entry := range ruleFiles {
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
	if currentRule.Match.Network != "" {
		prefix, err := ipv4ScopePrefix(currentRule.Match.Network, currentRule.Match.SubnetMask)
		if err != nil {
			return false
		}
		deviceHost, err := netip.ParseAddr(strings.TrimSpace(currentEvent.DeviceHost))
		if err != nil || !deviceHost.Is4() || !prefix.Contains(deviceHost) {
			return false
		}
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

func ipv4ScopePrefix(networkValue string, subnetMaskValue string) (netip.Prefix, error) {
	networkValue = strings.TrimSpace(networkValue)
	subnetMaskValue = strings.TrimSpace(subnetMaskValue)
	if (networkValue == "") != (subnetMaskValue == "") {
		return netip.Prefix{}, errors.New("match.network and match.subnet_mask must be provided together")
	}
	if networkValue == "" {
		return netip.Prefix{}, nil
	}
	networkAddress, err := netip.ParseAddr(networkValue)
	if err != nil || !networkAddress.Is4() {
		return netip.Prefix{}, errors.New("match.network must be a valid IPv4 network address")
	}
	maskAddress, err := netip.ParseAddr(subnetMaskValue)
	if err != nil || !maskAddress.Is4() {
		return netip.Prefix{}, errors.New("match.subnet_mask must be a valid IPv4 subnet mask")
	}
	octets := maskAddress.As4()
	mask := uint32(octets[0])<<24 | uint32(octets[1])<<16 | uint32(octets[2])<<8 | uint32(octets[3])
	prefixBits := bits.OnesCount32(mask)
	expectedMask := uint32(0)
	if prefixBits > 0 {
		expectedMask = ^uint32(0) << (32 - prefixBits)
	}
	if mask != expectedMask {
		return netip.Prefix{}, errors.New("match.subnet_mask must be a contiguous IPv4 subnet mask")
	}
	prefix := netip.PrefixFrom(networkAddress, prefixBits)
	if prefix.Masked().Addr() != networkAddress {
		return netip.Prefix{}, errors.New("match.network must be the canonical address for match.subnet_mask")
	}
	return prefix, nil
}

func planAction(currentRule Rule, currentEvent event.Event, attributes map[string]any) (PlannedAction, bool) {
	request := map[string]any{
		"driver":      currentRule.Action.Type,
		"device_host": currentEvent.DeviceHost,
		"dry_run":     currentRule.Policy.Mode == "dry-run",
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
		interfaceName := strings.TrimSpace(currentRule.Action.Interface)
		interfaceBinding := "literal"
		if interfaceName == "" {
			interfaceName = strings.TrimSpace(stringValue(attributes["interface"]))
			interfaceBinding = "event"
		}
		if interfaceName == "" || currentRule.Action.Enabled == nil {
			return PlannedAction{}, false
		}
		request["interface"] = interfaceName
		request["interface_binding"] = interfaceBinding
		if currentRule.Action.Transport != "" {
			request["transport"] = currentRule.Action.Transport
		}
		request["enabled"] = *currentRule.Action.Enabled
		request["ttl_seconds"] = currentRule.Action.TTLSeconds
	case "ssh.cli":
		commands := append([]string(nil), currentRule.Action.Commands...)
		verifyCommands := append([]string(nil), currentRule.Action.VerifyCommands...)
		if currentRule.Version == 3 {
			variables, sourceIDs, ok := resolveVariables(currentRule, currentEvent)
			if !ok {
				return PlannedAction{}, false
			}
			commands, ok = renderCommands(commands, variables)
			if !ok {
				return PlannedAction{}, false
			}
			verifyCommands, ok = renderCommands(verifyCommands, variables)
			if !ok {
				return PlannedAction{}, false
			}
			if err := validateCLICommands(commands, "rendered action.commands", maxCLICommands, true); err != nil {
				return PlannedAction{}, false
			}
			if err := validateCLICommands(verifyCommands, "rendered action.verify_commands", maxVerifyCommands, false); err != nil {
				return PlannedAction{}, false
			}
			request["variables"] = variables
			request["variable_source_message_ids"] = sourceIDs
		}
		request["rule_version"] = currentRule.Version
		request["transport"] = currentRule.Action.Transport
		request["mode"] = currentRule.Action.Mode
		request["commands"] = commands
		request["verify_commands"] = verifyCommands
		request["ttl_seconds"] = currentRule.Action.TTLSeconds
	default:
		return PlannedAction{}, false
	}
	dedupInput := currentEvent.EventID + "\x00" + currentRule.Metadata.ID + "\x00" + currentRule.Revision
	dedup := sha256.Sum256([]byte(dedupInput))
	status := "simulated"
	if currentRule.Policy.Mode == "auto" {
		status = "ready"
	}
	return PlannedAction{
		EventID: currentEvent.EventID, DeviceHost: currentEvent.DeviceHost,
		SubjectKey: currentEvent.SubjectKey, RuleID: currentRule.Metadata.ID,
		RuleRevision: currentRule.Revision, Mode: currentRule.Policy.Mode,
		ActionType: currentRule.Action.Type, Status: status,
		DedupKey:          hex.EncodeToString(dedup[:]),
		CooldownSeconds:   currentRule.Policy.CooldownSeconds,
		MaxActionsPerHour: currentRule.Policy.MaxActionsPerHour,
		RequestRedacted:   request,
	}, true
}

type sourceMessage struct {
	ID         int64  `json:"id"`
	Message    string `json:"message"`
	RawMessage string `json:"raw_message"`
}

type eventEvidence struct {
	SourceMessages []sourceMessage `json:"source_messages"`
}

func resolveVariables(currentRule Rule, currentEvent event.Event) (map[string]string, map[string]int64, bool) {
	var evidence eventEvidence
	if err := json.Unmarshal(currentEvent.Evidence, &evidence); err != nil || len(evidence.SourceMessages) == 0 {
		return nil, nil, false
	}
	values := make(map[string]string, len(currentRule.Variables))
	sourceIDs := make(map[string]int64, len(currentRule.Variables))
	for name, variable := range currentRule.Variables {
		compiled, err := regexp.Compile(variable.Pattern)
		if err != nil {
			return nil, nil, false
		}
		found := false
		for _, source := range evidence.SourceMessages {
			if source.ID <= 0 {
				continue
			}
			text := source.Message
			if variable.Source == "sqlite.syslog_message.raw_message" {
				text = source.RawMessage
			}
			match := compiled.FindStringSubmatch(text)
			if len(match) <= variable.CaptureGroup {
				continue
			}
			candidate := strings.TrimSpace(match[variable.CaptureGroup])
			if !validVariableValue(variable.Type, candidate) {
				continue
			}
			values[name] = candidate
			sourceIDs[name] = source.ID
			found = true
			break
		}
		if !found {
			return nil, nil, false
		}
	}
	return values, sourceIDs, true
}

func validVariableValue(variableType string, value string) bool {
	if value == "" || len(value) > 128 || strings.ContainsAny(value, "\r\n\x00") {
		return false
	}
	switch variableType {
	case "interface":
		return interfacePattern.MatchString(value)
	case "ipv4":
		address, err := netip.ParseAddr(value)
		return err == nil && address.Is4()
	case "identifier":
		return identifierValuePattern.MatchString(value)
	default:
		return false
	}
}

func renderCommands(commands []string, variables map[string]string) ([]string, bool) {
	rendered := make([]string, 0, len(commands))
	for _, command := range commands {
		valid := true
		value := templatePattern.ReplaceAllStringFunc(command, func(placeholder string) string {
			match := templatePattern.FindStringSubmatch(placeholder)
			if len(match) != 2 {
				valid = false
				return ""
			}
			replacement, ok := variables[match[1]]
			if !ok {
				valid = false
				return ""
			}
			return replacement
		})
		if !valid || strings.Contains(value, "{{") || strings.Contains(value, "}}") {
			return nil, false
		}
		rendered = append(rendered, value)
	}
	return rendered, true
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
