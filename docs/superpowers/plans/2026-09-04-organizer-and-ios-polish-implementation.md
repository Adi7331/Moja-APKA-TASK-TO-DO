# Organizer i spokojny styl systemowy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rozbudować „Dzień po dniu” o plan dnia, cykliczne zadania, przypomnienia, przegląd tygodnia i lekki responsywny styl systemowy.

**Architecture:** Logika dat, cykliczności i podsumowania pozostaje w małych klasach domenowych, dzięki czemu jest testowalna bez widżetów. `TaskItem` będzie jednym modelem dla pamięci lokalnej i Supabase, a `main.dart` tylko skoordynuje zapis lokalny, synchronizację i harmonogram powiadomień. Interfejs dostanie osobne, lekkie komponenty dla planu dnia, podsumowania tygodnia i ustawień organizera.

**Tech Stack:** Flutter/Dart, Material 3, SharedPreferences, Supabase Flutter, flutter_local_notifications, flutter_timezone.

**Spec:** `docs/superpowers/specs/2026-09-04-organizer-and-ios-polish-design.md`

## Global Constraints

- Zachowaj polskie teksty interfejsu i aktualne tryby: lokalny oraz synchronizowany przez Supabase.
- Nie dodawaj współdzielonych list, płatności, reklam ani funkcji iOS.
- Gradient stosuj wyłącznie na kartach „Teraz” i „Przegląd tygodnia”; listy zadań pozostają jednolite.
- Telefon poniżej 720 px używa jednej kolumny; komputer ma boczną nawigację i pływający przycisk dodawania.
- Plan dnia ma maksymalnie trzy aktywne przypięte zadania.
- Tydzień to poniedziałek 00:00–niedziela 23:59 w lokalnej strefie czasu.
- Nie uruchamiaj aplikacji automatycznie; weryfikuj analizą, testami oraz kompilacją.

---

## File structure

- Create: `lib/repeat_rule.dart` — serializacja reguł i wyliczanie następnego wystąpienia.
- Create: `lib/task_occurrence.dart` — utworzenie następnego zadania z odznaczoną checklistą.
- Create: `lib/weekly_review.dart` — czysta logika zakresu tygodnia i danych podsumowania.
- Create: `lib/organizer_settings.dart` — lokalnie zapisywane domyślne ustawienia przypomnień i przeglądu.
- Create: `lib/weekly_review_screen.dart` — responsywny widok podsumowania tygodnia.
- Modify: `lib/task_item.dart` — pola organizera oraz wspólna serializacja lokalna/Cloud.
- Modify: `lib/task_editor.dart` — wybór przypomnienia i powtarzalności.
- Modify: `lib/task_sync_service.dart` — zapis nowych pól do Supabase.
- Modify: `lib/notification_service.dart` — identyfikatory przypomnień, odłożenie i przegląd tygodnia.
- Modify: `lib/main.dart` — orkiestracja lokalnego zapisu, synchronizacji i funkcji cyklu życia zadania.
- Modify: `lib/task_row.dart` — akcja przypięcia i oszczędne oznaczenia organizera.
- Modify: `lib/today_screen.dart` — plan dnia, ekran tygodnia, ustawienia i responsywny wygląd.
- Modify: `lib/task_view.dart` — selekcja przypiętych i porządkowanie ukończonych według `completedAt`.
- Create: `supabase/organizer_migration.sql` — bezpieczna migracja `completed_at` oraz indeks.
- Modify/Create tests in `test/` dla każdej klasy domenowej i interakcji widżetów.

### Task 1: Model zadania i reguły powtarzalności

**Files:**
- Create: `lib/repeat_rule.dart`
- Modify: `lib/task_item.dart`
- Test: `test/repeat_rule_test.dart`
- Test: `test/task_item_test.dart`

**Interfaces:**
- Produces: `RepeatRule.fromJson(Map<String, dynamic>?)`, `RepeatRule.toJson()`, `RepeatRule.nextDueDate(DateTime reference)`.
- Produces: `TaskItem.reminderAt`, `TaskItem.repeatRule`, `TaskItem.pinnedToday`, `TaskItem.completedAt` and null-clearing `copyWith` support.

