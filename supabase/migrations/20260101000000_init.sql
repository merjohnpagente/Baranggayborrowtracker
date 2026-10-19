-- =====================================================================
-- Barangay Borrow Tracker - Supabase schema
-- Run this in Supabase Studio > SQL Editor (or `supabase db push`)
-- Safe to re-run: every object uses IF NOT EXISTS / ON CONFLICT guards.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 1. Types
-- ---------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('resident', 'official', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.asset_status as enum ('available', 'reserved', 'borrowed', 'maintenance', 'retired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.asset_condition as enum ('good', 'fair', 'needs_repair', 'damaged');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.request_status as enum ('pending', 'approved', 'declined', 'released', 'returned', 'cancelled');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text        not null,
  role        public.user_role not null default 'resident',
  phone       text,
  address     text,
  avatar_url  text,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.asset_categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  icon        text not null default 'category',
  description text,
  created_at  timestamptz not null default now()
);

create table if not exists public.assets (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null unique,
  name               text not null,
  category_id        uuid references public.asset_categories (id) on delete set null,
  description        text,
  image_url          text,
  status             public.asset_status   not null default 'available',
  condition          public.asset_condition not null default 'good',
  location           text,
  requires_approval  boolean not null default true,
  deposit_amount     numeric(10, 2) not null default 0,
  notes              text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create sequence if not exists public.request_ref_seq;

create table if not exists public.borrow_requests (
  id               uuid primary key default gen_random_uuid(),
  reference_no     text not null unique,
  asset_id         uuid not null references public.assets (id) on delete cascade,
  user_id          uuid not null references public.profiles (id) on delete cascade,
  purpose          text not null,
  borrow_date      date not null,
  return_date      date not null,
  status           public.request_status  not null default 'pending',
  reviewed_by      uuid references public.profiles (id) on delete set null,
  reviewed_at      timestamptz,
  review_remarks   text,
  released_by      uuid references public.profiles (id) on delete set null,
  released_at      timestamptz,
  returned_at      timestamptz,
  return_condition public.asset_condition,
  return_remarks   text,
  overdue          boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint borrow_request_dates_valid check (return_date >= borrow_date)
);

create index if not exists assets_category_idx      on public.assets (category_id);
create index if not exists assets_status_idx        on public.assets (status);
create index if not exists requests_user_idx        on public.borrow_requests (user_id);
create index if not exists requests_asset_idx       on public.borrow_requests (asset_id);
create index if not exists requests_status_idx      on public.borrow_requests (status);

-- ---------------------------------------------------------------------
-- 3. Helper functions (SECURITY DEFINER so RLS cannot recurse)
-- ---------------------------------------------------------------------
create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'admin', false);
$$;

create or replace function public.is_official()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() in ('official', 'admin'), false);
$$;

-- Used by the app before submitting a request (client-side courtesy check).
create or replace function public.check_asset_availability(
  p_asset_id    uuid,
  p_borrow_date date,
  p_return_date date
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.borrow_requests br
    where br.asset_id = p_asset_id
      and br.status in ('pending', 'approved', 'released')
      and br.borrow_date <= p_return_date
      and p_borrow_date <= br.return_date
  );
$$;

-- Flips the `overdue` flag for released items past their return date.
create or replace function public.refresh_overdue_requests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer;
begin
  update public.borrow_requests
     set overdue = true, updated_at = now()
   where status = 'released'
     and overdue = false
     and return_date < current_date;
  get diagnostics affected = row_count;
  return affected;
end;
$$;

-- ---------------------------------------------------------------------
-- 4. Triggers
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists assets_set_updated_at on public.assets;
create trigger assets_set_updated_at before update on public.assets
  for each row execute function public.set_updated_at();

drop trigger if exists requests_set_updated_at on public.borrow_requests;
create trigger requests_set_updated_at before update on public.borrow_requests
  for each row execute function public.set_updated_at();

-- Auto-create a profile row whenever a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'phone',
    'resident'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Residents may only cancel their own pending request; they must never
-- approve, release, return, or rewrite someone else's record.
create or replace function public.guard_borrow_request_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_is_official boolean;
begin
  v_is_official := public.is_official();
  if not v_is_official then
    if new.user_id <> old.user_id
       or new.asset_id <> old.asset_id
       or new.status <> 'cancelled'
       or old.status <> 'pending' then
      raise exception 'Residents may only cancel their own pending requests.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_borrow_request_update on public.borrow_requests;
create trigger guard_borrow_request_update
  before update on public.borrow_requests
  for each row execute function public.guard_borrow_request_update();

