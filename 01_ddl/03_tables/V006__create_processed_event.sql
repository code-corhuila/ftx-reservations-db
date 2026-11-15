-- V006 · processed_event: idempotent consumer (02-domain/domain-events.md, HU-RES-005).
-- PaymentApproved / PaymentRejected are delivered at least once. The eventId is stored in the same
-- transaction as the status change, so a redelivered event changes nothing.
-- Rollback: 05_rollbacks/01_ddl/03_tables/U006__create_processed_event.sql
CREATE TABLE reservations.processed_event (
    event_id      uuid        NOT NULL,
    event_type    varchar(40) NOT NULL,
    processed_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_processed_event PRIMARY KEY (event_id),
    CONSTRAINT chk_processed_event_type
        CHECK (event_type IN ('PaymentApproved', 'PaymentRejected'))
);

COMMENT ON TABLE reservations.processed_event IS 'Payment events already applied to a reservation (eventId = idempotency key).';
