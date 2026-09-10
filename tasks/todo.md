# TF-02 Task Checklist

- [x] Confirm no source-controlled app or widget privacy manifest currently exists.
- [x] Inventory first-party required-reason API use.
- [x] Inventory resolved dependency required-reason API use and manifests.
- [x] Select Apple-approved UserDefaults reason `CA92.1` from actual usage.
- [x] Determine that the widget does not currently require its own manifest.
- [x] Add and validate the main app privacy manifest.
- [x] Regenerate the Xcode project and verify main-target-only membership.
- [x] Verify Debug and unsigned Release built-bundle placement and contents.
- [x] Run the iOS tests (123 passed, 0 failed).
- [x] Run an unsigned Release build and static analyzer.
- [x] Update TF-02 checklist items with concrete evidence.
- [x] Confirm the main App Store Connect record exists for `edu.ucf.pickup` (Apple ID `68107128702`); no widget record was created.
- [ ] Generate/review the final archive privacy report in Xcode Organizer (user-owned, after TF-03 through TF-05).
- [ ] Confirm/publish matching App Store Connect App Privacy answers (user-owned).

## Corrected TF-01 State

The previous “no registered physical iPhone” blocker was stale. A signed Debug physical-device build has succeeded for both app and widget, with development APNs entitlement verified for the app and no unnecessary widget App Group entitlement. Production APNs entitlement and distribution archive checks remain open until the final archive.
