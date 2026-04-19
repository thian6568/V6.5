# MIGRATION_CHECKLIST.md

## Goal
Guide database migration work in the correct sequence so:
- dependencies are respected
- foreign keys stay valid
- enums are created before dependent tables
- row-level security is applied in the right order
- the single shared artwork source of truth is protected
- marketplace and Unity stay connected to the same artwork record

## Core Rule
The migration process must never create:
- a second artwork identity table
- a second artwork upload path
- a separate VR-only artwork source

The `artworks` table must remain the single source of truth.

---

## Migration Workflow

### Step 0 — Before any migration
Before creating or changing any migration:

- read:
  - `AGENTS.md`
  - `DATA_MODEL.md`
  - `TASKS.md`
  - `RLS_PLAN.md`
  - `ENUM_PLAN.md`
  - `API_SPEC.md`
- confirm:
  - single source of truth for artworks
  - correct build order
  - table dependency order
  - enum dependency order

### Validation before migration starts
Confirm:
- no duplicate artwork identity path exists
- no second VR upload path exists
- visibility logic uses one shared enum
- artwork authentication is separate from user authentication
- escrow/subscription/shipping/insurance are included in planning

---

## Step 1 — Create enums first
Create enums before tables that depend on them.

Recommended enum order:
1. role_name
2. profile_status
3. publish_status
4. visibility_mode
5. authentication_status
6. listing_status
7. order_status
8. escrow_status
9. subscription_status
10. refund_status
11. dispute_type
12. dispute_status
13. shipping_status
14. insurance_status
15. environment_status
16. performance_tier
17. assignment_status
18. content_type
19. feature_type
20. notification_status

### Validation after enum step
Confirm:
- no duplicate meanings
- no conflicting labels
- API spec and data model use the same names
- Unity and marketplace both depend on the same `visibility_mode`

---

## Step 2 — Migration 001 Foundation

Create:
- roles
- profiles
- audit_logs

### Validation after Migration 001
Confirm:
- profiles links to Supabase auth user id
- roles are usable
- audit log references are valid
- admin / artist / buyer roles can be represented

---

## Step 3 — Migration 002 Shared Artwork Source of Truth

Create:
- artworks
- artwork_assets
- artwork_authentication
- certificates
- ownership_history

### Critical checks after Migration 002
Confirm:
- artworks is the single source of truth
- artwork_assets references artworks
- artwork_authentication references artworks
- certificates references artworks
- ownership_history references artworks
- no duplicate artwork table was created

### Stop condition
Do not continue if:
- any second artwork identity path appears
- authentication is not properly tied to artwork
- ownership or certificate tables do not reference artworks correctly

---

## Step 4 — Migration 003 Marketplace / Orders

Create:
- listings
- orders
- order_items

### Critical checks after Migration 003
Confirm:
- listings references artworks
- order_items references artworks
- no marketplace-specific artwork table exists
- order model is separate from escrow model

---

## Step 5 — Migration 004 Financial Flows

Create:
- escrow_records
- subscriptions
- refund_requests
- disputes

### Critical checks after Migration 004
Confirm:
- escrow references orders
- subscriptions references profiles
- refund requests references orders
- disputes references orders and artworks
- financial states are separated correctly:
  - order status
  - escrow status
  - refund status
  - dispute status

---

## Step 6 — Migration 005 Logistics

Create:
- shipping_records
- insurance_records

### Critical checks after Migration 005
Confirm:
- shipping references orders
- insurance references orders
- logistics does not duplicate financial or order state logic

---

## Step 7 — Migration 006 VR / WebGL Environment Integration

Create:
- environments
- environment_assignments

### Critical checks after Migration 006
Confirm:
- environment_assignments references artworks
- environment_assignments references environments
- Unity can later read approved artworks through:
  - artworks
  - artwork_assets
  - environment_assignments
- no VR-only artwork record path exists

### Stop condition
Do not continue if:
- Unity assignment logic depends on a separate artwork source
- environment assignment bypasses the shared artwork rule

---

## Step 8 — Migration 007 Content / Admin Support

Create:
- homepage_content
- featured_content
- notifications

### Validation after Migration 007
Confirm:
- admin/public content layers do not interfere with core artwork logic
- notifications link to valid users

---

## Step 9 — Apply Row-Level Security

Apply RLS only after:
- tables exist
- relationships are confirmed
- enum plan is stable

Recommended RLS order:
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

### Validation after RLS
Confirm:
- artist can only manage own artworks
- buyer can only see own orders/subscriptions/refunds where applicable
- admin can manage all required records
- public reads are limited to approved/published records
- no policy allows duplicate artwork identity creation

---

## Step 10 — Seed / Reference Data
Only after schema + RLS are stable.

Seed:
- base roles
- test admin
- test artist
- test buyer
- sample environment records
- sample featured content if needed

### Validation after seed
Confirm:
- seed data respects current schema
- no test path bypasses approval logic
- sample artwork still follows the one shared source rule

---

## Step 11 — Migration Review Checklist
Before accepting a migration batch, confirm:

- enums created first
- dependency order respected
- foreign keys valid
- one shared artwork source remains intact
- no duplicate upload path exists
- no duplicate artwork identity path exists
- financial flows are separated cleanly
- Unity environment assignments point to shared artwork records
- RLS does not weaken approval or ownership boundaries

---

## Step 12 — Rollback / Safety Rules
For each migration batch:
- keep migrations small and reviewable
- record which tables changed
- record which enums changed
- record what validations ran
- note rollback risk if schema order is changed later

Do not merge a migration batch unless:
- validation notes are written
- risks are listed
- shared artwork rule is still confirmed

---

## Final Reminder
Migration success is not only “table created successfully”.

Migration success means:
- data model stays consistent
- the artwork source of truth remains single
- marketplace, authentication, certificate, and VR environment integration all continue to point to the same artwork record
