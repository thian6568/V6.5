# ENUM_PLAN.md

## Goal
Define the controlled values used across the Artist In Art platform so:
- database state stays clean
- API responses stay consistent
- frontend and backend use the same status values
- Codex does not invent conflicting labels later
- marketplace, artwork authentication, and VR/WebGL gallery stay synchronized

## Rule
Enums must be created before or together with the tables that depend on them.

Do not create duplicate status meanings with different names.

Use enums consistently.

---

## Enums and allowed values

1. `role_name`: `admin`, `artist`, `buyer`
2. `profile_status`: `active`, `suspended`, `pending`, `archived`
3. `publish_status`: `draft`, `submitted`, `approved`, `live`, `paused`, `archived`
4. `visibility_mode`: `marketplace_only`, `vr_only`, `both`
5. `authentication_status`: `pending`, `approved`, `rejected`
6. `listing_status`: `draft`, `submitted`, `approved`, `live`, `paused`, `archived`
7. `order_status`: `pending`, `confirmed`, `processing`, `shipped`, `delivered`, `cancelled`, `refunded`, `disputed`
8. `escrow_status`: `pending`, `held`, `partially_released`, `released`, `disputed`, `cancelled`
9. `subscription_status`: `active`, `trial`, `past_due`, `cancelled`, `expired`
10. `refund_status`: `requested`, `under_review`, `approved`, `rejected`, `processed`
11. `dispute_type`: `authenticity`, `shipping_damage`, `lost_shipment`, `non_delivery`, `other`
12. `dispute_status`: `open`, `under_review`, `resolved`, `rejected`, `closed`
13. `shipping_status`: `pending`, `prepared`, `shipped`, `delivered`, `returned`, `lost`
14. `insurance_status`: `not_selected`, `selected`, `active`, `claimed`, `closed`
15. `environment_status`: `draft`, `active`, `inactive`, `archived`
16. `performance_tier`: `light`, `standard`, `premium`
17. `assignment_status`: `pending`, `active`, `removed`
18. `content_type`: `hero`, `text_block`, `image_block`, `video_block`, `artist_spotlight`, `artwork_feature`, `exhibition_feature`, `tagline`, `newsletter`, `cta`
19. `feature_type`: `artist`, `artwork`, `exhibition`
20. `notification_status`: `unread`, `read`, `archived`

---

## Recommended enum creation order

1. `role_name`
2. `profile_status`
3. `publish_status`
4. `visibility_mode`
5. `authentication_status`
6. `listing_status`
7. `order_status`
8. `escrow_status`
9. `subscription_status`
10. `refund_status`
11. `dispute_type`
12. `dispute_status`
13. `shipping_status`
14. `insurance_status`
15. `environment_status`
16. `performance_tier`
17. `assignment_status`
18. `content_type`
19. `feature_type`
20. `notification_status`

---

## Validation rules

Before using enums in migrations, confirm:
- each enum has one clear meaning
- no duplicate meanings exist under different labels
- frontend, backend, and API specs use the same labels
- shared artwork logic is not split across conflicting status systems
- marketplace and Unity both rely on the same `visibility_mode` enum
