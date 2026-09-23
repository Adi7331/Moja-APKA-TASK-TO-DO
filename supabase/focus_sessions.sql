-- Dzień po dniu: prywatna historia sesji Skupienia.
-- Uruchom w Supabase SQL Editor po schema.sql. Nie przechowuje tokenów Google.

create table if not exists public.focus_sessions (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  planned_work_seconds integer not null check (planned_work_seconds between 1 and 86400),
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  check (ended_at >= started_at)
);

create index if not exists focus_sessions_user_started_idx
  on public.focus_sessions (user_id, started_at desc);

grant select, insert, update, delete on public.focus_sessions to authenticated;
alter table public.focus_sessions enable row level security;

create policy "read own focus sessions" on public.focus_sessions for select
  to authenticated using ((select auth.uid()) = user_id);
create policy "create own focus sessions" on public.focus_sessions for insert
  to authenticated with check ((select auth.uid()) = user_id);
create policy "update own focus sessions" on public.focus_sessions for update
  to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "delete own focus sessions" on public.focus_sessions for delete
  to authenticated using ((select auth.uid()) = user_id);

do $$
begin
  alter publication supabase_realtime add table public.focus_sessions;
exception when duplicate_object then null;
end $$;
