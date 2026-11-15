-- V003 · reservation: the core table of Futbolix (06-data/models.md, table "reservations").
--
-- Adapted to the norm:
--   * Singular snake_case name (Annex A, rule 1).
--   * court_id references a court of the courts domain (ftx-courts-db): NO foreign key
--     (Annex A rule 8, Annex J.3.4). The API validates it through ftx-courts-api.
--   * Closed sets are CHECK constraints, never ENUM (Annex A, rule 5).
--   * Constraints have explicit names (Annex A, rule 4).
--   * amount is an integer number of COP, the Money schema of _shared.yaml (int64).
--   * Cancellation date, actor and reason are kept (FR-035). Rows are never deleted:
--     reservation history is part of the MVP (06-data/models.md, "Data retention").
-- Rollback: 05_rollbacks/01_ddl/03_tables/U003__create_reservation.sql
CREATE TABLE reservations.reservation (
    id                   uuid         NOT NULL DEFAULT gen_random_uuid(),
    reservation_code     varchar(20)  NOT NULL,

    customer_name        varchar(150) NOT NULL,
    customer_email       varchar(255) NOT NULL,
    customer_phone       varchar(30)  NOT NULL,

    court_id             uuid         NOT NULL,
    reservation_date     date         NOT NULL,
    start_time           time         NOT NULL,
    end_time             time         NOT NULL,

    status               varchar(20)  NOT NULL DEFAULT 'PENDING',
    amount               bigint       NOT NULL,
    currency             char(3)      NOT NULL DEFAULT 'COP',

    cancelled_at         timestamptz,
    cancelled_by         varchar(20),
    cancellation_reason  varchar(255),

    created_at           timestamptz  NOT NULL DEFAULT now(),
    updated_at           timestamptz  NOT NULL DEFAULT now(),

    -- Materialised range, generated so it can never drift from the start and end times.
    -- The CASE leaves an inverted range NULL, so chk_reservation_time rejects it with a clear
    -- check_violation instead of a "range lower bound" data error.
    period               tsrange GENERATED ALWAYS AS (
                             CASE WHEN end_time > start_time
                                  THEN tsrange(reservation_date + start_time,
                                               reservation_date + end_time, '[)')
                             END
                         ) STORED,

    CONSTRAINT pk_reservation PRIMARY KEY (id),

    CONSTRAINT chk_reservation_code_format
        CHECK (reservation_code ~ '^[A-Z0-9]{1,20}$'),

    CONSTRAINT chk_reservation_status
        CHECK (status IN ('PENDING', 'CONFIRMED', 'CANCELLED', 'REJECTED')),

    CONSTRAINT chk_reservation_amount
        CHECK (amount > 0),

    CONSTRAINT chk_reservation_currency
        CHECK (currency = 'COP'),

    -- BR-004: the end is after the start and the range covers whole hours.
    CONSTRAINT chk_reservation_time
        CHECK (end_time > start_time),
    CONSTRAINT chk_reservation_whole_hours
        CHECK (date_trunc('hour', start_time) = start_time
           AND date_trunc('hour', end_time) = end_time),

    -- FR-035: a cancelled reservation keeps who and when; any other status has neither.
    CONSTRAINT chk_reservation_cancelled_by
        CHECK (cancelled_by IS NULL OR cancelled_by IN ('CUSTOMER', 'ADMINISTRATOR')),
    CONSTRAINT chk_reservation_cancellation_data
        CHECK ((status = 'CANCELLED') = (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL)),

    -- BR-005: two ACTIVE reservations (PENDING or CONFIRMED) never overlap on the same court.
    -- The losing transaction gets SQLSTATE 23P01; the API answers 409 RESERVATION_SLOT_UNAVAILABLE.
    -- CANCELLED and REJECTED rows free their slot automatically: no cleanup job.
    CONSTRAINT reservations_no_double_booking
        EXCLUDE USING gist (court_id WITH =, period WITH &&)
        WHERE (status IN ('PENDING', 'CONFIRMED'))
);

COMMENT ON TABLE  reservations.reservation          IS 'Reservations and their lifecycle. Owned by the reservations domain.';
COMMENT ON COLUMN reservations.reservation.court_id IS 'Court of the courts domain (ftx-courts-db). No foreign key by design.';
COMMENT ON COLUMN reservations.reservation.reservation_code IS 'Unguessable code (SecureRandom). Works as the customer''s secret: never logged.';
COMMENT ON COLUMN reservations.reservation.amount   IS 'Integer COP: hourly price x hours, computed by the server, never sent by the client.';
