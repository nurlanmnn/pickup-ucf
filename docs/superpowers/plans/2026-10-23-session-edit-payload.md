# Session edit payload — October 23, 2026

## Contract and reproduced defects

An edit saves the full editable form: sport/custom name, venue or custom pin,
schedule, capacity, skill and notes. Optional cleared fields must be JSON null,
not omitted. PostgREST PATCH only updates supplied columns
([official contract](https://docs.postgrest.org/en/stable/references/api/tables_views.html#update)).
Cancellation remains an independent status-only patch. Legacy Other-sport notes
stay composed for older clients; no stricter database representation is added.

Five synthetic HTTP regressions failed before implementation: renaming an
existing Other sport retained the old database/display name; selecting a standard
sport retained the custom name; blank notes retained old notes; venue → custom pin
retained venue_id; custom pin → venue retained the old label/coordinates.
The tests intercept the actual SDK requests and model persisted PATCH state.

## Local fix

SessionRowPatch now includes the already-normalized custom_sport_name and explicitly
encodes nil editable fields. No create RPC, status patch, grant or schema changes.
The deployed schema already has this column and its authenticated UPDATE grant.
The pending host-edit guard accepts both explicit-null location switches and the
older build-5 omitted-null representation.

## Verification

- Focused SessionCreationTests: 13/13 passed after five edit regressions failed red.
- HTTP uses a synthetic .invalid host and intercepts every request with URLProtocol.
- Scheme has PICKUP_UNIT_TESTS=1; shared client denies HTTP and bootstrap skips.
- Independent read-only review found no actionable correctness, compatibility,
  security or test-validity issue.
- Full signed isolated simulator suite: 267/267 passed on iPhone 16e / iOS 26.3.1.
- Initial unsigned full run failed three existing Keychain tests (five assertions,
  including two unexpected errors). Those tests explicitly require signing;
  normal simulator signing fixed the setup. No app change was needed for them.
- Unsigned generic-iOS Release build and Release analyzer passed.
- git diff --check passed.
- Logs: /tmp/pickup-edit-red.log, /tmp/pickup-edit-green.log,
  /tmp/pickup-edit-full-ios.log (unsigned setup failure),
  /tmp/pickup-edit-full-signed-ios.log, /tmp/pickup-edit-release-analyze.log.

Local source only. TestFlight build 5 is unchanged; compatible candidate upload and
physical-device edit acceptance remain open. No deployment, push or upload.
