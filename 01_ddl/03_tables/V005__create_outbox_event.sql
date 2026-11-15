-- V005 · outbox_event: transactional outbox (ADR-006, HU-RES-006).
-- The reservation change and its event are written in ONE transaction; a relay publishes the
-- pending rows to RabbitMQ (exchange futbolix.events) and marks them published. If the broker is
-- down, the events wait here instead of being lost, and the reservation is still created.
-- Rollback: 05_rollbacks/01_ddl/03_tables/U005__create_outbox_event.sql
CREATE TABLE reservations.outbox_event (
    id               uuid         NOT NULL DEFAULT gen_random_uuid(),   -- the eventId of the envelope
    aggregate_id     uuid         NOT NULL,
    event_type       varchar(40)  NOT NULL,
    routing_key      varchar(60)  NOT NULL,
    payload          jsonb        NOT NULL,                             -- the full event envelope
    occurred_at      timestamptz  NOT NULL DEFAULT now(),
    published_at     timestamptz,
    attempts         integer      NOT NULL DEFAULT 0,
    last_error       varchar(255),

    CONSTRAINT pk_outbox_event PRIMARY KEY (id),
    CONSTRAINT chk_outbox_event_type
        CHECK (event_type IN ('ReservationCreated', 'ReservationCancelled')),
    CONSTRAINT chk_outbox_event_routing_key
        CHECK (routing_key IN ('reservation.created', 'reservation.cancelled')),
    CONSTRAINT chk_outbox_event_attempts
        CHECK (attempts >= 0)
);

COMMENT ON TABLE reservations.outbox_event IS 'Events of the reservations domain waiting to be (or already) published to futbolix.events.';
