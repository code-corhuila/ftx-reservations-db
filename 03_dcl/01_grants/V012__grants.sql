-- V012 · Permissions of the reservations domain.
--   reservations_reader: read reservations only (reports, support).
--   reservations_writer: what ftx-reservations-api needs, and nothing more:
--     reservation      SELECT, INSERT, UPDATE   (never DELETE: history is kept, FR-035)
--     idempotency_key  SELECT, INSERT
--     outbox_event     SELECT, INSERT, UPDATE   (the relay marks rows as published)
--     processed_event  SELECT, INSERT
--   Never DDL: structure only comes from this repository.
-- Table by table, never ON ALL TABLES: the schema also holds flyway_schema_history.
-- Rollback: 05_rollbacks/03_dcl/01_grants/U012__grants.sql
GRANT USAGE ON SCHEMA reservations TO reservations_reader, reservations_writer;

GRANT SELECT ON reservations.reservation TO reservations_reader;

GRANT SELECT, INSERT, UPDATE ON reservations.reservation     TO reservations_writer;
GRANT SELECT, INSERT         ON reservations.idempotency_key TO reservations_writer;
GRANT SELECT, INSERT, UPDATE ON reservations.outbox_event    TO reservations_writer;
GRANT SELECT, INSERT         ON reservations.processed_event TO reservations_writer;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reservations_app') THEN
        GRANT reservations_writer TO reservations_app;
    ELSE
        RAISE NOTICE 'reservations_app does not exist yet: grant skipped (created by ftx-infra-postgres)';
    END IF;
END
$$;
