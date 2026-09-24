# Project TODO

This file is the source of truth for project progress. Check an item only after its implementation works and has been validated. Leave partial work unchecked, preserve unfinished tasks, and add newly discovered work under the appropriate phase.

## Phase 0 — Repository and Project Setup

- [x] Establish `TODO.md` as the source-of-truth roadmap
- [x] Create the native macOS application project
- [x] Configure the application as a SwiftUI app
- [x] Set a reasonable minimum supported macOS version
- [x] Set the application name and bundle identifier
- [ ] Create the initial app, model, view, service, provider, persistence, utility, and resource organization
  - App, Models, Views, and Resources are in place; service, provider, persistence, and utility folders will be added with their first implementations.
- [x] Add a project `.gitignore` for Xcode output, user state, and secret configuration
- [x] Confirm the project opens in Xcode
- [x] Confirm the project builds successfully
- [x] Confirm the application launches successfully
- [ ] Document local development prerequisites

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

- [ ] Create the shared assignment model
- [ ] Create the shared course model
- [ ] Create the assignment status enum
- [ ] Create the assignment source enum
- [ ] Create the assignment change model
- [ ] Create the assignment change type enum
- [ ] Define stable internal and provider identifier behavior
- [ ] Represent optional due dates safely
- [ ] Represent optional source URLs safely
- [ ] Add model unit tests

## Phase 3 — SwiftData Persistence

- [ ] Configure the SwiftData model container
- [ ] Create the persistent course model
- [ ] Create the persistent assignment model
- [ ] Create the persistent assignment change model
- [ ] Create the persistent sync metadata model
- [ ] Persist non-sensitive user preferences where appropriate
- [ ] Persist provider configuration without credentials or tokens
- [ ] Implement conversion between persistence and domain models if needed
- [ ] Prevent duplicate persistent courses
- [ ] Prevent duplicate persistent assignments
- [ ] Test saving courses and assignments
- [ ] Test loading saved data after application restart
- [ ] Define a practical schema migration strategy
- [ ] Handle persistence initialization and migration failures safely

## Phase 4 — Mock Assignment Data

- [x] Add representative development/mock assignments
- [x] Include assignments due today, tomorrow, and later this week
- [ ] Include an overdue assignment fixture
- [ ] Include an assignment without a due date fixture
- [ ] Include a long assignment title fixture
- [x] Sort mock assignments by due date
- [ ] Group mock assignments into Today, Tomorrow, This Week, and No Due Date
  - Today, Tomorrow, and This Week are implemented; No Due Date awaits an optional-due-date domain model.
- [x] Display mock assignments in the menu bar interface
- [x] Verify the mock-data UI does not require network access

## Phase 5 — Menu Bar Assignment Experience

- [x] Show each assignment title
- [x] Show each assignment course name or code
- [x] Show each assignment due date and time
- [ ] Show each assignment source
- [x] Show an upcoming assignment count
- [ ] Visually distinguish overdue assignments without relying on color alone
- [ ] Visually distinguish submitted assignments when status is available
- [ ] Make assignments with source URLs clickable
- [ ] Open assignment URLs in the default browser
- [ ] Handle long assignment and course names gracefully
- [x] Add useful empty states for each date group
- [ ] Add a compact loading state
- [ ] Add a compact synchronization error state

## Phase 6 — Dashboard

- [ ] Create a full native macOS dashboard window
- [x] Open the dashboard from the menu bar
- [ ] Add sidebar navigation
- [ ] Add the Today section
- [ ] Add the Upcoming section
- [ ] Add the Calendar section
- [ ] Add the Changes section
- [ ] Add the Courses section
- [ ] Add the Settings section
- [x] Add the upcoming assignment list
- [ ] Add course filtering
- [ ] Add assignment search
- [ ] Preserve window sizing and sensible macOS behavior
- [ ] Add useful empty, loading, and error states

## Phase 7 — Provider Architecture

- [ ] Define an LMS assignment-provider protocol
- [ ] Define provider authentication behavior
- [ ] Define course-fetching behavior
- [ ] Define assignment-fetching behavior
- [ ] Define provider capability and availability metadata
- [ ] Keep provider-specific data types outside shared UI code
- [ ] Normalize provider output into shared course and assignment models
- [ ] Add dependency injection for provider selection
- [ ] Create a mock provider for offline development and tests
- [ ] Add provider contract tests

## Phase 8 — Brightspace Integration Layer

