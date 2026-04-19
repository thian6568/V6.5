# TEST_PLAN.md

## Goal
Define the testing and validation strategy for Artist In Art so:
- backend, web, Unity, and infrastructure work in the correct order
- the single shared artwork source of truth is protected
- regressions are caught early
- Codex validates changes before asking for review
- each phase has a clear pass/fail result

## Core Rule
Testing is not only about whether code runs.

Testing is successful only if:
- one artwork upload still creates one main artwork record
- the same artwork record is reused by marketplace, authentication, certificate, dashboard, and VR/WebGL gallery
- no duplicate artwork path is introduced
- approvals, financial workflows, and visibility rules still behave correctly

---

## 1. Test Strategy

### Test layers
Use these layers:

1. unit tests
2. integration tests
3. end-to-end tests
4. smoke tests
5. manual validation where needed
6. environment/deployment validation

### Testing rule
Run the smallest useful validation step first.

Examples:
- focused unit test
- targeted integration test
- route-level smoke check
- specific end-to-end flow
- direct reproduction command

Do not skip validation after major backend, web, Unity, or infra changes.

---

## 2. Test Categories

### A. Backend tests
Purpose:
- validate schema, relationships, permissions, and backend flows

### B. Web tests
Purpose:
- validate UI flows, role restrictions, and marketplace behavior

### C. Unity tests
Purpose:
- validate environment loading, assignment logic, and shared artwork integration

### D. Infra tests
Purpose:
- validate staging/production separation, storage/CDN path, config, and deployment safety

---

## 3. Global Critical Tests

These are the most important tests in the whole project.

### 3.1 Shared artwork source of truth
Must verify:
- artwork is uploaded once
- one main artwork record is created
- marketplace uses same artwork id
- artwork authentication uses same artwork id
- certificate uses same artwork id
- environment assignment uses same artwork id
- Unity reads same artwork id
- no duplicate record or second upload path appears

### 3.2 Role security
Must verify:
- artist can manage only own artworks
- buyer can view only own orders/subscriptions/refunds
- admin can manage approvals and platform-wide records
- public cannot access restricted admin or private records

### 3.3 Approval flow
Must verify:
- artwork authentication requires admin approval
- listing visibility requires admin/business approval where defined
- Unity/gallery does not show unapproved artwork

### 3.4 Financial flow
Must verify:
- checkout creates correct order
- escrow opens correctly
- subscription state is separate from order state
- refund/dispute states are separate from escrow and order states
- shipping and insurance records attach to correct order

---

## 4. Backend Test Plan

### 4.1 Schema tests
Check:
- all expected tables exist
- enums exist
- foreign keys are valid
- indexes exist where needed
- environment assignments reference artworks and environments correctly

### 4.2 RLS tests
Check:
- artist cannot access another artist’s private records
- buyer cannot access another buyer’s orders
- public cannot read restricted records
- admin paths work correctly
- no policy allows duplicate artwork identity creation

### 4.3 API tests
Check:
- auth endpoints
- artwork creation/update endpoints
- artwork authentication endpoints
- certificate endpoints
- listing endpoints
- order endpoints
- escrow endpoints
- subscription endpoints
- refund/dispute endpoints
- shipping/insurance endpoints
- environment assignment endpoints

### 4.4 Backend critical assertions
Must verify:
- listings reference artworks.id
- certificates reference artworks.id
- environment_assignments reference artworks.id
- order_items reference artworks.id
- no second artwork table is used by any feature

---

## 5. Web Test Plan

### 5.1 Public pages
Check:
- landing page loads
- homepage loads
- public listing pages load
- artwork detail page loads from shared artwork record
- public verification page shows only approved/public-safe fields

### 5.2 Auth pages
Check:
- register works
- login works
- logout works
- password reset works
- role-based redirects/protection works

### 5.3 Artist dashboard
Check:
- artist can upload artwork once
- artist can edit same artwork record
- artist can manage visibility mode
- artist sees own sales/orders only
- artist can submit authentication details

### 5.4 Admin dashboard
Check:
- admin can view pending artwork authentication
- admin can approve/reject artwork authentication
- admin can manage listings
- admin can review refunds/disputes
- admin can manage homepage and featured content

