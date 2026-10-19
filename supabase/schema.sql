-- =====================================================================
-- Barangay Borrow Tracker — Supabase (Postgres) schema
-- ---------------------------------------------------------------------
-- Run with:   Supabase Dashboard > SQL Editor > paste > Run
--       or:   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/schema.sql
--
-- The whole file is a single transaction: the entire security model
-- lands, or none of it does. Re-running is safe — enums are guarded
-- against duplicates, tables use IF NOT EXISTS, and every function /
-- trigger / policy is dropped and recreated.
--
-- ---------------------------------------------------------------------
-- THE SECURITY MODEL IN ONE PARAGRAPH
-- ---------------------------------------------------------------------
-- Roles are data, not code. A signed-in user has exactly one row in
-- `public.profiles` (created for them by a trigger, never by them),
-- and every policy asks "what is that row's role?" through the helper
-- functions in section 4. Those helpers are SECURITY DEFINER on
-- purpose: a policy that read `profiles.role` directly would recurse
-- into the profiles policy, so the helper runs as the table owner and
-- sidesteps RLS exactly once, at the door.
--
-- Three rules hold everywhere in this file:
--   1. A client never decides who it is. `role` and `account_status`
--      can only be written by an admin (profiles policies + insert
--      trigger). A resident can create their own profile row, but the
--      WITH CHECK and the BEFORE INSERT trigger both clamp it to
--      ('resident', 'pending').
--   2. A client never decides whether an asset is free. Scheduling is
--      decided by the database: `bookings_no_overlapping_confirmed`
--      is an EXCLUDE constraint, so two overlapping confirmed
--      bookings physically cannot coexist regardless of what any
--      client sends. `approve_booking()` adds a row lock, a state
--      check and a friendly conflict message on top of it so that the
--      person tapping "Approve" gets an explanation instead of an
--      SQLSTATE.
--   3. A client never writes history. `audit_logs` has no INSERT
--      policy at all (rows come from triggers and SECURITY DEFINER
--      functions) and is append-only by trigger — UPDATE and DELETE
--      raise, even for the table owner.
--
-- Anything the client *does* do directly (inserting a booking,
-- cancelling one, flagging a notification read) is allowed only
-- through an RLS policy that pins the fields a given actor may touch,
-- and every state change is then re-validated by the
-- `booking_status_transition` trigger.
--
-- Column names are snake_case and identical to the field names the
-- Flutter client reads off the wire.
-- =====================================================================

begin;

-- =====================================================================
-- 0. Extensions
-- ---------------------------------------------------------------------
-- pgcrypto     -> gen_random_uuid() for row ids.
-- btree_gist   -> lets the exclusion constraint below combine a plain
--                 uuid equality (`asset_id with =`) with a range
--                 overlap (`tstzrange(...) with &&`). Without this,
--                 GiST cannot index uuid at all and the concurrency
--                 guarantee below would be impossible.
create extension if not exists pgcrypto;
create extension if not exists btree_gist;

