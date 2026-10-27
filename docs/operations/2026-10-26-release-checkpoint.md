# October 26 release checkpoint

This records evidence and remaining publishing work, not approval to merge,
deploy, upload, invite testers or submit Beta App Review. Source feature-branch
verification/push and bounded approved device checks remain authorized.

| Area | Current evidence | Still needed |
| --- | --- | --- |
| Source | Feature branch codex/calendar-write-only; isolated detail increment verified UI11/11, signed units374/374, Release/analyzer | Compatible candidate binary and exact-candidate acceptance; broader BETA-11 remains partial |
| Production schema | Read-only history recheck: head20261022170532; zero October23 migrations applied | Approved rollout of the ten ordered migrations listed in launch-handoff; deployment preflights and role/API matrix |
| Push worker | Deployed send-push version18 retrieved read-only; pending local worker fix remains separate | Approved compatible worker rollout and provider/candidate acceptance |
| Hybrid core | Real two-account create/discover/join/leave/rejoin/chat; notes persisted; physical Live Activity appearance/end owner-confirmed | Dispatch-aware alert/navigation retest, block/unblock, notes rendering on recipient, remaining offline/account-transition/accessibility/device matrix |
| Notification observation | No-alert reply14:15:48.852Z preceded14:16:01.504Z worker dispatch | New bounded controlled fixture and observation after dispatch; no notification app defect established |
| Fixture cleanup | October26 test cancelled; zero active Activity tokens; refreshed phone feed empty | October25 independently exported Calendar copy may remain; no new Calendar export occurred |
| Public pages | Privacy, Terms and Community Guidelines returned HTTPS200 in current check | Candidate browser rendering and final disclosure/metadata consistency at submission |
| Operations | Support/moderation primary previously named; owner question pending for remaining roles | Named primary and backup responders, private escalation path and recovery RPO/RTO/retention decisions |
| Store/reviewer | Last verified TestFlight1.0(5) source53ac5c7; phone current exact binary metadata unrefreshed | Current App Store Connect audit, unique new build selection, reviewer fixture refresh, age/privacy/export declarations and explicit submission authorization |

Existing local/disposable test and restore evidence stays valid for unchanged
source. Do not rerun passing SQL/Edge suites without a relevant change or an
unresolved concern. Do not treat local simulator tests as production deployment,
physical iOS17 acceptance, managed-platform recovery or Apple review acceptance.

The security advisor still reports intentional internal RLS-without-policy tables,
authenticated SECURITY DEFINER RPCs requiring the existing scoped-access audit,
and disabled leaked-password protection. This check made no policy/configuration
change. Review advisories in context rather than granting table policies or
revoking intended RPCs simply to silence the scanner. Remediation references:
[RLS without policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[authenticated definer RPCs](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable),
[password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

Detailed device evidence: [hybrid check](../testflight/2026-10-26-hybrid-device-check.md).
Detailed source scope: [isolated detail UI plan](../superpowers/plans/2026-10-26-session-detail-ui-smoke.md).
