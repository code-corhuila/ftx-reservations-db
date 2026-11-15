-- V001 · Own schema of the reservations domain (Annex J.3: one schema per domain in the
-- single instance of ftx-infra-postgres). Nothing of this domain lives in public.
-- Rollback: 05_rollbacks/01_ddl/01_schemas/U001__create_schema_reservations.sql
CREATE SCHEMA IF NOT EXISTS reservations;
COMMENT ON SCHEMA reservations IS 'Reservations domain of Futbolix. Owned by ftx-reservations-db.';
