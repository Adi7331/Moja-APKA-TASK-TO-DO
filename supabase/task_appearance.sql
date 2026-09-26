-- Uruchom caly plik w Supabase SQL Editor przed wydaniem wygladu zadan.
-- Migracja jest bezpieczna do ponownego uruchomienia po czesciowym wykonaniu.
-- Istniejace RLS dla tasks nie jest zmieniane; nowa tabela ma polityki wlasciciela.

create table if not exists public.task_categories (
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

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_categories'
      and policyname = 'read own task categories'
  ) then
    create policy "read own task categories"
      on public.task_categories for select to authenticated
      using ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_categories'
      and policyname = 'create own task categories'
  ) then
    create policy "create own task categories"
      on public.task_categories for insert to authenticated
      with check ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_categories'
      and policyname = 'update own task categories'
  ) then
    create policy "update own task categories"
      on public.task_categories for update to authenticated
      using ((select auth.uid()) = user_id)
      with check ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_categories'
      and policyname = 'delete own task categories'
  ) then
    create policy "delete own task categories"
      on public.task_categories for delete to authenticated
      using ((select auth.uid()) = user_id);
  end if;
end
$$;

alter table public.tasks
  alter column category set default 'Bez kategorii',
  add column if not exists category_id uuid
    references public.task_categories(id) on delete set null,
  add column if not exists emoji text,
  add column if not exists color_key text;

create index if not exists task_categories_user_updated_idx
  on public.task_categories (user_id, updated_at desc);
create index if not exists tasks_user_category_idx
  on public.tasks (user_id, category_id)
  where deleted_at is null;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'task_categories'
  ) then
    alter publication supabase_realtime add table public.task_categories;
  end if;
end
$$;

-- Tylko stare, nieprzypisane wpisy "Skrzynka" staja sie "Bez kategorii".
-- Pozostale wartosci tekstowe i zadania nie sa usuwane ani przepisywane.
update public.tasks
set category = 'Bez kategorii'
where category_id is null
  and category = 'Skrzynka';
