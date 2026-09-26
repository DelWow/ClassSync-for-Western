# ClassSync for Western

ClassSync is a native macOS menu bar application for tracking course assignments and due-date changes. It can build a local schedule from reviewed syllabus imports and a private Brightspace calendar feed, then look for deadline-change messages in a Western account already configured in Apple Mail.

> This is an independent student project and is not affiliated with, endorsed by, or operated by Western University.

## Current Features

- Native SwiftUI `MenuBarExtra` with an agent-style menu bar presence
- Upcoming, submitted, overdue, and no-due-date assignment states
- Today, Tomorrow, This Week, Overdue, and No Due Date grouping
- Full dashboard with focused Today, Upcoming, Calendar, Changes, and Courses sections
- Search and course filtering
- Assignment and notification links open in Google Chrome, with Safari as the fallback
- Local SwiftData storage for courses, assignments, changes, and sync metadata
- Provider-independent assignment and course models
- Isolated, read-only Western Brightspace client and mapping layer with sanitized contract tests
- Reviewed local syllabus import for text-based PDF, plain-text, RTF, and Word documents
- Opt-in private Western Brightspace iCalendar feed sync with Keychain storage
- Opt-in local Apple Mail deadline-change detection with an approval step
- Multi-source reconciliation that prefers official/calendar data while retaining syllabus fallbacks
- Mock provider and manual synchronization in Debug builds
- Due-date, title, creation, removal, and submission-status change detection
- Local settings for sync and future notification preferences
- macOS Keychain service for future authentication tokens
- Native deadline reminders and assignment-change notifications
- Optional Apple Calendar deadline sync with update and deduplication support
- Deferrable background refresh using `NSBackgroundActivityScheduler`
- Launch at Login using `SMAppService.mainApp`

The official Brightspace API client foundation is implemented but remains approval-gated. Syllabus import, the user's private Brightspace calendar feed, and local Apple Mail review provide useful read-only workflows without asking for a Western password or bypassing MFA.

Background refresh uses macOS's energy-aware scheduler. The selected interval is a request, not an exact guarantee: macOS may defer work based on battery, thermal, and system conditions. Manual Sync Now remains available at all times.

Assignment change history is retained locally for up to one year and capped at the 1,000 most recent records.

Apple Calendar integration is off by default. Enabling it from Settings requests full EventKit access because ClassSync must find, update, and remove the events it creates when deadlines change. ClassSync stores a local assignment-to-event identifier map and does not import unrelated calendar contents.

## Local Course Sources

Open Settings and use **Course Sources** to add data:

1. Choose **Import Syllabus**, review every detected item, correct any course or date details, and import only the selected rows. The parser handles common month-first, day-first, numeric, 12-hour, and 24-hour formats and reconstructs nearby cells from many PDF tables. Past dates are highlighted and can be moved forward by whole years or deselected in bulk. Re-importing replaces that course's earlier syllabus snapshot. Documents are read locally and are not copied or uploaded. Image-only/scanned PDFs require future OCR support.
2. In Brightspace, copy your private Calendar subscription URL and paste it directly into ClassSync's secure field. ClassSync accepts only an HTTPS Western Brightspace calendar-feed URL and stores it in macOS Keychain. Feed imports retain deadlines from the previous 60 days through the next 400 days so historical courses do not overwhelm the app. Treat this URL as a credential: never paste it into chat, source code, screenshots, or logs.
3. Add the Western account to Apple Mail, enable email scanning in ClassSync, and choose **Scan Now**. macOS will ask whether ClassSync may automate Mail. Only recent Inbox messages from `@uwo.ca` or `@westernu.ca` accounts are inspected locally. ClassSync presents possible changes for approval and does not save message bodies.

**Sync Now** refreshes the connected calendar feed and, only when enabled, scans Apple Mail. A feed or email cannot guarantee that every quiz or deadline is represented, so users should review imported data against the official course pages.

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

Debug builds show local sample data when the database has no configured source; those samples are removed as soon as a syllabus is imported or a private calendar feed is connected. Release builds never present fixtures as real LMS data: they use only configured local/feed sources until approved OAuth registration is available. `Providers/Brightspace` also contains the production-facing read-only API boundary: response models, a mapper, a Bearer-token HTTP client, Keychain-backed credential storage, and a provider that can aggregate active courses, due-date calendar events, assignment folders, and the current user's submission state.

Western's OWL tenant is configured as `https://westernu.brightspace.com`. The client targets LP `1.49` for current-user enrollments and LE `1.82` for calendar and assignment-folder reads. It requests only these scopes:

- `enrollment:own_enrollment:read`
- `calendar:my_events:read`
- `dropbox:folders:read`

Brightspace requires an OAuth application registration before API access. Western's Brightspace administrator must approve/register ClassSync, its redirect URI, and these scopes. Do not add a client secret to this repository or ship one inside the macOS app. D2L's documented authorization-code flow uses a client secret, so the final exchange design must be agreed with Western/D2L before account connection is enabled. Settings presents the intended **Sign in with Western** action in a disabled approval-gated state; the mock provider remains the safe default until the required configuration is available.

The intended threat boundary is narrow: authentication occurs through the university/Brightspace login experience (including MFA), tokens are stored only in macOS Keychain, API requests use TLS and Bearer authorization, logs never contain credentials, and provider responses are mapped into minimal shared models. Expired tokens produce a reconnect-required error. ClassSync never requests or stores a Western password.

ClassSync is read-only. Provider clients must not submit assignments or modify course content.

## Privacy

The local model is intentionally limited to:

- Course identifiers, names, codes, active state, and display color
- Assignment identifiers, titles, due dates, source URLs, and submission status
- Assignment change history and synchronization timestamps
- Non-sensitive application preferences
- Opaque identifiers for email messages already reviewed, without their subjects or bodies

Syllabus contents and inspected email bodies are processed transiently on the Mac and are not retained. The private Brightspace calendar URL is stored only in Keychain. The app does not model or collect grades, class lists, other students' data, or unnecessary instructor information. Future authentication tokens must be stored in macOS Keychain, never in source code or `UserDefaults`. Logs must not contain passwords, tokens, session cookies, private feed URLs, email contents, or sensitive student data.

Keychain entries use the application bundle identifier as their service scope and `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so credentials do not migrate to another device. Secret configuration filenames are ignored by Git; production credentials must come from an approved external configuration or service and must never be embedded in the app bundle.

## Roadmap

[`TODO.md`](TODO.md) is the source of truth for project progress. Real-account validation is still required for the private calendar and Apple Mail workflows. Official full Brightspace API access remains gated on Western/D2L OAuth registration; future LMS and multi-university providers remain post-MVP work.

## Branding

The project does not use Western University's logo. Any future branding must respect university permissions and trademarks.
