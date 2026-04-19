# Artist In Art — Project Brief (backend-core)

## Purpose
`backend-core` is the single source of truth for platform data and business rules.

## Stack
- Supabase (Postgres, Auth, Storage, Realtime)
- TypeScript services (Edge Functions / API layer)
- Row-Level Security (RLS)
- Optional Redis queue for async workflows (notifications, settlements)

## Scope of this folder
- Database schema and migrations
- Authentication and authorization rules
- Shared artwork model and lifecycle logic
- Listings, orders, escrow, subscriptions, refunds, shipping, insurance
- Certificates, ownership history, and artwork authentication records
- APIs consumed by web-marketplace and unity-webgl-gallery