-- =====================================================================
-- 1. Enumerated types
-- ---------------------------------------------------------------------
-- These are the wire values the app parses. Renaming a label is safe;
-- renaming a value orphans existing rows, so treat them as a public
-- contract. Each creation is wrapped so the script is re-runnable.
do $$ begin
  create type public.user_role as enum ('admin', 'staff', 'approver', 'resident');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.account_status as enum ('pending', 'active', 'suspended');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.asset_category as enum
    ('vehicle', 'facility', 'equipment', 'furniture', 'shelter', 'electronics', 'power', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.asset_status as enum
    ('available', 'reserved', 'borrowed', 'maintenance', 'retired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.asset_condition as enum
    ('good', 'serviceable', 'minor_damage', 'major_damage', 'missing_items');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.booking_status as enum
    ('pending', 'approved', 'rejected', 'cancelled', 'released', 'returned', 'overdue', 'completed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.booking_type as enum ('reservation', 'borrow', 'event');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.maintenance_status as enum ('open', 'in_progress', 'resolved');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.notification_type as enum
    ('request_submitted', 'request_approved', 'request_rejected', 'reservation_approaching',
     'return_due_soon', 'overdue_return', 'asset_returned', 'maintenance_alert');
exception when duplicate_object then null; end $$;

-- =====================================================================
-- 2. Tables
-- =====================================================================

-- ---------------------------------------------------------------------
-- profiles — one row per auth user.
-- The id IS the auth.users id, so `auth.uid()` can be compared with it
-- directly in every policy and no joins are needed to answer "is this
-- me?".
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  full_name      text,
  email          text,
  phone_number   text,
  role           public.user_role       not null default 'resident',
  account_status public.account_status  not null default 'pending',
  barangay       text,
  purok          text,
  created_at     timestamptz           not null default now(),
  -- The client sends updated_at when a resident edits their own contact
  -- details, so the column has to exist or PostgREST rejects the whole
  -- update. Kept honest by set_updated_at() below like assets.
  updated_at     timestamptz           not null default now()
);

-- ---------------------------------------------------------------------
-- assets — the catalogue.
-- `archived_at` is a soft delete: rows are never destroyed, they stop
-- being reservable and stop being visible to anyone but an admin.
-- `qr_code_value` is unique so a printed QR label maps to exactly one
-- asset (unique allows many NULLs, which is what we want for assets
-- that have not been labelled yet).
-- ---------------------------------------------------------------------
create table if not exists public.assets (
  id               uuid primary key default gen_random_uuid(),
  asset_code       text not null unique,
  name             text not null,
  category         public.asset_category,
  description      text,
  image_urls       text[] not null default '{}',
  location         text,
  quantity         integer not null default 1,
  condition        public.asset_condition default 'good',
  status           public.asset_status    default 'available',
  plate_number     text,
  qr_code_value    text unique,
  maintenance_note text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  archived_at      timestamptz,
  -- An asset always exists in at least one piece.
  constraint assets_quantity_at_least_one check (quantity >= 1)
);

-- ---------------------------------------------------------------------
-- bookings — requests, reservations and event bookings, one lifecycle.
-- `request_id` is the human reference printed on the paper form
-- (BR-260119-0007); the client may supply it and a trigger fills in a
-- generated one if it does not.
-- The asset FK is ON DELETE RESTRICT on purpose: an asset that has
-- been borrowed has history, and deleting it would orphan the custody
-- trail. Retire it instead (status = 'retired' / archived_at).
-- ---------------------------------------------------------------------
create table if not exists public.bookings (
  id                     uuid primary key default gen_random_uuid(),
  request_id             text not null unique,
  asset_id               uuid references public.assets   (id) on delete restrict,
  borrower_id            uuid references public.profiles (id) on delete set null,
  booking_type           public.booking_type default 'borrow',
  purpose                text not null,
  start_time             timestamptz not null,
  end_time               timestamptz not null,
  expected_return_time   timestamptz not null,
  authorized_driver_id   uuid references public.profiles (id) on delete set null,
  authorized_driver_name text,
  status                 public.booking_status default 'pending',
  submitted_at           timestamptz not null default now(),
  approved_by            uuid references public.profiles (id) on delete set null,
  approved_at            timestamptz,
  rejection_reason       text,
  notes                  text,
  document_urls          text[] not null default '{}',
  cancelled_at           timestamptz,
  cancelled_by           uuid references public.profiles (id) on delete set null,
  released_at            timestamptz,
  returned_at            timestamptz,
  -- A request that ends before it starts is a bug at the source, and
  -- catching it here beats catching it in a tstzrange overlap query.
  constraint bookings_end_after_start check (end_time > start_time)
);

-- ---------------------------------------------------------------------
-- transactions — the custody record: what went out, what came back.
-- One row per booking (`booking_id` is UNIQUE), so a release can never
-- be double-booked even if a retry slips past the status guard.
-- `flagged_for_inspection` is computed inside return_asset() from the
-- reported condition: the follow-up belongs to the record, not to
-- whoever happens to be looking at the screen.
-- ---------------------------------------------------------------------
create table if not exists public.transactions (
  id                   uuid primary key default gen_random_uuid(),
  booking_id           uuid unique references public.bookings (id) on delete cascade,
  asset_id             uuid references public.assets   (id) on delete restrict,
  borrower_id          uuid references public.profiles (id) on delete set null,
  released_by          uuid references public.profiles (id) on delete set null,
  released_at          timestamptz not null default now(),
  initial_condition    public.asset_condition,
  initial_notes        text,
  included_items       text[] not null default '{}',
  release_photo_urls   text[] not null default '{}',
  returned_to          uuid references public.profiles (id) on delete set null,
  returned_at          timestamptz,
  return_condition     public.asset_condition,
  damage_notes         text,
  missing_items        text,
  return_notes         text,
  return_photo_urls    text[] not null default '{}',
  -- free text on purpose: 'open' | 'closed' | 'flagged' today, and
  -- whoever inherits this database is allowed to add a value.
  return_status        text not null default 'open',
  flagged_for_inspection boolean not null default false,
  created_at           timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- notifications — one row per message. No INSERT policy exists for
-- clients: notifications are produced by the workflow functions and by
-- scheduled jobs, so a user cannot forge "your request was approved".
-- ---------------------------------------------------------------------
create table if not exists public.notifications (
  id                uuid primary key default gen_random_uuid(),
  recipient_id      uuid references public.profiles (id) on delete cascade,
  title             text not null,
  message           text,
  related_record_id uuid,
  related_type      text,
  type              public.notification_type not null,
  read_at           timestamptz,
  created_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- audit_logs — append-only. "timestamp" is the column name the client
-- reads; it is qualified everywhere it is referenced so the parser can
-- never confuse it with the timestamptz type.
-- Written only by triggers and SECURITY DEFINER functions.
-- ---------------------------------------------------------------------
create table if not exists public.audit_logs (
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references public.profiles (id) on delete set null,
  action      text not null,
  entity_type text not null,
  entity_id   uuid,
  details     jsonb not null default '{}'::jsonb,
  timestamp   timestamptz not null default now()
);

comment on table public.audit_logs is
  'Append-only history. No INSERT policy exists for clients (rows come from triggers and SECURITY DEFINER functions); UPDATE and DELETE raise an exception from a trigger.';

-- ---------------------------------------------------------------------
-- maintenance_records — defects. An open record is what keeps an asset
-- out of circulation (see refresh_asset_status()).
-- ---------------------------------------------------------------------
create table if not exists public.maintenance_records (
  id                uuid primary key default gen_random_uuid(),
  asset_id          uuid references public.assets   (id) on delete cascade,
  issue_description text not null,
  status            public.maintenance_status default 'open',
  reported_at       timestamptz not null default now(),
  resolved_at       timestamptz,
  reported_by       uuid references public.profiles (id) on delete set null,
  resolution_notes  text
);

-- =====================================================================
-- 3. Constraints and indexes
-- =====================================================================

-- ---------------------------------------------------------------------
-- The real concurrency guarantee.
--
-- Two confirmed bookings for the same asset may not overlap in time.
-- '[)' means a booking that ends exactly when the next one starts is
-- NOT a conflict — handover at 12:00 is normal. The predicate keeps
-- the constraint off rows that are not confirmed yet, so a resident
-- may have several pending requests for the same dates; only approved
-- / released / overdue rows block each other.
--
-- This is enforced by the index, not by application code: two
-- sessions trying to confirm overlapping bookings serialise here and
-- the loser gets SQLSTATE 23P01. approve_booking() catches that and
-- re-raises it as a message a barangay official can act on.
-- ---------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_constraint where conname = 'bookings_no_overlapping_confirmed'
  ) then
    alter table public.bookings
      add constraint bookings_no_overlapping_confirmed
      exclude using gist (
        asset_id with =,
        tstzrange(start_time, end_time, '[)') with &&
      )
      where (status in ('approved', 'released', 'overdue'));
  end if;
end $$;

comment on constraint bookings_no_overlapping_confirmed on public.bookings is
  'GiST exclusion constraint: one asset cannot be confirmed for two overlapping time ranges. This is the authoritative double-booking guard.';

-- Calendar queries: "everything for this asset between these dates".
create index if not exists bookings_asset_time_idx
  on public.bookings (asset_id, start_time, end_time);

-- "My requests", newest first.
create index if not exists bookings_borrower_idx
  on public.bookings (borrower_id);

-- Approval queues and dashboard counters.
create index if not exists bookings_status_idx
  on public.bookings (status);

-- The overdue sweep reads exactly this shape.
create index if not exists bookings_open_by_due_idx
  on public.bookings (expected_return_time)
  where status in ('released', 'overdue');

-- Catalogue filters.
create index if not exists assets_category_idx on public.assets (category);
create index if not exists assets_status_idx   on public.assets (status);
-- Archived rows are excluded from every public listing; keep that hot
-- path small.
create index if not exists assets_live_idx
  on public.assets (created_at desc)
  where archived_at is null;

create index if not exists transactions_asset_idx    on public.transactions (asset_id);
create index if not exists transactions_borrower_idx on public.transactions (borrower_id);
-- "What has not come back yet" is the query every officer screen runs.
create index if not exists transactions_open_idx
  on public.transactions (released_at desc)
  where returned_at is null;

create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, read_at);
create index if not exists notifications_unread_idx
  on public.notifications (recipient_id, created_at desc)
  where read_at is null;

create index if not exists audit_logs_timestamp_idx on public.audit_logs (timestamp desc);
create index if not exists audit_logs_entity_idx    on public.audit_logs (entity_type, entity_id);

create index if not exists maintenance_asset_idx
  on public.maintenance_records (asset_id)
  where status <> 'resolved';

-- =====================================================================
-- 4. Role helpers (SECURITY DEFINER so RLS cannot recurse)
-- ---------------------------------------------------------------------
-- Why SECURITY DEFINER: the profiles policies call is_admin(), and
-- is_admin() reads profiles.role. If the helper ran as the caller, the
-- database would have to evaluate the profiles policy again from
-- inside itself — infinite recursion. Running as the owner means the
-- lookup happens once, with RLS bypassed, and returns a single value
-- that policies can compare cheaply.
--
-- Why `stable`: the role cannot change inside a statement, and telling
-- Postgres so lets it evaluate the helper once per query.
--
-- Why `set search_path = public`: a SECURITY DEFINER function must not
-- inherit the caller's search_path, or a caller could shadow `auth`
-- or a table name with their own object and run code as the owner.

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select p.role from public.profiles p where p.id = auth.uid();
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

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'staff', false);
$$;

create or replace function public.is_approver()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'approver', false);
$$;

