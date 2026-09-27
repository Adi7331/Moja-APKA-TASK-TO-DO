-- Run in SQL Editor before enabling cloud sync for Godziny.
begin;
create table if not exists public.work_hour_entries (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  work_date date not null,
  name text not null check (length(btrim(name)) between 1 and 200),
  place text not null default '' check (length(place) <= 200),
  start_minute integer not null check (start_minute between 0 and 1439),
  end_minute integer not null check (end_minute between 0 and 1439),
  break_minutes integer not null default 0 check (break_minutes >= 0),
  next_day boolean not null default false,
  rate_cents integer not null check (rate_cents between 0 and 100000000),
  paid boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  restore_requested boolean not null default false,
  check (end_minute + case when next_day then 1440 else 0 end - start_minute between 1 and 1440),
  check (break_minutes < end_minute + case when next_day then 1440 else 0 end - start_minute)
);
create table if not exists public.work_hour_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  rate_cents integer not null default 0 check (rate_cents between 0 and 100000000),
  updated_at timestamptz not null default now()
);
create index if not exists work_hour_entries_owner_date on public.work_hour_entries(user_id, work_date desc);
alter table public.work_hour_entries add column if not exists restore_requested boolean not null default false;
alter table public.work_hour_entries enable row level security;
alter table public.work_hour_settings enable row level security;
revoke all on public.work_hour_entries, public.work_hour_settings from anon, authenticated;
grant select, insert, update, delete on public.work_hour_entries, public.work_hour_settings to authenticated;
drop policy if exists "owner work entries" on public.work_hour_entries;
create policy "owner work entries" on public.work_hour_entries for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "owner work settings" on public.work_hour_settings;
create policy "owner work settings" on public.work_hour_settings for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
-- An offline stale edit cannot clear a newer deletion tombstone. Explicit Undo
-- is a new local mutation with a fresh timestamp, so it can restore the row.
create or replace function public.work_hours_accept_newer()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    if new.updated_at <= old.updated_at then
      return null;
    end if;
    if tg_table_name = 'work_hour_entries' then
      if old.deleted_at is not null and new.deleted_at is null and not new.restore_requested then
        return null;
      end if;
    end if;
  end if;
  -- Preserve the flag during BEFORE INSERT: an UPSERT then carries it into
  -- EXCLUDED and the UPDATE trigger can authorize an explicit restoration.
  if tg_op = 'UPDATE' and tg_table_name = 'work_hour_entries' then
    new.restore_requested := false;
  end if;
  return new;
end;
$$;
revoke all on function public.work_hours_accept_newer() from public;
drop trigger if exists work_hours_newer_only on public.work_hour_entries;
create trigger work_hours_newer_only before insert or update on public.work_hour_entries
  for each row execute function public.work_hours_accept_newer();
drop trigger if exists work_hours_newer_only on public.work_hour_settings;
create trigger work_hours_newer_only before update on public.work_hour_settings
  for each row execute function public.work_hours_accept_newer();
commit;
