# TASKS.md

## Build Order
1. backend-core
2. web-marketplace
3. unity-webgl-gallery
4. infra-deployment

## Phase 1 — Planning
- read all repo documents
- confirm project understanding
- confirm single source of truth for artworks
- confirm MVP boundary
- identify risks and contradictions
- propose implementation order

## Phase 2 — Backend Core
### Authentication
- create user authentication model
- create role model
- define role-based access rules

### Artwork authentication
- create artwork model
- create artwork authentication model
- create certificate model
- create ownership history model

### Commerce
- create listings model
- create orders model
- create order_items model
- create escrow_records model
- create subscriptions model
- create refund_requests model
- create disputes model
- create shipping_records model
- create insurance_records model

### Gallery connection
- create environments model
- create environment_assignments model

### Backend tasks
- create migrations
- define row-level security
- define core API structure
- validate shared artwork rule

## Phase 3 — Web Marketplace
### Public site
- build landing page
- build homepage
- build listing page
- build artwork detail page

### User account
- build register page
- build login page
- build password reset page
- build account settings page

### Artist dashboard
- build upload artwork page
- build edit artwork page
- build visibility controls
- build sales/orders view
- build statement summary view

### Admin dashboard
- build user management pages
- build artwork approval pages
- build listing approval pages
- build featured content manager
- build refund/dispute review pages

### Commerce UI
- build cart
- build checkout
- build invoice / receipt page
- build subscription page
- build refund request page

## Phase 4 — Unity WebGL Gallery
- define environment metadata format
- define environment loading flow
- define approved artwork loading flow
- define wall anchor placement logic
- define environment preview logic
- connect Unity to shared backend data
- validate no duplicate upload path exists

## Phase 5 — Infrastructure / Deployment
- define staging environment
- define production environment
- define storage and CDN setup
- define logs and monitoring
- define backup strategy
- define deployment scripts
- define monthly running-cost estimate

## Rules for All Tasks
- do not break shared artwork rule
- do not create duplicate artwork storage
- do not skip admin approval
- do not add non-MVP features unless requested
- always summarize changed files and validation steps
