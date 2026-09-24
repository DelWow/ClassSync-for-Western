# Project TODO

This file is the source of truth for project progress. Check an item only after its implementation works and has been validated. Leave partial work unchecked, preserve unfinished tasks, and add newly discovered work under the appropriate phase.

## Phase 0 — Repository and Project Setup

- [x] Establish `TODO.md` as the source-of-truth roadmap
- [x] Create the native macOS application project
- [x] Configure the application as a SwiftUI app
- [x] Set a reasonable minimum supported macOS version
- [x] Set the application name and bundle identifier
- [x] Create the initial app, model, view, service, provider, persistence, utility, and resource organization
- [x] Add a project `.gitignore` for Xcode output, user state, and secret configuration
- [x] Confirm the project opens in Xcode
- [x] Confirm the project builds successfully
- [x] Confirm the application launches successfully
- [x] Document local development prerequisites

## Phase 1 — Native macOS Menu Bar Foundation

- [x] Create the SwiftUI application entry point
- [x] Create a native `MenuBarExtra`
- [x] Add a menu bar icon and accessible label
- [x] Open a SwiftUI menu bar window when the icon is selected
- [x] Display the application name in the menu bar window
- [x] Add a working Sync Now button
- [x] Display the last sync time or Never state
- [x] Add a working Open Dashboard button
- [x] Add a working Settings button
- [x] Add a working Quit button
- [ ] Verify core menu actions using the running application

## Phase 2 — Assignment and Course Domain Models

- [x] Create the shared assignment model
- [x] Create the shared course model
- [x] Create the assignment status enum
- [x] Create the assignment source enum
- [x] Create the assignment change model
- [x] Create the assignment change type enum
- [x] Define stable internal and provider identifier behavior
- [x] Represent optional due dates safely
- [x] Represent optional source URLs safely
- [x] Add model unit tests

## Phase 3 — SwiftData Persistence

- [x] Configure the SwiftData model container
- [x] Create the persistent course model
- [x] Create the persistent assignment model
- [x] Create the persistent assignment change model
- [x] Create the persistent sync metadata model
- [x] Persist non-sensitive user preferences where appropriate
- [ ] Persist provider configuration without credentials or tokens
- [x] Implement conversion between persistence and domain models if needed
- [x] Prevent duplicate persistent courses
- [x] Prevent duplicate persistent assignments
- [x] Test saving courses and assignments
- [ ] Test loading saved data after application restart
- [ ] Define a practical schema migration strategy
- [x] Handle persistence initialization and migration failures safely

## Phase 4 — Mock Assignment Data

- [x] Add representative development/mock assignments
- [x] Include assignments due today, tomorrow, and later this week
- [x] Include an overdue assignment fixture
- [x] Include an assignment without a due date fixture
- [x] Include a long assignment title fixture
- [x] Sort mock assignments by due date
- [x] Group mock assignments into Today, Tomorrow, This Week, and No Due Date
- [x] Display mock assignments in the menu bar interface
- [x] Verify the mock-data UI does not require network access

## Phase 5 — Menu Bar Assignment Experience

- [x] Show each assignment title
- [x] Show each assignment course name or code
- [x] Show each assignment due date and time
- [x] Show each assignment source
- [x] Show an upcoming assignment count
- [x] Visually distinguish overdue assignments without relying on color alone
- [x] Visually distinguish submitted assignments when status is available
- [x] Make assignments with source URLs clickable
- [x] Open assignment URLs in the default browser
- [x] Handle long assignment and course names gracefully
- [x] Add useful empty states for each date group
- [x] Add a compact loading state
- [x] Add a compact synchronization error state

## Phase 6 — Dashboard

