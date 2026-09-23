# Responsywny tydzień i akcje zadań — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodać szybkie akcje statusu oraz lekki widok tygodnia, wygodne na telefonie i desktopie.

**Architecture:** Status będzie odrębnym responsywnym komponentem w `TaskRow`. Kalendarz będzie niezależnym ekranem z czystymi funkcjami operującymi na `TaskItem`; `MyApp` pozostaje właścicielem lokalnego zapisu i synchronizacji Supabase.

**Tech Stack:** Flutter/Dart, Material 3, flutter_test, SharedPreferences, supabase_flutter.

**Spec:** `docs/superpowers/specs/2026-09-05-responsive-calendar-and-interactions-design.md`

## Global Constraints

- Jeden akcent błękitny; gradient tylko na nagłówku, „Teraz” i podsumowaniu tygodnia.
- Płaskie, kontrastowe karty; emoji wyłącznie dla kategorii.
- Rytm 8/16/24/32 px, cele dotyku minimum 48 px.
- Desktop: hover/focus 120 ms i pressed 100 ms. Telefon nie zależy od hovera.
- Animuj tylko opacity i transform pojedynczego elementu; nie animuj list ani scrolla.
- Desktop: szerokość co najmniej 720 px. Telefon: poniżej 720 px; przy 390 px bez przepełnienia.
- Nie dodawaj zależności pub; użyj `LongPressDraggable` i `DragTarget` Fluttera.
- Kalendarz opiera się o `TaskItem.dueAt`; przenoszenie zachowuje godzinę, a pusty termin dostaje 09:00.

---

## Struktura plików

- `lib/task_status_control.dart` — wybór statusu dla desktopu i telefonu.
- `lib/task_row.dart` — płaski wiersz z bezpośrednimi statusami.
- `lib/weekly_calendar.dart` — logika tygodnia i ekran kalendarza.
- `lib/today_screen.dart` — wejścia do „Tygodnia”.
- `lib/main.dart` — routing, zapis i synchronizacja zmiany terminu.
- `test/task_status_control_test.dart`, `test/weekly_calendar_test.dart`, `test/widget_test.dart` — testy.

### Task 1: Model tygodnia oraz przeniesienie terminu

**Files:**
- Create: `lib/weekly_calendar.dart`
- Test: `test/weekly_calendar_test.dart`

**Interfaces:**
- Consumes: `TaskItem.dueAt` i `startOfWeek(DateTime)` z `lib/weekly_review.dart`.
- Produces: `weekDays(DateTime)`, `tasksByDay(Iterable<TaskItem>, DateTime)` i `moveTaskToDay(TaskItem, DateTime)`.

- [ ] **Step 1: Write the failing test**

```dart
test('groups dated tasks and skips undated tasks', () {
  final task = TaskItem(id: 'monday', title: 'Plan', status: 'todo',
    dueAt: DateTime(2026, 9, 7, 14, 30));
  final grouped = tasksByDay([task], DateTime(2026, 9, 7));
  expect(grouped[DateTime(2026, 9, 7)], [task]);
  expect(grouped[DateTime(2026, 9, 8)], isEmpty);
});

test('moves a task preserving time and defaults empty time to 09:00', () {
  final moved = moveTaskToDay(TaskItem(id: 'a', title: 'Plan', status: 'todo',
    dueAt: DateTime(2026, 9, 7, 14, 30)), DateTime(2026, 9, 10));
  expect(moved.dueAt, DateTime(2026, 9, 10, 14, 30));
  expect(moveTaskToDay(const TaskItem(id: 'b', title: 'Nowe', status: 'todo'),
    DateTime(2026, 9, 10)).dueAt, DateTime(2026, 9, 10, 9));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/weekly_calendar_test.dart`

