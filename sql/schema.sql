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

CREATE TABLE "load" (
  "category" VARCHAR,
  "number" INTEGER,
  "name" VARCHAR,
  "nickname" VARCHAR,
  "age" VARCHAR,
  "team" VARCHAR,
  "city" VARCHAR,
  "phone" VARCHAR,
  "email" VARCHAR,
  "comment" VARCHAR,
{{LOAD_STARTTIME_COLUMNS}}
);

CREATE TABLE "loadresult" (
  "number" INTEGER UNIQUE,
  "starttime" VARCHAR,
  "correction" INTEGER,
  "finishtime" VARCHAR,
  "penalty" VARCHAR,
  "status" VARCHAR
);

CREATE TABLE "start" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
  "number" INTEGER NOT NULL UNIQUE,
  "starttime" TEXT,
  "automaticstarttime" TEXT,
  "automaticcorrection" INTEGER,
  "automaticphonetime" TEXT,
  "manualstarttime" TEXT,
  "manualcorrection" INTEGER,
  "finishtime" TEXT
);

CREATE TABLE "finish" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
  "number" INTEGER UNIQUE,
  "finishtime" TEXT,
  "phonetime" TEXT,
  "set" INTEGER,
  "manual" INTEGER
);

CREATE TABLE "config" (
  "key" VARCHAR NOT NULL UNIQUE,
  "value" VARCHAR
);

CREATE TABLE "lora" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
  "number" INTEGER,
  "starttime" VARCHAR,
  "correction" VARCHAR,
  "isset" INTEGER,
  "timemark" VARCHAR
);

CREATE TABLE IF NOT EXISTS "sumdays" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
  "number" INTEGER UNIQUE,
  "place" INTEGER,
  "sumresult" VARCHAR,
  "sumstages" INTEGER,
  "diffleader" VARCHAR,
  "status" VARCHAR
);
