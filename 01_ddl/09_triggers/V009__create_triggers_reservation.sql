-- V009 · Triggers of reservation: lifecycle guard first, then updated_at.
-- Rollback: 05_rollbacks/01_ddl/09_triggers/U009__create_triggers_reservation.sql
CREATE TRIGGER trg_reservation_guard_transition
    BEFORE UPDATE ON reservations.reservation
    FOR EACH ROW
    EXECUTE FUNCTION reservations.guard_reservation_transition();

CREATE TRIGGER trg_reservation_updated_at
    BEFORE UPDATE ON reservations.reservation
    FOR EACH ROW
    EXECUTE FUNCTION reservations.set_updated_at();
