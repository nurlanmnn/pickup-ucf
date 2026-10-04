# PickUp UCF — External TestFlight Readiness Plan

## Objective

Complete the operational, policy, reviewer-access, metadata, and production-evidence work required to move from internal TestFlight to a small external cohort. The release owner confirmed TF-06 physical-device smoke completion on 2026-10-04. The exact external candidate must still satisfy the separate EXT-06 go/no-go gate.

## Phase 1 — Public policy surfaces

1. Add a publishable Terms of Use page consistent with the Privacy Policy and Community Guidelines.
2. Cross-link the three public policy pages and add Terms to the in-app Settings screen.
3. [Completed 2026-09-30] Deploy the policy-site revision and verify every URL over HTTPS on mobile and desktop.
4. [Completed 2026-09-30] Confirm Nurlan Mammadli as the operating identity and `support.roomateapp@gmail.com` as the monitored support address.

**Acceptance:** Privacy Policy, Terms, Community Guidelines, and support contact are reachable from the app and public site without placeholders.

## Phase 2 — Operational ownership

1. Name primary and backup owners for support, moderation, backend operations, notifications, and release decisions.
2. Confirm the support mailbox accepts external mail and establish monitoring coverage.
3. [Completed 2026-09-30] Provision Nurlan Mammadli as the production moderator through a privileged path; server verification returned one moderator row and a successful moderator role check. Ordinary-user runtime verification remains in the production evidence phase.
4. Store personal contact details and privileged account identifiers outside Git.

**Acceptance:** Every safety and production event has a named responder, backup, response target, and private escalation path.

## Phase 3 — Production evidence

1. Execute the anonymous/authenticated/blocked/suspended/moderator/deleted RLS matrix with disposable accounts.
2. Exercise verification and password-reset email success and failure paths.
3. Verify notification scheduling, authorization, delivery, invalid-token cleanup, deep links, and monitoring.
4. Test account deletion and reconcile retained data with the published policy.
5. Record backup, restore, migration, secret-rotation, rollback, and incident procedures.

**Acceptance:** Production services pass end-to-end checks on the candidate configuration, and recovery expectations are recorded.

## Phase 4 — Reviewer access and metadata

1. [Completed 2026-10-04] Create a dedicated preverified reviewer account and synthetic seed data; release owner confirmed TestFlight sign-in and checked the seeded experience. Build/device and individual action results were not supplied.
2. Complete the external review packet with candidate identity, contact details, credentials, known issues, and exact test instructions.
3. Complete age-rating and export-compliance declarations based on shipped behavior.
4. Create a small external group without inviting testers yet.

**Acceptance:** A reviewer can exercise every review-relevant feature from a fresh install without contacting the developer.

## Phase 5 — Go/no-go and submission

1. Run the full two-account/two-device critical path on the exact candidate build.
2. Confirm there are no open P0 issues and assign every accepted P1 issue to an owner and target build.
3. Submit the build to TestFlight Beta App Review.
4. After approval, release to 5–15 known testers and monitor the first hour and day before expanding.

**Acceptance:** The first cohort receives an approved, supportable build with recorded production state and stop conditions.

## Dependencies and boundaries

- Policy deployment must precede a build that exposes the Terms URL.
- Named ownership must precede moderator provisioning and external invitations.
- Reviewer credentials and personal contact information must never be committed.
- External testers must not be invited until the exact candidate passes the go/no-go gate.
- A production migration, secret change, account grant, TestFlight submission, or external invitation must be recorded in the release evidence when performed.
