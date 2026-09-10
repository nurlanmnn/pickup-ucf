# Implementation Plan: TF-02 Privacy Manifest and Required-Reason APIs

## Overview

Complete TF-02 for the PickUp UCF iOS app without starting later TestFlight workstreams. Inventory first-party and resolved Swift Package API/data use, add the minimum accurate privacy manifest resources, prove target membership through generated-project and built-bundle inspection, and leave archive privacy-report and App Store Connect disclosure confirmation explicitly user-owned.

## Verified Baseline

- Repository was clean on `main` at the start of this workstream (`git status --short --branch`, 2026-09-10).
- No source-controlled app or widget `PrivacyInfo.xcprivacy` existed before TF-02.
- The app directly uses `UserDefaults` for create-session defaults, Discover filter mode, and app-created calendar event identifiers.
- Those values remain inside the app's standard defaults domain; Apple required-reason code `CA92.1` accurately covers this use.
- The widget and its shared `GameLiveActivityAttributes.swift` source do not use any required-reason API or transmit/retain data.
- Resolved packages are Supabase Swift 2.46.0, swift-crypto 4.5.0, swift-asn1 1.7.0, swift-http-types 1.5.1, swift-clocks 1.0.6, swift-concurrency-extras 1.3.2, and xctest-dynamic-overlay 1.9.0.
- Source inspection found no dependency use of required-reason categories except Supabase Storage reading a file's size through `attributesOfItem`; file size is not one of Apple's file-timestamp required-reason accesses. Swift Crypto supplies its own empty/no-tracking privacy manifests, and its product manifest is present in the built app bundles.
- Repository-owned backend integrations transmit data to Supabase, Brevo, Open-Meteo, and APNs for app features. On 2026-09-10, the user confirmed these production processors are used only for app functionality, with no advertising, data-broker sharing, cross-company tracking, or undisclosed analytics/crash-reporting integration.
- The user confirmed the main App Store Connect record on 2026-09-10: PickUp UCF, bundle ID `edu.ucf.pickup`, SKU `pickup-ucf-ios`, Apple ID `68107128702`, status Prepare for Submission. No widget app record was created.

## Architecture Decisions

- Add `ios/PickUpUCF/PrivacyInfo.xcprivacy` under the app target's XcodeGen source tree so Xcode copies it to the application bundle root.
- Declare `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`; do not add unrelated approved reasons.
- Do not add a widget manifest while the extension has no required-reason API use, tracking, independent collection, or third-party dependency.
- Set tracking to false and provide no tracking domains because the repository contains no advertising, cross-app tracking, data-broker sharing, or tracking SDK.
- Declare first-party data retained by Supabase conservatively as linked to the user and not used for tracking: name, email address, device ID, precise custom game coordinates, chat messages, other user content, and product interaction for app functionality; fitness/activity data and the user ID used to retrieve it for app functionality and product personalization because preferred sports customize Discover.
- Treat on-device-only current-location display, `UserDefaults`, calendar contents, and Apple-managed framework behavior as not collected by PickUp UCF.

## Task List

### Phase 1: Inventory and manifest design

- [x] Inventory direct app and widget use of all Apple required-reason API categories.
- [x] Inventory relevant resolved dependency usage and existing dependency manifests.
- [x] Map first-party production data flows to Apple's privacy-manifest data categories and purposes.

### Phase 2: Add and validate resources

- [x] Add a syntactically valid app privacy manifest with the verified declarations.
- [x] Regenerate `PickUpUCF.xcodeproj` and confirm the manifest belongs only to the main app resources phase.
- [x] Build the app and inspect the app and embedded widget bundle roots for the expected manifest layout.
- [x] Validate every built privacy manifest with `plutil` and inspect the built declarations.

### Checkpoint: Agent-verifiable TF-02 work

