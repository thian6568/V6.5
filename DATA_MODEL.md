# DATA_MODEL.md

## Core Data Rule
All connected platform features must use one shared artwork source of truth.

## Main Entities

### users
Purpose:
- store platform users

Main fields:
- id
- email
- password/auth reference
- role_id
- display_name
- status
- created_at
- updated_at

### roles
Purpose:
- define user permissions

Main fields:
- id
- name
- description

Examples:
- admin
- artist
- buyer

### artworks
Purpose:
- main artwork record
- single source of truth for each artwork

Main fields:
- id
- artist_user_id
- artwork_code
- title
- description
- category
- medium
- dimensions
- price
- currency
- publish_status
- visibility_mode
- created_at
- updated_at

Visibility mode:
- marketplace_only
- vr_only
- both

### artwork_assets
Purpose:
- store media files linked to artwork

Main fields:
- id
- artwork_id
- asset_type
- asset_url
- thumbnail_url
- sort_order

Examples:
- main image
- certificate file
- texture image
- preview image

### artwork_authentication
Purpose:
- store artwork authenticity details

Main fields:
- id
- artwork_id
- serial_number
- authentication_status
- certificate_id
- verification_notes
- verified_by_admin_id
- verified_at

Authentication status examples:
- pending
- approved
- rejected

### certificates
Purpose:
- store certificate records

Main fields:
- id
- artwork_id
- certificate_number
- certificate_url
- issue_date
- signature_hash
- qr_code_url
- nfc_reference

### ownership_history
Purpose:
- track ownership over time

Main fields:
- id
- artwork_id
- owner_user_id
- ownership_status
- transfer_date
- notes

### listings
Purpose:
- marketplace listing linked to artwork

Main fields:
- id
- artwork_id
- seller_user_id
- listing_status
- price
- currency
- published_at

Listing status examples:
- draft
- submitted
- approved
- live
- paused
- archived

### orders
Purpose:
- store order header

Main fields:
- id
- buyer_user_id
- order_status
- total_amount
- currency
- escrow_status
- shipping_status
- insurance_status
- created_at

### order_items
Purpose:
- store order line items

Main fields:
- id
- order_id
- artwork_id
- price
- quantity

### subscriptions
Purpose:
- membership / subscription records

Main fields:
- id
- user_id
- plan_name
- status
- start_date
- end_date
- renewal_type

### escrow_records
Purpose:
- track escrow lifecycle

Main fields:
- id
- order_id
- escrow_status
- hold_amount
- released_amount
- opened_at
- released_at
- notes

Escrow status examples:
- pending
- held
- partially_released
- released
- disputed
- cancelled

### refund_requests
Purpose:
- store refund requests

Main fields:
- id
- order_id
- requester_user_id
- reason
- refund_status
- requested_amount
- approved_amount
- created_at
- resolved_at

### disputes
Purpose:
- store dispute cases

Main fields:
- id
- order_id
- artwork_id
- dispute_type
- dispute_status
- opened_by_user_id
- assigned_admin_id
- notes

### shipping_records
Purpose:
- store shipping details

Main fields:
- id
- order_id
- carrier_name
- shipping_method
- tracking_number
- shipment_status
- shipped_at
- delivered_at

### insurance_records
Purpose:
- store insurance details

Main fields:
- id
- order_id
- provider_name
- policy_number
- insured_amount
- insurance_status

### environments
Purpose:
- store 3D environment library

Main fields:
- id
- environment_code
- name
- category
- thumbnail_url
- version
- status
- addressable_key
- performance_tier

### environment_assignments
Purpose:
- assign approved artworks to environments

Main fields:
- id
- environment_id
- artwork_id
- wall_anchor_id
- placement_x
- placement_y
- placement_z
- rotation
- scale
- assignment_status

### homepage_content
Purpose:
- manage homepage / featured content

Main fields:
- id
- content_type
- title
- body
- image_url
- sort_order
- visibility_status

### featured_content
Purpose:
- featured artists / artworks / exhibitions

Main fields:
- id
- feature_type
- linked_record_id
- start_date
- end_date
- active_status

### audit_logs
Purpose:
- record important actions

Main fields:
- id
- actor_user_id
- action_type
- entity_type
- entity_id
- log_message
- created_at

## Critical Relationships
- one user can own many artworks
- one artwork can have many assets
- one artwork has one main authentication record
- one artwork can have one or more certificates over time
- one artwork can have many ownership history records
- one artwork can have one marketplace listing at a time or versioned listings
- one order can have many order_items
- one order can have one escrow record
- one order can have shipping and insurance records
- one environment can have many environment assignments
- one artwork can be assigned to one or more environments if business rules allow

## Important Data Model Rules
1. artworks is the single source of truth for artwork identity.
2. listings must reference artworks.
3. certificates must reference artworks.
4. environment_assignments must reference artworks.
5. Unity gallery must read approved artwork data from artworks + environment_assignments.
6. No second artwork table may be created for VR-only artworks.
