# Supabase RLS Policies (Blueprint)

This folder contains the row-level security baseline for the backend-core MVP.

## Files
- `001_rls_policies.sql`: enables RLS and defines default policies for all core tables.

## Why this exists
- Protect the single shared artwork source of truth (`artworks`).
- Prevent duplicate marketplace/VR artwork storage paths.
- Keep approval and financial workflows admin-controlled.
- Provide owner-scoped access for artists and buyers.

## Deployment notes
1. Apply schema migrations first.
2. Apply this RLS script after all referenced tables/columns exist.
3. Replace placeholder status-column assumptions if schema names differ.
4. Add per-table integration tests in `backend/supabase/tests` for select/insert/update/delete outcomes by role.


## Enum dependency
- Apply `backend/supabase/migrations/0001_enum_types.sql` before table migrations that use enum columns.
- Keep policy predicates aligned to enum values from `ENUM_PLAN.md` (for example `publish_status`, `listing_status`, `environment_status`).
