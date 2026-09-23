-- Moduł Notatki. Uruchom po schema.sql i subtasks.sql.
create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '' check (char_length(title) <= 160),
  preview_text text not null default '' check (char_length(preview_text) <= 400),
  color_key text not null default 'neutral' check (color_key in ('neutral','blue','lavender','mint','peach','sand')),
  pinned boolean not null default false,
  archived_at timestamptz,
  deleted_at timestamptz,
  reminder_at timestamptz,
  revision integer not null default 1 check (revision > 0),
  conflict_of uuid references public.notes(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.note_blocks (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.notes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  block_type text not null check (block_type in ('text','heading','quote','checklist','table','attachment')),
  payload jsonb not null default '{}'::jsonb,
  position integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.note_attachments (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.notes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null default 'application/octet-stream',
  byte_size bigint not null check (byte_size between 0 and 20971520),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.note_labels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 48),
  color_key text not null default 'neutral',
  unique(user_id, name)
);

create table if not exists public.note_label_links (
  note_id uuid not null references public.notes(id) on delete cascade,
  label_id uuid not null references public.note_labels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (note_id, label_id)
);

create table if not exists public.note_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  trash_retention_days integer check (trash_retention_days is null or trash_retention_days in (7, 30)),
  updated_at timestamptz not null default now()
);

alter table public.tasks add column if not exists source_note_id uuid references public.notes(id) on delete set null;

create index if not exists notes_user_updated_idx on public.notes (user_id, updated_at desc);
create index if not exists notes_user_active_idx on public.notes (user_id, pinned, updated_at desc) where deleted_at is null;
create index if not exists note_blocks_note_position_idx on public.note_blocks (note_id, position);
create index if not exists note_attachments_note_idx on public.note_attachments (note_id, created_at);
create index if not exists note_label_links_note_idx on public.note_label_links (note_id);

grant select, insert, update, delete on public.notes, public.note_blocks, public.note_attachments,
  public.note_labels, public.note_label_links, public.note_settings to authenticated;

alter table public.notes enable row level security;
alter table public.note_blocks enable row level security;
alter table public.note_attachments enable row level security;
alter table public.note_labels enable row level security;
alter table public.note_label_links enable row level security;
alter table public.note_settings enable row level security;

create policy "read own notes" on public.notes for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own notes" on public.notes for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own notes" on public.notes for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own notes" on public.notes for delete to authenticated using ((select auth.uid()) = user_id);

create policy "read own note blocks" on public.note_blocks for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own note blocks" on public.note_blocks for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own note blocks" on public.note_blocks for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own note blocks" on public.note_blocks for delete to authenticated using ((select auth.uid()) = user_id);

create policy "read own note attachments" on public.note_attachments for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own note attachments" on public.note_attachments for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own note attachments" on public.note_attachments for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own note attachments" on public.note_attachments for delete to authenticated using ((select auth.uid()) = user_id);

create policy "read own note labels" on public.note_labels for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own note labels" on public.note_labels for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own note labels" on public.note_labels for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own note labels" on public.note_labels for delete to authenticated using ((select auth.uid()) = user_id);

create policy "read own note label links" on public.note_label_links for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own note label links" on public.note_label_links for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "delete own note label links" on public.note_label_links for delete to authenticated using ((select auth.uid()) = user_id);

create policy "read own note settings" on public.note_settings for select to authenticated using ((select auth.uid()) = user_id);
create policy "create own note settings" on public.note_settings for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own note settings" on public.note_settings for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "delete own note settings" on public.note_settings for delete to authenticated using ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public) values ('note-attachments', 'note-attachments', false)
on conflict (id) do update set public = excluded.public;

create policy "read own note files" on storage.objects for select to authenticated
using (bucket_id = 'note-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "upload own note files" on storage.objects for insert to authenticated
with check (bucket_id = 'note-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "update own note files" on storage.objects for update to authenticated
using (bucket_id = 'note-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'note-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "delete own note files" on storage.objects for delete to authenticated
using (bucket_id = 'note-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);

do $$
declare
  table_name text;
begin
  foreach table_name in array array['notes','note_blocks','note_attachments','note_labels','note_label_links','note_settings'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    exception when duplicate_object then
      null;
    end;
  end loop;
end $$;
