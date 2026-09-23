# Task Checklists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add checklists of small steps to each task, including private cloud synchronization and a compact progress counter.

**Architecture:** `SubtaskItem` belongs to one `TaskItem`. Cloud rows live in a RLS-protected `public.subtasks` table, while local-mode subtasks serialize inside the existing `TaskItem` storage record.

**Tech Stack:** Flutter/Dart, `shared_preferences`, Supabase Postgres/RLS/Realtime, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-31-task-checklists-design.md`

## Global Constraints

- Use only the Supabase publishable key in Flutter.
- Enable RLS and use `to authenticated` plus owner predicates for every `public.subtasks` policy.
- Use both `using` and `with check` in the UPDATE policy.
- Add `public.subtasks` to `supabase_realtime`.
- Verify with analysis, tests and builds only; do not launch the application.

---

### Task 1: Create the secure cloud table

**Files:** Create `supabase/subtasks.sql`; modify `README.md`.

**Produces:** `public.subtasks(id, task_id, user_id, title, position, is_done, updated_at)`.

- [ ] Write `supabase/subtasks.sql` with this schema and policies:

```sql
create table public.subtasks (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 240),
  position integer not null default 0,
  is_done boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.subtasks enable row level security;
revoke all on public.subtasks from anon;
grant select, insert, update, delete on public.subtasks to authenticated;
create policy "read own subtasks" on public.subtasks for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own subtasks" on public.subtasks for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own subtasks" on public.subtasks for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own subtasks" on public.subtasks for delete to authenticated using ((select auth.uid()) = user_id);
create index subtasks_task_position_idx on public.subtasks (task_id, position, updated_at);
alter publication supabase_realtime add table public.subtasks;
```

- [ ] Ask the user to run this exact SQL in Supabase SQL Editor; expect `Success. No rows returned`.
- [ ] Verify publication membership with `select tablename from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'subtasks';`; expect one row.
- [ ] Commit only these documentation and SQL files with message `feat: add private subtask schema`.

### Task 2: Add serializable local checklist data

**Files:** Create `lib/subtask_item.dart`; modify `lib/task_item.dart`; test `test/task_item_test.dart`.

**Produces:** `SubtaskItem({id, title, isDone, position})`, `TaskItem.subtasks`, `completedSubtaskCount`, `subtaskCount`.

- [ ] Write a failing test which saves a `TaskItem` containing two `SubtaskItem`s, restores it with `TaskItem.fromStorage`, and expects progress `1` of `2`.
- [ ] Run `flutter test test/task_item_test.dart`; expect failure because the model does not exist.
- [ ] Implement `SubtaskItem.toStorage`, `SubtaskItem.fromStorage`, and include the list in `TaskItem.toStorage`/`TaskItem.fromStorage`.
- [ ] Run `flutter test test/task_item_test.dart`; expect pass.
- [ ] Commit model and test with `feat: persist local task checklists`.

### Task 3: Synchronize checklist rows

**Files:** Modify `lib/task_sync_service.dart`; test `test/task_sync_service_test.dart`.

**Produces:** `loadSubtasks(taskId)`, `addSubtask(taskId, title, position)`, `setSubtaskDone(id, isDone)`, `deleteSubtask(id)`.

- [ ] Write a failing repository test expecting an inserted row to carry the authenticated `user_id`, `task_id`, title and position.
- [ ] Run `flutter test test/task_sync_service_test.dart`; expect failure before the methods exist.
- [ ] Implement the four methods against `subtasks`, always updating `updated_at`; `addSubtask` must read `currentUser` and throw when absent.
- [ ] Run the focused test and then all tests; expect pass.
- [ ] Commit with `feat: synchronize subtasks`.

### Task 4: Edit and display checklist progress

**Files:** Modify `lib/main.dart`; test `test/widget_test.dart`.

**Produces:** an editable “Małe kroki” section and a conditional `x/y kroków` label on each task card.

- [ ] Write a failing widget test that adds and completes one of two local steps, then expects `1/2 kroków`.
- [ ] Run `flutter test test/widget_test.dart`; expect failure before checklist UI exists.
- [ ] Add the section to the existing task editor with checkbox, delete action and text field plus “Dodaj krok”.
- [ ] For cloud mode call TaskSyncService methods; for local mode replace the TaskItem and save it through LocalTaskStore.
- [ ] Display `${task.completedSubtaskCount}/${task.subtaskCount} kroków` only when `subtaskCount > 0`.
- [ ] Run `flutter test test/widget_test.dart`; expect pass.
- [ ] Commit with `feat: edit task checklists`.

### Task 5: Final verification and documentation

**Files:** Modify `README.md`.

- [ ] Document running `supabase/subtasks.sql` and checking Realtime.
- [ ] Run `flutter analyze` and `flutter test`; expect no analysis issues and all tests pass.
- [ ] Run `flutter build windows --debug` and `flutter build apk --debug`; expect both `Built` outputs without launching either application.
- [ ] Commit the README with `docs: explain checklist setup`.
