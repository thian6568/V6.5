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

  echo "==> Applying migrations 0001, 0002, 0003, 0004, 0005, 0006, 0007, 0008, 0009, 0010, 0011, 0012, 0013"
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

  echo "SUCCESS: migrations 0001-0013 and Migration 008/009/010/011/012 assertions validated."
}

main "$@"
