-- Assertions for migrations 0001-0003.
-- This script must fail fast by raising exceptions when expected schema objects are missing.

-- Tables expected after 0001-0003.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'roles'),
      ('public', 'profiles'),
      ('public', 'audit_logs'),
      ('public', 'artworks'),
      ('public', 'artwork_assets'),
      ('public', 'artwork_authentication'),
      ('public', 'certificates'),
      ('public', 'ownership_history')
  ) as expected(schema_name, table_name)
  left join information_schema.tables t
    on t.table_schema = expected.schema_name
   and t.table_name = expected.table_name
  where t.table_name is null;

  if missing_count > 0 then
    raise exception 'Missing expected tables after migration apply: %', missing_count;
  end if;
end
$$;

-- Enum existence checks.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'role_name'),
      ('public', 'profile_status'),
      ('public', 'publish_status'),
      ('public', 'visibility_mode'),
      ('public', 'authentication_status')
  ) as expected(schema_name, type_name)
  left join pg_type t on t.typname = expected.type_name
  left join pg_namespace n on n.oid = t.typnamespace and n.nspname = expected.schema_name
  where n.oid is null;

  if missing_count > 0 then
    raise exception 'Missing expected enums after migration apply: %', missing_count;
  end if;
end
$$;

-- Foreign key checks for shared artwork rule dependencies.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('profiles', 'profiles_role_id_fkey'),
      ('profiles', 'profiles_auth_user_id_fkey'),
      ('audit_logs', 'audit_logs_actor_profile_id_fkey'),
      ('artworks', 'artworks_artist_profile_id_fkey'),
      ('artwork_assets', 'artwork_assets_artwork_id_fkey'),
      ('artwork_authentication', 'artwork_authentication_artwork_id_fkey'),
      ('artwork_authentication', 'artwork_authentication_verified_by_profile_id_fkey'),
      ('certificates', 'certificates_artwork_id_fkey'),
      ('certificates', 'certificates_issued_by_profile_id_fkey'),
      ('ownership_history', 'ownership_history_artwork_id_fkey'),
      ('ownership_history', 'ownership_history_owner_profile_id_fkey')
  ) as expected(table_name, constraint_name)
  left join information_schema.table_constraints tc
    on tc.table_schema = 'public'
   and tc.table_name = expected.table_name
   and tc.constraint_name = expected.constraint_name
   and tc.constraint_type = 'FOREIGN KEY'
  where tc.constraint_name is null;

  if missing_count > 0 then
    raise exception 'Missing expected foreign keys after migration apply: %', missing_count;
  end if;
end
$$;

-- Unique constraints / unique indexes checks.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'roles_name_key'),
      ('public', 'profiles_auth_user_id_key'),
      ('public', 'artwork_assets_unique_path_per_artwork'),
      ('public', 'artwork_authentication_artwork_id_key'),
      ('public', 'certificates_certificate_number_key'),
      ('public', 'ownership_history_one_current_owner_idx')
  ) as expected(schema_name, object_name)
  left join (
    select connamespace as namespace_oid, conname as object_name
    from pg_constraint
    where contype = 'u'
    union all
    select i.schemaname::regnamespace::oid as namespace_oid, i.indexname as object_name
    from pg_indexes i
  ) existing
    on existing.object_name = expected.object_name
   and existing.namespace_oid = expected.schema_name::regnamespace::oid
  where existing.object_name is null;

  if missing_count > 0 then
    raise exception 'Missing expected unique constraints/indexes after migration apply: %', missing_count;
  end if;
end
$$;

-- Index checks for Migration 002 performance paths.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('artworks_artist_profile_id_idx'),
      ('artworks_publish_status_idx'),
      ('artworks_visibility_mode_idx'),
      ('artwork_assets_artwork_id_idx'),
      ('artwork_assets_primary_idx'),
      ('artwork_authentication_status_idx'),
      ('artwork_authentication_verified_by_idx'),
      ('certificates_artwork_id_idx'),
      ('ownership_history_artwork_id_idx'),
      ('ownership_history_owner_profile_id_idx'),
      ('ownership_history_one_current_owner_idx')
  ) as expected(index_name)
  left join pg_indexes i
    on i.schemaname = 'public'
   and i.indexname = expected.index_name
  where i.indexname is null;

  if missing_count > 0 then
    raise exception 'Missing expected indexes after migration apply: %', missing_count;
  end if;
end
$$;

-- Shared artwork rule checks: single main artwork identity table and no VR-specific duplicate.
do $$
declare
  duplicate_count integer;
begin
  select count(*) into duplicate_count
  from information_schema.tables
  where table_schema = 'public'
    and table_name in ('vr_artworks', 'gallery_artworks', 'marketplace_artworks');

  if duplicate_count > 0 then
    raise exception 'Found duplicate/VR-specific artwork table(s): %', duplicate_count;
  end if;
end
$$;
