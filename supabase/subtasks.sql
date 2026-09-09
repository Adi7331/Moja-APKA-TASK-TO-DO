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

create policy "read own subtasks"
on public.subtasks for select to authenticated
using ((select auth.uid()) = user_id);

create policy "create own subtasks"
on public.subtasks for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "update own subtasks"
on public.subtasks for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "delete own subtasks"
on public.subtasks for delete to authenticated
using ((select auth.uid()) = user_id);

create index subtasks_task_position_idx
on public.subtasks (task_id, position, updated_at);

alter publication supabase_realtime add table public.subtasks;
