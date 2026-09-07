# Implementation Plan: TF-01 Signing, Capabilities, and Archive

## Overview

Complete the remaining TF-01 release work for PickUp UCF after the app icon was added. The Apple Developer team is `AS53KCG63V`; the registered bundle identifiers are `edu.ucf.pickup` and `edu.ucf.pickup.widget`. The app and widget do not currently share a container, so no App Group entitlement will be added.

## Architecture Decisions

- Keep `ios/project.yml` as the source of truth and regenerate the Xcode project with XcodeGen.
- Use automatic signing for the app, widget, and unit-test targets.
- Generate the main app entitlement file from XcodeGen so `CODE_SIGN_ENTITLEMENTS` survives project regeneration.
- Declare `aps-environment` as `development` in source. Xcode selects the final APNs environment from the provisioning profile and uses `production` for TestFlight distribution.
- Add no widget entitlement file until the widget needs an Apple capability or shared container.
- Increment the build number immediately before the first upload so an unused build number is not consumed during local verification.

## Task List

### Phase 1: Source-controlled signing configuration

- [x] Configure team `AS53KCG63V` for the app, widget, and test targets.
- [x] Generate `PickUpUCF.entitlements` with Push Notifications enabled for the main app.
- [x] Preserve the registered app and widget bundle identifiers.
- [x] Keep App Groups absent from both targets.

### Checkpoint: Project regeneration

- [x] `xcodegen generate` succeeds.
- [x] The generated project contains the app icon catalog and `CODE_SIGN_ENTITLEMENTS`.
- [x] Debug and Release build settings resolve the expected team and bundle identifiers.

### Phase 2: Build and entitlement verification

- [x] Unsigned Release build succeeds and contains `Assets.car` and the app icon.
- [ ] A signed device/archive build resolves automatic provisioning for both targets.
- [ ] The distribution-signed app contains `aps-environment = production`.
- [ ] The widget contains no unneeded App Group entitlement.

### Phase 3: First TestFlight archive

- [ ] Increment the build number for the upload.
- [ ] Create a Release archive in Xcode Organizer.
- [ ] Validate the archive and resolve every blocking issue.
- [ ] Upload and confirm App Store Connect finishes processing the build.
- [ ] Install the processed build through TestFlight on a physical device.

## Verification Commands

```sh
cd ios
xcodegen generate
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' archive
codesign -d --entitlements - --xml "/path/to/PickUpUCF.app"
```

Use Xcode Organizer for App Store validation and upload. Do not place certificates, provisioning profiles, `.p8` keys, or passwords in the repository.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Push Notifications is not enabled on the registered main App ID | Signed build or APNs registration fails | Let automatic signing refresh the profile, then inspect the signed entitlement |
| A local signing certificate is missing | Archive cannot be signed | Use Xcode Accounts to create/download the Apple Development or Distribution certificate |
| App and widget profiles resolve under different teams | Embedded-extension validation fails | Pin the same team and automatic signing on every target |
| Build number was already uploaded | App Store Connect rejects the upload | Check existing TestFlight builds and increment immediately before upload |

## Rollback

Remove the generated entitlement declaration and team settings from `ios/project.yml`, regenerate the project, and delete `ios/PickUpUCF/PickUpUCF.entitlements`. The app icon change is independent and does not need to be rolled back.

## Open Validation

- Confirm the registered `edu.ucf.pickup` App ID has Push Notifications enabled by successfully resolving a signed provisioning profile.
- Confirm a valid signing certificate for team `AS53KCG63V` is available on this Mac.
- Register at least one physical iPhone with team `AS53KCG63V`; Apple currently refuses to create development provisioning profiles because the team has no registered devices.
