# ENUM_PLAN.md (backend-core)

Backend core must use the root enum plan as the canonical list of controlled values.

Source of truth: `../ENUM_PLAN.md`

## Backend requirement
- Create enum types in migrations before tables that consume them.
- Keep table columns aligned to enum names (for example: `publish_status`, `listing_status`, `environment_status`).
- Do not introduce duplicate status meanings under different labels.