-- Officers hand assets over and take them back; approvers decide who
-- gets what. Distinct duties, deliberately: an approver cannot release.
create or replace function public.is_officer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() in ('admin', 'staff'), false);
$$;

-- =====================================================================
-- 5. Trigger functions
-- =====================================================================

-- ---------------------------------------------------------------------
-- Keep assets.updated_at honest without trusting the client.
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists assets_set_updated_at on public.assets;
create trigger assets_set_updated_at
  before update on public.assets
  for each row execute function public.set_updated_at();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- NEW USER GUARD.
--
-- A profile row can be inserted by its owner (the client does this
-- straight after sign-up), but it can never be inserted *as* anything
-- other than a pending resident:
--   * the RLS WITH CHECK on profiles already refuses any other value,
--   * this trigger rewrites the two columns anyway, so the rule also
--     holds for privileged sessions (dashboard inserts, admin tools,
--     service_role).
-- The email is copied from auth.users — the client cannot claim an
-- email that is not the one it authenticated with.
--
-- SECURITY DEFINER is required: when a profile is created from the
-- auth.users trigger there is no signed-in caller at all, so RLS would
-- otherwise reject the insert.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email      text;
  v_full_name  text;
begin
  -- Never self-assign privilege or an active account.
  new.role           := 'resident';
  new.account_status := 'pending';

  -- Take identity from auth.users, not from the payload.
  if to_regclass('auth.users') is not null then
    select u.email,
           u.raw_user_meta_data ->> 'full_name'
      into v_email, v_full_name
      from auth.users u
     where u.id = new.id;
  end if;

  if new.email is null or btrim(new.email) = '' then
    new.email := v_email;
  end if;

  if new.full_name is null or btrim(new.full_name) = '' then
    new.full_name := coalesce(v_full_name, split_part(coalesce(v_email, ''), '@', 1));
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_before_insert_guard on public.profiles;
create trigger profiles_before_insert_guard
  before insert on public.profiles
  for each row execute function public.handle_new_profile();

-- Optional convenience: create the profile automatically at sign-up so
-- a client that forgets to call it still gets a row (and still gets a
-- pending resident, because of the trigger above). Wrapped because the
-- function only exists on Supabase, where auth.users is present and
-- owned by postgres.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, phone_number)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(coalesce(new.email, ''), '@', 1)),
    new.email,
    new.raw_user_meta_data ->> 'phone_number'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

do $$
begin
  if to_regclass('auth.users') is not null then
    -- An inner block so a permissions failure on auth.users does not
    -- abort the whole schema: warn and carry on.
    begin
      drop trigger if exists on_auth_user_created on auth.users;
      create trigger on_auth_user_created
        after insert on auth.users
        for each row execute function public.handle_new_user();
    exception when others then
      raise notice 'Skipped the auth.users trigger: %', sqlerrm;
    end;
  else
    raise notice 'auth.users not found — skipping the on_auth_user_created trigger.';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Reference numbers.
-- The client normally sends its own request_id; when it does not, the
-- database still has to satisfy the NOT NULL + UNIQUE pair, so a
-- readable one is generated: BR-YYMMDD-XXXXXX.
-- ---------------------------------------------------------------------
create or replace function public.default_request_id()
returns trigger
language plpgsql
as $$
begin
  if new.request_id is null or btrim(new.request_id) = '' then
    new.request_id := 'BR-' || to_char(now(), 'YYMMDD') || '-'
                     || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_before_insert_request_id on public.bookings;
create trigger bookings_before_insert_request_id
  before insert on public.bookings
  for each row execute function public.default_request_id();

-- ---------------------------------------------------------------------
-- PRIVILEGE ESCALATION GUARD (profiles).
--
-- RLS decides *which rows* a caller may touch. It cannot decide *which
-- columns* they may change, because a policy's WITH CHECK expression is
-- evaluated against the proposed NEW row and has no view of the row it
-- is replacing. So the rule "a user may edit their own profile but may
-- not edit their own role" is split in two:
--
--     profiles_update_self_or_admin  ->  you may UPDATE your row
--     guard_profile_privilege_change ->  but role and account_status are
--                                        immutable unless you are an admin
--
-- The trigger is the belt to the policy's braces: it also protects the
-- SECURITY DEFINER paths and the database owner, which RLS by design
-- does not constrain.
--
-- session_user, not current_user: inside a SECURITY DEFINER function
-- current_user is the *owner* (postgres), which would make this trigger
-- a no-op. session_user is the role that actually logged in, which is
-- `postgres` for the SQL editor / migrations (that is how the very
-- first admin is bootstrapped) and `authenticator` for the API.
-- ---------------------------------------------------------------------
create or replace function public.guard_profile_privilege_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Nothing privileged changed: allow.
  if new.role is not distinct from old.role
     and new.account_status is not distinct from old.account_status then
    return new;
  end if;

  if session_user = 'postgres' or public.is_admin() then
    return new;
  end if;

  raise exception
    'Only an administrator can change a role or an account status.'
    using errcode = 'insufficient_privilege';
end;
$$;

drop trigger if exists profiles_guard_privilege_change on public.profiles;
create trigger profiles_guard_privilege_change
  before update on public.profiles
  for each row execute function public.guard_profile_privilege_change();

-- ---------------------------------------------------------------------
-- BORROWER UPDATE GUARD (bookings).
--
-- Same division of labour as above: the RLS policy on bookings limits
-- the borrower to their own row, and this trigger limits what they may
-- *do* to it — withdraw it, and nothing else, and only while it has not
-- been handed over.
--
-- Officers and approvers pass through untouched (the state machine
-- trigger and the RPCs govern them), as does the database owner.
-- ---------------------------------------------------------------------
create or replace function public.guard_booking_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Reviewers and officers: governed by the transition trigger.
  if public.is_officer() or public.is_approver() or session_user = 'postgres' then
    return new;
  end if;

  -- A borrower may not re-point or re-time their own request.
  if new.borrower_id          is distinct from old.borrower_id
     or new.asset_id          is distinct from old.asset_id
     or new.start_time        is distinct from old.start_time
     or new.end_time          is distinct from old.end_time
     or new.expected_return_time is distinct from old.expected_return_time then
    raise exception 'A submitted request cannot be reassigned or re-timed.'
      using errcode = 'insufficient_privilege';
  end if;

  -- The only thing left they may do is withdraw it, and only while it
  -- has not been actioned or released.
  if new.status = 'cancelled' and old.status in ('pending', 'approved') then
    return new;
  end if;

  raise exception
    'You may only withdraw your own request, and only before it is released.'
    using errcode = 'insufficient_privilege';
end;
$$;

drop trigger if exists bookings_guard_borrower_update on public.bookings;
create trigger bookings_guard_borrower_update
  before update on public.bookings
  for each row execute function public.guard_booking_update();

