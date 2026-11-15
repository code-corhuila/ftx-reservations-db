-- V010 · Indexes (06-data/models.md).
-- Rollback: 05_rollbacks/01_ddl/10_indexes/U010__create_indexes.sql

-- The code is the customer's only key: unique, and the lookup of GET /reservations/{code}.
CREATE UNIQUE INDEX idx_reservation_reservation_code
    ON reservations.reservation (reservation_code);

-- GET /availability: the active reservations of one court on one date.
CREATE INDEX idx_reservation_court_id_reservation_date
    ON reservations.reservation (court_id, reservation_date, start_time, end_time);

-- GET /admin/reservations filters by status and dates, newest first.
CREATE INDEX idx_reservation_status
    ON reservations.reservation (status);
CREATE INDEX idx_reservation_reservation_date
    ON reservations.reservation (reservation_date);

-- The outbox relay reads only the pending events, oldest first.
CREATE INDEX idx_outbox_event_pending
    ON reservations.outbox_event (occurred_at)
    WHERE published_at IS NULL;
