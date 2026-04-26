# Backend DB Validation Plan (Migrations 0001-0013)

This plan validates Migration 001 through Migration 012, implemented in files 0001 through 0013, against a **real PostgreSQL/Supabase-compatible database** before any Migration 013+ work.

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
- `0012_migration_011_marketplace_sort_facets_saved_search.sql`
- `0013_migration_012_marketplace_collections_wishlist.sql`

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

## Migration 012 coverage
Migration 012 validates the backend foundation for:

- `public.marketplace_collections`
- `public.marketplace_collection_items`
- `public.wishlists`
- `public.wishlist_items`

Guardrails preserved:

- `public.artworks` remains the single artwork identity path
- no second artwork table
- no second upload path
- no coupling to environments
- no coupling to homepage/admin content logic
- backend foundation only, no frontend implementation

## Validation workflow
Run:

```bash
bash scripts/db_validate_migrations.sh
