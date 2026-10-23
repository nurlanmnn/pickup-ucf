# Server-owned message fields — October 23, 2026

## Contract

Message UUID and created_at come from server defaults. Authenticated inserts
accept only session_id, user_id and body, matching current source and TestFlight
build 5's MessageInsert. A crafted participant must not poison cursor ordering
or Date decoding with arbitrary/nonfinite timestamps. Trusted maintenance keeps
its existing privileges; no stored history rewrite is proposed.

Reproduce a crafted infinity timestamp inside synthetic rollback fixtures before
restricting column INSERT grants. Verify normal three-field sends still succeed.

## Local fix and evidence

The red SQL probe accepted created_at=infinity and failed with
`participant can forge message timestamp`. Migration 20261023225500 removes
client INSERT privileges at table and column levels, then grants only the three
SDK payload fields. Current source and build-5 source 53ac5c7 both match that
shape. SELECT/RETURNING, RLS, defaults and trusted service privileges are preserved.

Full candidate SQL/RLS passes 37 phase notices inside rollback, including
positive/negative infinity, forged future/past time and explicit UUID rejection,
and successful three-field insertion returning a finite server timestamp/UUID.
Independent review found no actionable issue; git diff --check passed. Logs:
/tmp/pickup-message-fields-red.log and /tmp/pickup-message-fields-candidate-sql.log.
No Swift or Edge code changed; their unchanged passing suites were not repeated.

Local source only; migration remains undeployed. No claim of historical-data
cleanup or exact-candidate production acceptance is made.
