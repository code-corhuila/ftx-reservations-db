-- V002 · btree_gist lets one exclusion constraint combine "same court" (=) with
-- "overlapping time" (&&). It is the engine-level guarantee against double booking
-- (06-data/models.md, "Double-booking prevention"; principle P5).
--
-- Extensions belong to the whole instance. IF NOT EXISTS makes this a no-op when
-- ftx-infra-postgres already created it; it lives in public on purpose, like any
-- shared extension, and holds no data of this domain.
-- Rollback: 05_rollbacks/01_ddl/02_extensions/U002__create_extension_btree_gist.sql
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;
