# RLS_PLAN.md

## Goal
Define row-level security rules for Artist In Art so that:
- users only see what they are allowed to see
- artists manage only their own records
- buyers access only their own orders and subscriptions
- admins can manage the full platform
- the shared artwork source of truth is protected
- no direct bypass exists for authentication, approvals, financial flows, or environment assignments

## Core Security Rule
The backend must protect the single shared artwork source of truth.

The following must stay linked and protected:
- artworks
- artwork_assets
- artwork_authentication
- certificates
- ownership_history
- listings
- order_items
- environment_assignments

No policy may allow users to create or update a second artwork path outside the main `artworks` record.

---

## Role Model
Expected roles:
- admin
- artist
- buyer

Role is stored in:
- `profiles.role_id`
or equivalent resolved role mapping

Supabase auth user id must map to:
- `profiles.id`

---

## RLS Order of Work

### Step 1 — Enable RLS
Enable RLS for all application tables.

Tables:
- profiles
- audit_logs
- artworks
- artwork_assets
- artwork_authentication
- certificates
- ownership_history
- listings
- orders
- order_items
- escrow_records
- subscriptions
- refund_requests
- disputes
- shipping_records
- insurance_records
- environments
- environment_assignments
- homepage_content
- featured_content
- notifications

---

## profiles

### Select
- users can view their own profile
- admins can view all profiles

### Insert
- insert only for own user profile creation flow
- do not allow ordinary user to create another profile for another auth user

### Update
- users can update their own allowed profile fields
- admins can update any profile
- role changes should be admin-only

### Delete
- delete should be admin-only or disallowed unless explicitly needed

---

## audit_logs

### Select
- admin-only

### Insert
- system/service role only
- optionally admin system functions only

### Update
- disallow for normal users

### Delete
- disallow except strict admin / maintenance path

---

## artworks

### Select
- artist can view own artworks
- admin can view all artworks
- buyer/public can view only approved and visible artworks according to business rules

### Insert
- artist can create own artwork record
- admin can create only if admin workflow requires it
- user must not create artwork for another artist

### Update
- artist can update own artwork while allowed by workflow state
- admin can update any artwork
- public/buyer cannot update artwork
- critical fields like ownership or admin approval status should not be editable by ordinary artist unless explicitly allowed

### Delete
- admin-only
- artist delete only if business rule allows draft deletion

### Important
- this is the only main artwork record
- policies must not allow bypass through another table

---

## artwork_assets

### Select
- artist can view assets for own artworks
- admin can view all
- public can view assets only for approved visible artworks if needed

### Insert
- artist can add assets only to own artworks
- admin can add assets to any artwork

### Update
- artist can update own artwork assets
- admin can update any artwork assets

### Delete
- artist can delete own draft assets if allowed
- admin can delete any asset

---

## artwork_authentication

### Select
- artist can view authentication records for own artworks
- admin can view all
- public/buyer can view limited authenticity info only through public verification endpoint, not raw admin notes

### Insert
- artist may initiate authentication request for own artwork
- admin can create/update verification record
- no one may create authentication record for someone else’s artwork unless admin

### Update
- admin-only for verification status, approval state, certificate issuance link, admin notes
- artist may update limited request-side fields only if explicitly allowed

### Delete
- admin-only

### Important
- authentication is separate from user auth
- do not expose internal verification notes publicly

---

## certificates

### Select
- artist can view own certificate records
- admin can view all
- buyer/current owner can view certificate linked to purchased artwork where allowed
- public verification endpoint may expose limited certificate data

### Insert
- admin or secure backend function only

### Update
- admin-only or secure backend function only

### Delete
- admin-only

---

## ownership_history

### Select
- admin can view all
- artist can view ownership history for own artworks if business rule allows
- buyer can view ownership history related to owned artwork where allowed
- public access should be restricted to limited verification output only

### Insert
- secure backend function or admin-only
- ownership changes should not be freely client-writable

### Update
- admin-only
- preferably immutable after insert

### Delete
- admin-only or disallow

---

## listings

### Select
- artist can view own listings
- admin can view all
- public/buyer can view only approved live listings

### Insert
- artist can create listing only for own artwork
- listing must reference existing `artworks.id`
- do not allow listing creation for someone else’s artwork

### Update
- artist can update own listing within allowed states
- admin can update any listing
- public/buyer cannot update listings

### Delete
- artist can archive or remove own draft listing if business rule allows
- admin can delete or archive any listing

### Important
- listing policy must never create duplicate artwork identity

---

## orders

### Select
- buyer can view own orders
- admin can view all orders
- artist may view orders that contain their artworks through secure query or service endpoint, not necessarily direct unrestricted table select

### Insert
- secure checkout flow only
- buyer creates own order through backend flow

