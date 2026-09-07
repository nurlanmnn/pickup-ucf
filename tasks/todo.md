# TF-01 Task Checklist

- [x] Add the production 1024×1024 app icon.
- [x] Compile the asset catalog into an unsigned Release bundle.
- [x] Register `edu.ucf.pickup` with Apple.
- [x] Register `edu.ucf.pickup.widget` with Apple.
- [x] Verify that no App Group is currently required.
- [x] Configure team `AS53KCG63V` for every target.
- [x] Add source-controlled Push Notifications entitlements to the main app.
- [x] Regenerate the Xcode project and verify build settings.
- [ ] Resolve signed provisioning for the app and widget.
- [ ] Verify the distribution-signed APNs entitlement is `production`.
- [ ] Increment the build number.
- [ ] Archive, validate, and upload through Xcode Organizer.
- [ ] Confirm App Store Connect processing and physical-device TestFlight installation.

## Current blocker

Apple cannot create development provisioning profiles until team `AS53KCG63V` has at least one registered physical iPhone.
