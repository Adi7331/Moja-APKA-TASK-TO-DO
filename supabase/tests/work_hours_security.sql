-- Run after work_hours.sql. All users and rows below are rolled back.
begin;
select set_config('hours_test.owner_a', gen_random_uuid()::text, true);
select set_config('hours_test.owner_b', gen_random_uuid()::text, true);
select set_config('hours_test.entry', gen_random_uuid()::text, true);
insert into auth.users(id)
values (current_setting('hours_test.owner_a')::uuid),
       (current_setting('hours_test.owner_b')::uuid);
select set_config('request.jwt.claim.sub', current_setting('hours_test.owner_a'), true);
set local role authenticated;
do $$
declare
  owner_id uuid := current_setting('hours_test.owner_a')::uuid;
  other_id uuid := current_setting('hours_test.owner_b')::uuid;
  entry_id uuid := current_setting('hours_test.entry')::uuid;
  rejected boolean := false;
begin
  insert into public.work_hour_entries
    (id, user_id, work_date, name, start_minute, end_minute, rate_cents, updated_at)
  values (entry_id, owner_id, '2026-09-27', 'Security test', 480, 1020, 4000, '2026-09-27 08:00Z');
  if (select count(*) from public.work_hour_entries where id = entry_id) <> 1 then
    raise exception 'Owner cannot read own entry';
  end if;
  insert into public.work_hour_settings(user_id, rate_cents, updated_at)
  values (owner_id, 4000, '2026-09-27 08:00Z');
  update public.work_hour_settings set rate_cents = 5000, updated_at = '2026-09-27 09:00Z'
  where user_id = owner_id;
  update public.work_hour_settings set rate_cents = 2000, updated_at = '2026-09-27 08:30Z'
  where user_id = owner_id;
  if (select rate_cents from public.work_hour_settings where user_id = owner_id) <> 5000 then
    raise exception 'Stale settings overwrote newer rate';
  end if;
  begin
    insert into public.work_hour_settings(user_id, rate_cents) values (other_id, 1234);
  exception when insufficient_privilege then rejected := true;
  end;
  if not rejected then raise exception 'Cross-owner insert allowed'; end if;
  update public.work_hour_entries set deleted_at = '2026-09-27 10:00Z', updated_at = '2026-09-27 10:00Z'
  where id = entry_id;
  -- Ordinary UPSERT must not resurrect even with a later device timestamp.
  insert into public.work_hour_entries
    (id, user_id, work_date, name, start_minute, end_minute, rate_cents, updated_at, deleted_at, restore_requested)
  values (entry_id, owner_id, '2026-09-27', 'Stale offline edit', 480, 1020, 4000, '2026-09-27 11:00Z', null, false)
  on conflict (id) do update set name = excluded.name, updated_at = excluded.updated_at,
    deleted_at = excluded.deleted_at, restore_requested = excluded.restore_requested;
  if (select deleted_at is null from public.work_hour_entries where id = entry_id) then
    raise exception 'Ordinary UPSERT resurrected deleted entry';
  end if;
  -- Explicit Undo must survive BEFORE INSERT -> ON CONFLICT -> BEFORE UPDATE.
  insert into public.work_hour_entries
    (id, user_id, work_date, name, start_minute, end_minute, rate_cents, updated_at, deleted_at, restore_requested)
  values (entry_id, owner_id, '2026-09-27', 'Restored', 480, 1020, 4000, '2026-09-27 12:00Z', null, true)
  on conflict (id) do update set name = excluded.name, updated_at = excluded.updated_at,
    deleted_at = excluded.deleted_at, restore_requested = excluded.restore_requested;
  if not (select deleted_at is null and name = 'Restored' and not restore_requested
          from public.work_hour_entries where id = entry_id) then
    raise exception 'Explicit Undo did not restore entry';
  end if;
  update public.work_hour_entries set name = 'Too old', updated_at = '2026-09-27 09:00Z'
  where id = entry_id;
  if (select name from public.work_hour_entries where id = entry_id) <> 'Restored' then
    raise exception 'Stale update accepted';
  end if;
end;
$$;
reset role;
select set_config('request.jwt.claim.sub', current_setting('hours_test.owner_b'), true);
set local role authenticated;
do $$
declare affected integer;
begin
  if exists(select 1 from public.work_hour_entries where id = current_setting('hours_test.entry')::uuid)
     or exists(select 1 from public.work_hour_settings where user_id = current_setting('hours_test.owner_a')::uuid) then
    raise exception 'Second owner can read first owner data';
  end if;
  update public.work_hour_entries set paid = true where id = current_setting('hours_test.entry')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-owner update allowed'; end if;
  delete from public.work_hour_entries where id = current_setting('hours_test.entry')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-owner deletion allowed'; end if;
end;
$$;
reset role;
set local role anon;
do $$
declare rejected boolean := false;
begin
  begin
    perform 1 from public.work_hour_entries;
  exception when insufficient_privilege then rejected := true;
  end;
  if not rejected then raise exception 'Anonymous read allowed'; end if;
end;
$$;
reset role;
rollback;
select 'Owner isolation, stale writes, deletion and explicit UPSERT Undo passed; test data rolled back' as result;
