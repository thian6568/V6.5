# AGENTS.md

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

## Core Architecture
- Next.js = main web app
- Supabase/Postgres = single source of truth
- Unity WebGL = gallery runtime
- Unity Addressables = remote environment loading
- AWS Singapore = final hosting
- v0 may be used only for UI acceleration, not as the main system of record

## Non-Negotiable System Rules
1. One artwork upload creates one main artwork record.
2. That same artwork record must be reused by:
   - marketplace
   - artist dashboard
   - admin dashboard
   - artwork authentication page
   - certificate page
   - VR/WebGL gallery
3. No duplicate upload path for marketplace and VR gallery.
4. Unity must read approved artwork data from backend.
5. Marketplace and VR gallery must stay synchronized after edits.
6. User authentication and artwork authentication are separate systems.
7. Escrow, subscriptions, shipping, and insurance are compulsory.
8. Admin approval logic must not be bypassed.

## MVP Boundary
For the first implementation stage, focus on:
- backend schema
- user authentication
- artwork authentication
- shared artwork logic
- marketplace listing flow
- cart and checkout flow
- escrow flow
- subscription flow
- shipping and insurance records
- WebGL gallery integration

Do not add unless explicitly requested:
- wallet connector
- Web3 marketplace logic
- blockchain smart contracts
- advanced VR headset-only features
- non-essential AI features

## Mandatory Implementation Order
1. Backend first
2. Web second
3. Unity third
4. Deployment last

Do not reverse this order without explicit approval.

## Backend Rules
- Supabase/Postgres is the single source of truth.
- Do not create a second artwork database path.
- Do not create separate marketplace artwork records and VR artwork records.
- Keep artwork authentication tied to the same core artwork record.
- Certificates, ownership history, listing status, and environment assignment must reference the same artwork record.

## Web Rules
- Next.js handles public pages, dashboards, marketplace, checkout, subscription pages, and admin tools.
- Do not move core business logic into UI-only code.
- Keep admin controls for approval, featured content, and visibility management.

## Unity Rules
- Unity must not require a second artwork upload.
- Unity must consume approved artwork metadata from backend.
- Unity must respect artwork visibility rules:
  - marketplace only
  - VR only
  - both
- Environment assignment must reference the shared artwork record.

## Security and Deployment Safety
- Never place production secrets in prompts or repo files.
- Never deploy to production before staging validation.
- Never bypass approval logic for authentication, listing visibility, or financial workflows.
- Apply cost-sensitive defaults where possible.
- Keep staging and production separate.

## Build and Test Rules
After each major change:
- run the relevant tests or validation steps
- summarize what changed
- list files changed
- state what was tested
- state what still needs review

Do not ask for PR until tests or validation are reported.

## Definition of Done
A task is not done unless:
- the shared artwork rule still holds
- no duplicate artwork storage path was introduced
- relevant tests or validation were run
- changed files are listed clearly
- risks or follow-up items are stated
- the implementation matches the current project scope

## Review Priority
When reviewing changes, prioritize:
1. shared artwork source of truth
2. artwork authentication correctness
3. marketplace and VR sync
4. checkout / escrow / subscription / shipping / insurance logic
5. deployment safety

## Working Style
- Plan first, code second.
- Keep changes small and reviewable.
- Do not invent hidden assumptions.
- If a rule conflicts with implementation, stop and explain the conflict before coding.
- If the current project folder is backend-only, do not redesign Unity or frontend.
- If the current project folder is Unity-only, do not redesign backend tables unless explicitly requested.

## Required Final Reminder
The most important rule is:

One uploaded artwork must be stored once in the core database, authenticated once, and reused by the marketplace, certificate system, dashboards, and the VR/WebGL gallery without duplicate upload.