-- Only admins may promote/demote accounts.
create or replace function public.guard_profile_role()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_previous public.user_role;
begin
  select role into v_previous from public.profiles where id = new.id;
  if new.role is distinct from v_previous and not public.is_admin() then
    raise exception 'Only administrators can change user roles.';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_profile_role on public.profiles;
create trigger guard_profile_role
  before update on public.profiles
  for each row execute function public.guard_profile_role();

-- Keep asset.status in sync with the request lifecycle.
create or replace function public.sync_asset_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.status in ('approved', 'released') then
      update public.assets set status = 'reserved'
       where id = new.asset_id and status = 'available';
    end if;
  else
    if new.status = 'approved' then
      update public.assets set status = 'reserved'
       where id = new.asset_id and status = 'available';
    elsif new.status = 'released' then
      update public.assets set status = 'borrowed' where id = new.asset_id;
    elsif new.status in ('returned', 'declined', 'cancelled') then
      update public.assets set status = 'available'
       where id = new.asset_id and status in ('reserved', 'borrowed');
    end if;

    if new.status = 'returned' and new.return_condition is not null then
      update public.assets set condition = new.return_condition where id = new.asset_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists sync_asset_status_on_request on public.borrow_requests;
create trigger sync_asset_status_on_request
  after insert or update of status on public.borrow_requests
  for each row execute function public.sync_asset_status();

-- Human friendly reference number: BR-260119-0007
create or replace function public.set_request_reference()
returns trigger language plpgsql as $$
begin
  if new.reference_no is null or new.reference_no = '' then
    new.reference_no := 'BR-' || to_char(new.created_at, 'YYMMDD') || '-'
      || lpad(nextval('public.request_ref_seq')::text, 4, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists set_request_reference on public.borrow_requests;
create trigger set_request_reference
  before insert on public.borrow_requests
  for each row execute function public.set_request_reference();

-- ---------------------------------------------------------------------
-- 5. Row Level Security
-- ---------------------------------------------------------------------
alter table public.profiles         enable row level security;
alter table public.asset_categories enable row level security;
alter table public.assets           enable row level security;
alter table public.borrow_requests  enable row level security;

drop policy if exists "profiles are readable by signed in users" on public.profiles;
create policy "profiles are readable by signed in users"
  on public.profiles for select to authenticated using (true);

drop policy if exists "users update their own profile" on public.profiles;
create policy "users update their own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "officials manage profiles" on public.profiles;
create policy "officials manage profiles"
  on public.profiles for update to authenticated
  using (public.is_official()) with check (public.is_official());

drop policy if exists "categories readable by signed in users" on public.asset_categories;
create policy "categories readable by signed in users"
  on public.asset_categories for select to authenticated using (true);

drop policy if exists "admins manage categories" on public.asset_categories;
create policy "admins manage categories"
  on public.asset_categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "assets readable by signed in users" on public.assets;
create policy "assets readable by signed in users"
  on public.assets for select to authenticated using (true);

drop policy if exists "officials manage assets" on public.assets;
create policy "officials manage assets"
  on public.assets for all to authenticated
  using (public.is_official()) with check (public.is_official());

drop policy if exists "requests visible to owner or official" on public.borrow_requests;
create policy "requests visible to owner or official"
  on public.borrow_requests for select to authenticated
  using (user_id = auth.uid() or public.is_official());

drop policy if exists "residents create their own requests" on public.borrow_requests;
create policy "residents create their own requests"
  on public.borrow_requests for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "owners or officials update requests" on public.borrow_requests;
create policy "owners or officials update requests"
  on public.borrow_requests for update to authenticated
  using (user_id = auth.uid() or public.is_official())
  with check (user_id = auth.uid() or public.is_official());

-- ---------------------------------------------------------------------
-- 6. Storage bucket for asset photos
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('asset-photos', 'asset-photos', true)
on conflict (id) do nothing;

drop policy if exists "asset photos are public" on storage.objects;
create policy "asset photos are public"
  on storage.objects for select using (bucket_id = 'asset-photos');

drop policy if exists "officials upload asset photos" on storage.objects;
create policy "officials upload asset photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'asset-photos' and public.is_official());

drop policy if exists "officials delete asset photos" on storage.objects;
create policy "officials delete asset photos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'asset-photos' and public.is_official());

-- ---------------------------------------------------------------------
-- 7. Grants
-- ---------------------------------------------------------------------
grant execute on function public.check_asset_availability(uuid, date, date) to authenticated;
grant execute on function public.refresh_overdue_requests() to authenticated;