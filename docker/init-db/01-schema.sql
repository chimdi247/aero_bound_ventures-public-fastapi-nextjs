-- ============================================================
-- Aero Bound Ventures schema bootstrap (PostgreSQL)
-- ============================================================
-- Runs automatically the FIRST time the db container starts against
-- an empty data volume (official postgres image behavior for
-- /docker-entrypoint-initdb.d). It will NOT re-run against an existing
-- volume -- see docker/README.md to reset it.
--
-- This is a line-for-line transcription of
-- backend/alembic/versions/2026_07_18_2346-20260718base_current_schema_baseline.py
-- (the app's actual Alembic baseline), not a re-derivation from the
-- SQLModel classes, so it matches exactly what the app's ORM queries
-- expect -- including the `ix_booking_id` index that duplicates the
-- primary key and the plural-looking but singular table names
-- (`userindb`, `usergroup`, etc.) SQLModel derives from the class
-- names.
--
-- The alembic_version bookkeeping table is seeded at the end so that,
-- if you later add real Alembic migrations, `alembic upgrade head`
-- correctly recognizes this database as already being at the
-- `20260718base` revision instead of trying to recreate these tables.
-- ============================================================

CREATE TABLE IF NOT EXISTS "group" (
    id          uuid PRIMARY KEY,
    name        VARCHAR NOT NULL,
    description VARCHAR,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ix_group_name ON "group" (name);

CREATE TABLE IF NOT EXISTS permission (
    id          uuid PRIMARY KEY,
    name        VARCHAR NOT NULL,
    codename    VARCHAR NOT NULL,
    description VARCHAR,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ix_permission_codename ON permission (codename);
CREATE UNIQUE INDEX IF NOT EXISTS ix_permission_name ON permission (name);

CREATE TABLE IF NOT EXISTS userindb (
    id                  uuid PRIMARY KEY,
    email               VARCHAR NOT NULL,
    password            VARCHAR,
    google_id           VARCHAR,
    auth_provider       VARCHAR NOT NULL,
    reset_token         VARCHAR,
    reset_token_expires TIMESTAMP WITH TIME ZONE,
    is_active           BOOLEAN NOT NULL,
    is_superuser        BOOLEAN NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ix_userindb_email ON userindb (email);
CREATE UNIQUE INDEX IF NOT EXISTS ix_userindb_google_id ON userindb (google_id);

CREATE TABLE IF NOT EXISTS booking (
    id                     uuid PRIMARY KEY,
    user_id                uuid NOT NULL REFERENCES userindb (id),
    flight_order_id        VARCHAR NOT NULL,
    status                 VARCHAR NOT NULL,
    created_at             TIMESTAMP WITH TIME ZONE NOT NULL,
    total_price            DOUBLE PRECISION NOT NULL,
    amadeus_order_response JSON,
    ticket_url             VARCHAR
);
CREATE INDEX IF NOT EXISTS ix_booking_cursor ON booking (created_at, id);
CREATE INDEX IF NOT EXISTS ix_booking_id ON booking (id);
CREATE INDEX IF NOT EXISTS ix_booking_user_cursor ON booking (user_id, created_at, id);

CREATE TABLE IF NOT EXISTS grouppermission (
    id            uuid PRIMARY KEY,
    group_id      uuid NOT NULL REFERENCES "group" (id),
    permission_id uuid NOT NULL REFERENCES permission (id),
    assigned_at   TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS notification (
    id         uuid PRIMARY KEY,
    user_id    uuid NOT NULL REFERENCES userindb (id),
    type       VARCHAR NOT NULL,
    message    VARCHAR NOT NULL,
    is_read    BOOLEAN NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_notification_user_cursor ON notification (user_id, created_at, id);

CREATE TABLE IF NOT EXISTS usergroup (
    id          uuid PRIMARY KEY,
    user_id     uuid NOT NULL REFERENCES userindb (id),
    group_id    uuid NOT NULL REFERENCES "group" (id),
    assigned_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS userpermission (
    id            uuid PRIMARY KEY,
    user_id       uuid NOT NULL REFERENCES userindb (id),
    permission_id uuid NOT NULL REFERENCES permission (id),
    assigned_at   TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Alembic's own bookkeeping table, seeded with the baseline revision
-- so future real migrations chain onto this state correctly.
CREATE TABLE IF NOT EXISTS alembic_version (
    version_num VARCHAR(32) NOT NULL PRIMARY KEY
);
INSERT INTO alembic_version (version_num)
VALUES ('20260718base')
ON CONFLICT (version_num) DO NOTHING;