-- ---------------------------------------------------------------------
-- THE STATE MACHINE.
--
--   pending   -> approved | rejected | cancelled
--   approved  -> released | cancelled | overdue
--   released  -> returned | overdue
--   overdue   -> returned
--   returned  -> completed
--   rejected | cancelled | completed -> terminal
--
-- This is the database copy of the rule the app also draws on screen.
-- The app's copy is a courtesy; this one is the control: a stale or
-- tampered client cannot approve a rejected request, resurrect a
-- cancelled one, or jump straight to 'completed' and skip the
-- custody record.
--
-- The trigger also stamps the bookkeeping columns (who decided, when
-- it was cancelled, when it went out) so those fields cannot be
-- forged by an UPDATE that does not go through the RPCs.
-- ---------------------------------------------------------------------
create or replace function public.validate_booking_status_transition()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_allowed text;
begin
  -- Nothing to validate when the status did not move.
  if new.status is not distinct from old.status then
    return new;
  end if;

  -- Stamp, never trust: these columns are evidence.
  if new.status in ('approved', 'rejected') and new.approved_by is null then
    new.approved_by := auth.uid();
    new.approved_at := now();
  end if;
  if new.status = 'cancelled' and new.cancelled_at is null then
    new.cancelled_at := now();
    new.cancelled_by := auth.uid();
  end if;
  if new.status = 'released' and new.released_at is null then
    new.released_at := now();
  end if;
  if new.status = 'returned' and new.returned_at is null then
    new.returned_at := now();
  end if;

  v_allowed := case old.status
    when 'pending'  then 'approved, rejected, cancelled'
    when 'approved' then 'released, cancelled, overdue'
    when 'released' then 'returned, overdue'
    when 'overdue'  then 'returned'
    when 'returned' then 'completed'
    else 'nothing — this is a terminal state'
  end;

  if not (
       (old.status = 'pending'  and new.status in ('approved', 'rejected', 'cancelled'))
    or (old.status = 'approved' and new.status in ('released', 'cancelled', 'overdue'))
    or (old.status = 'released' and new.status in ('returned', 'overdue'))
    or (old.status = 'overdue'  and new.status = 'returned')
    or (old.status = 'returned' and new.status = 'completed')
  ) then
    raise exception
      'Illegal booking status transition: % -> %. A booking that is % may only move to: %.',
      old.status, new.status, old.status, v_allowed
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_status_transition_guard on public.bookings;
create trigger bookings_status_transition_guard
  before update of status on public.bookings
  for each row execute function public.validate_booking_status_transition();

-- ---------------------------------------------------------------------
-- AUDIT TRAIL.
--
-- Every booking that is created or changes status is written to
-- audit_logs together with the actor and the before/after values.
-- It fires for direct table UPDATEs too (an officer using a generic
-- SQL client, a migration, the admin dashboard), so the trail cannot
-- be bypassed by going around the RPCs — the RPCs add a *decision*
-- row on top of this mechanical one, with the reason attached.
-- ---------------------------------------------------------------------
create or replace function public.audit_booking_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      'booking.created',
      'booking',
      new.id,
      jsonb_build_object(
        'request_id',  new.request_id,
        'to',          new.status,
        'booking_type', new.booking_type,
        'asset_id',    new.asset_id,
        'borrower_id', new.borrower_id,
        'start_time',  new.start_time,
        'end_time',    new.end_time
      )
    );
  elsif new.status is distinct from old.status then
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      'booking.status_changed',
      'booking',
      new.id,
      jsonb_build_object(
        'request_id',  new.request_id,
        'from',        old.status,
        'to',          new.status,
        'booking_type', new.booking_type,
        'asset_id',    new.asset_id,
        'borrower_id', new.borrower_id,
        'rejection_reason', new.rejection_reason
      )
    );
  end if;
  return null;
end;
$$;

drop trigger if exists bookings_audit on public.bookings;
create trigger bookings_audit
  after insert or update on public.bookings
  for each row execute function public.audit_booking_change();

-- Archiving an asset is a governance action, so it is logged.
create or replace function public.audit_asset_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.archived_at is distinct from old.archived_at then
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      case when new.archived_at is null then 'asset.restored' else 'asset.archived' end,
      'asset',
      new.id,
      jsonb_build_object('asset_code', new.asset_code, 'archived_at', new.archived_at)
    );
  elsif new.status is distinct from old.status then
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      'asset.status_changed',
      'asset',
      new.id,
      jsonb_build_object('asset_code', new.asset_code, 'from', old.status, 'to', new.status)
    );
  end if;
  return null;
end;
$$;

drop trigger if exists assets_audit on public.assets;
create trigger assets_audit
  after update on public.assets
  for each row execute function public.audit_asset_change();

-- ---------------------------------------------------------------------
-- APPEND-ONLY.
-- There is no UPDATE or DELETE policy on audit_logs, so RLS already
-- blocks clients. This trigger blocks everyone else, including the
-- owner and service_role: a table that claims to be a history cannot
-- be edited by accident or by a well-meaning cleanup script.
-- =====================================================================
create or replace function public.audit_logs_append_only()
returns trigger
language plpgsql
as $$
begin
  raise exception 'audit_logs is append-only; % is not permitted.', tg_op
    using errcode = 'insufficient_privilege';
end;
$$;

drop trigger if exists audit_logs_no_mutation on public.audit_logs;
create trigger audit_logs_no_mutation
  before update or delete on public.audit_logs
  for each row execute function public.audit_logs_append_only();