### Update
- order status updates should be admin or secure backend function only
- buyer should not directly edit financial/order-state fields

### Delete
- admin-only or disallow

---

## order_items

### Select
- buyer can view items for own orders
- admin can view all
- artist may view relevant sold items through secure filtered query

### Insert
- secure checkout flow only

### Update
- admin/backend only

### Delete
- admin/backend only

---

## escrow_records

### Select
- admin can view all
- buyer and seller may view escrow status for relevant order through secure filtered endpoint
- avoid unrestricted raw table access

### Insert
- secure backend flow only

### Update
- secure backend flow or admin-only
- no direct client-side escrow status changes

### Delete
- admin-only or disallow

### Important
- escrow state must be tightly controlled
- no public writes

---

## subscriptions

### Select
- user can view own subscription
- admin can view all subscriptions

### Insert
- user can create own subscription through approved checkout/subscription flow
- admin/backend can create if needed

### Update
- user can cancel own subscription if business rule allows
- admin can update any subscription
- financial state changes should be backend-driven

### Delete
- admin-only or disallow

---

## refund_requests

### Select
- requester can view own refund request
- admin can view all
- related seller/artist visibility only if business rule allows

### Insert
- buyer can create refund request for own order
- admin can create on behalf if needed

### Update
- admin can update status, approved amount, resolution notes
- buyer may update limited explanatory fields only before review if allowed

### Delete
- admin-only or disallow

---

## disputes

### Select
- opening user can view own dispute
- admin can view all
- involved seller/artist can view related dispute where allowed

### Insert
- buyer or admin through controlled flow
- must reference valid order and artwork

### Update
- admin-only for dispute status and resolution
- limited party responses may be allowed through controlled fields

### Delete
- admin-only or disallow

---

## shipping_records

### Select
- buyer can view shipping record for own order
- admin can view all
- artist/seller can view relevant shipping info where needed

### Insert
- backend/admin only

### Update
- backend/admin only for tracking and shipment status
- no unrestricted client writes

### Delete
- admin-only or disallow

---

## insurance_records

### Select
- buyer can view insurance record for own order
- admin can view all
- artist/seller can view where needed by workflow

### Insert
- backend/admin only

### Update
- backend/admin only

### Delete
- admin-only or disallow

---

## environments

### Select
- public can view environments intended for public gallery selection if business rule allows
- admin can view all
- artist may view environments needed for assignment workflow

### Insert
- admin-only

### Update
- admin-only

### Delete
- admin-only

---

## environment_assignments

### Select
- admin can view all
- artist can view assignments for own artworks
- Unity/public gallery can read only approved visible assignments through safe endpoint/view

### Insert
- admin or approved backend workflow only
- artist direct insert only if explicitly allowed and subject to approval

### Update
- admin-only or controlled backend flow
- assignment changes must not bypass visibility/approval rules

### Delete
- admin-only

### Important
- environment assignments must reference existing shared artwork records
- no direct VR-only artwork entry is allowed

---

## homepage_content

### Select
- public can view published content
- admin can view all content states

### Insert
- admin-only

### Update
- admin-only

### Delete
- admin-only

---

## featured_content

### Select
- public can view active featured content
- admin can view all

### Insert
- admin-only

### Update
- admin-only

### Delete
- admin-only

---

## notifications

### Select
- user can view own notifications
- admin can view all only if required

### Insert
- backend/admin only

### Update
- user can mark own notification read
- admin/backend can update system fields if needed

### Delete
- user can delete own notification if allowed
- admin can delete any if needed

---

## Special Policy Rules

### Admin override
Admin may access and manage all application records required by business logic.

### Artist ownership rule
Artist may only manage records linked to artworks they own unless admin.

### Buyer ownership rule
Buyer may only access orders, subscriptions, refunds, and notifications linked to their own profile.

### Public visibility rule
Public access is limited to:
- approved live listings
- approved public verification info
- published homepage/content
- public environment data if enabled

### Shared artwork protection rule
No policy may allow:
- creation of a second main artwork identity path
- separate VR-only artwork records
- environment assignment that bypasses the shared artwork source

---

## Validation Before Applying Policies
Before finalizing RLS, confirm:
- all foreign key dependencies are correct
- artist ownership checks are based on artwork owner profile
- buyer checks are based on order owner profile
- admin path exists for approvals
- public access is restricted to approved/published records
- Unity read path does not bypass approval and visibility logic
- no table allows duplicate artwork identity creation

---

## Codex Execution Instruction
When implementing RLS:

1. summarize each table’s select/insert/update/delete policy plan first
2. identify tables that must be backend/admin-only
3. identify tables that need public read paths
4. identify tables that need artist-owned access
5. warn before applying any policy that could weaken the shared artwork rule
6. report final policy summary after implementation
