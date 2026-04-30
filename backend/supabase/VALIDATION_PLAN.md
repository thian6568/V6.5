# Backend DB Validation Plan (Migrations 0001-0024)

This plan validates Migration 001 through Migration 024, implemented in files 0001 through 0025, against a real PostgreSQL/Supabase-compatible database before any next migration work.

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
- `0014_migration_013_marketplace_social_sharing.sql`
- `0015_migration_014_marketplace_inquiries_contact.sql`
- `0016_migration_015_marketplace_offers_negotiations.sql`
- `0017_migration_016_marketplace_cart_checkout_intents.sql`
- `0018_migration_017_checkout_contact_delivery_invoice_draft.sql`
- `0019_migration_018_checkout_order_draft_conversion.sql`
- `0020_migration_019_order_finalization_foundation.sql`
- `0021_migration_020_order_status_lifecycle_foundation.sql`
- `0022_migration_021_order_fulfillment_readiness_foundation.sql`
- `0023_migration_022_order_handover_foundation.sql`
- `0024_migration_023_order_completion_acceptance_foundation.sql`
- `0025_migration_024_order_completion_evidence_foundation.sql`

## Goals

1. Verify migrations apply cleanly in order.
2. Verify schema reset/re-apply behavior.
3. Verify enum creation.
4. Verify foreign keys.
5. Verify unique constraints and unique indexes.
6. Verify check constraints.
7. Verify performance indexes.
8. Re-confirm shared artwork rule:
   - one main artwork identity table: `public.artworks`
   - no VR-only artwork table
   - no second upload identity path

## Migration 024 coverage

Migration 024 validates the backend foundation for order completion evidence records and completion evidence event tracking after completion acceptance.

It adds and validates:

- `public.marketplace_order_completion_evidence_status`
- `public.marketplace_order_completion_evidence_type`
- `public.marketplace_order_completion_evidence_event_type`
- `public.marketplace_order_completion_evidence_actor_role`
- `public.marketplace_order_completion_evidence_records`
- `public.marketplace_order_completion_evidence_events`

## Migration 024 guardrails

Migration 024 must remain backend-only and must not introduce unrelated platform logic.

Guardrails preserved:

- `public.artworks` remains the single artwork identity path
- no second artwork table
- no second upload path
- no coupling to environments
- no coupling to homepage/admin content logic
- backend foundation only, no frontend implementation
- no AI, bots, or agents
- no payment capture
- no payment gateway integration
- no escrow release logic
- no crypto
- no live shipping execution
- no real tax calculation execution
- no replacement of existing `public.orders`
- no replacement of existing `public.order_items`
- `public.orders` remains the final canonical order table

## Validation workflow

Run:

```bash
bash scripts/db_validate_migrations.sh
```

Expected validation behavior:

1. Create or reset the local validation database.
2. Bootstrap the local auth-compatible schema.
3. Apply migrations `0001` through `0025` in order.
4. Run assertion checks from `backend/supabase/tests/001_assert_migration_002.sql`.
5. Fail fast if any expected table, enum, foreign key, check constraint, unique constraint, or index is missing.

## GitHub Actions validation

The workflow file is:

```text
.github/workflows/backend-db-validation.yml
```

The workflow runs on:

- manual dispatch
- push changes touching migration validation files
- pull request changes touching migration validation files

The workflow uses PostgreSQL 16 and runs:

```bash
bash scripts/db_validate_migrations.sh
```

## Local testing notes

Syntax check:

```bash
bash -n scripts/db_validate_migrations.sh
```

Full local DB validation requires PostgreSQL tools such as:

- `createdb`
- `dropdb`
- `psql`

If these are not installed locally, full validation should be completed by GitHub Actions.

## Pull request acceptance checklist

Before merge, confirm:

- exactly 5 files are changed
- migration file exists for Migration 024
- DB assertion file includes Migration 024 checks
- workflow validates migrations `0001-0025`
- validation plan documents Migration 024
- GitHub Actions passes
- no frontend/UI files are changed
- no payment gateway files are changed
- no crypto files are changed
- no escrow release logic is changed
- no AI/bot/agent files are changed

## Expected changed files for this PR

This PR should contain exactly these 5 changed files:

```text
backend/supabase/migrations/0025_migration_024_order_completion_evidence_foundation.sql
backend/supabase/tests/001_assert_migration_002.sql
scripts/db_validate_migrations.sh
.github/workflows/backend-db-validation.yml
backend/supabase/VALIDATION_PLAN.md
```
