# Backend-Core Migration Plan (Pre-Migration Summary)

This plan follows the required creation sequence from `MIGRATION_CHECKLIST.md`, keeps enums aligned to `ENUM_PLAN.md`, and protects `artworks` as the single source of truth.

## Required Creation Order
1. roles
2. profiles
3. audit_logs
4. artworks
5. artwork_assets
6. artwork_authentication
7. certificates
8. ownership_history
9. listings
10. orders
11. order_items
12. escrow_records
13. subscriptions
14. refund_requests
15. disputes
16. shipping_records
17. insurance_records
18. environments
19. environment_assignments
20. homepage_content
21. featured_content
22. notifications

## 1) Foreign Key Dependencies
- `profiles.role_id -> roles.id`
- `profiles.auth_user_id -> auth.users.id` (Supabase auth)
- `audit_logs.actor_profile_id -> profiles.id`
- `artworks.artist_profile_id -> profiles.id`
- `artwork_assets.artwork_id -> artworks.id`
- `artwork_authentication.artwork_id -> artworks.id`
- `artwork_authentication.verified_by_profile_id -> profiles.id`
- `certificates.artwork_id -> artworks.id`
- `ownership_history.artwork_id -> artworks.id`
- `ownership_history.owner_profile_id -> profiles.id`
- `listings.artwork_id -> artworks.id`
- `listings.seller_profile_id -> profiles.id`
- `orders.buyer_profile_id -> profiles.id`
- `order_items.order_id -> orders.id`
- `order_items.artwork_id -> artworks.id`
- `escrow_records.order_id -> orders.id`
- `subscriptions.profile_id -> profiles.id`
- `refund_requests.order_id -> orders.id`
- `refund_requests.requester_profile_id -> profiles.id`
- `disputes.order_id -> orders.id`
- `disputes.artwork_id -> artworks.id`
- `disputes.opened_by_profile_id -> profiles.id`
- `disputes.assigned_admin_profile_id -> profiles.id`
- `shipping_records.order_id -> orders.id`
- `insurance_records.order_id -> orders.id`
- `environment_assignments.environment_id -> environments.id`
- `environment_assignments.artwork_id -> artworks.id`
- `notifications.profile_id -> profiles.id`

## 2) Enum / Controlled Values Needed (exact)
- `role_name`: `admin`, `artist`, `buyer`
- `profile_status`: `active`, `suspended`, `pending`, `archived`
- `publish_status`: `draft`, `submitted`, `approved`, `live`, `paused`, `archived`
- `visibility_mode`: `marketplace_only`, `vr_only`, `both`
- `authentication_status`: `pending`, `approved`, `rejected`
- `listing_status`: `draft`, `submitted`, `approved`, `live`, `paused`, `archived`
- `order_status`: `pending`, `confirmed`, `processing`, `shipped`, `delivered`, `cancelled`, `refunded`, `disputed`
- `escrow_status`: `pending`, `held`, `partially_released`, `released`, `disputed`, `cancelled`
- `subscription_status`: `active`, `trial`, `past_due`, `cancelled`, `expired`
- `refund_status`: `requested`, `under_review`, `approved`, `rejected`, `processed`
- `dispute_type`: `authenticity`, `shipping_damage`, `lost_shipment`, `non_delivery`, `other`
- `dispute_status`: `open`, `under_review`, `resolved`, `rejected`, `closed`
- `shipping_status`: `pending`, `prepared`, `shipped`, `delivered`, `returned`, `lost`
- `insurance_status`: `not_selected`, `selected`, `active`, `claimed`, `closed`
- `environment_status`: `draft`, `active`, `inactive`, `archived`
- `performance_tier`: `light`, `standard`, `premium`
- `assignment_status`: `pending`, `active`, `removed`
- `content_type`: `hero`, `text_block`, `image_block`, `video_block`, `artist_spotlight`, `artwork_feature`, `exhibition_feature`, `tagline`, `newsletter`, `cta`
- `feature_type`: `artist`, `artwork`, `exhibition`
- `notification_status`: `unread`, `read`, `archived`

## 3) Row-Level Security (RLS) Application Order
1. profiles
2. audit_logs
3. artworks
4. artwork_assets
5. artwork_authentication
6. certificates
7. ownership_history
8. listings
9. orders
10. order_items
11. escrow_records
12. subscriptions
13. refund_requests
14. disputes
15. shipping_records
16. insurance_records
17. environments
18. environment_assignments
19. homepage_content
20. featured_content
21. notifications

## 4) Risks if Order is Changed
- FK breakage and migration churn from creating dependent tables before parents.
- Duplicate artwork identity paths if `artworks` is not established early and enforced as canonical.
- Marketplace/VR drift if listings or environment mappings are built without strict `artworks.id` references.
- Security regressions if auth/roles/RLS baseline is delayed.
- Financial workflow inconsistency if order/escrow/refund/dispute states are mixed or tables are created out of sequence.

## Critical Guardrails
- artworks is the single source of truth.
- `artworks` is the single source of truth.
- `artwork_assets`, `artwork_authentication`, `certificates`, `ownership_history`, `listings`, `order_items`, and `environment_assignments` must reference `artworks.id`.
- No VR-only artwork table and no second artwork creation path.
- Keep `visibility_mode` shared across marketplace and Unity.
- Keep artwork approval (`publish_status`) separate from authenticity approval (`authentication_status`) and listing approval (`listing_status`).
