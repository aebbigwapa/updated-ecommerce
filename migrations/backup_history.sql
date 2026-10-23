-- Backup history table for admin backup feature
CREATE TABLE IF NOT EXISTS backup_history (
    id              uuid PRIMARY KEY,
    file_name       text NOT NULL,
    storage_path    text NOT NULL,
    file_url        text,
    file_size_kb    numeric(10,2) NOT NULL DEFAULT 0,
    total_rows      integer NOT NULL DEFAULT 0,
    row_counts      jsonb,
    triggered_by    text NOT NULL DEFAULT 'admin',
    notes           text,
    status          text NOT NULL DEFAULT 'success' CHECK (status IN ('success', 'failed')),
    errors          jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS backup_history_created_at_idx
    ON backup_history (created_at DESC);