- [x] Create a full native macOS dashboard window
- [x] Open the dashboard from the menu bar
- [x] Add sidebar navigation
- [x] Add the Today section
- [x] Add the Upcoming section
- [x] Add the Calendar section
- [x] Add the Changes section
- [x] Add the Courses section
- [x] Add the Settings section
- [x] Add the upcoming assignment list
- [x] Add course filtering
- [x] Add assignment search
- [x] Preserve window sizing and sensible macOS behavior
- [x] Add useful empty, loading, and error states

## Phase 7 — Provider Architecture

- [x] Define an LMS assignment-provider protocol
- [x] Define provider authentication behavior
- [x] Define course-fetching behavior
- [x] Define assignment-fetching behavior
- [x] Define provider capability and availability metadata
- [x] Keep provider-specific data types outside shared UI code
- [x] Normalize provider output into shared course and assignment models
- [x] Add dependency injection for provider selection
- [x] Create a mock provider for offline development and tests
- [x] Add provider contract tests

## Phase 8 — Brightspace Integration Layer

- [x] Create the isolated Brightspace provider directory
- [x] Create `BrightspaceProvider`
- [x] Create `BrightspaceClient`
- [x] Create Brightspace response models
- [x] Create `BrightspaceMapper`
- [x] Create the Brightspace authentication component
- [x] Determine Western OWL Brightspace tenant and supported official API configuration
- [x] Document required university approval or API registration
- [x] Implement authenticated read-only requests
- [x] Map Brightspace errors into user-safe application errors
- [x] Ensure shared UI does not depend on Brightspace response types
- [x] Prevent write, submission, or course-content modification operations

## Phase 9 — Authentication

- [x] Research official Brightspace OAuth/API access for Western
- [x] Prefer official OAuth when it is available
- [x] Document the authentication approach and threat model
- [ ] Implement a secure connect-account flow
- [ ] Support MFA without bypassing university protections
- [ ] Implement an embedded WebKit flow only if required and appropriate
- [x] Never request storage of the user's Western password
- [x] Never bypass access controls or authentication protections
- [x] Detect authentication expiration
- [ ] Provide a reconnect flow
- [ ] Provide a disconnect flow
- [x] Provide a mock authentication path if production access is unavailable

## Phase 10 — Keychain Storage

- [x] Create `KeychainService`
- [x] Save authentication tokens in macOS Keychain
- [x] Read authentication tokens from macOS Keychain
- [x] Delete authentication tokens from macOS Keychain
- [x] Define appropriate Keychain accessibility settings
- [x] Never store tokens in source code
- [x] Never store tokens in `UserDefaults`
- [x] Never print passwords, tokens, cookies, or secrets
- [x] Exclude secrets from crash and diagnostic logs
- [x] Add Keychain error handling and tests

## Phase 11 — Brightspace Course Sync

- [x] Fetch the student's active courses
- [x] Map external Brightspace course IDs
- [x] Map course code and name
- [x] Map provider source and active state
- [x] Save courses locally
- [x] Update renamed courses
- [x] Avoid duplicate courses
- [ ] Ignore or archive old courses according to a documented rule
- [x] Respect locally disabled courses
- [x] Test course creation, update, and deduplication

## Phase 12 — Brightspace Assignment Sync

- [x] Fetch Brightspace assignments
- [ ] Fetch relevant quizzes
- [x] Fetch relevant labs, projects, exams, discussions, and calendar deadlines where supported
- [x] Store stable Brightspace item IDs
- [x] Map items into the shared assignment model
- [x] Save due dates and time zones correctly
- [x] Save course relationships
- [x] Save original Brightspace URLs
- [x] Update existing assignments instead of duplicating them
- [x] Handle assignments without due dates
- [x] Handle deleted or cancelled assignments
- [x] Map submission status when the API provides it
- [x] Test assignment creation, update, removal, and deduplication

## Phase 13 — Sync Engine

