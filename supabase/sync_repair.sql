-- Uruchom jednorazowo w Supabase SQL Editor.
-- Migracja jest idempotentna: można wykonać ją ponownie bez kasowania danych.

alter table public.tasks
  add column if not exists completed_at timestamptz;

alter table public.tasks
  add column if not exists source_note_id uuid;

create index if not exists tasks_user_completed_at_idx
  on public.tasks (user_id, completed_at desc)
  where completed_at is not null;

grant select, insert, update, delete on public.tasks to authenticated;
