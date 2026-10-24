# Push outbox failure recovery

October 24, 2026. Source/mock verification only; Edge deployment remains unauthorized.

## Reproduced defects

A synthetic APNs transport rejection for the first pending notification escaped
`sendToUserDevices` and rejected the whole handler. Later unrelated notifications
were not attempted. Repeated failure of an early row could starve later recipients.
A second regression injected an outbox acknowledgement database error: the handler
reported `sent: 2` even though only one of the two rows was acknowledged.

Both regressions failed against the previous source before implementation:
`handler keeps a failed notification pending and delivers later rows` threw the
synthetic transport error; `handler counts only persisted notification
acknowledgements` reported two instead of one.

## Change

The existing outbox loop handles each row's send and acknowledgement in a try/catch.
A failed row remains unacknowledged, the worker emits a fixed privacy-safe retry
warning, and later recipients are attempted. A database acknowledgement error does
not advance the response count. Authentication, batch order/size, APNs payloads,
Live Activity processing and current any-device-success semantics are unchanged.
This preserves the existing at-least-once behavior: APNs success followed by a
failed acknowledgement can produce a duplicate on retry; this fix does not claim
exactly-once delivery or independent retries for each of a user's devices.

## Verification

`deno test --allow-env supabase/functions/send-push supabase/functions/send-auth-email`
passed **31/31 with type checking**, including both red-to-green regressions.
Synthetic clients/provider callbacks cover first-row transport failure followed by
healthy delivery and database acknowledgement failure followed by a successful row.
No live provider, credentials, database or APNs endpoint was contacted. Unchanged
weather/iOS/SQL suites were not repeated for this isolated Edge change.

Independent final source/test review approved the change with no required findings. No production
Edge deployment occurred. Physical notification/APNs acceptance remains open.