- [x] Create `SyncService`
- [x] Define idle, syncing, success, and failed sync states
- [x] Prevent simultaneous sync operations
- [x] Fetch provider data through the provider protocol
- [x] Normalize fetched data
- [x] Compare remote data with local data
- [x] Store changes atomically where practical
- [x] Store the last attempted sync time
- [x] Store the last successful sync time
- [x] Handle offline and network failure states
- [x] Handle expired authentication
- [x] Implement bounded retries only for appropriate transient failures
- [x] Support manual synchronization
- [x] Surface user-friendly synchronization errors
- [x] Add sync-engine unit and integration tests

## Phase 14 — Due-Date and Assignment Change Detection

- [x] Detect assignment due-date changes
- [x] Detect assignment title changes
- [x] Detect newly created assignments
- [x] Detect removed or cancelled assignments
- [ ] Detect assignment availability changes
- [x] Detect submission-status changes when available
- [x] Record old and new values safely
- [x] Record the detection timestamp
- [x] Avoid recording the same change more than once
- [x] Handle time-zone-equivalent dates without false changes
- [x] Add high-priority due-date change tests
- [x] Add tests for every supported change type

## Phase 15 — Native macOS Notifications

- [x] Add the UserNotifications framework
- [x] Request notification permission in context
- [x] Explain why notification permission is needed
- [x] Handle denied notification permission gracefully
- [x] Send a due-date-change notification
- [x] Send a new-assignment notification when enabled
- [x] Send a removed-assignment notification when enabled
- [x] Include useful course and assignment context
- [x] Open the relevant assignment or dashboard from a notification when possible
- [x] Record handled notifications
- [x] Prevent repeat notifications for the same change
- [x] Test authorization and notification construction

## Phase 16 — Deadline Reminders

- [x] Add configurable 24-hour reminders
- [x] Add configurable 6-hour reminders
- [x] Add configurable 1-hour reminders
- [x] Schedule native local notifications
- [x] Avoid scheduling duplicate reminders
- [x] Cancel reminders for removed or submitted assignments
- [x] Cancel outdated reminders when a due date changes
- [x] Schedule replacement reminders after a due-date change
- [x] Handle deadlines too near or already past
- [x] Test reminder scheduling, cancellation, and rescheduling

## Phase 17 — Change History

- [x] Persist assignment change history
- [x] Create the Recent Changes dashboard screen
- [x] Show course and assignment context
- [x] Show old and new values
- [x] Show when each change was detected
- [x] Filter changes by course
- [x] Filter changes by change type
- [x] Filter changes by date
- [x] Add an informative empty state
- [x] Define history retention behavior

## Phase 18 — Calendar

- [x] Build a simple native SwiftUI month calendar
- [x] Add assignment indicators to dates
- [x] Show assignments for the selected date
- [x] Add a chronological list view
- [x] Open assignments from calendar and list views
- [x] Handle month navigation
- [x] Handle locale, calendar, and time-zone settings
- [x] Add accessible labels and keyboard navigation
- [ ] Add a week view only after month and list views are reliable

## Phase 19 — Course Colors

- [x] Assign a default color to each course
- [x] Allow users to choose course colors
- [x] Persist course color choices
- [x] Apply course colors in assignment lists
- [x] Apply course colors in the calendar
- [x] Apply course colors in the menu bar
- [x] Apply course colors in change history
- [x] Pair colors with text or symbols so status never relies on color alone
- [ ] Verify acceptable contrast in light and dark appearances

## Phase 20 — Settings

- [x] Create the native Settings scene
- [x] Add a General settings section
- [x] Add a Sync settings section
- [x] Add a Notifications settings section
- [x] Add a Courses settings section
- [x] Add an Account settings section
- [x] Add automatic-sync preference
- [x] Add configurable sync frequency
- [x] Add per-notification-type preferences
- [x] Add per-course enable and disable controls
- [ ] Add Brightspace connect and disconnect controls
- [x] Persist settings locally
- [x] Apply setting changes without requiring an unnecessary restart

## Phase 21 — Background Sync

