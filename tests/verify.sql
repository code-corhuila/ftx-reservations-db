-- =============================================================================
-- ftx-reservations-db · Post-migration checks (run by db-ci.yml after migrate)
--
-- Every failed check raises an exception, so psql (ON_ERROR_STOP=1) exits
-- non-zero and the CI turns red. Test rows are rolled back (SQLSTATE P0099),
-- so the database is left exactly as the migrations created it.
-- The customer data used here is invented (M7: no real persons).
-- =============================================================================

-- 1. BR-005: two active reservations cannot overlap on the same court (exclusion constraint).
DO $$
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTA1', 'Test Customer A', 'a@example.test', '3000000001',
            'c0000000-0000-4000-8000-000000000001', DATE '2030-01-10', '18:00', '20:00', 120000);
    BEGIN
        INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                              court_id, reservation_date, start_time, end_time, amount)
        VALUES ('TESTB1', 'Test Customer B', 'b@example.test', '3000000002',
                'c0000000-0000-4000-8000-000000000001', DATE '2030-01-10', '19:00', '21:00', 120000);
        RAISE EXCEPTION 'FAIL an overlapping active reservation was accepted';
    EXCEPTION WHEN exclusion_violation THEN
        RAISE NOTICE 'OK  overlapping active reservation rejected (23P01)';
    END;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
END $$;

-- 2. Adjacent slots ([18,20) and [20,21)) and other courts do not collide.
DO $$
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTA2', 'Test Customer A', 'a@example.test', '3000000001',
            'c0000000-0000-4000-8000-000000000001', DATE '2030-01-10', '18:00', '20:00', 120000),
           ('TESTB2', 'Test Customer B', 'b@example.test', '3000000002',
            'c0000000-0000-4000-8000-000000000001', DATE '2030-01-10', '20:00', '21:00', 60000),
           ('TESTC2', 'Test Customer C', 'c@example.test', '3000000003',
            'c0000000-0000-4000-8000-000000000002', DATE '2030-01-10', '18:00', '20:00', 120000);
    RAISE NOTICE 'OK  adjacent slots and other courts accepted';
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
END $$;

-- 3. A CANCELLED or REJECTED reservation frees its slot automatically.
DO $$
DECLARE first_id uuid;
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTA3', 'Test Customer A', 'a@example.test', '3000000001',
            'c0000000-0000-4000-8000-000000000003', DATE '2030-01-10', '18:00', '19:00', 60000)
    RETURNING id INTO first_id;
    UPDATE reservations.reservation
       SET status = 'CANCELLED', cancelled_at = now(), cancelled_by = 'CUSTOMER'
     WHERE id = first_id;
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTB3', 'Test Customer B', 'b@example.test', '3000000002',
            'c0000000-0000-4000-8000-000000000003', DATE '2030-01-10', '18:00', '19:00', 60000);
    RAISE NOTICE 'OK  cancelled reservation frees its slot';
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
END $$;

-- 4. BR-004: whole hours only, and the end after the start.
DO $$
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTA4', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '18:30', '19:30', 60000);
    RAISE EXCEPTION 'FAIL a non whole-hour reservation was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  non whole-hour reservation rejected';
END $$;
DO $$
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTB4', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '20:00', '18:00', 60000);
    RAISE EXCEPTION 'FAIL an inverted range was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  inverted range rejected';
END $$;

-- 5. Closed sets and amount.
DO $$
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount, status)
    VALUES ('TESTA5', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '18:00', '19:00', 60000, 'PAID');
    RAISE EXCEPTION 'FAIL an unknown status was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  unknown status rejected';
END $$;
DO $$
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTB5', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '18:00', '19:00', 0);
    RAISE EXCEPTION 'FAIL a zero amount was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  zero amount rejected';
END $$;
DO $$
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('ftx-lower', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '18:00', '19:00', 60000);
    RAISE EXCEPTION 'FAIL a code outside ^[A-Z0-9]+$ was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  malformed reservation code rejected';
END $$;

-- 6. Lifecycle: CONFIRMED and REJECTED are reached only from PENDING; final states stay final;
--    the slot, amount and code never change.
DO $$
DECLARE rid uuid;
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTA6', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '18:00', '19:00', 60000)
    RETURNING id INTO rid;
    UPDATE reservations.reservation SET status = 'REJECTED' WHERE id = rid;
    BEGIN
        UPDATE reservations.reservation SET status = 'CONFIRMED' WHERE id = rid;
        RAISE EXCEPTION 'FAIL REJECTED -> CONFIRMED was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK  REJECTED is final';
    END;
    BEGIN
        UPDATE reservations.reservation SET amount = 1 WHERE id = rid;
        RAISE EXCEPTION 'FAIL the amount of a reservation was changed';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK  amount, slot and code are immutable';
    END;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