- [ ] **Step 1: Write the failing model tests**

```dart
test('weekly rule picks the next selected weekday after completion', () {
  const rule = RepeatRule(unit: RepeatUnit.week, interval: 1, weekdays: {1, 4});
  expect(rule.nextDueDate(DateTime(2026, 9, 1, 9)), DateTime(2026, 9, 3, 9));
});

test('task storage retains organizer fields', () {
  final task = TaskItem(id: 'a', title: 'Rytuał', status: 'todo',
      reminderAt: DateTime(2026, 9, 7, 9), pinnedToday: true,
      repeatRule: const RepeatRule.daily());
  final restored = TaskItem.fromStorage(task.toStorage());
  expect(restored.pinnedToday, isTrue);
  expect(restored.repeatRule, const RepeatRule.daily());
});
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test test/repeat_rule_test.dart test/task_item_test.dart --reporter compact`

Expected: FAIL because `RepeatRule` and the organizer properties do not exist.

- [ ] **Step 3: Implement the smallest complete domain model**

```dart
enum RepeatUnit { day, week, month }

class RepeatRule {
  const RepeatRule({required this.unit, this.interval = 1, this.weekdays = const {}})
      : assert(interval > 0);
  const RepeatRule.daily() : this(unit: RepeatUnit.day);
  final RepeatUnit unit;
  final int interval;
  final Set<int> weekdays;
  DateTime nextDueDate(DateTime reference) { /* select next valid local date */ }
}
```

Extend `TaskItem.fromRow`, `fromStorage`, `toStorage` and `copyWith` so each reads/writes `reminder_at`/`reminderAt`, `repeat_rule`/`repeatRule`, `pinned_today`/`pinnedToday`, and `completed_at`/`completedAt`. Use a private sentinel parameter in `copyWith` so an editor can intentionally clear a nullable date.

- [ ] **Step 4: Run focused tests and static analysis**

Run: `flutter test test/repeat_rule_test.dart test/task_item_test.dart --reporter compact && flutter analyze`

Expected: all selected tests pass and analyzer reports no issues.

- [ ] **Step 5: Commit the isolated model change**

```bash
git add lib/repeat_rule.dart lib/task_item.dart test/repeat_rule_test.dart test/task_item_test.dart
git commit -m "feat: add organizer task model"
```

### Task 2: Wystąpienia cykliczne i tygodniowe dane domenowe

**Files:**
- Create: `lib/task_occurrence.dart`
- Create: `lib/weekly_review.dart`
- Test: `test/task_occurrence_test.dart`
- Test: `test/weekly_review_test.dart`

**Interfaces:**
- Consumes: `TaskItem`, `RepeatRule`, `SubtaskItem` from Task 1.
- Produces: `TaskItem createNextOccurrence(TaskItem completed, DateTime completedAt, String id)`.
- Produces: `DateTime startOfWeek(DateTime local)`, `WeeklyReview buildWeeklyReview(List<TaskItem> tasks, DateTime now)`.

- [ ] **Step 1: Write the failing lifecycle and week-boundary tests**

```dart
test('completion creates a fresh weekly occurrence and clears its checklist', () {
  final next = createNextOccurrence(repeatingTaskWithOneDoneSubtask,
      DateTime(2026, 9, 6, 18), 'next');
  expect(next.status, 'todo');
  expect(next.subtasks.single.isDone, isFalse);
  expect(next.pinnedToday, isFalse);
});

test('review counts only completions from the previous Monday through Sunday', () {
  final review = buildWeeklyReview(tasks, DateTime(2026, 9, 7));
  expect(review.completedCount, 2);
  expect(review.weekStart, DateTime(2026, 8, 31));
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/task_occurrence_test.dart test/weekly_review_test.dart --reporter compact`

Expected: FAIL because the occurrence factory and review types do not exist.

- [ ] **Step 3: Implement deterministic occurrence and review calculations**