- [x] Research supported macOS background-refresh approaches
- [x] Choose and document the MVP scheduling approach
- [x] Avoid constant polling
- [x] Respect macOS resource and battery management
- [x] Support an approximate 30-to-60-minute refresh interval when possible
- [x] Honor the user's configured sync frequency
- [x] Honor manual-only mode
- [x] Preserve the manual Sync Now action
- [x] Prevent background and manual sync collisions
- [x] Communicate that exact background intervals are not guaranteed
- [ ] Test foreground-to-background behavior

## Phase 22 — Menu Bar Status

- [x] Show an unobtrusive healthy state
- [x] Show the number of assignments due today when enabled
- [x] Show a due-soon indicator
- [x] Show a synchronization problem indicator
- [x] Provide accessible text for every icon state
- [x] Avoid distracting or rapidly changing status

## Phase 23 — Launch at Login

- [x] Add a Launch at Login preference
- [x] Implement launch at login with Apple's supported API
- [x] Reflect the actual system registration state
- [x] Handle registration failures gracefully
- [ ] Verify enable and disable behavior

## Phase 24 — Apple Calendar Integration

- [x] Add an opt-in Apple Calendar setting
- [x] Request EventKit permission in context
- [x] Handle denied calendar permission gracefully
- [x] Let the user choose or create a target calendar
- [x] Create assignment events without duplicates
- [x] Store event identifiers needed for later updates
- [x] Update existing events when due dates change
- [x] Remove or mark events when assignments are cancelled according to user preference
- [x] Disable calendar integration cleanly
- [x] Test event creation, update, deduplication, and removal

## Phase 25 — Assignment Links and Read-Only Guarantees

- [x] Retain the original provider URL for each assignment when available
- [x] Validate provider URLs before opening them
- [x] Open assignment pages in the default browser
- [x] Provide a fallback when an assignment URL is missing
- [x] Document that the application is read-only
- [x] Ensure no provider client method submits assignments
- [x] Ensure no provider client method modifies LMS course content

## Phase 26 — Error Handling

- [x] Define typed application errors
- [x] Add a friendly network-error message
- [ ] Add an expired-session message with reconnect action
- [x] Add a provider-unavailable message
- [x] Add a persistence-error message
- [x] Add notification and calendar permission guidance
- [x] Preserve diagnostic context without exposing secrets
- [x] Never expose raw tokens, sensitive headers, or stack traces to users
- [x] Make recoverable errors actionable
- [ ] Test key error-state UI

## Phase 27 — Logging and Diagnostics

- [x] Create lightweight structured logging
- [x] Add Authentication, Sync, Database, Notifications, and Brightspace categories
- [x] Use appropriate log privacy annotations
- [x] Never log passwords, OAuth tokens, or session cookies
- [x] Avoid logging unnecessary student information
- [x] Add useful development diagnostics for failed syncs
- [ ] Add a privacy-safe diagnostics export only if needed

## Phase 28 — Automated Testing

- [x] Configure the unit test target
- [x] Test assignment sorting
- [x] Test assignments without due dates
- [x] Test due-date change detection
- [x] Test duplicate prevention across repeated syncs
- [x] Test existing assignment updates
- [x] Test reminder rescheduling after a due-date change
- [x] Test provider mapping
- [x] Test sync state transitions
- [x] Test authentication-expiration handling
- [ ] Add UI tests for critical menu bar and dashboard flows where practical
- [ ] Run the test suite in continuous integration

## Phase 29 — Brightspace Provider Testing

- [x] Create `MockBrightspaceClient`
- [x] Inject the Brightspace network client
- [x] Add representative sanitized Brightspace fixtures
- [x] Test successful response mapping
- [x] Test pagination where applicable
- [x] Test missing and malformed fields
- [x] Test rate-limit and temporary-server errors
- [x] Test unauthorized and expired-session responses
- [x] Ensure provider tests do not require a live student account

## Phase 30 — Privacy and Security Review

