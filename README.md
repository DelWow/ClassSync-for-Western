# ClassSync for Western

ClassSync is a native macOS menu bar application for tracking course assignments and due-date changes. The current development build uses local mock Brightspace data while the user interface, persistence, provider boundary, synchronization engine, and change detection are developed and tested.

> This is an independent student project and is not affiliated with, endorsed by, or operated by Western University.

## Current Features

- Native SwiftUI `MenuBarExtra` with an agent-style menu bar presence
- Upcoming, submitted, overdue, and no-due-date assignment states
- Today, Tomorrow, This Week, Overdue, and No Due Date grouping
- Full dashboard with Today, Upcoming, Calendar, Changes, Courses, and Settings sections
- Search and course filtering
- Local SwiftData storage for courses, assignments, changes, and sync metadata
- Provider-independent assignment and course models
- Isolated, read-only Western Brightspace client and mapping layer with sanitized contract tests
- Mock provider and manual synchronization
- Due-date, title, creation, removal, and submission-status change detection
- Local settings for sync and future notification preferences
- macOS Keychain service for future authentication tokens
- Native deadline reminders and assignment-change notifications
- Optional Apple Calendar deadline sync with update and deduplication support
- Deferrable background refresh using `NSBackgroundActivityScheduler`
- Launch at Login using `SMAppService.mainApp`

The Brightspace client foundation is implemented but is not selected by the app yet. The development build continues to use the mock provider until Western approves/registers the OAuth application and supplies the required public configuration.

Background refresh uses macOS's energy-aware scheduler. The selected interval is a request, not an exact guarantee: macOS may defer work based on battery, thermal, and system conditions. Manual Sync Now remains available at all times.

Assignment change history is retained locally for up to one year and capped at the 1,000 most recent records.

Apple Calendar integration is off by default. Enabling it from Settings requests full EventKit access because ClassSync must find, update, and remove the events it creates when deadlines change. ClassSync stores a local assignment-to-event identifier map and does not import unrelated calendar contents.

## Requirements

- macOS 14 or newer
- Xcode 26.3 or a compatible Xcode version with the macOS 14 SDK
- Swift 5 language mode or newer

## Build and Test

Open `ClassSync.xcodeproj` in Xcode and run the shared `ClassSync` scheme, or use:

```sh
xcodebuild \
  -project ClassSync.xcodeproj \
  -scheme ClassSync \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Run unit tests with:

```sh
xcodebuild test \
  -project ClassSync.xcodeproj \
  -scheme ClassSync \
  -configuration Debug \
  -destination 'platform=macOS'
```

Release candidates should also follow [`docs/MANUAL_TESTING.md`](docs/MANUAL_TESTING.md). Signing and notarization handoff is documented in [`docs/RELEASING.md`](docs/RELEASING.md). A GitHub Actions workflow is ready to run the same macOS test suite after the files are committed and pushed.

## Architecture

```text
ClassSync/
├── App/          Application entry point and observable app state
├── Models/       Provider-independent domain models and mock fixtures
├── Persistence/  SwiftData models and local store
├── Providers/    Provider protocol, mock provider, and isolated Brightspace adapter
├── Services/     Sync, change detection, and Keychain services
├── Utilities/    Privacy-safe logging categories
├── Views/        Menu bar, dashboard, settings, and shared components
└── Resources/    Application metadata and assets
```

Providers return the shared `Course` and `Assignment` models. The UI and persistence layers do not depend on Brightspace response types. `SyncService` fetches the latest provider snapshot, compares it with stored data, records changes, and replaces the local assignment snapshot.

## Brightspace Integration

Debug builds use `MockAssignmentProvider` for deterministic offline development. Release builds never present fixtures as real LMS data: they use an unavailable production placeholder until approved OAuth registration is configured. `Providers/Brightspace` contains the production-facing read-only boundary: response models, a mapper, a Bearer-token HTTP client, Keychain-backed credential storage, and a provider that aggregates active courses, due-date calendar events, assignment folders, and the current user's submission state.

Western's OWL tenant is configured as `https://westernu.brightspace.com`. The client targets LP `1.49` for current-user enrollments and LE `1.82` for calendar and assignment-folder reads. It requests only these scopes:

- `enrollment:own_enrollment:read`
- `calendar:my_events:read`
- `dropbox:folders:read`

Brightspace requires an OAuth application registration before API access. Western's Brightspace administrator must approve/register ClassSync, its redirect URI, and these scopes. Do not add a client secret to this repository or ship one inside the macOS app. D2L's documented authorization-code flow uses a client secret, so the final exchange design must be agreed with Western/D2L before the Connect Account UI is enabled. Until then, no production login is presented and the mock provider remains the safe default.

The intended threat boundary is narrow: authentication occurs through the university/Brightspace login experience (including MFA), tokens are stored only in macOS Keychain, API requests use TLS and Bearer authorization, logs never contain credentials, and provider responses are mapped into minimal shared models. Expired tokens produce a reconnect-required error. ClassSync never requests or stores a Western password.

ClassSync is read-only. Provider clients must not submit assignments or modify course content.

## Privacy

The local model is intentionally limited to:

- Course identifiers, names, codes, active state, and display color
- Assignment identifiers, titles, due dates, source URLs, and submission status
- Assignment change history and synchronization timestamps
- Non-sensitive application preferences

The app does not model or collect grades, messages, class lists, other students' data, or unnecessary instructor information. Future authentication tokens must be stored in macOS Keychain, never in source code or `UserDefaults`. Logs must not contain passwords, tokens, session cookies, or sensitive student data.

Keychain entries use the application bundle identifier as their service scope and `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so credentials do not migrate to another device. Secret configuration filenames are ignored by Git; production credentials must come from an approved external configuration or service and must never be embedded in the app bundle.

## Roadmap

[`TODO.md`](TODO.md) is the source of truth for project progress. The main MVP gate is now Western/D2L OAuth registration and production end-to-end validation; future LMS and multi-university providers remain post-MVP work.

## Branding

The project does not use Western University's logo. Any future branding must respect university permissions and trademarks.
