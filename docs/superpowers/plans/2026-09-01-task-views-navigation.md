# Task Views Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the task-view navigation clickable on Windows and Android for Today, Inbox, Upcoming and Completed tasks.

**Architecture:** A pure selector in `task_view.dart` maps a list of `TaskItem` to a `TaskView` using an injected clock. `MyApp` owns the selected view and passes it with callbacks to `TodayScreen`; presentation widgets do not mutate tasks or call Supabase.

**Tech Stack:** Flutter/Dart, Material 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-01-task-views-navigation-design.md`

## Global Constraints

- Keep `TaskItem`, local persistence, Supabase synchronization and notifications unchanged.
- `Skrzynka` contains active no-date tasks in category `Skrzynka`.
- `Nadchodzące` contains active tasks after the current day, sorted by date ascending.
- `Ukończone` contains only `done` tasks, sorted by date descending with undated items last.
- Keep the quick-add action available in every view.
- Do not add a dependency, Google OAuth, theme settings or a database migration.

---

### Task 1: Add a pure task-view selector

**Files:**
- Create: `lib/task_view.dart`
- Create: `test/task_view_test.dart`

**Interfaces:**
- Produces `enum TaskView { today, inbox, upcoming, completed }`.
- Produces `List<TaskItem> tasksForView(List<TaskItem> tasks, TaskView view, DateTime now)`.

- [ ] **Step 1: Write the failing unit tests**

```dart
test('places undated inbox tasks only in the inbox', () {
  final inbox = TaskItem(id: '1', title: 'Pomysł', status: 'todo');
  expect(tasksForView([inbox], TaskView.inbox, DateTime(2026, 9, 1)), [inbox]);
  expect(tasksForView([inbox], TaskView.upcoming, DateTime(2026, 9, 1)), isEmpty);
});

test('sorts upcoming active tasks from the nearest date', () {
  final later = TaskItem(id: 'later', title: 'Później', status: 'todo', dueAt: DateTime(2026, 9, 4));
  final sooner = TaskItem(id: 'sooner', title: 'Wcześniej', status: 'todo', dueAt: DateTime(2026, 9, 2));
  expect(tasksForView([later, sooner], TaskView.upcoming, DateTime(2026, 9, 1)), [sooner, later]);
});

test('shows completed tasks only in the completed view', () {
  final done = TaskItem(id: 'done', title: 'Gotowe', status: 'done');
  final open = TaskItem(id: 'open', title: 'Otwarte', status: 'todo');
  expect(tasksForView([done, open], TaskView.completed, DateTime(2026, 9, 1)), [done]);
});
```

- [ ] **Step 2: Verify the tests fail**

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/task_view_test.dart
```

Expected: compilation failure because `TaskView` and `tasksForView` do not exist.

- [ ] **Step 3: Implement the selector**

Create `task_view.dart`. Use `DateTime(now.year, now.month, now.day + 1)` as the boundary after today. Return copied, sorted lists; never mutate the supplied list.

- [ ] **Step 4: Verify the selector tests pass**

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/task_view_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/task_view.dart test/task_view_test.dart
git commit -m "feat: add task view selector"
```

### Task 2: Make desktop and phone navigation interactive

**Files:**
- Modify: `lib/today_screen.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes `TaskView selectedView` and `ValueChanged<TaskView> onViewChanged`.
- `TodayScreen` renders the supplied task list with title and empty-state copy derived from `selectedView`.

- [ ] **Step 1: Write failing widget tests**

```dart
await tester.tap(find.text('Skrzynka'));
await tester.pumpAndSettle();
expect(find.text('Skrzynka jest pusta. Zapisz tu rzecz, o której chcesz pamiętać.'), findsOneWidget);
```

Add a narrow-window test that taps the header menu icon, then taps `Nadchodzące`, and asserts the callback receives `TaskView.upcoming`.

- [ ] **Step 2: Verify the new widget tests fail**

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart --plain-name "changes the active task view"
```

Expected: FAIL because navigation items have no callbacks.

- [ ] **Step 3: Implement the navigation controls**

Pass callbacks into `_DesktopNavigation` and `_NavigationItem`; make items `InkWell` controls with selected state based on `TaskView`. Replace the header no-op three-dot button with a `PopupMenuButton<TaskView>` on compact layouts. Add title and empty-state mappings for all four views.

- [ ] **Step 4: Verify all widget tests pass**

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/today_screen.dart test/widget_test.dart
git commit -m "feat: add interactive task navigation"
```

### Task 3: Connect navigation to application state

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes `TaskView` and `tasksForView`.
- `MyApp` owns `TaskView _selectedView` and passes selector results to `TodayScreen`.

- [ ] **Step 1: Write a failing app-level test**

```dart
await tester.tap(find.text('Tryb lokalny'));
await tester.pumpAndSettle();
await tester.tap(find.text('Skrzynka'));
await tester.pumpAndSettle();
expect(find.text('Kreacje do reklamy'), findsNothing);
expect(find.text('Wykosić trawnik'), findsNothing);
```

- [ ] **Step 2: Verify it fails**

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test test/widget_test.dart --plain-name "filters app tasks through the inbox view"
```

Expected: FAIL because `MyApp` does not own a selected view.

- [ ] **Step 3: Wire the selector into `MyApp`**

Add `_selectedView = TaskView.today`, route `_visibleTasks` through `tasksForView`, and reset only the status filter when the selected view is not `today`. Pass `selectedView` and `onViewChanged` to `TodayScreen`. Keep search scoped to the selected list.

- [ ] **Step 4: Run full verification**

```powershell
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' analyze
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' test
& 'C:\Users\kalix\Desktop\Moja APKA TASK TO DO\.tooling\flutter\bin\flutter.bat' build windows --debug
```

Expected: analysis has no issues, all tests pass, and the Windows debug executable builds without starting.

- [ ] **Step 5: Commit**

```powershell
git add lib/main.dart test/widget_test.dart
git commit -m "feat: connect task views to app state"
```
