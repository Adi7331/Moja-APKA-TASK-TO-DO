-- Moduł Biznes: rekordy synchronizowane przez trwałą kolejkę klienta.
-- Uruchom w Supabase SQL Editor przed użyciem synchronizacji i zdjęć.

create table if not exists public.business_records (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('product', 'test', 'workflow', 'session', 'idea')),
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);

create index if not exists business_records_owner_kind_updated_idx
  on public.business_records (user_id, kind, updated_at desc);

grant select, insert, update, delete on public.business_records to authenticated;
revoke all on public.business_records from anon;
alter table public.business_records enable row level security;

drop policy if exists "read own business records" on public.business_records;
create policy "read own business records" on public.business_records for select
  to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "create own business records" on public.business_records;
create policy "create own business records" on public.business_records for insert
  to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "update own business records" on public.business_records;
create policy "update own business records" on public.business_records for update
  to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists "delete own business records" on public.business_records;
create policy "delete own business records" on public.business_records for delete
  to authenticated using ((select auth.uid()) = user_id);

-- A delayed device must not overwrite a newer edit or resurrect a tombstone.
create or replace function public.guard_business_record_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.deleted_at is not null and new.deleted_at is null then
    new.payload := old.payload;
    new.deleted_at := old.deleted_at;
    new.updated_at := old.updated_at;
    return new;
  end if;
  if new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_business_record_update on public.business_records;
create trigger guard_business_record_update
before update on public.business_records
for each row execute function public.guard_business_record_update();

do $$ begin
  alter publication supabase_realtime add table public.business_records;
exception when duplicate_object then null;
end $$;

insert into storage.buckets (id, name, public, file_size_limit)
values ('business-assets', 'business-assets', false, 20971520)
on conflict (id) do nothing;

drop policy if exists "read own business assets" on storage.objects;
create policy "read own business assets" on storage.objects for select to authenticated
  using (bucket_id = 'business-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "upload own business assets" on storage.objects;
create policy "upload own business assets" on storage.objects for insert to authenticated
  with check (bucket_id = 'business-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "update own business assets" on storage.objects;
create policy "update own business assets" on storage.objects for update to authenticated
  using (bucket_id = 'business-assets' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'business-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "delete own business assets" on storage.objects;
create policy "delete own business assets" on storage.objects for delete to authenticated
  using (bucket_id = 'business-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);
