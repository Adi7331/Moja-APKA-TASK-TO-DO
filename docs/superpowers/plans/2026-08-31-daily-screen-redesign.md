# Daily Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Flutter task interface into a compact, system-inspired daily planner while retaining existing local storage, Supabase synchronization, notifications, and task data.

**Architecture:** Keep `MyApp` as the owner of authentication, task mutations, local persistence, cloud synchronization, and notification scheduling. Move visual code into focused, passive widgets that receive immutable data and callbacks. `TodayScreen` composes a responsive desktop shell or a phone layout; `TaskEditor` owns only unsaved form fields and returns an editor draft through one callback.

**Tech Stack:** Flutter/Dart, Material 3, `flutter_test`, Supabase Flutter, Shared Preferences, flutter_local_notifications.

**Spec:** `docs/superpowers/specs/2026-08-31-daily-screen-redesign-design.md`

## Global Constraints

- Keep the existing `TaskItem`, `SubtaskItem`, Supabase tables, local JSON format, and notification API unchanged.
- Use a system-like light/dark palette with `ColorScheme`; the primary interactive color is blue.
- Emoji are optional category hints and never replace readable status/category text.
- Touch targets for task completion and primary actions must be at least 44 logical pixels high on phone layouts.
- Do not add a package dependency for the redesign.
- Do not implement Google OAuth, recurring tasks, Android widgets, Windows tray integration, or new conflict-resolution behavior in this plan.
- Finish with `flutter analyze` and `flutter test` using `C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat`.

---

## File Structure

- Create: `lib/app_theme.dart` — app color schemes and shared theme configuration.
- Create: `lib/task_category_icon.dart` — stable category-to-emoji mapping.
- Create: `lib/task_row.dart` — accessible task list row, metadata and checklist progress.
- Create: `lib/today_screen.dart` — responsive daily-plan shell, focus card, filter strip, sectioned list and desktop navigation.
- Create: `lib/task_editor.dart` — adaptive editor sheet/panel and `TaskDraft` value object.
- Modify: `lib/main.dart` — keep state/service methods and compose extracted widgets.
- Modify: `test/widget_test.dart` — retain existing coverage and add behavior checks for the new structure.

## Task 1: Theme and category presentation primitives