- [ ] Create the isolated Brightspace provider directory
- [ ] Create `BrightspaceProvider`
- [ ] Create `BrightspaceClient`
- [ ] Create Brightspace response models
- [ ] Create `BrightspaceMapper`
- [ ] Create the Brightspace authentication component
- [ ] Determine Western OWL Brightspace tenant and supported official API configuration
- [ ] Document required university approval or API registration
- [ ] Implement authenticated read-only requests
- [ ] Map Brightspace errors into user-safe application errors
- [ ] Ensure shared UI does not depend on Brightspace response types
- [ ] Prevent write, submission, or course-content modification operations

## Phase 9 — Authentication

- [ ] Research official Brightspace OAuth/API access for Western
- [ ] Prefer official OAuth when it is available
- [ ] Document the authentication approach and threat model
- [ ] Implement a secure connect-account flow
- [ ] Support MFA without bypassing university protections
- [ ] Implement an embedded WebKit flow only if required and appropriate
- [ ] Never request storage of the user's Western password
- [ ] Never bypass access controls or authentication protections
- [ ] Detect authentication expiration
- [ ] Provide a reconnect flow
- [ ] Provide a disconnect flow
- [ ] Provide a mock authentication path if production access is unavailable

## Phase 10 — Keychain Storage

- [ ] Create `KeychainService`
- [ ] Save authentication tokens in macOS Keychain
- [ ] Read authentication tokens from macOS Keychain
- [ ] Delete authentication tokens from macOS Keychain
- [ ] Define appropriate Keychain accessibility settings
- [ ] Never store tokens in source code
- [ ] Never store tokens in `UserDefaults`
- [ ] Never print passwords, tokens, cookies, or secrets
- [ ] Exclude secrets from crash and diagnostic logs
- [ ] Add Keychain error handling and tests

## Phase 11 — Brightspace Course Sync

- [ ] Fetch the student's active courses
- [ ] Map external Brightspace course IDs
- [ ] Map course code and name
- [ ] Map provider source and active state
- [ ] Save courses locally
- [ ] Update renamed courses
- [ ] Avoid duplicate courses
- [ ] Ignore or archive old courses according to a documented rule
- [ ] Respect locally disabled courses
- [ ] Test course creation, update, and deduplication

## Phase 12 — Brightspace Assignment Sync

- [ ] Fetch Brightspace assignments
- [ ] Fetch relevant quizzes
- [ ] Fetch relevant labs, projects, exams, discussions, and calendar deadlines where supported
- [ ] Store stable Brightspace item IDs
- [ ] Map items into the shared assignment model
- [ ] Save due dates and time zones correctly
- [ ] Save course relationships
- [ ] Save original Brightspace URLs
- [ ] Update existing assignments instead of duplicating them
- [ ] Handle assignments without due dates
- [ ] Handle deleted or cancelled assignments
- [ ] Map submission status when the API provides it
- [ ] Test assignment creation, update, removal, and deduplication

## Phase 13 — Sync Engine

- [ ] Create `SyncService`
- [ ] Define idle, syncing, success, and failed sync states
- [ ] Prevent simultaneous sync operations
- [ ] Fetch provider data through the provider protocol
- [ ] Normalize fetched data
- [ ] Compare remote data with local data
- [ ] Store changes atomically where practical
- [ ] Store the last attempted sync time
- [ ] Store the last successful sync time
- [ ] Handle offline and network failure states
- [ ] Handle expired authentication
- [ ] Implement bounded retries only for appropriate transient failures
- [ ] Support manual synchronization
- [ ] Surface user-friendly synchronization errors
- [ ] Add sync-engine unit and integration tests

## Phase 14 — Due-Date and Assignment Change Detection

- [ ] Detect assignment due-date changes
- [ ] Detect assignment title changes
- [ ] Detect newly created assignments
- [ ] Detect removed or cancelled assignments
- [ ] Detect assignment availability changes
- [ ] Detect submission-status changes when available
- [ ] Record old and new values safely
- [ ] Record the detection timestamp
- [ ] Avoid recording the same change more than once
- [ ] Handle time-zone-equivalent dates without false changes
- [ ] Add high-priority due-date change tests
- [ ] Add tests for every supported change type

## Phase 15 — Native macOS Notifications

