create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 240),
  note text not null default '',
  status text not null default 'todo' check (status in ('todo','in_progress','done')),
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  category text not null default 'Bez kategorii',
  emoji text,
  color_key text,
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

create table public.task_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  color text not null default '#2F6FED' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  emoji text check (emoji is null or char_length(emoji) <= 16),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name)
);
alter table public.task_categories enable row level security;
grant select, insert, update, delete on public.task_categories to authenticated;
create policy "read own task categories" on public.task_categories for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own task categories" on public.task_categories for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own task categories" on public.task_categories for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own task categories" on public.task_categories for delete to authenticated using ((select auth.uid()) = user_id);
alter table public.tasks add column category_id uuid references public.task_categories(id) on delete set null;
create index task_categories_user_updated_idx on public.task_categories (user_id, updated_at desc);
create index tasks_user_category_idx on public.tasks (user_id, category_id) where deleted_at is null;
alter publication supabase_realtime add table public.task_categories;
