# API Spec (backend-core)

## Auth / Accounts
- `POST /auth/register`
- `POST /auth/login`
- `GET /profiles/me`

## Artwork + Authentication
- `POST /artworks`
- `PATCH /artworks/:id`
- `POST /artworks/:id/submit-for-approval`
- `GET /artworks/:id`
- `POST /artworks/:id/authenticate`
- `GET /authenticity/:artworkId`

## Marketplace
- `POST /listings`
- `GET /listings`
- `GET /listings/:id`
- `POST /checkout/session`
- `POST /orders/:id/confirm`

## Escrow / Refunds / Disputes
- `POST /escrow/open`
- `POST /escrow/release`
- `POST /refunds`
- `POST /disputes`

## Logistics
- `POST /shipping`
- `POST /insurance`

## Unity
- `GET /environments`
- `GET /environments/:id/approved-artworks`
- `POST /environment-assignments`