- [ ] Add the UserNotifications framework
- [ ] Request notification permission in context
- [ ] Explain why notification permission is needed
- [ ] Handle denied notification permission gracefully
- [ ] Send a due-date-change notification
- [ ] Send a new-assignment notification when enabled
- [ ] Send a removed-assignment notification when enabled
- [ ] Include useful course and assignment context
- [ ] Open the relevant assignment or dashboard from a notification when possible
- [ ] Record handled notifications
- [ ] Prevent repeat notifications for the same change
- [ ] Test authorization and notification construction

## Phase 16 — Deadline Reminders

- [ ] Add configurable 24-hour reminders
- [ ] Add configurable 6-hour reminders
- [ ] Add configurable 1-hour reminders
- [ ] Schedule native local notifications
- [ ] Avoid scheduling duplicate reminders
- [ ] Cancel reminders for removed or submitted assignments
- [ ] Cancel outdated reminders when a due date changes
- [ ] Schedule replacement reminders after a due-date change
- [ ] Handle deadlines too near or already past
- [ ] Test reminder scheduling, cancellation, and rescheduling

## Phase 17 — Change History

- [ ] Persist assignment change history
- [ ] Create the Recent Changes dashboard screen
- [ ] Show course and assignment context
- [ ] Show old and new values
- [ ] Show when each change was detected
- [ ] Filter changes by course
- [ ] Filter changes by change type
- [ ] Filter changes by date
- [ ] Add an informative empty state
- [ ] Define history retention behavior

## Phase 18 — Calendar

- [ ] Build a simple native SwiftUI month calendar
- [ ] Add assignment indicators to dates
- [ ] Show assignments for the selected date
- [ ] Add a chronological list view
- [ ] Open assignments from calendar and list views
- [ ] Handle month navigation
- [ ] Handle locale, calendar, and time-zone settings
- [ ] Add accessible labels and keyboard navigation
- [ ] Add a week view only after month and list views are reliable

## Phase 19 — Course Colors

- [ ] Assign a default color to each course
- [ ] Allow users to choose course colors
- [ ] Persist course color choices
- [ ] Apply course colors in assignment lists
- [ ] Apply course colors in the calendar
- [ ] Apply course colors in the menu bar
- [ ] Apply course colors in change history
- [ ] Pair colors with text or symbols so status never relies on color alone
- [ ] Verify acceptable contrast in light and dark appearances

## Phase 20 — Settings

- [x] Create the native Settings scene
- [ ] Add a General settings section
- [ ] Add a Sync settings section
- [ ] Add a Notifications settings section
- [ ] Add a Courses settings section
- [ ] Add an Account settings section
- [ ] Add automatic-sync preference
- [ ] Add configurable sync frequency
- [ ] Add per-notification-type preferences
- [ ] Add per-course enable and disable controls
- [ ] Add Brightspace connect and disconnect controls
- [ ] Persist settings locally
- [ ] Apply setting changes without requiring an unnecessary restart

## Phase 21 — Background Sync

- [ ] Research supported macOS background-refresh approaches
- [ ] Choose and document the MVP scheduling approach
- [ ] Avoid constant polling
- [ ] Respect macOS resource and battery management
- [ ] Support an approximate 30-to-60-minute refresh interval when possible
- [ ] Honor the user's configured sync frequency
- [ ] Honor manual-only mode
- [ ] Preserve the manual Sync Now action
- [ ] Prevent background and manual sync collisions
- [ ] Communicate that exact background intervals are not guaranteed
- [ ] Test foreground-to-background behavior

## Phase 22 — Menu Bar Status

- [ ] Show an unobtrusive healthy state
- [ ] Show the number of assignments due today when enabled
- [ ] Show a due-soon indicator
- [ ] Show a synchronization problem indicator
- [ ] Provide accessible text for every icon state
- [ ] Avoid distracting or rapidly changing status

## Phase 23 — Launch at Login

- [ ] Add a Launch at Login preference
- [ ] Implement launch at login with Apple's supported API
- [ ] Reflect the actual system registration state
- [ ] Handle registration failures gracefully
- [ ] Verify enable and disable behavior

## Phase 24 — Apple Calendar Integration

- [ ] Add an opt-in Apple Calendar setting
- [ ] Request EventKit permission in context
- [ ] Handle denied calendar permission gracefully
- [ ] Let the user choose or create a target calendar
- [ ] Create assignment events without duplicates
- [ ] Store event identifiers needed for later updates
- [ ] Update existing events when due dates change
- [ ] Remove or mark events when assignments are cancelled according to user preference
- [ ] Disable calendar integration cleanly
- [ ] Test event creation, update, deduplication, and removal

