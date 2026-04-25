# Backend DB Validation Plan (Migrations 0001-0011)

This plan validates Migration 001 through Migration 010, implemented in files 0001 through 0011, against a **real PostgreSQL/Supabase-compatible database** before any Migration 011+ work.

## Scope
- `0001_enum_types.sql`
- `0002_migration_001_foundation.sql`
- `0003_migration_002_artwork_core.sql`
- `0004_migration_003_marketplace_orders.sql`
- `0005_migration_004_financial_flows.sql`
- `0006_migration_005_logistics.sql`
- `0007_migration_006_environments.sql`
- `0008_migration_007_content_admin_support.sql`
- `0009_migration_008_submission_review.sql`
- `0010_migration_009_marketplace_navigation.sql`
- `0011_migration_010_marketplace_filters_tags_search.sql`

## Goals
1. Verify migrations apply cleanly in order.
2. Verify schema reset/re-apply behavior.
3. Verify enum creation.
4. Verify foreign keys.
5. Verify unique constraints.
6. Verify check constraints.
7. Verify indexes.
8. Re-confirm shared artwork rule:
   - one main artwork identity table (`public.artworks`)
   - no VR-only artwork table
   - no second upload identity path

## Validation workflow
Run:

```bash
scripts/db_validate_migrations.sh
