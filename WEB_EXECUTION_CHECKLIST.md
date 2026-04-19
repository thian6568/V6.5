# WEB_EXECUTION_CHECKLIST.md

## Goal
Guide the web-marketplace implementation after backend-core is stable so:
- the web app uses the correct backend source of truth
- the one shared artwork rule is preserved
- artist, buyer, and admin flows are separated clearly
- marketplace, checkout, subscriptions, refunds, and verification pages work correctly
- no UI logic creates duplicate artwork paths

## Core Rule
The web app must never create a second artwork identity path.

All artwork-related web flows must use the same shared backend record from:
- artworks
- artwork_assets
- artwork_authentication
- certificates
- ownership_history
- listings
- environment_assignments

The web app must not create:
- a marketplace-only artwork source
- a VR-only artwork source
- a second upload path outside the shared artwork flow

---

## Phase 1 — Web foundation setup

### Implement
- [ ] Next.js app structure
- [ ] route groups for public, auth, artist, buyer, admin
- [ ] shared layout system
- [ ] navigation system
- [ ] environment/config handling
- [ ] API client layer
- [ ] validation layer
- [ ] auth/session integration with backend

### Rules
- keep business logic out of purely visual components
- use shared validation and shared types where possible
- do not hard-code backend assumptions into many places

### Validation
- [ ] app routes resolve correctly
- [ ] auth session state can be read
- [ ] role-aware navigation can render correctly
- [ ] API client can connect to backend environment

---

## Phase 2 — Public pages

### Implement
- [ ] landing page
- [ ] homepage
- [ ] about page
- [ ] faq page
- [ ] contact page
- [ ] public search/listing discovery page
- [ ] public artwork detail page
- [ ] public verification page

### Rules
- public pages must only show approved/published content
- artwork detail page must use the shared artwork record
- verification page must use approved backend authenticity data only

### Validation
- [ ] public homepage loads
- [ ] public artwork detail page loads from shared backend record
- [ ] public verification page returns correct allowed information
- [ ] unpublished or restricted records are not exposed publicly

---

## Phase 3 — Authentication pages

### Implement
- [ ] register page
- [ ] login page
- [ ] logout flow
- [ ] password reset page
- [ ] account settings page

### Rules
- user authentication must remain separate from artwork authentication
- session handling must use backend auth state correctly
- role-based routing must be enforced

### Validation
- [ ] artist can register/login
- [ ] buyer can register/login
- [ ] session persists correctly
- [ ] incorrect role access is blocked from restricted pages

---

## Phase 4 — Artist dashboard

### Implement
- [ ] artist dashboard overview
- [ ] artwork upload page
- [ ] artwork edit page
- [ ] artwork detail management page
- [ ] visibility mode controls
- [ ] sales/orders page
- [ ] statement / payout summary page
- [ ] authentication detail management page

### Rules
- upload page must create only one main artwork record
- edit page must update the same artwork record
- artist can only manage own artworks
- visibility mode must use:
  - marketplace_only
  - vr_only
  - both

### Validation
- [ ] artist can upload artwork once
- [ ] edit page updates same artwork id
- [ ] artwork can be set to marketplace_only / vr_only / both
- [ ] artist can view only own artworks and sales
- [ ] artist can manage authentication request details without bypassing admin approval

---

## Phase 5 — Marketplace pages

### Implement
- [ ] listing grid page
- [ ] listing detail page
- [ ] filters
- [ ] search UI
- [ ] featured artworks section
- [ ] featured artists section

### Rules
- listings must come from shared artwork + listing records
- listing page must not create a second artwork representation path
- marketplace must reflect artwork visibility and listing approval state

### Validation
- [ ] live listings render correctly
- [ ] listing detail uses shared artwork id
- [ ] filters/search do not expose non-approved content
- [ ] featured content is rendered from approved sources

---

## Phase 6 — Cart / checkout

### Implement
- [ ] add to cart
- [ ] cart page
- [ ] remove from cart
- [ ] checkout page
- [ ] order confirmation page
- [ ] invoice / receipt view
- [ ] order history page

### Rules
- cart and checkout must use approved listing/artwork state
- checkout must use backend-generated order flow
- order creation must not bypass escrow or business rules

### Validation
- [ ] user can add artwork to cart
- [ ] cart renders correct item details
- [ ] checkout can submit correctly
- [ ] confirmed order appears in order history
- [ ] invoice / receipt page shows correct backend data

