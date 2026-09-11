# TF-04 Task Checklist

## Preserved Prior Work

- [x] Preserve completed TF-02 implementation evidence and its open archive/App Store Connect follow-up.
- [x] Preserve completed TF-03 implementation and agent-owned verification evidence at `ab9e67b`.
- [ ] Keep TF-03 production deployment and physical-device verification open and user-owned.

## Characterization and Regression Coverage

- [x] Reproduce the generic `LocalizedError` ordering bug.
- [x] Cover real constructible Supabase `AuthError` values.
- [x] Cover real constructible `PostgrestError` values.
- [x] Cover nested/wrapped errors and bounded unwrapping.
- [x] Cover network loss, timeouts, cancellation, domain validation, conflicts, capacity/waitlist, and permissions.
- [x] Prove unknown server/SQL/identifier/token details receive only generic copy.
- [x] Run focused tests red-first.

## Centralized Mapper

- [x] Match structured Supabase errors before generic protocol handling.
- [x] Trust only app-authored domain error copy.
- [x] Preserve safe actionable auth, network, conflict, capacity/waitlist, permission, and domain guidance.
- [x] Replace developer/admin remediation with user-appropriate copy.
- [x] Add a stable safe fallback without raw-error logging.
- [x] Run focused tests green.

## Presentation Audit and Verification

- [x] Audit every user-facing repository-error path for centralized mapping.
- [x] Preserve deliberate field-level validation feedback.
- [x] Run all focused error/view-model tests.
- [x] Run the complete iOS Debug simulator suite (149/149).
- [x] Run the unsigned generic-device Release build.
- [x] Run the Release static analyzer.
- [x] Run `git diff --check` and final security/scope review.
- [x] Update only evidence-supported TF-04 readiness boxes.

## Must Remain Out of Scope

- [x] Did not start TF-05 accessibility work.
- [x] Did not change server-side input boundaries or deploy migrations/functions.
- [x] Did not commit, push, archive, upload, or submit.
