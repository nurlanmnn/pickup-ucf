# Correct the soccer session venue to RWC Park

Rename the official Soccer Practice Fields venue in place to RWC Park and replace
its coordinates with UCF's official directions pin: 28.592627488099,
-81.200138801506. Preserve its ID and all existing session references.

Sources:
- https://www.ucf.edu/location/rwc-park/ (Get Directions target supplies coordinates)
- https://www.imleagues.com/School/ViewFacility.aspx?Id=0da9202f270d4f3a8af270677c853008&SchId=136f2fd71bae48bc8ee2f37e418505d9
  lists 12669 Scholarship Dr, Orlando, FL 32816, USA.

Update seed.sql for new databases and add a data migration for existing databases.
Verify the update in a rolled-back local transaction, then apply this single
correction to the connected pickup-ucf production project and re-read the venue.
Session maps and Apple Maps use venue coordinates already; no iOS change needed.
Rollback: update the same venue back to Soccer Practice Fields, 28.5975, -81.1905.
No unrelated venue corrections, backend deployments, or Git push are included.

## Verification

Docker was unavailable, so the exact update was tested against the connected
project in a transaction that was rolled back. One official venue updated and
retained its ID. Applied the single correction as a tracked production migration
`20261014134738_correct_soccer_venue_to_rwc_park`; the local file version matches
the migration version returned by the server. Updated the seed for fresh databases.
No schema, grants, RLS, app code, or other venue records were changed.