---

## Phase 7 — Escrow / subscription / shipping / insurance UI

### Implement
- [ ] escrow status display
- [ ] subscription plans page
- [ ] current subscription page
- [ ] shipping method selection UI
- [ ] insurance option selection UI

### Rules
- UI must reflect backend status, not invent separate state logic
- escrow state display must read backend escrow_records
- subscription display must read backend subscription state
- shipping/insurance selections must map cleanly to backend flows

### Validation
- [ ] escrow status can be displayed correctly
- [ ] user can view subscription plans
- [ ] current subscription renders correctly
- [ ] shipping options render correctly
- [ ] insurance option flow works correctly

---

## Phase 8 — Refunds / disputes UI

### Implement
- [ ] refund request page
- [ ] refund request detail page
- [ ] dispute open page
- [ ] dispute detail page
- [ ] buyer order issue reporting flow

### Rules
- refund/dispute UI must reference order and artwork from backend
- refund state and dispute state must remain separate
- user must only access own refund/dispute records unless admin

### Validation
- [ ] buyer can open refund request on own order
- [ ] buyer can view own refund status
- [ ] buyer can open dispute on own order
- [ ] unauthorized access is blocked

---

## Phase 9 — Buyer account pages

### Implement
- [ ] buyer dashboard overview
- [ ] order history page
- [ ] subscription page
- [ ] settings page
- [ ] notifications page

### Rules
- buyer can only access own records
- no admin-only data should appear
- authentication and order views must use backend role restrictions

### Validation
- [ ] buyer sees only own orders
- [ ] buyer sees only own subscription state
- [ ] buyer sees only own notifications
- [ ] role protection works correctly

---

## Phase 10 — Admin dashboard

### Implement
- [ ] admin dashboard overview
- [ ] user management page
- [ ] artwork management page
- [ ] artwork authentication approval page
- [ ] listing approval page
- [ ] order management page
- [ ] refund review page
- [ ] dispute review page
- [ ] homepage content manager
- [ ] featured content manager
- [ ] settings page

### Rules
- admin pages must control approval workflows
- admin pages must not bypass backend security rules
- approval pages must operate on the same shared artwork and listing records
- homepage and featured content must use controlled content sources

### Validation
- [ ] admin can view summary metrics
- [ ] admin can approve/reject artwork authentication
- [ ] admin can approve/reject listing visibility
- [ ] admin can review orders, refunds, disputes
- [ ] homepage/featured content management works

---

## Phase 11 — Verification and certificate pages

### Implement
- [ ] artwork authenticity page
- [ ] certificate verification page
- [ ] serial-number verification page

### Rules
- these pages must read from shared backend records
- do not expose private admin notes
- expose only approved/public-safe verification data

### Validation
- [ ] verification by artwork id works
- [ ] verification by certificate number works
- [ ] verification by serial number works
- [ ] sensitive internal fields are not exposed

---

## Phase 12 — Web-wide validation

### Shared artwork validation
- [ ] artwork upload uses one main record only
- [ ] marketplace reads same artwork record
- [ ] verification page reads same artwork record
- [ ] admin approval page reads same artwork record
- [ ] Unity-facing visibility controls are based on same record

### Security validation
- [ ] artist can only manage own artworks
- [ ] buyer can only see own orders and refunds
- [ ] admin-only routes are protected
- [ ] public pages show only approved content
- [ ] session and role checks behave correctly

### Business validation
- [ ] cart and checkout use valid listing state
- [ ] escrow status display works
- [ ] subscription UI works
- [ ] refund/dispute UI works
- [ ] shipping/insurance selection UI works

---

## Required Output After Each Major Web Step
After each phase, report:
1. what was implemented
2. which routes/components changed
3. what backend endpoints were used
4. what validation/tests were run
5. what risks or open items remain

Do not claim completion without validation.

---

## Stop Conditions
Stop and warn before continuing if:
- a second artwork upload path appears in UI flow
- a page invents a duplicate artwork identity representation
- admin approvals are bypassed
- public pages expose restricted records
- checkout flow bypasses backend business logic
- verification pages expose private admin-only fields

---

## Definition of Web Done
Web-marketplace is not done unless:
- all required pages exist
- all major flows use the shared backend source of truth
- no duplicate artwork path exists
- role restrictions work
- validations were run
- risks were reported clearly