- [x] Document the minimum data collected and why
- [x] Store only required course, assignment, sync, preference, and change data
- [x] Avoid storing grades, messages, class lists, or other students' data
- [x] Avoid storing unnecessary instructor information
- [x] Keep local files protected by standard macOS application sandboxing
- [x] Review App Sandbox entitlements and network access
- [x] Review Keychain access scope
- [x] Add local-data deletion controls
- [ ] Delete local provider data on account disconnect when the user requests it
- [x] Complete a secrets and sensitive-logging review
- [x] Document privacy behavior for users

## Phase 31 — Documentation and README

- [x] Create the project README
- [x] Explain what the application does
- [x] List current features and known limitations
- [x] Document requirements and build steps
- [x] Document the architecture and folder structure
- [x] Document Brightspace authentication and integration behavior
- [x] Document local storage and privacy considerations
- [x] Link to or summarize the roadmap
- [x] Add the independent-project and non-affiliation disclaimer
- [x] Confirm no Western University logo or protected branding is used without permission
- [x] Document manual testing steps for release candidates

## Phase 32 — Development Configuration and Release Hygiene

- [ ] Add example configuration files if configuration becomes necessary
- [x] Keep real configuration and secrets out of version control
- [x] Ignore `.DS_Store`, DerivedData, user state, and secret files
- [x] Add Debug-only mock-data configuration
- [x] Define Debug and Release behavior clearly
- [x] Configure application sandbox entitlements
- [x] Configure only required capabilities
- [x] Set application version and build numbering
- [x] Add an application icon that does not misuse university branding
- [ ] Validate a clean build from a fresh checkout
- [x] Prepare signing, notarization, and distribution documentation

## Phase 33 — MVP End-to-End Validation

- [ ] Launch the native menu bar application
- [ ] Connect a Brightspace account securely
- [ ] Retrieve active courses
- [ ] Retrieve upcoming assignments
- [ ] Persist assignments locally
- [ ] Display upcoming assignments in the menu bar
- [ ] Open the full assignment dashboard and calendar
- [ ] Complete manual and background syncs
- [ ] Detect and persist a changed due date
- [ ] Deliver one non-duplicated due-date notification
- [ ] Display the recorded change in history
- [ ] Deliver configured deadline reminders
- [ ] Verify the complete flow with no stored password or leaked secret

## Phase 34 — Future LMS Integrations

- [ ] Keep future providers out of scope until the Brightspace MVP is reliable
- [ ] Add `GradescopeProvider`
- [ ] Add `CrowdmarkProvider`
- [ ] Add `CanvasProvider`
- [ ] Add `MoodleProvider`
- [ ] Normalize every provider into the same shared course and assignment models
- [ ] Add account and provider selection UI
- [ ] Resolve duplicate assignments surfaced by multiple providers
- [ ] Add provider-specific contract and integration tests

## Phase 35 — Future Multi-University Support

- [x] Keep Western-specific configuration out of shared domain and UI layers
- [ ] Create a university configuration model
- [ ] Map universities to one or more supported LMS providers
- [ ] Add university selection and setup UI
- [ ] Support institution-specific authentication configuration
- [ ] Support Waterloo and Brightspace/LEARN configuration
- [ ] Support University of Toronto and Canvas configuration
- [ ] Support additional Moodle institutions
- [ ] Document how contributors add a university safely
- [ ] Test multiple university/provider configurations

## Phase 36 — Post-MVP Polish

- [ ] Perform an accessibility audit
- [ ] Verify keyboard-only navigation
- [ ] Verify VoiceOver labels and reading order
- [ ] Verify Dynamic Type and long localized strings where supported
- [ ] Verify light and dark appearances
- [ ] Profile launch, memory, network, and energy use
- [ ] Improve onboarding without expanding data collection
- [ ] Add user-facing release notes
- [ ] Establish a feedback and issue-reporting process
