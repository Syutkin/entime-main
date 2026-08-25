CREATE TABLE "main" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
  "category" VARCHAR,
  "sumplace" INTEGER,
  "number" INTEGER UNIQUE,
  "rfid" VARCHAR,
  "name" VARCHAR,
  "nickname" VARCHAR,
  "age" VARCHAR,
  "team" VARCHAR,
  "city" VARCHAR,
  "phone" VARCHAR,
  "email" VARCHAR,
  "comment" VARCHAR,
{{STAGE_COLUMNS}}
  "sumresult" VARCHAR,
  "sumdiffleader" VARCHAR,
  "sumstages" INTEGER,
  "thrudiff" VARCHAR,
  "thruplace" INTEGER,
  "status" VARCHAR
);

CREATE TABLE "start" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
  "number" INTEGER NOT NULL UNIQUE,
  "starttime" VARCHAR,
  "automaticstarttime" VARCHAR,
  "automaticcorrection" INTEGER,
  "automaticphonetime" VARCHAR,
  "manualstarttime" VARCHAR,
  "manualcorrection" INTEGER,
  "finishtime" VARCHAR
);

CREATE TABLE "config" (
  "key" VARCHAR NOT NULL UNIQUE,
  "value" VARCHAR
);

CREATE TABLE IF NOT EXISTS "start_marks" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
  "stage_index" INTEGER NOT NULL CHECK ("stage_index" > 0),
  "applied_stage_index" INTEGER CHECK ("applied_stage_index" > 0),
  "event_time" VARCHAR NOT NULL,
  "correction_ms" INTEGER,
  "participant_number" INTEGER CHECK ("participant_number" > 0),
  "match_delta_ms" INTEGER CHECK ("match_delta_ms" >= 0),
  "source_kind" VARCHAR NOT NULL CHECK ("source_kind" IN ('serial', 'ble')),
  "source_device_id" VARCHAR NOT NULL,
  "received_at" VARCHAR NOT NULL,
  "assignment_mode" VARCHAR CHECK ("assignment_mode" IN ('manual', 'automatic')),
  "status" VARCHAR NOT NULL CHECK ("status" IN
    ('pending', 'applied', 'hidden', 'conflict', 'error')),
  "applied_at" VARCHAR,
  "diagnostic" TEXT
);

CREATE INDEX IF NOT EXISTS "idx_start_marks_status_received_at"
  ON "start_marks" ("status", "received_at");

CREATE INDEX IF NOT EXISTS "idx_start_marks_stage_event_time"
  ON "start_marks" ("stage_index", "event_time");

CREATE TABLE IF NOT EXISTS "finish_marks" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
  "stage_index" INTEGER NOT NULL CHECK ("stage_index" > 0),
  "event_time" VARCHAR NOT NULL,
  "participant_number" INTEGER CHECK ("participant_number" > 0),
  "source_kind" VARCHAR NOT NULL CHECK ("source_kind" IN
    ('serial', 'ble', 'manual')),
  "source_device_id" VARCHAR,
  "received_at" VARCHAR NOT NULL,
  "assignment_mode" VARCHAR CHECK ("assignment_mode" = 'manual'),
  "status" VARCHAR NOT NULL CHECK ("status" IN
    ('pending', 'applied', 'ignored_debounce', 'hidden', 'error')),
  "applied_at" VARCHAR,
  "diagnostic" TEXT
);

CREATE INDEX IF NOT EXISTS "idx_finish_marks_status_received_at"
  ON "finish_marks" ("status", "received_at");

CREATE INDEX IF NOT EXISTS "idx_finish_marks_stage_event_time"
  ON "finish_marks" ("stage_index", "event_time");
