# API_SPEC.md

## API Purpose
This document defines the main API structure for Artist In Art.

The API must support:
- user authentication
- artwork authentication
- marketplace / e-commerce
- escrow
- subscriptions
- shipping
- insurance
- artist dashboard
- admin dashboard
- WebGL / VR gallery integration
- one shared artwork source of truth

## Core API Rule
All artwork-related APIs must use the same core artwork record.

This means:
- one artwork upload
- one main artwork record
- same record used by marketplace, dashboard, certificate, and VR/WebGL gallery
- no separate VR-only artwork upload path

---

# 1. Auth / Accounts

## POST /auth/register
Purpose:
- register a new user

Request:
- email
- password
- role
- display_name

Response:
- user id
- role
- status

## POST /auth/login
Purpose:
- login user

Request:
- email
- password

Response:
- access token
- refresh token
- user profile summary

## POST /auth/logout
Purpose:
- logout current session

## POST /auth/password-reset
Purpose:
- start password reset flow

## GET /profiles/me
Purpose:
- get current user profile

## PATCH /profiles/me
Purpose:
- update current user profile

## GET /admin/users
Purpose:
- admin list users

## PATCH /admin/users/:id/role
Purpose:
- admin update user role

---

# 2. Artworks

## POST /artworks
Purpose:
- create one main artwork record

Important:
- this is the only creation path for artwork record
- no second creation path for VR-only artwork

Request:
- title
- description
- category
- medium
- dimensions
- price
- currency
- visibility_mode

Response:
- artwork id
- artwork code
- status

## GET /artworks/:id
Purpose:
- get artwork detail

## PATCH /artworks/:id
Purpose:
- update artwork core data

Important:
- updates must affect the same shared record used by marketplace and VR

## POST /artworks/:id/assets
Purpose:
- attach artwork image / asset files

## GET /artworks/:id/assets
Purpose:
- list artwork assets

## POST /artworks/:id/submit-for-approval
Purpose:
- send artwork for admin review

## PATCH /artworks/:id/visibility
Purpose:
- update visibility mode

Allowed values:
- marketplace_only
- vr_only
- both

---

# 3. Artwork Authentication

## POST /artworks/:id/authenticate
Purpose:
- create or update artwork authentication record

Request:
- serial_number
- verification_notes
- certificate draft data

Response:
- authentication record id
- authentication status

## GET /authenticity/artwork/:artworkId
Purpose:
- public or controlled authenticity view

Returns:
- artwork id
- title
- artist
- serial number
- authenticity status
- certificate number
- ownership summary if allowed

## PATCH /admin/artworks/:id/authentication-status
Purpose:
- admin approve or reject artwork authentication

Allowed values:
- pending
- approved
- rejected

## GET /artworks/:id/certificate
Purpose:
- get certificate record for artwork

## POST /artworks/:id/certificate/generate
Purpose:
- generate certificate of authenticity

## GET /artworks/:id/ownership-history
Purpose:
- get ownership history for artwork

## POST /artworks/:id/ownership-history
Purpose:
- append ownership event

---

# 4. Marketplace Listings

## POST /listings
Purpose:
- create marketplace listing from existing artwork record

Important:
- listing must reference existing artwork_id
- listing must not create a second artwork record

Request:
- artwork_id
- listing_status
- price
- currency

## GET /listings
Purpose:
- list marketplace listings

Supports:
- search
- filter
- sorting
- featured mode

## GET /listings/:id
Purpose:
- get listing detail

## PATCH /listings/:id
Purpose:
- update listing

## PATCH /admin/listings/:id/status
Purpose:
- admin approve or reject listing

Allowed values:
- draft
- submitted
- approved
- live
- paused
- archived

---

# 5. Cart / Checkout / Orders

## POST /cart/items
Purpose:
- add item to cart

Request:
- artwork_id
- quantity

## GET /cart
Purpose:
- get current cart

## DELETE /cart/items/:id
Purpose:
- remove item from cart

## POST /checkout/session
Purpose:
- create checkout session

Response:
- checkout session id
- order draft
- totals
- shipping options
- insurance options

## POST /orders/:id/confirm
Purpose:
- confirm order after checkout

## GET /orders/:id
Purpose:
- get order detail

## GET /orders
Purpose:
- list user orders

## GET /admin/orders
Purpose:
- admin list all orders

---

# 6. Escrow

## POST /escrow/open
Purpose:
- open escrow record for order

Request:
- order_id
- hold_amount

## POST /escrow/release
Purpose:
- release escrow for order

Request:
- order_id
- release_amount
- release_reason

## GET /escrow/order/:orderId
Purpose:
- get escrow status for order

## PATCH /admin/escrow/:id/status
Purpose:
- admin update escrow status

Allowed values:
- pending
- held
- partially_released
- released
- disputed
- cancelled

---

# 7. Subscriptions

## GET /subscriptions/plans
Purpose:
- list available membership plans

