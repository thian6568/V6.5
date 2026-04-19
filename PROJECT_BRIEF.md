# Artist In Art — Project Brief

## Project Summary
Artist In Art is one connected ecosystem platform with 4 main parts:

1. web-marketplace
2. backend-core
3. unity-webgl-gallery
4. infra-deployment

The platform must support:
- user authentication
- artwork authentication
- marketplace / e-commerce
- escrow payment
- membership / subscription
- shipping
- insurance
- WebGL / VR gallery
- support for custom 3D environments
- one shared artwork source of truth

## Main Build Goal
Build a professional art platform where:
- artists can upload artworks once
- artworks are stored once in the core database
- the same artwork record is reused across:
  - marketplace
  - artist dashboard
  - admin dashboard
  - artwork authentication page
  - certificate page
  - WebGL / VR gallery
- approved artworks can auto-load into selected gallery environments
- no duplicate upload path exists for marketplace and VR gallery

## Project Structure

### 1. web-marketplace
This handles:
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
This handles:
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
This handles:
- Unity WebGL gallery runtime
- support for custom 3D environments
- room loading
- room navigation
- artwork placement
- environment metadata
- auto-loading approved artworks from backend
- future VR support

### 4. infra-deployment
This handles:
- hosting
- staging and production environments
- storage
- CDN
- logs
- backups
- monitoring
- deployment scripts
- final infrastructure setup

## Core Architecture
- Next.js = main web application
- v0 = UI acceleration only
- Supabase / Postgres = single source of truth
- Unity WebGL = gallery runtime
- Unity Addressables = remote environment library
- default deployment target: AWS Singapore
- deployment architecture should remain portable for a future approved hosting move

## Critical Project Rule
One uploaded artwork must be:
- stored once
- authenticated once
- reused by marketplace, dashboard, certificate, and VR/WebGL gallery
- never duplicated into a second artwork source

## Compulsory Business Features
- user registration and login
- role-based access
- artwork authentication
- certificate of authenticity
- marketplace listing and sales
- escrow payment flow
- membership / subscription
- shipping method support
- insurance support
- admin approval controls
- artist dashboard
- admin dashboard
- WebGL gallery integration

## Implementation Priority
1. backend-core
2. web-marketplace
3. unity-webgl-gallery
4. infra-deployment

## Success Condition
The project is successful only if:
- one shared artwork source of truth exists
- marketplace and gallery stay synchronized
- artwork authentication is working
- business flows are complete
- deployment is documented and runnable