-- ---------------------------------------------------------------------
-- Asset availability is derived, not typed in by hand.
--
-- Refresh recomputes an asset's status from the bookings that exist for
-- it, in priority order: physically out > reserved > free.
--
-- 'maintenance' and 'retired' are deliberately sticky. Those two states
-- are set by a human decision (a defect report, a retirement), and a
-- routine status refresh must not quietly undo it — otherwise the
-- moment a borrower returns a broken asset, the sync would put it
-- straight back in the catalogue.
-- ---------------------------------------------------------------------
create or replace function public.refresh_asset_status(p_asset_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.asset_status;
begin
  if p_asset_id is null then
    return;
  end if;

  select a.status into v_status
    from public.assets a
   where a.id = p_asset_id;

  if not found or v_status in ('maintenance', 'retired') then
    return;
  end if;

  update public.assets a
     set status = case
          when exists (select 1 from public.bookings b
                        where b.asset_id = a.id and b.status in ('released', 'overdue'))
            then 'borrowed'::public.asset_status
          when exists (select 1 from public.bookings b
                        where b.asset_id = a.id and b.status = 'approved')
            then 'reserved'::public.asset_status
          else 'available'::public.asset_status
        end
   where a.id = p_asset_id;
end;
$$;

-- One trigger, every path. approve_booking() also sets the status
-- explicitly, but this is what makes a *direct* cancel (which the app
-- does with a plain UPDATE) free the asset again.
create or replace function public.sync_asset_status_on_booking()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.refresh_asset_status(new.asset_id);
  if tg_op = 'UPDATE' and old.asset_id is distinct from new.asset_id then
    perform public.refresh_asset_status(old.asset_id);
  end if;
  return null;
end;
$$;

drop trigger if exists bookings_sync_asset_status on public.bookings;
create trigger bookings_sync_asset_status
  after insert or update of status on public.bookings
  for each row execute function public.sync_asset_status_on_booking();

-- ---------------------------------------------------------------------
-- Bookings rejected by staff are not garbage: queue them for the
-- approval officer instead of letting them silently vanish.
-- ---------------------------------------------------------------------
create or replace function public.notify_staff_of_pending_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications
    (recipient_id, title, message, related_record_id, related_type, type)
  select
    p.id,
    'New request ' || new.request_id,
    coalesce(new.purpose, 'A resident submitted a borrow request.'),
    new.id,
    'booking',
    'request_submitted'
  from public.profiles p
  where p.role in ('admin', 'approver')
    and p.account_status = 'active'
    and p.id is distinct from new.borrower_id;

  -- And tell the applicant it was received.
  if new.borrower_id is not null then
    insert into public.notifications
      (recipient_id, title, message, related_record_id, related_type, type)
    values
      (new.borrower_id,
       'Request received — ' || new.request_id,
       'Your request has been submitted and is waiting for review.',
       new.id, 'booking', 'request_submitted');
  end if;

  return null;
end;
$$;

drop trigger if exists bookings_notify on public.bookings;
create trigger bookings_notify
  after insert on public.bookings
  for each row execute function public.notify_staff_of_pending_request();

-- ---------------------------------------------------------------------
-- Resolving a defect should record *when* it was resolved even if the
-- officer forgets the field.
-- ---------------------------------------------------------------------
create or replace function public.stamp_maintenance_resolution()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'resolved' and new.resolved_at is null then
    new.resolved_at := now();
  end if;
  if new.status <> 'resolved' then
    new.resolved_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists maintenance_stamp_resolution on public.maintenance_records;
create trigger maintenance_stamp_resolution
  before update on public.maintenance_records
  for each row execute function public.stamp_maintenance_resolution();

-- =====================================================================
-- 6. Workflow functions (the only doors into a state change)
-- =====================================================================
-- All of these are SECURITY DEFINER: the caller passes an RLS check
-- inside the function body, and the function then writes with the
-- owner's rights. That is deliberate and is the only reason these
-- functions are safe — so each one re-checks authorisation itself
-- rather than trusting the caller.

-- ---------------------------------------------------------------------
-- approve_booking — the concurrency-safe approval.
--
-- Sequence, and why each step is there:
--   1. authorisation      — admins and approvers only. Checked inside
--                           the function because SECURITY DEFINER
--                           would otherwise hand us the owner's rights
--                           to anyone who can EXECUTE.
--   2. SELECT ... FOR UPDATE — takes a row lock on THIS booking and
--                           holds it to the end of the transaction.
--                           Two officers tapping Approve at the same
--                           instant: the first commits, the second
--                           wakes up holding the *new* row (READ
--                           COMMITTED re-reads it), sees 'approved' at
--                           step 3 and fails cleanly instead of
--                           double-booking.
--   3. state check        — only 'pending' may become 'approved'.
--   4. overlap re-check   — the friendly version of the exclusion
--                           constraint, run under the same lock so it
--                           cannot see a stale view.
--   5. update + audit + notify + reserve the asset.
-- ---------------------------------------------------------------------
create or replace function public.approve_booking(
  p_booking_id uuid,
  p_reason    text default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking  public.bookings;
  v_conflict public.bookings;
begin
  -- 1. Who is asking?
  if not (public.is_admin() or public.is_approver()) then
    raise exception 'Only an approver or an administrator can approve a request.'
      using errcode = 'insufficient_privilege';
  end if;

  -- 2. Lock the row. Everything below is now serialised per booking.
  select b.* into v_booking
    from public.bookings b
   where b.id = p_booking_id
     for update;

  if not found then
    raise exception 'Request not found.' using errcode = 'no_data_found';
  end if;

  -- 3. Is it still awaiting a decision?
  if v_booking.status <> 'pending' then
    raise exception 'This request is already % and can no longer be approved.', v_booking.status;
  end if;

  -- 4. Is the asset actually free for that window? (this function is
  --    the racing path; this check is what produces the message a
  --    human can act on.)
  select b.* into v_conflict
    from public.bookings b
   where b.asset_id = v_booking.asset_id
     and b.id is distinct from v_booking.id
     and b.status in ('approved', 'released', 'overdue')
     and tstzrange(b.start_time, b.end_time, '[)')
      && tstzrange(v_booking.start_time, v_booking.end_time, '[)')
   limit 1;

  if found then
    raise exception 'This asset is already reserved for that time.';
  end if;

  -- 5. Write it. The UPDATE may still lose a race against a *different*
  --    booking (two overlapping pending requests approved on two
  --    devices), and then the exclusion constraint fires; translate
  --    23P01 into the same human message instead of leaking SQLSTATE.
  begin
    update public.bookings b
       set status      = 'approved',
           approved_by = auth.uid(),
           approved_at = now(),
           -- The officer's optional note only fills a blank left by the
           -- applicant; it never overwrites what the resident wrote.
           notes       = coalesce(b.notes, p_reason)
     where b.id = p_booking_id
     returning b.* into v_booking;
  exception when exclusion_violation then
    raise exception 'This asset is already reserved for that time.';
  end;

  -- Reserve the asset (the trigger below also does this; being
  -- explicit keeps the function readable on its own).
  update public.assets a
     set status = 'reserved'
   where a.id = v_booking.asset_id
     and a.status = 'available';

  -- Decision trail, with the reason.
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'booking.approved', 'booking', v_booking.id,
    jsonb_build_object(
      'request_id', v_booking.request_id,
      'from',       'pending',
      'to',         'approved',
      'reason',     p_reason,
      'asset_id',   v_booking.asset_id,
      'borrower_id', v_booking.borrower_id
    )
  );

  if v_booking.borrower_id is not null then
    insert into public.notifications
      (recipient_id, title, message, related_record_id, related_type, type)
    values (
      v_booking.borrower_id,
      'Approved — ' || v_booking.request_id,
      coalesce('Your request was approved. ' || p_reason,
               'Your request was approved. See you at the release counter.'),
      v_booking.id, 'booking', 'request_approved'
    );
  end if;

  return v_booking;
end;
$$;

-- ---------------------------------------------------------------------
-- reject_booking — same locking discipline as approve_booking.
-- p_reason is NOT optional: a rejection a resident cannot understand
-- is not a decision, it is a dismissal.
-- ---------------------------------------------------------------------
create or replace function public.reject_booking(
  p_booking_id uuid,
  p_reason    text
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
begin
  if not (public.is_admin() or public.is_approver()) then
    raise exception 'Only an approver or an administrator can reject a request.'
      using errcode = 'insufficient_privilege';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to reject a request.';
  end if;

  select b.* into v_booking
    from public.bookings b
   where b.id = p_booking_id
     for update;

  if not found then
    raise exception 'Request not found.' using errcode = 'no_data_found';
  end if;

  if v_booking.status <> 'pending' then
    raise exception 'This request is already % and can no longer be rejected.', v_booking.status;
  end if;

  update public.bookings b
     set status           = 'rejected',
         rejection_reason = btrim(p_reason),
         -- approved_by/approved_at double as "who decided, and when",
         -- so the UI can show the reviewer on any decision row.
         approved_by      = auth.uid(),
         approved_at      = now()
   where b.id = p_booking_id
   returning b.* into v_booking;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'booking.rejected', 'booking', v_booking.id,
    jsonb_build_object(
      'request_id', v_booking.request_id,
      'from',       'pending',
      'to',         'rejected',
      'reason',     p_reason,
      'asset_id',   v_booking.asset_id,
      'borrower_id', v_booking.borrower_id
    )
  );

  if v_booking.borrower_id is not null then
    insert into public.notifications
      (recipient_id, title, message, related_record_id, related_type, type)
    values (
      v_booking.borrower_id,
      'Not approved — ' || v_booking.request_id,
      p_reason,
      v_booking.id, 'booking', 'request_rejected'
    );
  end if;

  perform public.refresh_asset_status(v_booking.asset_id);

  return v_booking;
end;
$$;

-- ---------------------------------------------------------------------
-- release_asset — officers only (staff/admin, NOT approvers: signing
-- for an asset you approved is two jobs).
-- Creates the custody row and moves the booking to 'released'.
-- ---------------------------------------------------------------------
create or replace function public.release_asset(
  p_booking_id       uuid,
  p_initial_condition public.asset_condition,
  p_included_items   text[] default '{}',
  p_notes            text default null
)
returns public.transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
  v_tx      public.transactions;
begin
  if not public.is_officer() then
    raise exception 'Only a staff member or an administrator can release an asset.'
      using errcode = 'insufficient_privilege';
  end if;

  select b.* into v_booking
    from public.bookings b
   where b.id = p_booking_id
     for update;

  if not found then
    raise exception 'Request not found.' using errcode = 'no_data_found';
  end if;

  if v_booking.status <> 'approved' then
    raise exception 'Only an approved request can be released (this one is %).', v_booking.status;
  end if;

  insert into public.transactions
    (booking_id, asset_id, borrower_id, released_by, released_at,
     initial_condition, initial_notes, included_items)
  values
    (v_booking.id, v_booking.asset_id, v_booking.borrower_id, auth.uid(), now(),
     p_initial_condition, p_notes, coalesce(p_included_items, '{}'::text[]))
  returning * into v_tx;

  update public.bookings b
     set status = 'released'
   where b.id = p_booking_id;

  update public.assets a
     set status = 'borrowed'
   where a.id = v_booking.asset_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'asset.released', 'booking', v_booking.id,
    jsonb_build_object(
      'request_id',        v_booking.request_id,
      'asset_id',          v_booking.asset_id,
      'borrower_id',       v_booking.borrower_id,
      'transaction_id',    v_tx.id,
      'initial_condition', p_initial_condition,
      'included_items',    to_jsonb(coalesce(p_included_items, '{}'::text[]))
    )
  );

  return v_tx;
