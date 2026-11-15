-- U009 · Reverts V009__create_triggers_reservation.sql
DROP TRIGGER IF EXISTS trg_reservation_updated_at ON reservations.reservation;
DROP TRIGGER IF EXISTS trg_reservation_guard_transition ON reservations.reservation;
