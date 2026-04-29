# Backend DB Validation Plan (Migrations 0001-0020)

This plan validates Migration 001 through Migration 020, implemented in files 0001 through 0021, against a real PostgreSQL/Supabase-compatible database before any next migration work.

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

## Migration 020 coverage

Migration 020 validates the backend foundation for order status lifecycle rules and event tracking after order finalization.

It adds and validates:

- `public.marketplace_order_status_lifecycle_event_type`
- `public.marketplace_order_status_change_source`
- `public.marketplace_order_status_lifecycle_rules`
- `public.marketplace_order_status_lifecycle_events`

## Migration 020 guardrails

Migration 020 must remain backend-only and must not introduce unrelated platform logic.

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
