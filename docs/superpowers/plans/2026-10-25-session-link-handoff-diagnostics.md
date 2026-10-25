# BETA-10 session-link navigation handoff diagnostics

## Contract and scope

Instrument AppState.queueSessionDeepLink and consumePendingSessionDeepLinkIfNeeded
at their actual state decisions. Distinguish assigned navigation vs deferred for
unconfirmed/missing authentication, and resume skipped without pending ID vs
waiting for authentication vs reassigned after clearing pending state. No claim
that destination loaded, content is authorized/visible, chat opened, or delivery
worked. URL parsing, auth exchange, notification payload handling and UI unchanged.

Existing queue semantics stay exact: chat intent updates before auth branching;
confirmed auth assigns Discover detail without clearing any existing pending ID;
unauthenticated queue replaces pending ID/chat intent; resume guard reads pending
ID before authentication, clears both pending fields then calls original queue.
This produces one queue record per queue call and one resume record per consume
call (successful resume includes the nested queue record first). Do not refactor
or correct existing semantics. Account-context reset and one-shot chat unchanged.

Closed ten-field local Apple unified JSON, event session_link_handoff, operations
queue_session/resume_pending, results assigned/deferred/no_pending/waiting_for_auth/
resumed, failure none, ephemeral non-entity UUID, monotonic entry duration,
allowlisted version/build/configuration/environment. No session/user IDs, URL,
payload, email, tokens, chat intent, raw error or input logged. Fresh UUID for
nested queue and resume, no entity correlation. All info-level: no errors here.

## Files and implementation

Core/DeepLinkRouter.swift gains internal SessionLinkDiagnostics using existing
closed diagnostics conventions (Foundation+OSLog). App/PickUpUCFApp.swift gains
optional default initializer injection and entry/completion calls on AppState only.
Tests appended in existing SessionShareLinkTests.swift. No project/dependency/
backend/API changes. Example: diagnostics.finish(.queueAssigned, attempt: attempt).
First add inert injection+schema and real-state red tests, then emitters.

## Verification and limits

Fresh-context adversarial design/final review, synthetic actual AppState tests for
confirmed/unconfirmed/missing auth, pending replacement, successful resume and
nested order, pending/guard precedence, account change clearing and one-shot chat,
state-before-emission, fresh UUIDs/privacy and actual default Logger. Focused red/
green SessionLinkDiagnosticsTests/SessionShareLinkTests/AccountTransitionCoordinatorTests.
Final full normally signed isolated units on iPhone16e2680E61B-4AAF-4A52-9B42-5C5C36777DC1,
AX1/1 verified around restart/suite, unsigned Release build/analyzer. Reuse lane
commands in 2026-10-25-push-registration-decisions.md with fresh
/tmp/pickup-session-link-{red,focused,full}.{log,xcresult} paths; Release artifact
/tmp/pickup-session-link-release-analyze.log. No unchanged UI/SQL/Edge suite.
Existing human authorization covers spec/local work/source push; cross-model
skipped per autonomous continuation, no external CLI. Check usage first/major
boundaries/before costly tests; stop all work at any window >=85% used or required
human input. No merge/deployment/upload/phone/provider/production action.

## Focused and review evidence

Design review found no contract issue. Inert schema/injection red run failed16
missing-record assertions; original state/navigation assertions passed. Minimal
completion calls pass focused17/17 (seven new tests). Tests preserve confirmed/
unconfirmed/missing auth, guard precedence, pending replacement, successful
pending clearing and nested queue-before-resume order, existing pending retention
on authenticated queue, account-switch reset and one-shot chat consumption. Sink
assertions inspect actual state after each completion. Weak observed-state capture
avoids a test-only retain cycle.

Final independent review found no implementation defect. It noted default-Logger
smoke state assertions alone cannot prove logging, so actual output was separately
parsed: seven session_link_handoff records, all five results, exact ten keys,
finite operation/result/failure none, valid fresh UUIDs, nonnegative durations,
unit_test environment and privacy exclusions pass. No raw identifier, URL or intent
enters the emitter. Cross-model skipped under autonomous instructions.

## Final verification

Final normally signed isolated full suite **365/365** (seven new runtime tests).
AX1/1 checked before/after restart and after full suite. Unsigned Release build
and analyzer pass. Final actual default Logger seven session-link records cover
all five decisions; exact ten fields, finite values/failure none, unique valid
UUIDs, nonnegative durations, unit_test and privacy checks pass. Artifacts:
/tmp/pickup-session-link-{red,focused,full}.{log,xcresult},
/tmp/pickup-session-link-release-analyze.log. No unchanged UI/SQL/Edge rerun.
This is local AppState handoff evidence, not rendered destination, authorization,
provider delivery or physical-device acceptance. BETA-10/11 remain partial.
Usage after verification:73 percent five-hour/26 percent weekly used, below85.
