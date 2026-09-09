create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 240),
  note text not null default '',
  status text not null default 'todo' check (status in ('todo','in_progress','done')),
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  category text not null default 'Skrzynka',
  due_at timestamptz,
  reminder_at timestamptz,
  repeat_rule jsonb,
  pinned_today boolean not null default false,
  deleted_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.tasks enable row level security;
grant select, insert, update, delete on public.tasks to authenticated;
create policy "read own tasks" on public.tasks for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own tasks" on public.tasks for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own tasks" on public.tasks for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own tasks" on public.tasks for delete to authenticated using ((select auth.uid()) = user_id);
create index tasks_user_updated_idx on public.tasks (user_id, updated_at desc) where deleted_at is null;