```dart
TaskItem createNextOccurrence(TaskItem completed, DateTime completedAt, String id) =>
  completed.copyWith(
    id: id,
    status: 'todo',
    dueAt: completed.repeatRule!.nextDueDate(completed.dueAt ?? completedAt),
    reminderAt: null,
    pinnedToday: false,
    completedAt: null,
    subtasks: completed.subtasks.map((step) => SubtaskItem(
      id: 'step-$id-${step.position}', title: step.title, isDone: false,
      position: step.position)).toList(),
  );
```

Implement `WeeklyReview` with `completedCount`, `overdue`, and `nextDue` (maximum three). Overdue includes active tasks whose `dueAt` precedes current local time; completed count uses `completedAt`, never the mutable due date.

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/task_occurrence_test.dart test/weekly_review_test.dart --reporter compact && flutter analyze`

Expected: PASS with no analyzer diagnostics.

- [ ] **Step 5: Commit the pure organizer logic**

```bash
git add lib/task_occurrence.dart lib/weekly_review.dart test/task_occurrence_test.dart test/weekly_review_test.dart
git commit -m "feat: add recurring occurrence and weekly review logic"
```

### Task 3: Lokalny zapis, Supabase i bezpieczna migracja

**Files:**
- Modify: `lib/task_sync_service.dart`
- Create: `supabase/organizer_migration.sql`
- Test: `test/task_sync_service_test.dart`

**Interfaces:**
- Consumes: expanded `TaskItem` from Task 1.
- Produces: `TaskSyncService.updateOrganizerFields(TaskItem task)` and `TaskSyncService.completeAndCreateNext(TaskItem completed, TaskItem? next)`.

- [ ] **Step 1: Write mapping tests without real network access**

```dart
test('task payload sends completedAt and repeatRule in database field names', () {
  final payload = task.toSupabasePayload();
  expect(payload['completed_at'], '2026-09-06T18:00:00.000');
  expect(payload['repeat_rule'], {'unit': 'week', 'interval': 1, 'weekdays': [1]});
});
```

- [ ] **Step 2: Run the mapping test and verify it fails**

Run: `flutter test test/task_sync_service_test.dart --reporter compact`

Expected: FAIL because no complete organizer payload is produced.

- [ ] **Step 3: Implement local-first compatible payloads and migration**

Add a `TaskItem.toSupabasePayload()` method used by add/update/sync code. In `TaskSyncService`, update the completed task first and insert the next occurrence only when it is non-null; let `main.dart` retain its existing local-first error behaviour.

```sql
alter table public.tasks add column if not exists completed_at timestamptz;
create index if not exists tasks_user_completed_at_idx
  on public.tasks (user_id, completed_at desc)
  where completed_at is not null;
```

The migration must not recreate existing reminder, repeat or pinned columns.

- [ ] **Step 4: Run the focused test and analyzer**

Run: `flutter test test/task_sync_service_test.dart --reporter compact && flutter analyze`

Expected: PASS and no issues.

- [ ] **Step 5: Commit sync and migration files**

```bash
git add lib/task_item.dart lib/task_sync_service.dart supabase/organizer_migration.sql test/task_sync_service_test.dart
git commit -m "feat: sync organizer task fields"
```

### Task 4: Plan dnia i ukończenie cyklicznego zadania

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/task_row.dart`
- Modify: `lib/today_screen.dart`
- Modify: `lib/task_view.dart`
- Test: `test/widget_test.dart`
- Test: `test/task_view_test.dart`

**Interfaces:**
- Consumes: `createNextOccurrence`, `TaskSyncService.completeAndCreateNext` and `TaskItem.pinnedToday`.
- Produces: `Future<void> togglePinnedToday(TaskItem task)` and a `DailyPlan` section showing active pins.

- [ ] **Step 1: Write the failing UI and selection tests**

```dart
testWidgets('fourth task cannot be pinned in the daily plan', (tester) async {
  await tester.pumpWidget(makeAppWithFourOpenTasks());
  await tester.tap(find.byKey(const ValueKey('pin-task-4')));
  await tester.pump();
  expect(find.text('Plan dnia może mieć najwyżej 3 zadania.'), findsOneWidget);
});

test('completed pinned task is absent from pinnedTodayTasks', () {
  expect(pinnedTodayTasks(tasksWithCompletedPin), hasLength(0));
});
```

