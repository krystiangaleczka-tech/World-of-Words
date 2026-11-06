# T-0226 native iOS build preparation

Main baseline: e1da1ee51cbb167e1f34f81c471d0e662c044d63.
Prepared a macOS nightly/manual unsigned build loop and iOS Debug export
preset. Android IDs remain unchanged and minimum iOS 17 is explicit.

## Remaining owner/native gates
- Set repository variables IOS_APPLE_TEAM_ID and IOS_BUNDLE_IDENTIFIER.
- Run build-ios and inspect engine import/export, Xcode compile and artifacts.
- Provision credentials through approved secrets workflow at T-0316, never
  through an export preset in the repository.
- Test on a real iPhone, including Ambient silent switch, interruptions,
  feedback patterns and lifecycle. No native-device evidence is claimed.

## No false positives
If variables are missing the macOS job is SKIPPED and the configuration
job emits NOT RUN. It does not mean iOS export passed. This PR is draft
until an actual macOS run and independent review.
