-- V008 · Lifecycle of a reservation, enforced by the engine (reservation-service.yaml):
--
--   PENDING ──(PaymentApproved)──> CONFIRMED ──(cancel)──> CANCELLED
--      ├──(PaymentRejected)──> REJECTED
--      └──(cancel)──────────> CANCELLED
--
-- CANCELLED and REJECTED are final. The data of a reservation (court, date, hours, amount,
-- code, contact) never changes after it is created: only its status moves.
-- Rollback: 05_rollbacks/01_ddl/07_functions/U008__create_function_guard_reservation_transition.sql
CREATE OR REPLACE FUNCTION reservations.guard_reservation_transition() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.reservation_code <> OLD.reservation_code
       OR NEW.court_id <> OLD.court_id
       OR NEW.reservation_date <> OLD.reservation_date
       OR NEW.start_time <> OLD.start_time
       OR NEW.end_time <> OLD.end_time
       OR NEW.amount <> OLD.amount
       OR NEW.customer_email <> OLD.customer_email THEN
        RAISE EXCEPTION 'a reservation cannot change its code, court, slot, amount or contact'
            USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.status <> OLD.status AND NOT (
           (OLD.status = 'PENDING'   AND NEW.status IN ('CONFIRMED', 'REJECTED', 'CANCELLED'))
        OR (OLD.status = 'CONFIRMED' AND NEW.status = 'CANCELLED')
    ) THEN
        RAISE EXCEPTION 'invalid reservation transition % -> %', OLD.status, NEW.status
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;
