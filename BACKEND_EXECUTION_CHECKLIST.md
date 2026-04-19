# BACKEND_EXECUTION_CHECKLIST.md

## Goal
Guide backend-core implementation after migrations are completed so:
- the schema is used correctly
- the single shared artwork source of truth is preserved
- auth, marketplace, certificates, escrow, subscriptions, shipping, insurance, and environment assignment all work together
- Codex follows the correct execution order
- backend work is validated before web and Unity move forward

## Core Rule
The backend is successful only if:
- one artwork upload creates one main artwork record
- the same artwork record is reused by:
  - artwork authentication
  - certificates
  - ownership history
  - marketplace listings
  - orders / order_items
  - environment assignments
  - WebGL / VR gallery loading
- no second artwork source exists
- no second upload path exists for VR

---

## Phase 1 — Backend foundation validation

### Checklist
- [ ] all migrations applied successfully
- [ ] all enums created successfully
- [ ] all foreign keys validated
- [ ] all required indexes created
- [ ] all RLS policies applied
- [ ] all seed/reference data inserted correctly

### Validation output required
After this phase, report:
- migration status
- enum status
- RLS status
- any failed dependency
- any schema risk found

---

## Phase 2 — Authentication backend

### Implement
- [ ] user registration flow
- [ ] login flow
- [ ] logout/session flow
- [ ] password reset flow
- [ ] role mapping to profiles
- [ ] profile read/update flow

### Rules
- user authentication and artwork authentication must remain separate
- profile must map correctly to Supabase auth user
- role checks must support:
  - admin
  - artist
  - buyer

### Validation
- [ ] artist account can be created
- [ ] buyer account can be created
- [ ] admin role can be resolved
- [ ] unauthorized role access is blocked

---

## Phase 3 — Artwork core backend

### Implement
- [ ] create main artwork record
- [ ] update artwork record
- [ ] attach artwork assets
- [ ] submit artwork for approval
- [ ] update artwork visibility mode
- [ ] fetch artwork detail

### Rules
- this is the only main artwork creation path
- no VR-only artwork creation path
- visibility mode must use:
  - marketplace_only
  - vr_only
  - both

### Validation
- [ ] one artwork upload creates one main artwork record
- [ ] artwork assets reference the same artwork record
- [ ] updating artwork keeps same artwork id
- [ ] visibility mode updates correctly

---

## Phase 4 — Artwork authentication backend

### Implement
- [ ] create authentication request
- [ ] update authentication request
- [ ] admin approve/reject authentication
- [ ] certificate generation flow
- [ ] ownership history append flow
- [ ] verification detail read flow

### Rules
- authentication record must reference main artwork record
- certificate must reference main artwork record
- ownership history must reference main artwork record
- public verification must expose only allowed fields

### Validation
- [ ] artwork can move from pending to approved
- [ ] certificate record is linked correctly
- [ ] ownership history can be recorded
- [ ] verification endpoint returns correct data
- [ ] no duplicate artwork identity is created during authentication

---

## Phase 5 — Marketplace backend

### Implement
- [ ] create listing from existing artwork
- [ ] update listing
- [ ] list live listings
- [ ] listing detail retrieval
- [ ] admin approve/reject listing
- [ ] filter/search support if included in backend

### Rules
- listing must reference existing artwork_id
- listing must not duplicate artwork identity fields unnecessarily
- marketplace must read same artwork used by certificate and VR assignment

### Validation
- [ ] artist can create listing from own artwork
- [ ] listing references same artwork id
- [ ] approved live listing can be read publicly
- [ ] rejected or non-live listing is protected correctly

---

## Phase 6 — Cart / Checkout / Orders backend

### Implement
- [ ] add item to cart
- [ ] get cart
- [ ] remove item from cart
- [ ] create checkout session/draft
- [ ] confirm order
- [ ] order detail retrieval
- [ ] order list retrieval

### Rules
- order_items must reference artworks.id
- order model must stay separate from escrow model
- cart and checkout must use live approved artwork/listing state

### Validation
- [ ] cart can store artwork item
- [ ] checkout session can be created
- [ ] confirmed order creates order + order_items correctly
- [ ] order_items reference shared artwork record

---

## Phase 7 — Escrow backend

### Implement
- [ ] open escrow record
- [ ] retrieve escrow status
- [ ] release escrow fully or partially
- [ ] admin update escrow state where needed