end;
$$;

-- ---------------------------------------------------------------------
-- return_asset — officers only.
--
-- The inspection flag is derived here, from the condition reported at
-- the counter, so "somebody has to remember to flag this" cannot fail:
--   minor_damage | major_damage | missing_items -> flagged_for_inspection
--   good | serviceable                         -> closed, no flag
-- ---------------------------------------------------------------------
create or replace function public.return_asset(
  p_booking_id      uuid,
  p_return_condition public.asset_condition,
  p_damage_notes    text default null,
  p_missing_items   text default null,
  p_notes           text default null,
  p_photo_urls      text[] default '{}'
)
returns public.transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
  v_tx      public.transactions;
  v_flag    boolean;
begin
  if not public.is_officer() then
    raise exception 'Only a staff member or an administrator can receive a returned asset.'
      using errcode = 'insufficient_privilege';
  end if;

  select b.* into v_booking
    from public.bookings b
   where b.id = p_booking_id
     for update;

  if not found then
    raise exception 'Request not found.' using errcode = 'no_data_found';
  end if;

  if v_booking.status not in ('released', 'overdue') then
    raise exception 'This asset is not out (the request is %).', v_booking.status;
  end if;

  v_flag := p_return_condition in ('minor_damage', 'major_damage', 'missing_items');

  update public.transactions t
     set returned_to           = auth.uid(),
         returned_at            = now(),
         return_condition       = p_return_condition,
         damage_notes           = p_damage_notes,
         missing_items          = p_missing_items,
         return_notes           = p_notes,
         return_photo_urls      = coalesce(p_photo_urls, '{}'::text[]),
         flagged_for_inspection = v_flag,
         return_status          = case when v_flag then 'flagged' else 'closed' end
   where t.booking_id = p_booking_id
   returning t.* into v_tx;

  if not found then
    raise exception 'No custody record found for this request. Release it before recording a return.';
  end if;

  update public.bookings b
     set status = 'returned'
   where b.id = p_booking_id;

  -- The catalogue should describe reality: record the condition the
  -- asset came back in. Its *status* is derived by the trigger (or set
  -- here) — available again, unless another confirmed booking or an
  -- open defect still holds it.
  update public.assets a
     set condition = p_return_condition
   where a.id = v_booking.asset_id;

  update public.assets a
     set status = 'available'
   where a.id = v_booking.asset_id
     and a.status = 'borrowed';

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'asset.returned', 'booking', v_booking.id,
    jsonb_build_object(
      'request_id',      v_booking.request_id,
      'asset_id',        v_booking.asset_id,
      'borrower_id',     v_booking.borrower_id,
      'transaction_id',  v_tx.id,
      'return_condition', p_return_condition,
      'damage_notes',    p_damage_notes,
      'missing_items',   p_missing_items,
      'flagged_for_inspection', v_flag
    )
  );

  if v_booking.borrower_id is not null then
    insert into public.notifications
      (recipient_id, title, message, related_record_id, related_type, type)
    values (
      v_booking.borrower_id,
      'Return recorded — ' || v_booking.request_id,
      case when v_flag
           then 'Thank you. Your return has been recorded and flagged for inspection.'
           else 'Thank you. Your return has been recorded.'
      end,
      v_booking.id, 'booking', 'asset_returned'
    );
  end if;

  -- Recompute last, so an open defect wins over "available".
  perform public.refresh_asset_status(v_booking.asset_id);

  return v_tx;
end;
$$;

-- ---------------------------------------------------------------------
-- mark_overdue_bookings — the clock. Without something driving it, a
-- booking past its due date would sit at 'released' forever and the
-- transition matrix's `released -> overdue` edge would be dead code.
--
-- Call it from a Supabase scheduled function (pg_cron / edge function
-- with the service key). It is idempotent: the WHERE clause only ever
-- matches rows that are genuinely out and genuinely late.
--
-- SECURITY DEFINER because a scheduled job may run without a user
-- session; it is granted to `authenticated` so it can also be called
-- from the app, but the statement it runs is bounded and harmless.
-- ---------------------------------------------------------------------
create or replace function public.mark_overdue_bookings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_affected integer := 0;
begin
  with flagged as (
    update public.bookings b
       set status = 'overdue'
     where b.status = 'released'
       and b.expected_return_time < now()
    returning b.id, b.borrower_id, b.request_id
  ),
  counted as (
    select count(*)::integer as n from flagged
  ),
  queued as (
    insert into public.notifications
      (recipient_id, title, message, related_record_id, related_type, type)
    select f.borrower_id,
           'Overdue — ' || f.request_id,
           'The asset borrowed under ' || f.request_id || ' is past its expected return time. Please return it at the barangay hall.',
           f.id, 'booking', 'overdue_return'
      from flagged f
     where f.borrower_id is not null
  )
  select c.n into v_affected from counted c;

  return v_affected;
