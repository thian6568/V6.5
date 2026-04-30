#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="$ROOT_DIR/backend/supabase/migrations"
TESTS_DIR="$ROOT_DIR/backend/supabase/tests"
DB_NAME="${DB_NAME:-artist_in_art_migration_validation}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
PSQL=(psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER")

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

apply_migrations() {
  echo "==> Bootstrapping local auth schema"
  "${PSQL[@]}" -d "$DB_NAME" -f "$TESTS_DIR/000_bootstrap_auth.sql"

  echo "==> Applying migrations 0001-0028"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0001_enum_types.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0002_migration_001_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0003_migration_002_artwork_core.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0004_migration_003_marketplace_orders.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0005_migration_004_financial_flows.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0006_migration_005_logistics.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0007_migration_006_environments.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0008_migration_007_content_admin_support.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0009_migration_008_submission_review.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0010_migration_009_marketplace_navigation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0011_migration_010_marketplace_filters_tags_search.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0012_migration_011_marketplace_sort_facets_saved_search.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0013_migration_012_marketplace_collections_wishlist.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0014_migration_013_marketplace_social_sharing.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0015_migration_014_marketplace_inquiries_contact.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0016_migration_015_marketplace_offers_negotiations.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0017_migration_016_marketplace_cart_checkout_intents.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0018_migration_017_checkout_contact_delivery_invoice_draft.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0019_migration_018_checkout_order_draft_conversion.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0020_migration_019_order_finalization_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0021_migration_020_order_status_lifecycle_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0022_migration_021_order_fulfillment_readiness_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0023_migration_022_order_handover_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0024_migration_023_order_completion_acceptance_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0025_migration_024_order_completion_evidence_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0026_migration_025_order_closure_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0027_migration_026_order_post_closure_audit_foundation.sql"
  "${PSQL[@]}" -d "$DB_NAME" -f "$MIGRATIONS_DIR/0028_migration_027_order_archive_foundation.sql"
}

run_assertions() {
  echo "==> Running enum/FK/unique/index/shared-artwork assertions"
  "${PSQL[@]}" -d "$DB_NAME" -f "$TESTS_DIR/001_assert_migration_002.sql"
}

main() {
  require_command createdb
  require_command dropdb
  require_command psql

  echo "==> Resetting database: $DB_NAME"
  dropdb --if-exists -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
  createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"

  echo "==> Pass 1: fresh apply"
  apply_migrations
  run_assertions

  echo "==> Pass 2: schema reset + re-apply"
  dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
  createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
  apply_migrations
  run_assertions

  echo "SUCCESS: migrations 0001-0028 and Migration 008/009/010/011/012/013/014/015/016/017/018/019/020/021/022/023/024/025/026/027 assertions validated."
}

main "$@"
