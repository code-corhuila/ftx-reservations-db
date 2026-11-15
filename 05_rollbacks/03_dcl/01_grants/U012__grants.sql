-- U012 · Reverts V012__grants.sql
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reservations_app') THEN
        REVOKE reservations_writer FROM reservations_app;
    END IF;
END
$$;
REVOKE ALL ON reservations.processed_event FROM reservations_writer;
REVOKE ALL ON reservations.outbox_event    FROM reservations_writer;
REVOKE ALL ON reservations.idempotency_key FROM reservations_writer;
REVOKE ALL ON reservations.reservation     FROM reservations_writer, reservations_reader;
REVOKE USAGE ON SCHEMA reservations FROM reservations_reader, reservations_writer;
