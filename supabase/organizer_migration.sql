-- Pola reminder_at, repeat_rule i pinned_today są już w tabeli tasks.
-- Ta migracja zachowuje dane istniejących zadań i dodaje wyłącznie historię ukończeń.
alter table public.tasks
  add column if not exists completed_at timestamptz;

create index if not exists tasks_user_completed_at_idx
  on public.tasks (user_id, completed_at desc)
  where completed_at is not null;