- [ ] **Step 2: Run focused UI/domain tests to verify failure**

Run: `flutter test test/widget_test.dart test/task_view_test.dart --reporter compact`

Expected: FAIL because pin controls and `pinnedTodayTasks` do not exist.

- [ ] **Step 3: Implement local-first pin and completion flows**

Add `pinnedTodayTasks(List<TaskItem>)` that returns only open pins, maximum three. Add an accessible menu action in `TaskRow` with keys `pin-<task id>`/`unpin-<task id>`. In `main.dart`, write the changed task to local state before cloud sync; reject a fourth pin with a SnackBar. On completion, set `completedAt = DateTime.now()`, clear the pin, cancel its notification, create and save a next occurrence when `repeatRule != null`, then sync both records.

- [ ] **Step 4: Run focused tests and analyzer**

Run: `flutter test test/widget_test.dart test/task_view_test.dart --reporter compact && flutter analyze`

Expected: PASS with no analyzer diagnostics.

- [ ] **Step 5: Commit plan-day behaviour**

```bash
git add lib/main.dart lib/task_row.dart lib/today_screen.dart lib/task_view.dart test/widget_test.dart test/task_view_test.dart
git commit -m "feat: add daily plan and recurring completion"
```

### Task 5: Editor, organizer settings and reminders

**Files:**
- Create: `lib/organizer_settings.dart`
- Modify: `lib/task_editor.dart`
- Modify: `lib/notification_service.dart`
- Modify: `lib/main.dart`
- Test: `test/organizer_settings_test.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `RepeatRule`, `TaskItem.reminderAt` and existing `NotificationService`.
- Produces: `OrganizerSettings.load()`, `OrganizerSettings.save()`, `NotificationService.scheduleTaskReminder(TaskItem task)`, `NotificationService.scheduleWeeklyReview(DateTime when)`.

- [ ] **Step 1: Write failing settings and editor tests**

```dart
test('settings preserve reminder defaults and Monday review time', () async {
  final saved = OrganizerSettings(defaultReminderMinutes: 30, weeklyReviewHour: 0);
  await store.save(saved);
  expect(await store.load(), saved);
});

testWidgets('editor saves custom reminder and weekly repeat', (tester) async {
  await openEditor(tester);
  await tester.tap(find.byKey(const ValueKey('repeat-weekly')));
  await tester.tap(find.byKey(const ValueKey('reminder-custom')));
  await tester.tap(find.text('Dodaj zadanie'));
  expect(savedDraft.repeatRule!.unit, RepeatUnit.week);
  expect(savedDraft.reminderAt, isNotNull);
});
```

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/organizer_settings_test.dart test/widget_test.dart --reporter compact`

Expected: FAIL because editor controls and organizer settings are not available.

- [ ] **Step 3: Implement editing and scheduling contracts**

Extend `TaskDraft` with `DateTime? reminderAt` and `RepeatRule? repeatRule`. In advanced editor options add clearly labelled choices: reminder `Brak`, `W terminie`, `Własna godzina`; repeat `Nie powtarzaj`, `Codziennie`, `Co tydzień`, `Co miesiąc`, `Co N dni`, `Co N tygodni`; render weekday chips only for weekly repetition. Persist defaults through a small `SharedPreferences` store.

Give reminders separate stable IDs from weekly review notifications. Implement `snooze(task, duration)` to replace only `reminderAt`, never `dueAt`; provide exact choices 15 minutes, one hour, next day 09:00. Retain a foreground callback for action payloads and reconcile any pending decision when the application is opened.

- [ ] **Step 4: Run focused tests and analyzer**

Run: `flutter test test/organizer_settings_test.dart test/widget_test.dart --reporter compact && flutter analyze`

Expected: PASS and no static-analysis errors.

- [ ] **Step 5: Commit the editor and reminder contract**