end;
$$;

-- ---------------------------------------------------------------------
-- check_asset_availability — a courtesy check for the request form, so
-- a resident is told "already reserved" before they fill in ten fields.
-- It is NOT the control: a result of true guarantees nothing, because
-- anyone can approve a request between the check and the submit. The
-- exclusion constraint and approve_booking() are the control.
-- ---------------------------------------------------------------------
create or replace function public.check_asset_availability(
  p_asset_id uuid,
  p_start    timestamptz,
  p_end      timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
      from public.bookings b
     where b.asset_id = p_asset_id
       and b.status in ('approved', 'released', 'overdue')
       and tstzrange(b.start_time, b.end_time, '[)')
        && tstzrange(p_start, p_end, '[)')
  );
$$;

-- ---------------------------------------------------------------------
-- dashboard_summary — counts for the home screen, computed from real
-- rows, never cached in a column that can drift.
--
-- Note: this one is deliberately NOT security definer. Running as the
-- caller means RLS applies, so an officer sees the barangay's numbers
-- while a resident sees only their own requests. A definer version
-- would hand every signed-in user a global head count.
--
-- "upcoming_reservations" = approved bookings starting in the next 7
-- days; "overdue_returns" counts what is physically out past its due
-- time (status 'released' or 'overdue'), not merely what is flagged.
-- ---------------------------------------------------------------------
create or replace function public.dashboard_summary()
returns table (
  total_assets           bigint,
  available_assets       bigint,
  borrowed_assets        bigint,
  pending_requests       bigint,
  overdue_returns        bigint,
  upcoming_reservations  bigint,
  active_maintenance     bigint
)
language sql
stable
set search_path = public
as $$
  select
    (select count(*) from public.assets a
      where a.archived_at is null),

    (select count(*) from public.assets a
      where a.archived_at is null and a.status = 'available'),

    (select count(*) from public.assets a
      where a.archived_at is null and a.status = 'borrowed'),

    (select count(*) from public.bookings b
      where b.status = 'pending'),

    (select count(*) from public.bookings b
      where b.status in ('released', 'overdue')
        and b.expected_return_time < now()),

    (select count(*) from public.bookings b
      where b.status = 'approved'
        and b.start_time > now()
        and b.start_time <= now() + interval '7 days'),

    (select count(*) from public.maintenance_records m
      where m.status <> 'resolved');
$$;

-- =====================================================================
-- 7. Row Level Security
-- ---------------------------------------------------------------------
-- Every table is enabled, with no exceptions: a table with RLS enabled
-- and no policy is a table nobody can touch through the API, which is
-- exactly what audit_logs' write path wants.

alter table public.profiles           enable row level security;
alter table public.assets             enable row level security;
alter table public.bookings           enable row level security;
alter table public.transactions       enable row level security;
alter table public.notifications      enable row level security;
alter table public.audit_logs         enable row level security;
alter table public.maintenance_records enable row level security;

-- ---------------------------------------------------------------------
-- profiles
--   SELECT  your own row, or any row if you are an officer/approver
--          (approvers must be able to see who they are approving).
--   INSERT  your own row only, and only as a pending resident — the
--          WITH CHECK is what stops a public sign-up from POSTing
--          {"role": "admin"} and walking away with a barangay.
--   UPDATE  your own row, plus any row for an admin. Note what this
--          policy deliberately does NOT try to do: compare old and new
--          role values. A policy's WITH CHECK sees the proposed NEW row
--          and nothing else, so the OLD/NEW comparison that keeps a
--          resident from promoting themselves lives in
--          guard_profile_privilege_change() (section 5). RLS answers
--          "which rows"; the trigger answers "which columns".
--   DELETE  admins only.
-- ---------------------------------------------------------------------
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_officer() or public.is_approver());

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles
  for insert to authenticated
  with check (
    id = auth.uid()
    and role = 'resident'
    and account_status = 'pending'
  );

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

drop policy if exists profiles_delete_admin on public.profiles;
create policy profiles_delete_admin on public.profiles
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------
-- assets
--   SELECT  the public catalogue is readable by anyone, including
--          signed-out visitors of the public listing; archived assets
--          are visible to admins only.
--   INSERT/UPDATE/DELETE  admins only. Everything else about an asset
--          (status, condition) is moved by triggers and RPCs, never by
--          a client UPDATE.
-- ---------------------------------------------------------------------
drop policy if exists assets_select_public_catalogue on public.assets;
create policy assets_select_public_catalogue on public.assets
  for select to anon
  using (archived_at is null);

drop policy if exists assets_select_authenticated on public.assets;
create policy assets_select_authenticated on public.assets
  for select to authenticated
  using (archived_at is null or public.is_admin());

drop policy if exists assets_insert_admin on public.assets;
create policy assets_insert_admin on public.assets
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists assets_update_admin on public.assets;
create policy assets_update_admin on public.assets
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists assets_delete_admin on public.assets;
create policy assets_delete_admin on public.assets
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------
-- bookings
--   SELECT  your own requests; officers and approvers see everything,
--          because reviewing requires seeing everything.
--   INSERT  your own, forced to 'pending' — a client cannot submit a
--          request that is already approved, and cannot file one in
--          somebody else's name.
--   UPDATE  two permissive policies, OR'd by Postgres: the owner may
--          touch their own row, officers/approvers may touch any. What
--          the owner is *allowed to change* is not expressible here (a
--          WITH CHECK only sees the new row), so guard_booking_update()
--          narrows it to a withdrawal, and the transition trigger below
--          enforces the lifecycle for everyone else.
--   DELETE  admins only.
-- ---------------------------------------------------------------------
drop policy if exists bookings_select on public.bookings;
create policy bookings_select on public.bookings
  for select to authenticated
  using (borrower_id = auth.uid() or public.is_officer() or public.is_approver());

drop policy if exists bookings_insert_own_pending on public.bookings;
create policy bookings_insert_own_pending on public.bookings
  for insert to authenticated
  with check (
    borrower_id = auth.uid()
    and status = 'pending'
  );

-- (a) the owner's own row. `with check` stops an UPDATE from handing the
--     row to somebody else.
drop policy if exists bookings_update_own_cancel on public.bookings;
create policy bookings_update_own_cancel on public.bookings
  for update to authenticated
  using (borrower_id = auth.uid())
  with check (borrower_id = auth.uid());

-- (b) review queue.
drop policy if exists bookings_update_reviewer on public.bookings;
create policy bookings_update_reviewer on public.bookings
  for update to authenticated
  using (public.is_officer() or public.is_approver())
  with check (public.is_officer() or public.is_approver());