Expected: FAIL because calendar functions do not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
List<DateTime> weekDays(DateTime weekStart) => List.generate(
  7, (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
);

TaskItem moveTaskToDay(TaskItem task, DateTime day) {
  final time = task.dueAt;
  return task.copyWith(dueAt: DateTime(day.year, day.month, day.day,
    time?.hour ?? 9, time?.minute ?? 0));
}
```

Initialize all seven midnight keys in `tasksByDay`, include only non-null terms inside the week and sort each day by `dueAt`.

- [ ] **Step 4: Run test to verify it passes**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/weekly_calendar_test.dart`

Expected: PASS for groups, empty days and term preservation.

- [ ] **Step 5: Commit**

```powershell
git add lib/weekly_calendar.dart test/weekly_calendar_test.dart
git commit -m "feat: add weekly calendar task helpers"
```

### Task 2: Responsywny status jednym kliknięciem

**Files:**
- Create: `lib/task_status_control.dart`
- Test: `test/task_status_control_test.dart`

**Interfaces:**
- Consumes: `String status`, `ValueChanged<String> onStatusSelected`, `MediaQuery.sizeOf(context).width`.
- Produces: `TaskStatusControl(status: status, onStatusSelected: callback)`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('desktop changes status with one tap', (tester) async {
  String? selected;
  await tester.binding.setSurfaceSize(const Size(900, 600));
  await tester.pumpWidget(MaterialApp(home: TaskStatusControl(
    status: 'todo', onStatusSelected: (value) => selected = value)));
  await tester.tap(find.byKey(const ValueKey('status-in_progress')));
  expect(selected, 'in_progress');
});

testWidgets('phone primary action cycles todo to in progress', (tester) async {
  String? selected;
  await tester.binding.setSurfaceSize(const Size(390, 800));
  await tester.pumpWidget(MaterialApp(home: TaskStatusControl(
    status: 'todo', onStatusSelected: (value) => selected = value)));
  await tester.tap(find.byKey(const ValueKey('mobile-status-cycle')));
  expect(selected, 'in_progress');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/task_status_control_test.dart`

Expected: FAIL because `TaskStatusControl` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
class TaskStatusControl extends StatelessWidget {
  const TaskStatusControl({super.key, required this.status, required this.onStatusSelected});
  final String status;
  final ValueChanged<String> onStatusSelected;

  @override
  Widget build(BuildContext context) => MediaQuery.sizeOf(context).width >= 720
      ? _DesktopStatusActions(status: status, onStatusSelected: onStatusSelected)
      : _MobileStatusAction(status: status, onStatusSelected: onStatusSelected);
}
```

Desktop gets three 48 px actions keyed `status-todo`, `status-in_progress`, `status-done` and highlights current choice with `primaryContainer`. Phone gets a 48 px `FilledButton.tonalIcon` keyed `mobile-status-cycle` plus a 48 px `mobile-status-options` button opening all three explicit choices. Use `AnimatedContainer(Duration(milliseconds: 120))` for color only.

- [ ] **Step 4: Run test to verify it passes**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/task_status_control_test.dart`

Expected: PASS for every desktop action, mobile cycle, explicit mobile menu, and no 390 px overflow.

- [ ] **Step 5: Commit**

```powershell
git add lib/task_status_control.dart test/task_status_control_test.dart
git commit -m "feat: add responsive one-tap task status controls"
```

### Task 3: Wiersz zadania bez ukrytych statusów

**Files:**
- Modify: `lib/task_row.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `TaskStatusControl`, `TaskItem`, existing callbacks.
- Produces: `TaskRow` with direct statuses; overflow menu only pins/unpins and deletes.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('task row exposes statuses but keeps them out of more menu', (tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 600));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: TaskRow(/* callbacks */))));
  expect(find.byKey(const ValueKey('status-todo')), findsOneWidget);
  await tester.tap(find.byIcon(Icons.more_horiz));
  await tester.pumpAndSettle();
  expect(find.text('Do zrobienia'), findsNothing);
  expect(find.text('Usuń zadanie'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/widget_test.dart --plain-name "task row exposes statuses but keeps them out of more menu"`

Expected: FAIL while current menu contains statuses.

- [ ] **Step 3: Write minimal implementation**

Replace status `_TaskTag` with `TaskStatusControl` below title and metadata. Keep category emoji and high-priority label only. Keep surface `surfaceContainerLow`, use 16 px padding, preserve `InkWell` hover/focus, and animate completed row with `AnimatedOpacity` plus `AnimatedScale(scale: task.isDone ? 0.995 : 1)` for 120 ms. Overflow menu keeps only pin/unpin and delete; delete continues through confirmation callback.

- [ ] **Step 4: Run test to verify it passes**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/widget_test.dart`

Expected: PASS for current completion, editing, menu and task-detail tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/task_row.dart test/widget_test.dart
git commit -m "feat: expose task statuses directly in task rows"
```

### Task 4: Responsywny ekran „Tydzień”

**Files:**
- Modify: `lib/weekly_calendar.dart`
- Modify: `test/weekly_calendar_test.dart`

**Interfaces:**
- Consumes: `weekDays`, `tasksByDay`, `moveTaskToDay`, `TaskItem`.
- Produces: `WeeklyCalendarScreen(tasks: tasks, initialWeek: date, onOpenTask: callback, onMoveTask: callback, onQuickAdd: callback)`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('phone week screen exposes day chips and move action', (tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(MaterialApp(home: WeeklyCalendarScreen(
    tasks: [TaskItem(id: 'm', title: 'Poniedziałek', status: 'todo',
      dueAt: DateTime(2026, 9, 7, 10))],
    initialWeek: DateTime(2026, 9, 7), onOpenTask: (_) {},
    onMoveTask: (_, __) {}, onQuickAdd: () {},
  )));
  expect(find.byKey(const ValueKey('week-day-0')), findsOneWidget);
  expect(find.byKey(const ValueKey('move-task-m')), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/weekly_calendar_test.dart`

Expected: FAIL because `WeeklyCalendarScreen` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create state holding `_weekStart` and `_selectedDay`. On week change animate only day content using a 200 ms `FadeTransition` plus a short vertical `SlideTransition`. Desktop uses seven `Expanded DragTarget<TaskItem>` columns. Day cards are `LongPressDraggable<TaskItem>` and acceptance calls `onMoveTask(task, targetDay)`. Phone uses a horizontally scrolling list of keyed day chips plus selected-day list; each task has visible outlined `Przenieś na dzień`, opening a bottom sheet of seven days. For an empty selected day, show `Dodaj zadanie`.

- [ ] **Step 4: Run test to verify it passes**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/weekly_calendar_test.dart`

Expected: PASS for desktop seven targets, phone chips/move action, empty state and 390 px width.

- [ ] **Step 5: Commit**

```powershell
git add lib/weekly_calendar.dart test/weekly_calendar_test.dart
git commit -m "feat: add responsive weekly calendar"
```

### Task 5: Nawigacja, zapis i synchronizacja terminu

**Files:**
- Modify: `lib/today_screen.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `WeeklyCalendarScreen`, `moveTaskToDay(TaskItem, DateTime)`, `_sync.updateOrganizerTask` and `_saveLocalTasks`.
- Produces: `TodayScreen.onOpenWeek` and `_moveTaskToWeekDay(TaskItem task, DateTime day)`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('opens week from compact navigation', (tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.text('Tryb lokalny'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('task-view-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tydzień').last);
  await tester.pumpAndSettle();
  expect(find.text('Tydzień'), findsWidgets);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/widget_test.dart --plain-name "opens week from compact navigation"`

Expected: FAIL because compact navigation has no week entry.

- [ ] **Step 3: Write minimal implementation**

Add `Tydzień` and `Icons.calendar_view_week_outlined` to desktop navigation and compact menu. Keep the existing `Przegląd tygodnia` as a separate summary action. Add:

```dart
Future<void> _moveTaskToWeekDay(TaskItem task, DateTime day) async {
  final updated = moveTaskToDay(task, day);
  if (cloudMode) {
    await _sync.updateOrganizerTask(updated);
    await _loadCloudTasks();
  } else {
    setState(() => tasks[tasks.indexOf(task)] = updated);
    await _saveLocalTasks();
  }
}
```

Route through `_navigatorKey.currentState` and pass tasks, open-editor callback, quick-add callback and move callback. When `reminderAt == dueAt`, schedule the reminder for the updated due date.

- [ ] **Step 4: Run test to verify it passes**

Run: `.tooling\\flutter\\bin\\flutter.bat test test/widget_test.dart`

Expected: PASS for compact/desktop routes, local date update, current weekly review route, and no exceptions.

- [ ] **Step 5: Commit**

```powershell
git add lib/main.dart lib/today_screen.dart test/widget_test.dart
git commit -m "feat: connect weekly calendar to task navigation"
```

### Task 6: Całościowa weryfikacja i skrót Windows

**Files:**
- Modify: no source files unless verification identifies a defect.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: debug build Windows, bez automatycznego uruchomienia aplikacji.

- [ ] **Step 1: Run static analysis**

Run: `.tooling\\flutter\\bin\\flutter.bat analyze`

Expected: `No issues found!`.

- [ ] **Step 2: Run full suite**

Run: `.tooling\\flutter\\bin\\flutter.bat test`

Expected: all tests PASS.

- [ ] **Step 3: Build Windows without launching it**

Run: `.tooling\\flutter\\bin\\flutter.bat build windows --debug`

Expected: `Built build\\windows\\x64\\runner\\Debug\\dzien_po_dniu.exe`.

- [ ] **Step 4: Confirm desktop shortcut target**

Run: `powershell -NoProfile -Command "(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\\Dzień po dniu.lnk').TargetPath"`

Expected: it points to `...\\.worktrees\\task-app\\build\\windows\\x64\\runner\\Debug\\dzien_po_dniu.exe`.

- [ ] **Step 5: Commit only if verification required a source correction**

```powershell
git add <exact-corrected-files>
git commit -m "fix: resolve weekly calendar verification issue"
```

## Self-review

- **Spec coverage:** Tasks 2–3 implement direct statuses, phone alternatives, flat cards, concise status and restrained animation. Task 4 implements desktop drag/drop and phone chips/move action, including empty state. Task 5 covers both navigation modes plus local/Supabase persistence. Task 6 checks analysis, all tests, 390 px and a Windows build without launching. Existing weekly review remains available.
- **Placeholder scan:** No `TBD`, `TODO`, vague test steps or missing signatures remain.
- **Type consistency:** `moveTaskToDay(TaskItem, DateTime)` is declared in Task 1 and used in Tasks 4–5. `WeeklyCalendarScreen` callback types are declared in Task 4 and consumed in Task 5. `TaskStatusControl` keys used in Task 3 are declared in Task 2.