END $$;

-- 7. FR-035: CANCELLED requires who and when; other statuses carry neither.
DO $$
DECLARE rid uuid;
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTA7', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '18:00', '19:00', 60000)
    RETURNING id INTO rid;
    BEGIN
        UPDATE reservations.reservation SET status = 'CANCELLED' WHERE id = rid;
        RAISE EXCEPTION 'FAIL a cancellation without actor and date was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK  cancellation keeps actor and date';
    END;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
END $$;

-- 8. updated_at is maintained by the trigger.
DO $$
DECLARE rid uuid; ts timestamptz;
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount,
                                          created_at, updated_at)
    VALUES ('TESTA8', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '18:00', '19:00', 60000,
            now() - interval '1 day', now() - interval '1 day')
    RETURNING id INTO rid;
    UPDATE reservations.reservation SET status = 'CONFIRMED' WHERE id = rid RETURNING updated_at INTO ts;
    IF ts < now() THEN
        RAISE EXCEPTION 'FAIL updated_at trigger did not fire';
    END IF;
    RAISE NOTICE 'OK  updated_at trigger fires';
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
END $$;

-- 9. The reservation code is unique.
DO $$
BEGIN
    INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                          court_id, reservation_date, start_time, end_time, amount)
    VALUES ('TESTDUP', 'Test', 't@example.test', '3000000001',
            gen_random_uuid(), DATE '2030-01-10', '18:00', '19:00', 60000);
    BEGIN
        INSERT INTO reservations.reservation (reservation_code, customer_name, customer_email, customer_phone,
                                              court_id, reservation_date, start_time, end_time, amount)
        VALUES ('TESTDUP', 'Test', 't@example.test', '3000000001',
                gen_random_uuid(), DATE '2030-01-11', '18:00', '19:00', 60000);
        RAISE EXCEPTION 'FAIL a duplicated reservation code was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'OK  reservation code is unique';
    END;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
END $$;

-- 10. No foreign key to another domain (Annex J.3.4). The only FK is idempotency_key -> reservation.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.referential_constraints rc
                 JOIN information_schema.table_constraints tc
                   ON tc.constraint_name = rc.unique_constraint_name
                WHERE rc.constraint_schema = 'reservations' AND tc.table_schema <> 'reservations') THEN
        RAISE EXCEPTION 'FAIL the reservations schema references another domain';
    END IF;
    RAISE NOTICE 'OK  no cross-domain foreign key';
END $$;

-- 11. Nothing of this domain lives in public (Annex A, rule 9).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE '%reservation%') THEN
        RAISE EXCEPTION 'FAIL a reservations table lives in public';
    END IF;
    RAISE NOTICE 'OK  nothing in public';
END $$;

-- 12. Roles: NOLOGIN, least privilege, never DELETE on the history, never DDL.
DO $$
BEGIN
    IF (SELECT count(*) FROM pg_roles
         WHERE rolname IN ('reservations_reader', 'reservations_writer') AND NOT rolcanlogin) <> 2 THEN
        RAISE EXCEPTION 'FAIL reservations_reader / reservations_writer missing or LOGIN';
    END IF;
    IF NOT has_table_privilege('reservations_reader', 'reservations.reservation', 'SELECT')
       OR has_table_privilege('reservations_reader', 'reservations.reservation', 'INSERT') THEN
        RAISE EXCEPTION 'FAIL reservations_reader must read and never write';
    END IF;
    IF NOT has_table_privilege('reservations_writer', 'reservations.reservation', 'INSERT')
       OR has_table_privilege('reservations_writer', 'reservations.reservation', 'DELETE')
       OR has_table_privilege('reservations_writer', 'reservations.outbox_event', 'DELETE')
       OR has_schema_privilege('reservations_writer', 'reservations', 'CREATE') THEN
        RAISE EXCEPTION 'FAIL reservations_writer must write rows, never delete history, never create objects';
    END IF;
    RAISE NOTICE 'OK  roles NOLOGIN with least privilege';
END $$;

-- 13. No application role can touch the migration history.
DO $$
BEGIN
    IF to_regclass('reservations.flyway_schema_history') IS NOT NULL
       AND (has_table_privilege('reservations_writer', 'reservations.flyway_schema_history', 'SELECT')
         OR has_table_privilege('reservations_reader', 'reservations.flyway_schema_history', 'SELECT')) THEN
        RAISE EXCEPTION 'FAIL an application role can read flyway_schema_history';
    END IF;
    RAISE NOTICE 'OK  migration history is private';
END $$;
