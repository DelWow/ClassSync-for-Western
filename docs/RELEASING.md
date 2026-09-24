# Signing, Notarization, and Distribution

ClassSync is not ready for public distribution until the Western/D2L OAuth registration and production end-to-end test gate are complete.

## Prerequisites

- An Apple Developer Program team and a Developer ID Application certificate.
- A unique production bundle identifier and matching signing configuration.
- Apple notarization credentials stored in Keychain or CI secrets, never in the repository.
- Western/D2L approval for the OAuth client, redirect URI, and minimum read-only scopes.

## Archive

1. Increment `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
2. Run the unit suite and the manual release-candidate plan.
3. In Xcode, select My Mac and Product > Archive.
4. Validate the archive's sandbox entitlements: outbound network and calendar access only.
5. Export with Developer ID signing and hardened runtime enabled.

## Notarize and Staple

Use Apple's current `notarytool` workflow with credentials stored outside source control. Submit the exported archive, wait for acceptance, then staple the ticket to the app or disk image. Validate the final artifact with Gatekeeper before publishing.

Do not place Apple IDs, app-specific passwords, team secrets, OAuth client secrets, tokens, or notarization profiles in project files, scripts, logs, or CI output.

## Distribution Checklist

- [ ] Verify the app launches on a clean standard-user account.
- [ ] Verify the menu bar icon and app icon at standard resolutions.
- [ ] Verify first-run notification and calendar prompts explain their purpose.
- [ ] Verify Launch at Login registration with the signed app in its final location.
- [ ] Publish checksums and release notes alongside the notarized artifact.
- [ ] Retain the archive and notarization log for the released version.
