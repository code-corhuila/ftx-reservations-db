-- U010 · Reverts V010__create_indexes.sql
DROP INDEX IF EXISTS reservations.idx_outbox_event_pending;
DROP INDEX IF EXISTS reservations.idx_reservation_reservation_date;
DROP INDEX IF EXISTS reservations.idx_reservation_status;
DROP INDEX IF EXISTS reservations.idx_reservation_court_id_reservation_date;
DROP INDEX IF EXISTS reservations.idx_reservation_reservation_code;