## POST /subscriptions
Purpose:
- create subscription

Request:
- plan_name
- billing_choice
- user_id

## GET /subscriptions/me
Purpose:
- get current user subscription

## PATCH /subscriptions/:id/cancel
Purpose:
- cancel subscription

## GET /admin/subscriptions
Purpose:
- admin view subscriptions

---

# 8. Refunds / Disputes

## POST /refunds
Purpose:
- create refund request

Request:
- order_id
- requested_amount
- reason

## GET /refunds/:id
Purpose:
- get refund request detail

## PATCH /admin/refunds/:id/status
Purpose:
- admin approve / reject / adjust refund

## POST /disputes
Purpose:
- open dispute case

Request:
- order_id
- artwork_id
- dispute_type
- notes

## GET /disputes/:id
Purpose:
- get dispute detail

## PATCH /admin/disputes/:id/status
Purpose:
- admin update dispute status

---

# 9. Shipping / Insurance

## GET /shipping/options
Purpose:
- list shipping methods for cart or order

## POST /shipping
Purpose:
- create shipping record

Request:
- order_id
- carrier_name
- shipping_method
- destination

## GET /shipping/:orderId
Purpose:
- get shipping record for order

## PATCH /shipping/:id/status
Purpose:
- update shipment status

## POST /insurance
Purpose:
- create insurance record

Request:
- order_id
- provider_name
- insured_amount

## GET /insurance/:orderId
Purpose:
- get insurance record for order

---

# 10. Artist Dashboard

## GET /artist/artworks
Purpose:
- list artist’s artworks

## GET /artist/orders
Purpose:
- list artist sales/orders

## GET /artist/statements
Purpose:
- get artist statements

## GET /artist/payout-summary
Purpose:
- get payout summary

---

# 11. Admin Dashboard

## GET /admin/dashboard/summary
Purpose:
- admin overview metrics

## GET /admin/artworks/pending
Purpose:
- list artworks waiting for review

## GET /admin/featured-content
Purpose:
- get featured content list

## POST /admin/featured-content
Purpose:
- create featured content item

## PATCH /admin/featured-content/:id
Purpose:
- update featured content item

## GET /admin/audit-logs
Purpose:
- view audit logs

---

# 12. Homepage / CMS

## GET /homepage/content
Purpose:
- get homepage blocks and featured content

## PATCH /admin/homepage/content
Purpose:
- update homepage content

## GET /cms/pages/:slug
Purpose:
- get CMS page by slug

## PATCH /admin/cms/pages/:slug
Purpose:
- update CMS page

---

# 13. Environments / Unity / WebGL

## GET /environments
Purpose:
- list 3D environments

Returns:
- environment id
- name
- category
- thumbnail
- version
- performance tier

## GET /environments/:id
Purpose:
- get environment detail

## GET /environments/:id/approved-artworks
Purpose:
- list approved artworks assigned to this environment

Important:
- result must come from shared artwork record + environment assignment
- not from a separate VR artwork table

## POST /environment-assignments
Purpose:
- assign approved artwork to environment

Request:
- environment_id
- artwork_id
- wall_anchor_id
- placement_x
- placement_y
- placement_z
- rotation
- scale

## GET /environment-assignments/:environmentId
Purpose:
- get all assignments for one environment

## PATCH /environment-assignments/:id
Purpose:
- update assignment

## DELETE /environment-assignments/:id
Purpose:
- remove assignment

---

# 14. Certificates / Verification

## GET /verification/artwork/:artworkId
Purpose:
- verification page for artwork authenticity

## GET /verification/certificate/:certificateNumber
Purpose:
- certificate verification lookup

## GET /verification/serial/:serialNumber
Purpose:
- serial-number verification lookup

---

# 15. Notifications

## GET /notifications/me
Purpose:
- get current user notifications

## PATCH /notifications/:id/read
Purpose:
- mark notification as read

---

# 16. Audit / Logs

## GET /audit/artwork/:id
Purpose:
- get important audit trail for artwork

## GET /audit/order/:id
Purpose:
- get important audit trail for order

---

# 17. API Rules

## Shared artwork rules
- artworks table is the single source of truth
- listings must reference artwork_id
- certificates must reference artwork_id
- environment_assignments must reference artwork_id
- Unity must consume approved artwork data from shared backend
- no second artwork creation path for VR

## Approval rules
- artwork authentication approval must be admin-controlled
- listing approval must be admin-controlled
- VR/gallery visibility must respect approval and visibility state

## Security rules
- do not expose production secrets
- keep staging and production separate
- keep deployment portable
- do not bypass admin rules for financial or authenticity flows

## Implementation rules
- backend first
- web second
- Unity third
- deployment last

## Definition of done for API work
API work is not done unless:
- shared artwork rule still holds
- endpoints match the current data model
- duplicate artwork storage was not introduced
- financial and authenticity flows remain separate and correct
- tests or validation steps are reported
