# REQUIREMENTS.md

## Project Name
Artist In Art

## Project Goal
Build one connected platform with:
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

## Core System Rule
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

## Functional Requirements

### 1. User Authentication
The platform must support:
- register
- login
- logout
- password reset
- secure session handling
- role-based access

Required roles:
- admin
- artist
- buyer / collector

### 2. Artwork Authentication
The platform must support:
- unique artwork ID
- serial number
- certificate of authenticity
- authenticity status
- ownership record
- verification page
- QR / NFC-ready structure
- admin verification controls

### 3. Marketplace / E-commerce
The platform must support:
- artwork listing page
- artwork detail page
- cart
- checkout
- invoice / receipt
- order status
- refund request flow
- order management

### 4. Escrow / Subscription / Shipping / Insurance
The platform must support:
- escrow payment flow
- membership / subscription flow
- shipping method options
- insurance options
- related records in backend

### 5. Artist Dashboard
The artist dashboard must support:
- upload artwork
- edit artwork
- set title, description, dimensions, category, price
- publish / unpublish artwork
- choose visibility:
  - marketplace only
  - VR only
  - both
- manage artwork authentication details
- view orders / sales
- view statement / payout summary

### 6. Admin Dashboard
The admin dashboard must support:
- manage users
- manage roles
- manage artworks
- approve / reject artwork authentication
- approve / reject artwork visibility
- manage marketplace listings
- manage orders
- manage homepage content
- manage featured artists / featured artworks
- manage refunds / disputes

### 7. WebGL / VR Gallery
The platform must support:
- browser-based WebGL gallery
- support for custom 3D environments
- room navigation
- artwork placement on walls
- environment preview / thumbnail
- scalable environment library
- auto-load approved artworks from backend into selected environment

### 8. Hosting / Deployment
The project must support:
- staging environment
- production environment
- storage
- CDN
- logs
- backups
- monitoring
- portable deployment architecture

Default deployment target:
- AWS Singapore

But hosting must remain portable if deployment target changes later.

## Technical Requirements

### Web Layer
- Next.js for public site and dashboards
- v0 may be used for UI acceleration only

### Backend Layer
- Supabase / Postgres as single source of truth
- backend must contain shared artwork logic
- backend must not create separate artwork records for marketplace and VR

### Unity Layer
- Unity WebGL for gallery runtime
- Unity Addressables for remote environment loading
- Unity must read approved artwork data from backend
- Unity must not require a second artwork upload

## Non-Negotiable Rules
1. One artwork upload creates one main artwork record.
2. Marketplace and VR must use the same artwork source.
3. User authentication and artwork authentication are separate systems.
4. Admin approval must not be bypassed.
5. Escrow, subscriptions, shipping, and insurance are compulsory.
6. Backend first, web second, Unity third, deployment last.

## MVP Boundary
For MVP / first implementation, focus on:
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
