# Data Model (backend-core)

## Core Entities
- `users`, `roles`, `user_roles`
- `artworks`
- `artwork_authentication`
- `certificates`
- `ownership_history`
- `listings`
- `orders`
- `escrow_accounts`, `escrow_events`
- `subscriptions`
- `refund_requests`
- `disputes`
- `shipping_records`
- `insurance_records`
- `environments`
- `environment_assignments`

## Key Relationships
- `artworks.created_by -> users.id`
- `artwork_authentication.artwork_id -> artworks.id` (1:1 active)
- `certificates.artwork_id -> artworks.id` (1:many revisions)
- `ownership_history.artwork_id -> artworks.id` (append-only)
- `listings.artwork_id -> artworks.id` (at most one active listing)
- `orders.listing_id -> listings.id`
- `shipping_records.order_id -> orders.id`
- `insurance_records.order_id -> orders.id`
- `environment_assignments.artwork_id -> artworks.id`