```bash
git add lib/organizer_settings.dart lib/task_editor.dart lib/notification_service.dart lib/main.dart test/organizer_settings_test.dart test/widget_test.dart
git commit -m "feat: add reminders repeats and organizer settings"
```

### Task 6: Przegląd tygodnia i responsywny szlif systemowy

**Files:**
- Create: `lib/weekly_review_screen.dart`
- Modify: `lib/today_screen.dart`
- Modify: `lib/task_row.dart`
- Modify: `lib/app_theme.dart`
- Modify: `lib/main.dart`
- Test: `test/weekly_review_screen_test.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `WeeklyReview buildWeeklyReview(List<TaskItem>, DateTime)` and `OrganizerSettings`.
- Produces: `WeeklyReviewScreen(review: ..., onOpenDailyPlan: ...)` and a menu/navigation route labelled `Przegląd tygodnia`.

- [ ] **Step 1: Write failing screen and responsive layout tests**

```dart
testWidgets('weekly review presents completed count, overdue tasks and daily-plan shortcut', (tester) async {
  await tester.pumpWidget(makeWeeklyReview(review));
  expect(find.text('Ukończone w poprzednim tygodniu'), findsOneWidget);
  expect(find.text('Przejdź do planu dnia'), findsOneWidget);
});

testWidgets('compact width uses one-column organizer navigation', (tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(makeApp());
  expect(find.byKey(const ValueKey('compact-organizer-menu')), findsOneWidget);
});
```

- [ ] **Step 2: Run screen tests to verify failure**

Run: `flutter test test/weekly_review_screen_test.dart test/widget_test.dart --reporter compact`

Expected: FAIL because there is no weekly review screen or compact organizer menu.

- [ ] **Step 3: Implement the review and visual treatment**

Build the review as a scrollable single column showing completed count, overdue task rows, up to three upcoming rows and the daily-plan button. On start/open, compare the locally stored last-review week with current Monday; schedule the Monday 00:00 light reminder and present the review prompt only once per week.

Use a small `LinearGradient` only in the existing “Teraz” focus card and the review hero. Keep task list cards flat, use semantic labels and 44 px minimum tap targets. At widths below 720 px keep one column and a thumb-reachable bottom add action; at desktop preserve sidebar and a floating add action. Avoid whole-list animation or rebuilding; update only affected task rows using keyed list items.

- [ ] **Step 4: Run UI tests and analyzer**

Run: `flutter test test/weekly_review_screen_test.dart test/widget_test.dart --reporter compact && flutter analyze`

Expected: PASS with no issues.

- [ ] **Step 5: Commit review and visual polish**

```bash
git add lib/weekly_review_screen.dart lib/today_screen.dart lib/task_row.dart lib/app_theme.dart lib/main.dart test/weekly_review_screen_test.dart test/widget_test.dart
git commit -m "feat: add weekly review and responsive organizer polish"
```

### Task 7: Końcowa weryfikacja, instrukcja migracji i buildy

**Files:**
- Modify: `README.md`
- Verify: `supabase/organizer_migration.sql`
- Verify: all changed `lib/` and `test/` files.

**Interfaces:**
- Consumes: all preceding tasks.
- Produces: short user-facing migration instructions and verified Android/Windows artifacts.

- [ ] **Step 1: Add exact migration instructions**

Document that the user must run the contents of `supabase/organizer_migration.sql` in Supabase SQL Editor before relying on cloud weekly history. State that existing `reminder_at`, `repeat_rule` and `pinned_today` are preserved.

- [ ] **Step 2: Run complete static and test verification**

Run: `flutter analyze && flutter test --reporter compact`

Expected: analyzer reports no issues and every test passes.

- [ ] **Step 3: Build both supported targets without launching the application**

Run: `flutter build windows --debug && flutter build apk --debug`

Expected: Windows executable and Android debug APK are generated successfully.

- [ ] **Step 4: Commit documentation only after successful verification**

```bash
git add README.md supabase/organizer_migration.sql
git commit -m "docs: explain organizer migration and review"
```