### Rules
- escrow must reference order
- escrow status must be separate from order_status
- no direct uncontrolled client writes to escrow state

### Validation
- [ ] escrow can open for confirmed order
- [ ] escrow status can move through allowed states
- [ ] partial release works if supported
- [ ] dispute status does not overwrite order identity logic

---

## Phase 8 — Subscription backend

### Implement
- [ ] list plans
- [ ] create subscription
- [ ] retrieve current subscription
- [ ] cancel subscription
- [ ] admin subscription view

### Rules
- subscription must reference user profile
- subscription state must stay separate from order and escrow states

### Validation
- [ ] subscription can be created
- [ ] subscription status changes correctly
- [ ] user sees only own subscription

---

## Phase 9 — Refund / Dispute backend

### Implement
- [ ] create refund request
- [ ] retrieve refund request
- [ ] admin approve/reject/adjust refund
- [ ] open dispute
- [ ] retrieve dispute
- [ ] admin resolve dispute

### Rules
- refund requests must reference orders
- disputes must reference orders and artworks
- refund and dispute status must remain separate

### Validation
- [ ] buyer can open refund request on own order
- [ ] admin can update refund outcome
- [ ] dispute can be opened and resolved
- [ ] dispute still references shared artwork correctly

---

## Phase 10 — Shipping / Insurance backend

### Implement
- [ ] list shipping options
- [ ] create shipping record
- [ ] retrieve shipping record
- [ ] update shipping status
- [ ] create insurance record
- [ ] retrieve insurance record

### Rules
- shipping must reference order
- insurance must reference order
- shipping/insurance must not duplicate financial state logic

### Validation
- [ ] shipping record can be created
- [ ] insurance record can be created
- [ ] order-linked retrieval works
- [ ] buyer sees only own shipping/insurance where allowed

---

## Phase 11 — Environment / Unity integration backend

### Implement
- [ ] list environments
- [ ] retrieve environment detail
- [ ] create environment assignment
- [ ] update environment assignment
- [ ] remove environment assignment
- [ ] list approved artworks assigned to environment

### Rules
- environment assignments must reference:
  - environments.id
  - artworks.id
- Unity must later read artworks through:
  - artworks
  - artwork_assets
  - environment_assignments
- no second VR artwork path is allowed

### Validation
- [ ] approved artwork can be assigned to environment
- [ ] environment assignment references same artwork id as marketplace/authentication
- [ ] environment endpoint can return assigned approved artworks
- [ ] no duplicate upload path is introduced

---

## Phase 12 — Admin / homepage support backend

### Implement
- [ ] admin dashboard summary endpoint
- [ ] homepage content retrieval
- [ ] homepage content update
- [ ] featured content create/update/list
- [ ] audit log read endpoint
- [ ] notifications retrieval/update if included now

### Validation
- [ ] admin dashboard summary works
- [ ] homepage content can be managed
- [ ] featured content can be managed
- [ ] audit logs remain protected

---

## Phase 13 — Backend-wide validation

### Shared artwork validation
- [ ] one artwork upload creates one main artwork record
- [ ] same artwork record is used by:
  - authentication
  - certificate
  - ownership
  - listing
  - order_items
  - environment assignment
- [ ] no second artwork creation path exists
- [ ] no VR-only artwork table exists

### Security validation
- [ ] RLS blocks unauthorized access
- [ ] admin-only actions are protected
- [ ] buyer-only data is protected
- [ ] artist-only records are protected
- [ ] public endpoints only expose approved/published records

### Business validation
- [ ] checkout flow works with order creation
- [ ] escrow flow works
- [ ] subscription flow works
- [ ] refund/dispute flow works
- [ ] shipping/insurance flow works

---

## Required Output After Each Major Backend Step
After each phase, report:
1. what was implemented
2. which files changed
3. which tables or functions were touched
4. what validation/tests were run
5. what risks or open items remain

Do not claim completion without validation.

---

## Stop Conditions
Stop and warn before continuing if:
- a second artwork identity path appears
- a second artwork upload path appears
- Unity integration requires duplicate artwork storage
- listing logic duplicates artwork identity
- authentication logic merges user auth and artwork auth
- financial states become mixed or unclear

---

## Definition of Backend Done
Backend-core is not done unless:
- all required tables and policies exist
- all required backend flows exist
- the shared artwork rule still holds
- environment assignment uses the same shared artwork record
- validations were run
- risks were reported clearly