**Files:**
- Create: `lib/app_theme.dart`
- Create: `lib/task_category_icon.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Produces `ThemeData buildLightTheme()` and `ThemeData buildDarkTheme()`.
- Produces `String? categoryEmoji(String category)`.
- `TodayScreen` and `TaskRow` consume `categoryEmoji` and `Theme.of(context).colorScheme`.

- [ ] **Step 1: Write the failing category-icon test**

Add this unit test near the top of `test/widget_test.dart` after importing `task_category_icon.dart`:

```dart
test('maps known categories to a restrained emoji hint', () {
  expect(categoryEmoji('Praca'), '💼');
  expect(categoryEmoji('Dom'), '🏠');
  expect(categoryEmoji('Skrzynka'), isNull);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart
```

Expected: compilation failure because `task_category_icon.dart` and `categoryEmoji` do not exist.

- [ ] **Step 3: Add the minimal category mapping and reusable themes**

Create `lib/task_category_icon.dart`:

```dart
String? categoryEmoji(String category) => switch (category) {
      'Praca' => '💼',
      'Dom' => '🏠',
      _ => null,
    };
```

Create `lib/app_theme.dart` with blue primary color, `ColorScheme.fromSeed(seedColor: const Color(0xff0a7aff), brightness: ...)`, compact `InputDecorationTheme`, and rounded `FilledButtonThemeData`. Return separate light and dark `ThemeData` values from `buildLightTheme` and `buildDarkTheme`; keep `useMaterial3: true`.

- [ ] **Step 4: Run the focused test to verify it passes**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart
```

Expected: PASS, including the category mapping test and all pre-existing widget tests.

- [ ] **Step 5: Commit the isolated primitives**

```powershell
git add lib/app_theme.dart lib/task_category_icon.dart test/widget_test.dart
git commit -m "feat: add daily planner visual primitives"
```

## Task 2: Build testable task rows and the responsive today view

**Files:**
- Create: `lib/task_row.dart`
- Create: `lib/today_screen.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `TaskItem`, `String? categoryEmoji(String)`, selected filter string, and callbacks.
- Produces `TaskRow({required TaskItem task, required VoidCallback onOpen, required VoidCallback onComplete, required ValueChanged<String> onStatusSelected, required VoidCallback onDelete})`.
- Produces `TodayScreen({required List<TaskItem> visibleTasks, required List<TaskItem> laterTasks, required String selectedFilter, required ValueChanged<String> onFilterChanged, required ValueChanged<TaskItem> onOpenTask, required ValueChanged<TaskItem> onCompleteTask, required void Function(TaskItem, String) onStatusSelected, required ValueChanged<TaskItem> onDeleteTask, required VoidCallback onQuickAdd})`.

- [ ] **Step 1: Write failing widget tests for the structural contract**

Add tests that pump `TodayScreen` with one high-priority due task and one later task. Assert these exact visible strings:

```dart
expect(find.text('Najważniejsze'), findsOneWidget);
expect(find.text('Później'), findsOneWidget);
expect(find.text('Szybko zapisz zadanie'), findsOneWidget);
expect(find.text('Poprawić grafikę'), findsOneWidget);
expect(find.text('2 z 5 kroków'), findsOneWidget);
```

In the same test tap the `ValueKey('quick-add-task')` button and assert the supplied `onQuickAdd` callback ran.

- [ ] **Step 2: Run the new widget test to verify it fails**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart --plain-name "shows the sectioned daily plan"
```

Expected: compilation failure because `TodayScreen` does not exist.

- [ ] **Step 3: Implement the focused widgets**

Implement `TaskRow` as an `InkWell` with a 44px minimum height completion control, title, textual category/date metadata, optional category emoji, a `LinearProgressIndicator` only when `subtaskCount > 0`, and a popup menu for status/delete. The progress text must be `${task.completedSubtaskCount} z ${task.subtaskCount} kroków`.

Implement `TodayScreen` with:

```dart
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.visibleTasks, required this.laterTasks,
    required this.selectedFilter, required this.onFilterChanged,
    required this.onOpenTask, required this.onCompleteTask,
    required this.onStatusSelected, required this.onDeleteTask,
    required this.onQuickAdd});
  // fields match the Interfaces section
}
```

Use `LayoutBuilder`: at width under 720 show the date/header, a compact focus card, horizontal `ChoiceChip` filters, section headers and the extended quick-add FAB/button. At 720 or wider add the left navigation rail and place the same list in the central column. Keep the filter callback values `all`, `todo`, `in_progress`, and `done` so existing state logic continues to work.

- [ ] **Step 4: Run the focused and existing tests**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart
```

Expected: PASS. Existing search, filter, completion, popup-menu and checklist progress tests continue to pass after finder updates that preserve user-visible copy.

- [ ] **Step 5: Commit the today view**

```powershell
git add lib/task_row.dart lib/today_screen.dart test/widget_test.dart
git commit -m "feat: add responsive daily planner view"
```

## Task 3: Build and integrate the compact adaptive task editor

**Files:**
- Create: `lib/task_editor.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: optional `TaskItem`, available categories, and `Future<void> Function(TaskDraft draft) onSave`.
- Produces immutable `TaskDraft({required String title, required String note, required String category, required String priority, required DateTime? dueAt, required List<SubtaskItem> subtasks})`.
- Produces `showTaskEditor(BuildContext context, {TaskItem? task, required Future<void> Function(TaskDraft) onSave, required Future<void> Function(SubtaskItem) onToggleExistingStep, required Future<void> Function(SubtaskItem) onDeleteExistingStep})`.
- `MyApp` consumes `TaskDraft` and remains the only owner of `_sync`, `_localStore`, `tasks`, and `NotificationService` calls.

- [ ] **Step 1: Write failing editor interaction tests**

Add a widget test that opens an existing task through the app and asserts:

```dart
expect(find.text('Edytuj zadanie'), findsOneWidget);
expect(find.text('Termin'), findsOneWidget);
expect(find.text('Więcej opcji'), findsOneWidget);
expect(find.text('Opis (opcjonalnie)'), findsNothing);
```

Tap `Więcej opcji`, pump, then assert `Opis (opcjonalnie)`, `Kategoria`, and `Priorytet` are visible. Keep the existing checklist-add test and make it target the existing `ValueKey('subtask-input')` and `ValueKey('add-subtask')` keys.

- [ ] **Step 2: Run the editor test to verify it fails**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart --plain-name "expands additional task editor options"
```

Expected: FAIL because the current editor shows all options immediately and has no `Więcej opcji` control.

- [ ] **Step 3: Implement and wire the editor without direct service calls**

Create `TaskDraft` as a data holder in `task_editor.dart`. Implement `showTaskEditor` with `showModalBottomSheet` below 720px and `showDialog` at 720px or above. Put title, date/time and checklist first. Hide note/category/priority in an `AnimatedCrossFade` controlled by a text button labelled `Więcej opcji` / `Mniej opcji`.

Keep `subtask-input` and `add-subtask` keys unchanged. Existing cloud subtask callbacks are passed into the editor; the editor never imports `task_sync_service.dart`, `supabase_flutter.dart`, or `local_task_store.dart`. Disable the save button only while its `onSave` future is in progress and show an inline error string if it throws.

In `main.dart`, replace the inline body of `_showTaskForm` with `showTaskEditor`. Move existing create/update decisions into its `onSave(TaskDraft draft)` callback. Preserve local persistence, `_sync` calls, cloud subtask calls and notification scheduling. On success show `SnackBar(content: Text('Zapisano zadanie'))`. On a save exception, leave the editor open and show `Nie udało się zsynchronizować. Spróbuj ponownie.`.

- [ ] **Step 4: Run editor and full widget tests**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart
```

Expected: PASS, including the new options-expansion test and the checklist add/complete tests.

- [ ] **Step 5: Commit the editor**

```powershell
git add lib/task_editor.dart lib/main.dart test/widget_test.dart
git commit -m "feat: add compact adaptive task editor"
```

## Task 4: Integrate the daily view and run final verification

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `buildLightTheme`, `buildDarkTheme`, `TodayScreen`, `TaskDraft`, and `showTaskEditor` from prior tasks.
- Produces: the same `MyApp` public widget used by current tests.
- `MyApp` remains the only owner of `_sync`, `_localStore`, `tasks`, `_loadCloudTasks`, `_saveLocalTasks`, and `NotificationService` calls.

- [ ] **Step 1: Write a failing integration test for feedback and quick add**

Add a local-mode test that taps `ValueKey('quick-add-task')`, enters `Nowe zadanie`, saves, then asserts both:

```dart
expect(find.text('Nowe zadanie'), findsOneWidget);
expect(find.text('Zapisano zadanie'), findsOneWidget);
```

Add a test that taps a task row and confirms the new editor title appears, proving `TodayScreen` delegates opening to the state owner.

- [ ] **Step 2: Run integration tests to verify they fail**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart --plain-name "adds a task from the quick daily action"
```

Expected: FAIL because the old floating action button has no `quick-add-task` key and no save feedback.

- [ ] **Step 3: Replace the remaining monolithic daily presentation code in `main.dart`**

Import the four new UI files. Replace inline `ThemeData` values with `buildLightTheme()` and `buildDarkTheme()`. Replace the local-mode `Scaffold` list/card block with `TodayScreen`.

Derive `laterTasks` as visible tasks whose due date is after the end of today; pass all other visible tasks as the primary list. Do not mutate a task in a visual widget.

- [ ] **Step 4: Run analysis and the complete test suite**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' analyze
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test
```

Expected: `No issues found` from analysis and every test passes.

- [ ] **Step 5: Build Windows without launching the app**

Run:

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' build windows --debug
```

Expected: a successful build under `build\windows\x64\runner\Debug\dzien_po_dniu.exe`; do not start the executable.

- [ ] **Step 6: Commit integration and verification-ready redesign**

```powershell
git add lib/main.dart test/widget_test.dart
git commit -m "feat: integrate daily planner redesign"
```
