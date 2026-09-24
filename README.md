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
- Mock provider and manual synchronization
- Due-date, title, creation, removal, and submission-status change detection
- Local settings for sync and future notification preferences
- macOS Keychain service for future authentication tokens

Production Brightspace authentication and networking are not implemented yet.

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

## Architecture

```text
ClassSync/
├── App/          Application entry point and observable app state
├── Models/       Provider-independent domain models and mock fixtures
├── Persistence/  SwiftData models and local store
├── Providers/    Provider protocol and mock provider
├── Services/     Sync, change detection, and Keychain services
├── Utilities/    Privacy-safe logging categories
├── Views/        Menu bar, dashboard, settings, and shared components
└── Resources/    Application metadata and assets
```

Providers return the shared `Course` and `Assignment` models. The UI and persistence layers do not depend on Brightspace response types. `SyncService` fetches the latest provider snapshot, compares it with stored data, records changes, and replaces the local assignment snapshot.

## Brightspace Integration

The app currently uses `MockAssignmentProvider`. A production provider must use an official, authorized Brightspace API or OAuth flow where available. It must support Western's MFA and access controls without asking ClassSync to retain a Western password.

ClassSync is read-only. Provider clients must not submit assignments or modify course content.

## Privacy

The local model is intentionally limited to:

- Course identifiers, names, codes, active state, and display color
- Assignment identifiers, titles, due dates, source URLs, and submission status
- Assignment change history and synchronization timestamps
- Non-sensitive application preferences

The app does not model or collect grades, messages, class lists, other students' data, or unnecessary instructor information. Future authentication tokens must be stored in macOS Keychain, never in source code or `UserDefaults`. Logs must not contain passwords, tokens, session cookies, or sensitive student data.

## Roadmap

[`TODO.md`](TODO.md) is the source of truth for project progress. The next major milestones are production Brightspace research/authentication, course and assignment mapping, notifications, reminders, and background refresh.

## Branding

The project does not use Western University's logo. Any future branding must respect university permissions and trademarks.
