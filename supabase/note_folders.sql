-- Dzień po dniu: foldery prywatnych notatek.
-- Uruchom ten plik w Supabase SQL Editor po supabase/notes.sql.
-- Nie usuwa żadnej istniejącej notatki; po skasowaniu folderu jego notatki
-- automatycznie przechodzą do "Bez folderu".

create table if not exists public.note_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  color_key text not null default 'neutral'
    check (color_key in ('neutral','blue','lavender','mint','peach','sand')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name)
);

alter table public.note_folders
  add column if not exists emoji text
  check (emoji is null or char_length(emoji) between 1 and 16);

alter table public.notes
  add column if not exists folder_id uuid references public.note_folders(id) on delete set null;

create index if not exists notes_user_folder_updated_idx
  on public.notes (user_id, folder_id, updated_at desc);

grant select, insert, update, delete on public.note_folders to authenticated;
alter table public.note_folders enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'note_folders'
      and policyname = 'read own note folders'
  ) then
    create policy "read own note folders" on public.note_folders
      for select to authenticated
      using ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'note_folders'
      and policyname = 'create own note folders'
  ) then
    create policy "create own note folders" on public.note_folders
      for insert to authenticated
      with check ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'note_folders'
      and policyname = 'update own note folders'
  ) then
    create policy "update own note folders" on public.note_folders
      for update to authenticated
      using ((select auth.uid()) = user_id)
      with check ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'note_folders'
      and policyname = 'delete own note folders'
  ) then
    create policy "delete own note folders" on public.note_folders
      for delete to authenticated
      using ((select auth.uid()) = user_id);
  end if;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.note_folders;
exception when duplicate_object then null;
end $$;
