# ACCEPTANCE_CHECKLIST.md

## Core Architecture
- [ ] Supabase / Postgres is the single source of truth
- [ ] one artwork upload creates one main artwork record
- [ ] no duplicate artwork upload path exists for VR
- [ ] marketplace and VR use the same artwork record
- [ ] artwork edits stay synchronized across connected systems

## User Authentication
- [ ] user can register
- [ ] user can login
- [ ] user can logout
- [ ] user can reset password
- [ ] role-based access works
- [ ] admin, artist, and buyer roles are separated correctly

## Artwork Authentication
- [ ] artwork has unique artwork ID
- [ ] artwork has serial number
- [ ] certificate record can be created
- [ ] authenticity status can be stored
- [ ] ownership record can be stored
- [ ] verification page can be generated
- [ ] QR / NFC-ready structure exists
- [ ] admin verification controls work

## Marketplace / E-commerce
- [ ] artwork listing page works
- [ ] artwork detail page works
- [ ] cart works
- [ ] checkout works
- [ ] invoice / receipt flow works
- [ ] order records are stored
- [ ] refund request flow works
- [ ] escrow record flow exists
- [ ] subscription flow exists
- [ ] shipping method record exists
- [ ] insurance record exists

## Artist Dashboard
- [ ] artist can upload artwork
- [ ] artist can edit artwork
- [ ] artist can publish / unpublish artwork
- [ ] artist can set visibility mode
- [ ] artist can view orders / sales
- [ ] artist can view statement / payout summary
- [ ] artist can manage artwork authentication details

## Admin Dashboard
- [ ] admin can manage users
- [ ] admin can manage artworks
- [ ] admin can approve / reject artwork authentication
- [ ] admin can approve / reject listing visibility
- [ ] admin can manage orders
- [ ] admin can manage homepage / featured content
- [ ] admin can review refunds / disputes

## Unity / WebGL Gallery
- [ ] WebGL gallery loads
- [ ] custom environments can be loaded
- [ ] environment preview / thumbnail exists
- [ ] approved artworks can auto-load into selected environment
- [ ] Unity reads approved artwork data from backend
- [ ] Unity does not require a second artwork upload
- [ ] visibility rules are respected

## Deployment
- [ ] staging environment exists
- [ ] production environment exists
- [ ] storage is configured
- [ ] CDN is configured
- [ ] logs are available
- [ ] backups are configured
- [ ] deployment remains portable if provider changes later

## Done Only If
- [ ] relevant validation or tests were run
- [ ] changed files were listed clearly
- [ ] known risks or follow-up items were stated
- [ ] architecture rules were not broken
