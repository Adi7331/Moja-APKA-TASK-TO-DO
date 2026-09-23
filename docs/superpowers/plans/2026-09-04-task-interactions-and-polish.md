# Task Interactions and Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make core task interactions fast to use and give the existing Today experience a calmer, more intentional visual finish.

**Architecture:** Keep task state in `MyApp` and make the existing editor the single place for changing a task. Improve the editor's date controls and the task row's visible state rather than introduce a second task-detail data flow. Reuse the current `TodayScreen` callbacks so local and cloud modes retain identical behavior.

**Tech Stack:** Flutter, Material 3, flutter_test, existing Supabase/local persistence services.

**Spec:** Existing user-approved task-app design and this approved work package.

## Global Constraints

- Do not change the Supabase OAuth configuration or expose credentials.
- Do not launch the application as part of verification.
- Preserve local and cloud persistence through the current `TaskItem` and `TaskSyncService` flow.
- Keep all UI copy in Polish and retain light/dark support.

---

### Task 1: Fast deadline controls in the task editor

**Files:**
- Modify: `lib/task_editor.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `TaskDraft.dueAt` and existing editor `onSave` callback.
- Produces: visible quick deadline controls that set `dueAt` to today or tomorrow at 09:00, plus a control that clears the deadline.

- [ ] **Step 1: Write failing widget tests**

Add tests that open the task editor, tap `Na dziś`, and assert the deadline label no longer says `Dodaj termin i godzinę`; add a second test for `Bez terminu` after an existing task with a deadline is opened.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the quick deadline labels do not yet exist.

- [ ] **Step 3: Implement minimal quick deadline controls**

Place a horizontal chip row beneath the existing deadline button with keys `due-today`, `due-tomorrow`, and `due-none`. Each control updates only the in-memory `_dueAt`; the existing save route persists it.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

### Task 2: Make task state legible and useful from the list

**Files:**
- Modify: `lib/task_row.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `TaskItem.status`, `TaskItem.priority`, `TaskItem.note`, and existing completion/status callbacks.
- Produces: an accessible status label, priority treatment, optional note preview, and a larger clearly separated overflow control.

- [ ] **Step 1: Write failing widget tests**

Add a task row fixture with `in_progress`, high priority, and a note. Assert that `W trakcie`, `Wysoki priorytet`, and the note are visible. Tap the completion control and assert its callback is invoked.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because state and priority labels are not rendered.

- [ ] **Step 3: Implement compact state and priority treatments**

Add a small status/priority metadata line with semantic labels, render a one-line note preview when present, and use restrained color only for status/priority signals. Keep the whole row tappable for editing.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

### Task 3: Polish list hierarchy and empty states

**Files:**
- Modify: `lib/today_screen.dart`
- Modify: `lib/app_theme.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: current task lists, `TaskView`, and quick-add callback.
- Produces: view-specific empty states that guide the next action, calmer spacing and surfaces, and a consistent call-to-action.

- [ ] **Step 1: Write failing widget tests**

Add a `TaskView.inbox` empty fixture and assert `Skrzynka jest pusta` plus a visible `Dodaj zadanie` action that invokes the existing quick-add callback.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because empty views only show generic text.

- [ ] **Step 3: Implement the empty state and visual polish**

Replace generic empty text with a compact icon, view-specific title, supportive copy, and a secondary add button. Adjust only theme/list spacing, corner radii, and muted surfaces needed to make cards and controls feel deliberate in both brightness modes.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

### Task 4: Full verification

**Files:**
- Verify: `lib/`, `test/`

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 3: Build desktop and Android debug artifacts without launching them**

Run: `flutter build windows --debug` and `flutter build apk --debug`

Expected: both builds complete successfully.