### 5.5 Marketplace / checkout
Check:
- listing grid renders live approved items
- detail page uses same shared artwork id
- cart works
- checkout works
- order appears in history
- invoice/receipt renders correctly

### 5.6 Refund / dispute / subscription
Check:
- buyer can request refund on own order
- buyer can open dispute on own order
- buyer can view own subscription
- unauthorized access is blocked

---

## 6. Unity / WebGL Test Plan

### 6.1 Environment metadata
Check:
- environments list loads
- thumbnail/preview works
- category and performance tier are valid
- addressable metadata is usable

### 6.2 Room loading
Check:
- selected room loads
- previous room unloads safely
- loading state works
- failed load fallback works

### 6.3 Assignment logic
Check:
- environment assignment resolves to correct artwork
- wall anchor logic is correct
- placement values apply correctly

### 6.4 Artwork loading
Check:
- Unity fetches approved artwork data from backend
- Unity uses same artwork id as marketplace/authentication
- Unity does not require duplicate upload
- Unity respects visibility_mode
- unapproved artwork is not shown

### 6.5 WebGL validation
Check:
- WebGL build runs
- environment loads in browser
- assigned artworks render in browser
- performance tier behavior is acceptable

---

## 7. Infra / Deployment Test Plan

### 7.1 Environment separation
Check:
- staging is separate from production
- environment variables are separated
- production secrets are not committed

### 7.2 Storage / CDN
Check:
- artwork media path works
- certificate file path works
- WebGL asset path works
- environment bundle path works
- CDN path is correct

### 7.3 Logging / Monitoring / Backups
Check:
- logs are reachable
- monitoring path is defined
- backup plan exists
- restore path is documented

### 7.4 Deployment flow
Check:
- backend deployment order is correct
- web deployment order is correct
- WebGL asset deployment order is correct
- staging validation happens before production release

---

## 8. Test Execution Order

### Stage A — backend
Run first:
- schema tests
- enum checks
- foreign key checks
- RLS tests
- backend API tests

### Stage B — web
Run next:
- auth flow tests
- artist dashboard tests
- marketplace tests
- checkout tests
- refund/dispute/subscription tests

### Stage C — Unity
Run next:
- environment metadata tests
- room loading tests
- assignment tests
- approved artwork loading tests
- WebGL build validation

### Stage D — infra
Run last:
- staging config tests
- storage/CDN tests
- logging/backup checks
- deployment order validation

---

## 9. Manual Test Flows

### Manual Flow 1 — Upload once, use everywhere
1. artist uploads artwork
2. one artwork record is created
3. artist submits authentication info
4. admin approves artwork/authentication
5. listing is created from same artwork
6. artwork appears in marketplace
7. artwork is assigned to environment
8. Unity/WebGL gallery loads same artwork
9. verify same artwork id is used across all steps

### Manual Flow 2 — Marketplace to gallery consistency
1. open artwork detail page
2. confirm artwork id and title
3. open verification page
4. confirm same artwork id
5. open assigned WebGL environment
6. confirm same artwork is loaded

### Manual Flow 3 — Buyer purchase flow
1. buyer logs in
2. adds artwork to cart
3. checks out
4. order created
5. escrow record created
6. shipping/insurance records created if selected
7. buyer order history shows correct data

### Manual Flow 4 — Refund / dispute flow
1. buyer opens refund request
2. admin reviews
3. dispute may be opened if needed
4. order/refund/dispute states remain separate and correct

---

## 10. Required Output After Every Test Pass

After each major test run, report:
1. what was tested
2. which files/features were affected
3. which commands or checks were run
4. what passed
5. what failed
6. what still needs review
7. whether the shared artwork rule still holds

Do not claim completion without this report.

---

## 11. Stop Conditions

Stop and warn immediately if:
- a second artwork upload path appears
- a second artwork identity path appears
- Unity reads from a different artwork source than marketplace
- admin approval can be bypassed
- public pages expose restricted data
- checkout bypasses backend business logic
- production secrets appear in repo/config/prompted output

---

## 12. Definition of Testing Done

Testing is not done unless:
- critical backend tests pass
- critical web flow tests pass
- critical Unity/WebGL tests pass
- critical infra validation is complete
- shared artwork rule is confirmed
- risks and open items are documented