- [x] Run the iOS unit suite after the resource change.
- [x] Run an unsigned Release device build and confirm the manifest remains present.
- [x] Run the Release static analyzer.
- [x] Update the readiness checklist only for items supported by the inventory and built artifacts.

### Phase 3: User-owned release verification

- [ ] Generate a privacy report from the final distribution archive in Xcode Organizer and review it against this plan.
- [ ] Confirm/publish matching App Store Connect App Privacy answers for the exact production behavior.

## Verification Evidence (2026-09-10)

- `xcodegen generate` succeeded and generated exactly one app-target resources entry for `PrivacyInfo.xcprivacy`; the widget target has no entry.
- `plutil -lint` passed for the source manifest, Debug app manifest, Release app manifest, and embedded Swift Crypto manifest.
- The source manifest matched the Debug and unsigned Release app-bundle copies byte-for-byte.
- Debug simulator tests on iPhone 17 Pro (iOS 26.3) passed: 123 tests, 0 failures (`** TEST SUCCEEDED **`).
- The unsigned generic iOS Release build passed (`** BUILD SUCCEEDED **`).
- The unsigned generic iOS Release static-analysis run passed (`** ANALYZE SUCCEEDED **`).
- The app manifest was present at `DerivedData/Build/Products/Debug-iphonesimulator/PickUpUCF.app/PrivacyInfo.xcprivacy` and `DerivedData/Build/Products/Release-iphoneos/PickUpUCF.app/PrivacyInfo.xcprivacy`.
- No `PrivacyInfo.xcprivacy` was present in either built widget extension, matching the verified absence of widget required-reason API use, collection, tracking, or third-party dependencies.
- The built app declaration contains `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1`, tracking false, no tracking domains, and the nine collected-data categories recorded under Architecture Decisions.

## Reproduction Commands

```sh
cd ios
xcodegen generate
plutil -lint PickUpUCF/PrivacyInfo.xcprivacy
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Debug -destination 'platform=iOS Simulator,id=2BFDB27E-F302-4FF8-9175-0BB43E0203C5' -derivedDataPath DerivedData -disableAutomaticPackageResolution test
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO analyze
find DerivedData -path '*PickUpUCF.app/PrivacyInfo.xcprivacy' -o -path '*PickUpUCF.app/PlugIns/PickUpUCFWidget.appex/PrivacyInfo.xcprivacy'
```

The exact destination may be adjusted to an installed simulator runtime. Built products will be inspected directly rather than inferred from Xcode project membership.

## Manual Verification and Evidence Required

1. After TF-03 through TF-05 and the final distribution archive, generate the archive privacy report in Xcode Organizer.
2. Confirm the report shows no tracking and contains only the data types and required-reason APIs documented here.
3. In App Store Connect, answer App Privacy for the main app only and report back the generated report summary plus the published data-type/purpose/linking/tracking answers.

## Dependencies

- TF-01 source signing setup is present and signed Debug device builds have already succeeded.
- Final archive/report verification remains sequenced after TF-03 through TF-05, per the readiness requirements.
- The required main App Store Connect record exists; the archive privacy report and production-matched App Privacy answers remain open.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| A dependency changes its API or manifest behavior | Privacy report may gain declarations | Re-run dependency inventory and archive privacy report after package updates |
| Production behavior differs from repository code | Store disclosure becomes inaccurate | User confirms production services and App Store answers before checking the final item |
| XcodeGen drops target membership | Manifest is absent from the bundle | Regenerate and inspect both project resources and built bundle roots |
| Over-declaring widget behavior | Misleading extension manifest | Keep the widget manifest absent until its own code or dependencies require one |

## Rollback

Remove `ios/PickUpUCF/PrivacyInfo.xcprivacy`, regenerate `ios/PickUpUCF.xcodeproj`, and rebuild. No database, runtime behavior, credentials, signing assets, or external services are changed by this workstream.

## Official Apple Sources

- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests
- https://developer.apple.com/app-store/app-privacy-details/
