# Backend DB Validation Plan (Migrations 0001-0003)

This plan validates Migration 001 and Migration 002 against a **real PostgreSQL/Supabase-compatible database** before any Migration 003 work.

## Scope
- `0001_enum_types.sql`
- `0002_migration_001_foundation.sql`
- `0003_migration_002_artwork_core.sql`

## Goals
1. Verify migrations apply cleanly in order.
2. Verify schema reset/re-apply behavior.
3. Verify enum creation.
4. Verify foreign keys.
5. Verify unique constraints.
6. Verify indexes.
7. Re-confirm shared artwork rule:
   - one main artwork identity table (`public.artworks`)
   - no VR-only artwork table
   - no second upload identity path

## Validation workflow
Run:

```bash
scripts/db_validate_migrations.sh
```

The script performs:
1. DB reset (drop/create).
2. Bootstrap minimal `auth.users` for local validation.
3. Apply `0001`, `0002`, `0003` in strict order.
4. Execute SQL assertions (`backend/supabase/tests/001_assert_migration_002.sql`).
5. Repeat full reset and apply to validate reproducibility.

## SQL assertion coverage
`001_assert_migration_002.sql` checks:
- expected tables exist
- expected enums exist
- expected FKs exist
- expected unique constraints and unique indexes exist
- expected non-unique indexes exist
- no duplicate VR-specific artwork identity table names (`vr_artworks`, `gallery_artworks`, `marketplace_artworks`)

## Minimum environment/tooling
- PostgreSQL server reachable via env vars:
  - `DB_HOST` (default `127.0.0.1`)
  - `DB_PORT` (default `5432`)
  - `DB_USER` (default `postgres`)
  - `DB_NAME` (default `artist_in_art_migration_validation`)
- PostgreSQL client tools installed:
  - `psql`
  - `createdb`
  - `dropdb`

Optional:
- Supabase local stack or hosted dev DB, if preferred.

## What can be validated without DB
- migration file ordering
- migration object definitions by static inspection
- naming consistency across docs and SQL

## What requires real DB execution
- apply/reset success
- constraint creation behavior
- FK enforcement
- index materialization
- enum creation in actual catalog
- any runtime syntax/compatibility issues

## Pre-Migration 003 gate
Do not start Migration 003 until this validation passes in a real database environment.
