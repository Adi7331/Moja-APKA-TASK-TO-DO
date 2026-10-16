-- Run after business.sql. Test users and records are rolled back.
begin;
select set_config('business_test.owner_a', gen_random_uuid()::text, true);
select set_config('business_test.owner_b', gen_random_uuid()::text, true);
select set_config('business_test.record', gen_random_uuid()::text, true);
insert into auth.users(id)
values (current_setting('business_test.owner_a')::uuid),
       (current_setting('business_test.owner_b')::uuid);

select set_config('request.jwt.claim.sub', current_setting('business_test.owner_a'), true);
set local role authenticated;
do $$
declare
  owner_id uuid := current_setting('business_test.owner_a')::uuid;
  other_id uuid := current_setting('business_test.owner_b')::uuid;
  record_id text := current_setting('business_test.record');
  fresh_id text := current_setting('business_test.record') || '-fresh';
  rejected boolean := false;
begin
  insert into public.business_records(id, user_id, kind, payload, updated_at)
  values (record_id, owner_id, 'product', '{"name":"Lampa"}', '2026-10-16 08:00Z');
  if (select count(*) from public.business_records where id = record_id) <> 1 then
    raise exception 'Owner cannot read own business record';
  end if;
  begin
    insert into public.business_records(id, user_id, kind, payload)
    values ('cross-owner', other_id, 'product', '{}');
  exception when insufficient_privilege then rejected := true;
  end;
  if not rejected then raise exception 'Cross-owner insert allowed'; end if;

  update public.business_records
  set deleted_at = '2026-10-16 09:00Z', updated_at = '2026-10-16 09:00Z'
  where id = record_id;
  insert into public.business_records(id, user_id, kind, payload, updated_at, deleted_at)
  values (record_id, owner_id, 'product', '{"name":"Stale offline edit"}',
          '2026-10-16 10:00Z', null)
  on conflict (user_id, id) do update set payload = excluded.payload,
    updated_at = excluded.updated_at, deleted_at = excluded.deleted_at;
  if not (select deleted_at is not null and payload->>'name' = 'Lampa'
          from public.business_records where id = record_id) then
    raise exception 'Stale offline write resurrected or replaced deleted record';
  end if;

  insert into public.business_records(id, user_id, kind, payload, updated_at)
  values (fresh_id, owner_id, 'product', '{"name":"Newer edit"}', '2026-10-16 12:00Z');
  update public.business_records set payload = '{"name":"Old edit"}',
    updated_at = '2026-10-16 11:00Z' where id = fresh_id;
  if (select payload->>'name' from public.business_records where id = fresh_id)
     <> 'Newer edit' then
    raise exception 'Stale update overwrote newer record';
  end if;
end;
$$;

reset role;
select set_config('request.jwt.claim.sub', current_setting('business_test.owner_b'), true);
set local role authenticated;
do $$
declare affected integer;
  owner_id uuid := current_setting('business_test.owner_b')::uuid;
begin
  if exists (select 1 from public.business_records
             where id = current_setting('business_test.record')) then
    raise exception 'Second owner can read first owner data';
  end if;
  update public.business_records set payload = '{}'::jsonb
  where id = current_setting('business_test.record');
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-owner update allowed'; end if;
  delete from public.business_records
  where id = current_setting('business_test.record');
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-owner deletion allowed'; end if;

  insert into public.business_records(id, user_id, kind, payload)
  values (current_setting('business_test.record'), owner_id, 'workflow', '{}')
  on conflict (user_id, id) do update set payload = excluded.payload;
  if (select count(*) from public.business_records
      where id = current_setting('business_test.record')) <> 1 then
    raise exception 'The same record ID could not be stored independently per owner';
  end if;
end;
$$;

reset role;
set local role anon;
do $$
declare rejected boolean := false;
begin
  begin
    perform 1 from public.business_records;
  exception when insufficient_privilege then rejected := true;
  end;
  if not rejected then raise exception 'Anonymous read allowed'; end if;
end;
$$;
reset role;
rollback;
select 'Business owner isolation, stale updates and tombstones passed; test data rolled back' as result;
