# Task flow polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make core task actions immediate and safe, then add the first practical organizer flows: undo, postponing, natural-language quick entry, and a focused work view.

**Architecture:** Keep task persistence in `MyApp`, where both local storage and Supabase already converge. Extract deterministic date parsing into a pure Dart helper, use callbacks for new UI components, and keep the existing confirmation dialog before a destructive delete. Reuse the task editor for detailed editing; new quick flows add only the data they can reliably determine.

**Tech Stack:** Flutter Material 3, Dart, `shared_preferences`, Supabase Flutter, `flutter_test`.

**Spec:** User-approved Polish task-flow package, 2026-09-06.

## Global Constraints

- Preserve local mode and cloud mode behavior.
- Do not launch the app during implementation.
- All icon-only controls need Polish tooltips/semantics and a 48 px tap target.
- Use the existing graphite/blue visual system; error red appears only for destructive hover/focus/pressed feedback.
- Keep a confirmation dialog before deleting a task.
- Phone layouts must have a visible button alternative to any gesture.

---

### Task 1: Direct task actions

**Files:**
- Modify: `lib/task_row.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `TaskRow.onDelete` and optional `TaskRow.onTogglePin`.
- Produces: `ValueKey('delete-task-<id>')` and optional `ValueKey('pin-task-<id>')` direct controls.

- [ ] Write a widget test asserting that the direct trash calls `onDelete` and that an eligible task shows a direct pin control.
- [ ] Run the focused test; it must fail because the direct controls do not exist.
- [ ] Replace the task overflow menu with 48×48 icon buttons, neutral at rest and error-tinted only during interaction.
- [ ] Run the focused test and all task-row widget tests.

### Task 2: Safe undo and postponing domain logic

**Files:**
- Create: `lib/task_schedule.dart`
- Create: `test/task_schedule_test.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Produces: `PostponeOption` and `postponedTask(TaskItem, DateTime, PostponeOption)`.
- Produces: `MyApp` callbacks that restore a deleted task or previous task status before a short expiry.

- [ ] Write pure-unit tests for postponing by one hour, tomorrow morning, and next Monday while preserving a task's due-time relationship.
- [ ] Run tests; they must fail because the scheduling helper is absent.
- [ ] Implement the helper and persist/reschedule tasks through the existing local/cloud pathways.
- [ ] Add widget tests that confirm delete, show an undo action, restore the task, and open postponing choices.
- [ ] Run focused tests.

### Task 3: Quick entry that understands a small Polish date vocabulary

**Files:**
- Create: `lib/quick_task_parser.dart`
- Create: `test/quick_task_parser_test.dart`
- Modify: `lib/today_screen.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Produces: `QuickTaskParseResult { String title; DateTime? dueAt; }` from `parseQuickTask(String, DateTime now)`.
- Supports only explicit, predictable phrases: `dziś`, `jutro`, `jutro HH:MM`, and `w poniedziałek`.

- [ ] Write parser unit tests for title cleanup and each supported phrase, including no-date text.
- [ ] Run tests; they must fail because the parser is absent.
- [ ] Implement the pure parser with a 09:00 default when a day is explicit without a time.
- [ ] Add a compact quick-entry field with a visible add button and a note describing the supported examples.
- [ ] Add a widget test that creates a parsed task and run focused tests.

### Task 4: Focus view

**Files:**
- Create: `lib/focus_mode_screen.dart`
- Create: `test/focus_mode_screen_test.dart`
- Modify: `lib/today_screen.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes a chosen `TaskItem`, `onComplete`, and `onPostpone` callbacks.
- Produces a route with a visible back control, a clear completion action, and postponing control.

- [ ] Write phone and desktop widget tests that show the chosen task, return control, completion button, and postponement button.
- [ ] Run tests; they must fail because the route does not exist.
- [ ] Implement a calm, single-task screen using fixed semantic actions and no auto-starting timer.
- [ ] Wire the existing “Teraz” card to the focus route and run focused tests.

### Task 5: Full quality pass

**Files:**
- Modify only files required by analyzer/test failures.

- [ ] Run `flutter analyze`.
- [ ] Run the complete `flutter test` suite.
- [ ] Build the Windows debug executable without launching it.
- [ ] Review phone (390 px) and desktop (1100 px) widget coverage for the new controls.