drop policy if exists bookings_delete_admin on public.bookings;
create policy bookings_delete_admin on public.bookings
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------
-- transactions (custody records)
--   SELECT  your own loans; officers see all.
--   INSERT/UPDATE  officers only — and in practice they go through
--          release_asset()/return_asset(), which are the only paths
--          that set flagged_for_inspection correctly.
--   DELETE  admins only; the audit trail keeps the story anyway.
-- ---------------------------------------------------------------------
drop policy if exists transactions_select on public.transactions;
create policy transactions_select on public.transactions
  for select to authenticated
  using (borrower_id = auth.uid() or public.is_officer());

drop policy if exists transactions_insert_officer on public.transactions;
create policy transactions_insert_officer on public.transactions
  for insert to authenticated
  with check (public.is_officer());

drop policy if exists transactions_update_officer on public.transactions;
create policy transactions_update_officer on public.transactions
  for update to authenticated
  using (public.is_officer())
  with check (public.is_officer());

drop policy if exists transactions_delete_admin on public.transactions;
create policy transactions_delete_admin on public.transactions
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------
-- notifications
--   Strictly recipient-scoped, and INSERT has no policy at all: the
--   system produces notifications, users do not. A forged "your
--   request was approved" email is a real attack on a community that
--   trusts its barangay.
-- ---------------------------------------------------------------------
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
  for select to authenticated
  using (recipient_id = auth.uid());

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications
  for update to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own on public.notifications
  for delete to authenticated
  using (recipient_id = auth.uid());

-- ---------------------------------------------------------------------
-- audit_logs
--   SELECT  admins only.
--   INSERT  deliberately absent: with RLS on and no INSERT policy,
--           no client can write history — only the triggers and the
--           SECURITY DEFINER functions above can.
--   UPDATE/DELETE  absent AND blocked by a trigger.
-- ---------------------------------------------------------------------
drop policy if exists audit_logs_select_admin on public.audit_logs;
create policy audit_logs_select_admin on public.audit_logs
  for select to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------
-- maintenance_records
--   Officer-only in both directions: reporting a defect is an officer
--   action, so residents cannot file noise, and resolving one is a
--   decision that must leave a trail. Admins may delete typos.
-- ---------------------------------------------------------------------
drop policy if exists maintenance_select_officer on public.maintenance_records;
create policy maintenance_select_officer on public.maintenance_records
  for select to authenticated
  using (public.is_officer());

drop policy if exists maintenance_insert_officer on public.maintenance_records;
create policy maintenance_insert_officer on public.maintenance_records
  for insert to authenticated
  with check (public.is_officer());

drop policy if exists maintenance_update_officer on public.maintenance_records;
create policy maintenance_update_officer on public.maintenance_records
  for update to authenticated
  using (public.is_officer())
  with check (public.is_officer());

drop policy if exists maintenance_delete_admin on public.maintenance_records;
create policy maintenance_delete_admin on public.maintenance_records
  for delete to authenticated
  using (public.is_admin());

-- =====================================================================
-- 8. Grants
-- ---------------------------------------------------------------------
-- RLS decides *which rows*; grants decide *whether the role may issue
-- the statement at all*. Both are needed, and they are independent:
-- the grants below are deliberately broad on tables (so that policies
-- are the single place where the interesting rules live) and narrow
-- on functions.

grant usage on schema public to anon, authenticated;

grant select on public.assets to anon;
grant select on public.assets to authenticated;

grant select, insert, update, delete
  on public.profiles, public.assets, public.bookings, public.transactions,
     public.notifications, public.maintenance_records
  to authenticated;

grant select on public.audit_logs to authenticated;  -- RLS: admins only

-- SECURITY DEFINER functions must not be left executable by PUBLIC:
-- revoke first, then hand out exactly the surface the app needs.
revoke execute on function public.current_user_role()              from public;
revoke execute on function public.is_admin()                     from public;
revoke execute on function public.is_staff()                     from public;
revoke execute on function public.is_approver()                  from public;
revoke execute on function public.is_officer()                   from public;
revoke execute on function public.approve_booking(uuid, text)     from public;
revoke execute on function public.reject_booking(uuid, text)     from public;
revoke execute on function public.release_asset(uuid, public.asset_condition, text[], text) from public;
revoke execute on function public.return_asset(uuid, public.asset_condition, text, text, text, text[]) from public;
revoke execute on function public.mark_overdue_bookings()        from public;
revoke execute on function public.check_asset_availability(uuid, timestamptz, timestamptz) from public;
revoke execute on function public.dashboard_summary()            from public;
-- Internal helpers: no grant to authenticated on purpose, they are
-- only ever reached through the functions above.
revoke execute on function public.refresh_asset_status(uuid)      from public;
revoke execute on function public.set_updated_at()                from public;
revoke execute on function public.handle_new_profile()           from public;
revoke execute on function public.handle_new_user()               from public;
revoke execute on function public.default_request_id()            from public;
revoke execute on function public.guard_profile_privilege_change() from public;
revoke execute on function public.guard_booking_update()          from public;
revoke execute on function public.validate_booking_status_transition() from public;
revoke execute on function public.audit_booking_change()          from public;
revoke execute on function public.audit_asset_change()            from public;
revoke execute on function public.audit_logs_append_only()       from public;
revoke execute on function public.sync_asset_status_on_booking() from public;
revoke execute on function public.notify_staff_of_pending_request() from public;
revoke execute on function public.stamp_maintenance_resolution() from public;

grant execute on function public.current_user_role()              to authenticated;
grant execute on function public.is_admin()                      to authenticated;
grant execute on function public.is_staff()                      to authenticated;
grant execute on function public.is_approver()                   to authenticated;
grant execute on function public.is_officer()                    to authenticated;
grant execute on function public.approve_booking(uuid, text)      to authenticated;
grant execute on function public.reject_booking(uuid, text)      to authenticated;
grant execute on function public.release_asset(uuid, public.asset_condition, text[], text) to authenticated;
grant execute on function public.return_asset(uuid, public.asset_condition, text, text, text, text[]) to authenticated;
grant execute on function public.check_asset_availability(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.dashboard_summary()              to authenticated;
grant execute on function public.mark_overdue_bookings()         to authenticated, service_role;

commit;

-- =====================================================================
-- AFTER RUNNING THIS
-- ---------------------------------------------------------------------
-- 1. Create the first admin. Sign up through the app (or Dashboard >
--    Authentication > Users > Add user), then in the SQL editor:
--
--      update public.profiles
--         set role = 'admin', account_status = 'active'
--       where id = (select id from auth.users where email = 'you@example.com');
--
--    Two things make this work from the dashboard: `postgres` owns the
--    table and so bypasses its own RLS policies, and the
--    guard_profile_privilege_change() trigger has an explicit
--    `session_user = 'postgres'` escape hatch for exactly this moment
--    (there is no admin yet, and an API session can never be `postgres`
--    because PostgREST authenticates as `authenticator`). Once one
--    admin exists, promote everyone else from inside the app.
--
-- 2. Schedule mark_overdue_bookings() (Supabase > Cron, or any
--    external scheduler calling it with the service key) at least once
--    an hour; 'overdue' is derived from the clock, not typed in.
--
-- 3. Load supabase/seed_demo.sql for a browsable catalogue.
-- =====================================================================