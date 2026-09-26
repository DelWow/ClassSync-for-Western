# Release Candidate Manual Test Plan

Run this plan on the oldest supported macOS version and the current macOS release. Test once in light appearance and once in dark appearance.

## Build and Launch

- [ ] Build the shared `ClassSync` scheme with no warnings.
- [ ] Launch the app and confirm it appears in the menu bar without a Dock icon.
- [ ] Confirm the menu opens, mock assignments render, and long titles truncate cleanly.
- [ ] Confirm Sync Now, Open Dashboard, Settings, and Quit work.
- [ ] Relaunch the app and confirm saved settings and local data load.

## Dashboard and Accessibility

- [ ] Navigate Today, Upcoming, Calendar, Changes, Courses, and Settings with keyboard only.
- [ ] Search assignments and filter by course.
- [ ] Navigate calendar dates and open a valid assignment link.
- [ ] Confirm VoiceOver announces menu status, assignments, due dates, status, and calendar indicators.
- [ ] Confirm course colors remain distinguishable and every status also has text or a symbol.

## Notifications and Reminders

- [ ] Enable notifications from Settings and confirm macOS shows the system prompt.
- [ ] Deny permission once and confirm ClassSync gives actionable guidance without repeatedly prompting.
- [ ] Trigger one new-assignment and one due-date-change fixture; confirm each notification appears once.
- [ ] Click a notification and confirm only a validated HTTPS provider URL opens.
- [ ] Enable each reminder lead time and confirm pending reminders are replaced after a due-date change.

## Background and Login Behavior

- [ ] Enable automatic sync, close the menu, and confirm a later background activity updates the last-sync time.
- [ ] Confirm manual Sync Now remains usable and does not overlap an active background sync.
- [ ] Select Manual only and confirm the background request is cancelled.
- [ ] Enable and disable Launch at Login, then verify the state in System Settings > General > Login Items.

## Apple Calendar

- [ ] Enable calendar sync and grant full access from the system prompt.
- [ ] Choose an existing writable calendar and confirm assignment events appear once.
- [ ] Create the dedicated ClassSync calendar and select it.
- [ ] Change an assignment due date and confirm the existing event updates rather than duplicates.
- [ ] Test both cancelled-assignment policies.
- [ ] Disable calendar sync and confirm only ClassSync-linked events are removed.

## Syllabus Import and Course Sources

- [ ] Import a text-based PDF, plain-text, RTF, and Word syllabus through Settings > Course Sources.
- [ ] Confirm the review sheet permits editing course code, course name, assignment titles, dates, and row selection before saving.
- [ ] Test month-first, day-first, abbreviated-month, numeric, 12-hour, and 24-hour due-date formats.
- [ ] Test a PDF table whose extracted title, weight, and due date appear on adjacent lines.
- [ ] Confirm yearless January–April dates imported during fall resolve into the next calendar year.
- [ ] Confirm clearly stale dates are highlighted and the move-forward and deselect controls work.
- [ ] Import the same syllabus twice and confirm assignments are updated rather than duplicated.
- [ ] Correct a due date and re-import the same course; confirm the old overdue copy is replaced.
- [ ] Import a scanned/image-only PDF and confirm ClassSync explains that OCR is not yet supported.
- [ ] Confirm the original document is neither copied into ClassSync storage nor uploaded.

## Private Brightspace Calendar Feed

Treat the private calendar subscription URL as a credential. Enter it only in the app; never place it in this document, a bug report, logs, screenshots, or source control.

- [ ] Reject a non-HTTPS URL, a lookalike host, and a Western URL outside the calendar-feed path.
- [ ] Connect a real Western private calendar feed and confirm Sync Now imports its upcoming events with correct local dates and times.
- [ ] Confirm a matching calendar event replaces the displayed syllabus fallback rather than appearing twice.
- [ ] Disconnect and remove calendar data, then confirm any matching syllabus fallback becomes visible again.
- [ ] Confirm the private URL is stored in Keychain and never appears in logs or `UserDefaults`.

## Western Email Review

- [ ] Configure a `@uwo.ca` or `@westernu.ca` account in Apple Mail before enabling the integration.
- [ ] Enable email scanning and confirm the in-context explanation appears before macOS requests Automation access.
- [ ] Scan a sanitized deadline-change message and confirm ClassSync presents the matched assignment, existing date, proposed date, sender, and subject for review.
- [ ] Apply one suggestion and confirm the assignment, change history, reminders, and optional Apple Calendar event update.
- [ ] Dismiss one suggestion and confirm it does not reappear on the next scan.
- [ ] Deny Automation permission and confirm ClassSync provides actionable guidance without requesting a password.
- [ ] Confirm unrelated email bodies, subjects, and sender details are not persisted or logged.

## Privacy and Failure Cases

- [ ] Work offline and confirm a friendly network error appears while cached data remains available.
- [ ] Confirm logs contain no tokens, cookies, authorization headers, passwords, or student content.
- [ ] Use Delete Local ClassSync Data and confirm the destructive confirmation appears.
- [ ] Confirm local courses, assignments, history, reminders, sync timestamps, and linked calendar events are removed.
- [ ] Inspect the built app entitlements and confirm only sandbox, outbound network, calendar, user-selected read-only files, and the documented Apple Mail automation exception are present.

## Production Brightspace Gate

Do not perform these checks until Western/D2L has approved the OAuth registration and redirect design.

- [ ] Connect through the official Brightspace-hosted sign-in experience, including MFA.
- [ ] Confirm the app never asks for or stores a Western password.
- [ ] Sync active courses, calendar deadlines, assignment folders, and current-user submission status.
- [ ] Expire/revoke the token and confirm ClassSync requests reconnection without exposing raw errors.
- [ ] Disconnect and optionally remove local provider data.