## Phase 25 — Assignment Links and Read-Only Guarantees

- [ ] Retain the original provider URL for each assignment when available
- [ ] Validate provider URLs before opening them
- [ ] Open assignment pages in the default browser
- [ ] Provide a fallback when an assignment URL is missing
- [ ] Document that the application is read-only
- [ ] Ensure no provider client method submits assignments
- [ ] Ensure no provider client method modifies LMS course content

## Phase 26 — Error Handling

- [ ] Define typed application errors
- [ ] Add a friendly network-error message
- [ ] Add an expired-session message with reconnect action
- [ ] Add a provider-unavailable message
- [ ] Add a persistence-error message
- [ ] Add notification and calendar permission guidance
- [ ] Preserve diagnostic context without exposing secrets
- [ ] Never expose raw tokens, sensitive headers, or stack traces to users
- [ ] Make recoverable errors actionable
- [ ] Test key error-state UI

## Phase 27 — Logging and Diagnostics

- [ ] Create lightweight structured logging
- [ ] Add Authentication, Sync, Database, Notifications, and Brightspace categories
- [ ] Use appropriate log privacy annotations
- [ ] Never log passwords, OAuth tokens, or session cookies
- [ ] Avoid logging unnecessary student information
- [ ] Add useful development diagnostics for failed syncs
- [ ] Add a privacy-safe diagnostics export only if needed

## Phase 28 — Automated Testing

- [ ] Configure the unit test target
- [ ] Test assignment sorting
- [ ] Test assignments without due dates
- [ ] Test due-date change detection
- [ ] Test duplicate prevention across repeated syncs
- [ ] Test existing assignment updates
- [ ] Test reminder rescheduling after a due-date change
- [ ] Test provider mapping
- [ ] Test sync state transitions
- [ ] Test authentication-expiration handling
- [ ] Add UI tests for critical menu bar and dashboard flows where practical
- [ ] Run the test suite in continuous integration

## Phase 29 — Brightspace Provider Testing

- [ ] Create `MockBrightspaceClient`
- [ ] Inject the Brightspace network client
- [ ] Add representative sanitized Brightspace fixtures
- [ ] Test successful response mapping
- [ ] Test pagination where applicable
- [ ] Test missing and malformed fields
- [ ] Test rate-limit and temporary-server errors
- [ ] Test unauthorized and expired-session responses
- [ ] Ensure provider tests do not require a live student account

## Phase 30 — Privacy and Security Review

- [ ] Document the minimum data collected and why
- [ ] Store only required course, assignment, sync, preference, and change data
- [ ] Avoid storing grades, messages, class lists, or other students' data
- [ ] Avoid storing unnecessary instructor information
- [ ] Keep local files protected by standard macOS application sandboxing
- [ ] Review App Sandbox entitlements and network access
- [ ] Review Keychain access scope
- [ ] Add local-data deletion controls
- [ ] Delete local provider data on account disconnect when the user requests it
- [ ] Complete a secrets and sensitive-logging review
- [ ] Document privacy behavior for users

## Phase 31 — Documentation and README

- [ ] Create the project README
- [ ] Explain what the application does
- [ ] List current features and known limitations
- [ ] Document requirements and build steps
- [ ] Document the architecture and folder structure
- [ ] Document Brightspace authentication and integration behavior
- [ ] Document local storage and privacy considerations
- [ ] Link to or summarize the roadmap
- [ ] Add the independent-project and non-affiliation disclaimer
- [ ] Confirm no Western University logo or protected branding is used without permission
- [ ] Document manual testing steps for release candidates

## Phase 32 — Development Configuration and Release Hygiene

- [ ] Add example configuration files if configuration becomes necessary
- [ ] Keep real configuration and secrets out of version control
- [x] Ignore `.DS_Store`, DerivedData, user state, and secret files
- [ ] Add Debug-only mock-data configuration
- [ ] Define Debug and Release behavior clearly
- [ ] Configure application sandbox entitlements
- [ ] Configure only required capabilities
- [ ] Set application version and build numbering
- [ ] Add an application icon that does not misuse university branding
- [ ] Validate a clean build from a fresh checkout
- [ ] Prepare signing, notarization, and distribution documentation

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

- [ ] Keep Western-specific configuration out of shared domain and UI layers
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
