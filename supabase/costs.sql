-- Run in Supabase SQL Editor before enabling cloud sync for the Costs module.
-- Every table is private to its owner and can be safely applied more than once.

create table if not exists public.cost_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 60),
  color_value bigint not null default 4281292525,
  emoji text check (emoji is null or char_length(emoji) <= 16),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name)
);

create table if not exists public.cost_subscriptions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  amount_cents bigint not null check (amount_cents > 0),
  billing_cycle text not null check (billing_cycle in ('weekly', 'monthly', 'quarterly', 'yearly')),
  next_payment_at timestamptz not null,
  category_id uuid references public.cost_categories(id) on delete set null,
  reminder_days integer[] not null default array[3, 1],
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cost_entries (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 160),
  amount_cents bigint not null check (amount_cents > 0),
  entry_type text not null check (entry_type in ('expense', 'income')),
  status text not null check (status in ('planned', 'paid')),
  occurred_at timestamptz not null,
  category_id uuid references public.cost_categories(id) on delete set null,
  subscription_id uuid references public.cost_subscriptions(id) on delete set null,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cost_categories_owner_name_idx
  on public.cost_categories (user_id, name);
create index if not exists cost_subscriptions_owner_due_idx
  on public.cost_subscriptions (user_id, next_payment_at)
  where active;
create index if not exists cost_entries_owner_date_idx
  on public.cost_entries (user_id, occurred_at desc);

alter table public.cost_categories enable row level security;
alter table public.cost_subscriptions enable row level security;
alter table public.cost_entries enable row level security;

grant select, insert, update, delete on public.cost_categories to authenticated;
grant select, insert, update, delete on public.cost_subscriptions to authenticated;
grant select, insert, update, delete on public.cost_entries to authenticated;

drop policy if exists "read own cost categories" on public.cost_categories;
create policy "read own cost categories" on public.cost_categories
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "create own cost categories" on public.cost_categories;
create policy "create own cost categories" on public.cost_categories
  for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "update own cost categories" on public.cost_categories;
create policy "update own cost categories" on public.cost_categories
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists "delete own cost categories" on public.cost_categories;
create policy "delete own cost categories" on public.cost_categories
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "read own cost subscriptions" on public.cost_subscriptions;
create policy "read own cost subscriptions" on public.cost_subscriptions
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "create own cost subscriptions" on public.cost_subscriptions;
create policy "create own cost subscriptions" on public.cost_subscriptions
  for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "update own cost subscriptions" on public.cost_subscriptions;
create policy "update own cost subscriptions" on public.cost_subscriptions
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists "delete own cost subscriptions" on public.cost_subscriptions;
create policy "delete own cost subscriptions" on public.cost_subscriptions
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "read own cost entries" on public.cost_entries;
create policy "read own cost entries" on public.cost_entries
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "create own cost entries" on public.cost_entries;
create policy "create own cost entries" on public.cost_entries
  for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "update own cost entries" on public.cost_entries;
create policy "update own cost entries" on public.cost_entries
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists "delete own cost entries" on public.cost_entries;
create policy "delete own cost entries" on public.cost_entries
  for delete to authenticated using ((select auth.uid()) = user_id);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'cost_categories') then
    alter publication supabase_realtime add table public.cost_categories;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'cost_subscriptions') then
    alter publication supabase_realtime add table public.cost_subscriptions;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'cost_entries') then
    alter publication supabase_realtime add table public.cost_entries;
  end if;
end $$;
