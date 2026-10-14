-- Durable automation outbox and action audit state.
-- No credential or unredacted Authorization data belongs in these tables.

CREATE TABLE t13_automation_events (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id         TEXT NOT NULL UNIQUE,
    schema_version   INTEGER NOT NULL CHECK (schema_version = 1),
    event_type       TEXT NOT NULL,
    device_host      TEXT NOT NULL,
    subject_key      TEXT NOT NULL,
    attributes_json  TEXT NOT NULL DEFAULT '{}',
    evidence_json    TEXT NOT NULL DEFAULT '{}',
    source_alert_id  INTEGER UNIQUE,
    detected_at      TEXT NOT NULL,
    fingerprint      TEXT NOT NULL UNIQUE,
    status           TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'processed', 'ignored', 'failed')),
    created_at       TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (source_alert_id) REFERENCES t12_syslog_messages(id)
        ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE INDEX idx_t13_automation_events_status_time
    ON t13_automation_events(status, detected_at, id);
CREATE INDEX idx_t13_automation_events_device_time
    ON t13_automation_events(device_host, detected_at DESC);

CREATE TABLE t13_automation_actions (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id              TEXT NOT NULL,
    rule_id               TEXT NOT NULL,
    rule_revision         TEXT NOT NULL,
    mode                  TEXT NOT NULL DEFAULT 'dry-run'
                          CHECK (mode IN ('dry-run', 'approve', 'auto')),
    action_type           TEXT NOT NULL,
    status                TEXT NOT NULL DEFAULT 'detected'
                          CHECK (status IN (
                              'detected', 'simulated', 'pending_approval',
                              'approved', 'ready', 'claimed', 'applying',
                              'applied', 'verified', 'revert_due', 'reverting',
                              'reverted', 'failed', 'expired', 'cancelled',
                              'manual_intervention', 'noop_verified'
                          )),
    dedup_key             TEXT NOT NULL UNIQUE,
    attempts              INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    next_attempt_at       TEXT,
    lease_owner           TEXT,
    lease_until           TEXT,
    request_redacted_json TEXT,
    before_json           TEXT,
    after_json            TEXT,
    etag_before           TEXT,
    etag_after            TEXT,
    http_status           INTEGER,
    last_error            TEXT,
    approved_by           TEXT,
    approved_at           TEXT,
    applied_at            TEXT,
    verified_at           TEXT,
    revert_due_at         TEXT,
    reverted_at           TEXT,
    created_at            TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (event_id) REFERENCES t13_automation_events(event_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX idx_t13_automation_actions_ready
    ON t13_automation_actions(status, next_attempt_at, id);
CREATE INDEX idx_t13_automation_actions_revert
    ON t13_automation_actions(status, revert_due_at, id);
