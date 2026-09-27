# Godziny — wariant B

Approved scope: work-hours plan in conversation; selected monthly layout B.
Existing isolated branch codex/dniowka-reliability; clean checkout before changes.
Stages: domain and local durable outbox; task corrections; monthly UI; reports and cloud adapter; verification.
Default: preserve each entry rate, count distinct starting dates, no automatic Costs income.
Remote migration will be supplied as SQL, not applied to production without verifying the target.
Progress: regression tests written before implementation.
Domain: 5 regression tests passed; priority sorting RED observed then GREEN.
UI: phone save and category-filter test passed; PDF pagination and Polish font test passed.
Full suite first run: 329 passed, 1 legacy expectation still selecting removed Inbox. Updated test to select Upcoming and explicitly assert Inbox absent.
Ruling: use 45-second foreground polling plus resume refresh for new module, with immediate flush after local edits; production SQL is supplied but not applied in this turn.
Build/test artifacts isolated at G:\Codex-builds\dniowka-hours-20260927 to avoid locked native-assets file and low C: free space.
Final review: fixed stale offline edits resurrecting deleted entries; only an explicit Undo requests restoration. Added regression coverage for tombstones and exact outbox acknowledgement.
Final full suite: 337 tests passed (single concurrency), including large-text phone/desktop in both themes and multi-page PDF with embedded Polish font.
Windows preview rebuilt successfully from final UI source. Android incremental Kotlin cache disabled because plugin sources and builds use different Windows drives.
Not verified live: Supabase migration/RLS/trigger execution, two-device synchronization, Android system sharing and real Windows save dialog. SQL supplied, not applied to production. Conflict ordering uses device timestamps; clock skew remains a limitation.
Final flutter analyze: no issues. APK release build succeeded (71 MB); temporary signing path adjusted to the existing original keystore. No commit, publication or production migration performed.
Release follow-up: user approved commit, PR and release. Production project matched the configured URL (uoztjgwnzbmrzclwkdnr). Applied work_hours_entries_settings migration; rollback-only SQL tests passed for owner isolation, rate conflict ordering, stale edits, tombstones and explicit UPSERT Undo. Test users/entries were rolled back. Security advisor reported no hours-table issues; existing leaked-password protection warning is outside this module.
Remaining manual checks: synchronization on two physical devices and native share/save dialogs. Release version: 1.2.4+1002004, new branch codex/work-hours from current origin/main.
