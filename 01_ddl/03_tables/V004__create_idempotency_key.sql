-- V004 · idempotency_key: POST /reservations requires an Idempotency-Key (reservation-service.yaml).
-- Repeating a request with the same key returns the original reservation and never creates a
-- second one. The key and the reservation are written in the same transaction.
-- request_hash detects a key reused with a different body (answered 422 by the API).
-- Rollback: 05_rollbacks/01_ddl/03_tables/U004__create_idempotency_key.sql
CREATE TABLE reservations.idempotency_key (
    idempotency_key  uuid        NOT NULL,
    request_hash     char(64)    NOT NULL,
    reservation_id   uuid        NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_idempotency_key PRIMARY KEY (idempotency_key),
    -- Same domain, same schema: here a foreign key is correct.
    CONSTRAINT fk_idempotency_key_reservation
        FOREIGN KEY (reservation_id) REFERENCES reservations.reservation (id)
);

COMMENT ON TABLE reservations.idempotency_key IS 'Idempotency-Key of POST /reservations -> the reservation it created.';
