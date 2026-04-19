# Artist In Art

## Overview
Artist In Art is one connected platform for:
- web marketplace
- artist dashboard
- admin dashboard
- user authentication
- artwork authentication
- WebGL / VR gallery
- escrow payment
- membership / subscription
- shipping
- insurance

The platform is designed around **one shared artwork source of truth**.

## Core Rule
One uploaded artwork must:
- be uploaded once
- be stored once in the core database
- be authenticated once
- be reused by:
  - marketplace
  - artist dashboard
  - admin dashboard
  - certificate / authenticity page
  - WebGL / VR gallery

No duplicate upload path is allowed for marketplace and VR gallery.

## Project Structure

### 1. web-marketplace
Handles:
- landing page
- homepage
- CMS pages
- artist dashboard
- admin dashboard
- buyer / collector account
- artwork listing page
- artwork detail page
- cart
- checkout
- subscription pages
- refund request pages

### 2. backend-core
Handles:
- Supabase / Postgres core database
- user authentication
- artwork authentication
- artwork records
- listing records
- order records
- certificate records
- ownership history
- subscription records
- refund / dispute records
- shipping records
- insurance records
- environment assignment records

### 3. unity-webgl-gallery
Handles:
- Unity WebGL gallery runtime
- support for custom 3D environments
- room loading
- room navigation
- artwork placement
- environment metadata
- auto-loading approved artworks from backend
- future VR support

### 4. infra-deployment
Handles:
- hosting
- staging and production environments
- storage
- CDN
- logs
- backups
- monitoring
- deployment scripts
- infrastructure setup

## Recommended Stack
- Next.js = main web application
- v0 = UI acceleration only
- Supabase / Postgres = single source of truth
- Unity WebGL = gallery runtime
- Unity Addressables = remote environment loading
- AWS Singapore = default deployment target
- deployment architecture must remain portable if provider changes later

## Main Feature Groups

### User Authentication
- register
- login
- logout
- password reset
- secure sessions
- role-based access

Roles:
- admin
- artist
- buyer / collector

### Artwork Authentication
- unique artwork ID
- serial number
- certificate of authenticity
- authenticity status
- ownership record
- verification page
- QR / NFC-ready structure
- admin verification controls

### Marketplace / E-commerce
- artwork listing page
- artwork detail page
- cart
- checkout
- invoice / receipt
- order status
- refund request flow
- order management

### Escrow / Subscription / Shipping / Insurance
- escrow payment flow
- membership / subscription flow
- shipping methods
- insurance options
- backend records for all of these

### Artist Dashboard
- upload artwork
- edit artwork
- publish / unpublish artwork
- manage authentication information
- view sales / orders
- statement / payout summary
- choose visibility:
  - marketplace only
  - VR only
  - both

### Admin Dashboard
- manage users
- manage roles
- manage artworks
- approve / reject artwork authentication
- approve / reject listing visibility
- manage orders
- manage homepage content
- manage featured artists / artworks
- manage refunds / disputes

### WebGL / VR Gallery
- browser-based WebGL gallery
- support custom 3D environments
- room navigation
- artwork placement on walls
- environment preview / thumbnail
- scalable environment library
- auto-load approved artworks from backend into selected environment

## Build Priority
1. backend-core
2. web-marketplace
3. unity-webgl-gallery
4. infra-deployment

## Important Rules
1. One artwork upload creates one main artwork record.
2. Marketplace and VR must use the same artwork record.
3. User authentication and artwork authentication are separate systems.
4. Admin approval must not be bypassed.
5. Escrow, subscriptions, shipping, and insurance are compulsory.
6. Backend first, web second, Unity third, deployment last.

## MVP Boundary
For the first implementation stage, focus on:
- backend schema
- user authentication
- artwork authentication
- marketplace
- cart / checkout
- escrow flow
- subscription flow
- shipping / insurance records
- WebGL gallery integration
- shared artwork rule

Do not add unless explicitly requested:
- wallet connector
- Web3 marketplace logic
- blockchain smart contracts
- advanced non-essential AI features
- headset-only VR features

## Important Documents
This repo should include:
- `AGENTS.md`
- `PROJECT_BRIEF.md`
- `REQUIREMENTS.md`
- `SYSTEM_RULES.md`
- `DATA_MODEL.md`
- `API_SPEC.md`
- `TASKS.md`
- `ACCEPTANCE_CHECKLIST.md`

## Definition of Done
Work is not done unless:
- the shared artwork rule still holds
- no duplicate artwork storage path was introduced
- relevant tests or validation steps were run
- changed files are listed clearly
- risks or follow-up items are stated

## Final Reminder
The most important project rule is:

One uploaded artwork must be stored once in the core database, authenticated once, and reused by the marketplace, certificate system, dashboards, and the VR/WebGL gallery without duplicate upload.
