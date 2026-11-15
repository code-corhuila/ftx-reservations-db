-- U002 · Reverts V002__create_extension_btree_gist.sql
-- The extension belongs to the instance: it is dropped only when nothing else uses it.
DO $$
BEGIN
    BEGIN
        DROP EXTENSION IF EXISTS btree_gist RESTRICT;
    EXCEPTION WHEN dependent_objects_still_exist THEN
        RAISE NOTICE 'btree_gist is still used by another domain: kept';
    END;
END
$$;
