# Requirements (backend-core)

## Functional
1. Maintain one canonical `artworks` record per upload.
2. Reuse that record across marketplace, certificates, dashboards, and VR gallery.
3. Separate user authentication from artwork authentication workflows.
4. Support listing lifecycle (draft, pending, approved, active, sold, archived).
5. Support escrow transaction states and dispute handling.
6. Support compliant payment intent metadata for escrow-backed checkout.
7. Support subscriptions and recurring billing references.
8. Support refund requests, shipping records, and insurance records.
9. Support certificate issuance and authenticity verification endpoints.
10. Support environment assignments for Unity WebGL scenes.

## Non-Functional
- Auditability for compliance and dispute resolution.
- Idempotent order/settlement operations.
- Strong access controls via RLS + service role boundaries.
