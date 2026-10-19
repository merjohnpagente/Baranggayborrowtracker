-- =====================================================================
-- Barangay Borrow Tracker — DEMO DATA
-- ---------------------------------------------------------------------
-- ####################  DEMO DATA ONLY  ###############################
-- ##################  NOT FOR PRODUCTION  #############################
-- ---------------------------------------------------------------------
-- This file fills the asset catalogue with examples so a fresh
-- install has something to look at. It is *safe to delete*: everything
-- here lives in `public.assets` (plus one maintenance record) and can
-- be removed with:
--
--     delete from public.assets
--      where asset_code like 'BRGY-%';
--
-- Before running it for real, change the asset_code prefix and the
-- locations so they match your barangay, or just delete the rows and
-- enter your own through the app (only admins can create assets).
--
-- HOW TO RUN
--   1. supabase/schema.sql      (must run first)
--   2. this file
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/seed_demo.sql
--   or paste it into Supabase Dashboard > SQL Editor > Run.
--
-- WHAT THIS FILE DELIBERATELY DOES NOT DO
--   It does not create users. `public.profiles.id` is a foreign key to
--   `auth.users.id`, and auth.users is owned by Supabase Auth — it has
--   passwords, sessions, email confirmations and recovery flows
--   attached to it. Hand-writing rows into it (or into profiles) would
--   produce accounts that cannot sign in and a role column that lies
--   about who is actually authenticated. So: no fake users, no
--   placeholder profiles, no example bookings either (a booking needs a
--   real borrower_id).
--
--   That leaves exactly one manual step, and it is the one that matters:
--   creating the first administrator. See section 2 below.
--
--   Run this as `postgres` (the Supabase SQL editor does). RLS applies
--   to the `authenticated` role, not to you, so seeding works without
--   any policy gymnastics.
-- =====================================================================

begin;

-- =====================================================================
-- 1. Demo assets
-- ---------------------------------------------------------------------
-- One row per category so every filter chip in the app has something
-- to filter. `on conflict (asset_code) do update` keeps re-runs safe:
-- the descriptive columns are refreshed, while status / condition /
-- archived_at are left alone — re-seeding must not resurrect an asset
-- that is currently out on loan.

insert into public.assets
  (asset_code, name, category, description, image_urls, location, quantity,
   condition, status, plate_number, qr_code_value, maintenance_note)
values
  -- Vehicles ---------------------------------------------------------
  ('BRGY-VEH-001',
   'Barangay Service Vehicle (Toyota Hilux)',
   'vehicle',
   'White Hilux with an orange stripe. Seats five plus a cargo bed. Requires a licensed driver; record the authorised driver on the request.',
   '{}',
   'Barangay Hall Parking',
   1, 'good', 'available', 'ABC 1234', 'BRGY-VEH-001', null),

  ('BRGY-VEH-002',
   'Service Motorcycle (TMZ)',
   'vehicle',
   'Light motorcycle for errands and response runs. Helmets issued with the asset.',
   '{}',
   'Barangay Hall Parking',
   1, 'serviceable', 'available', null, 'BRGY-VEH-002', null),

  -- Facilities --------------------------------------------------------
  ('BRGY-FAC-001',
   'Barangay Covered Court',
   'facility',
   'Covered basketball court with lighting, booked in three-hour blocks. Not transferable to another resident.',
   '{}',
   'Court A, Purok 3',
   1, 'good', 'available', null, 'BRGY-FAC-001', null),

  ('BRGY-FAC-002',
   'Barangay Multipurpose Hall',
   'facility',
   'Main hall, capacity 300. Air-con unit is on a separate power circuit; see the caretaker.',
   '{}',
   'Barangay Hall',
   1, 'good', 'available', null, 'BRGY-FAC-002', null),

  -- Equipment ---------------------------------------------------------
  ('BRGY-EQP-001',
   'Portable Sound System with 2 Wireless Mics',
   'equipment',
   'Two-way speaker set, mixer, two wireless microphones, one stand and two XLR cables.',
   '{}',
   'Barangay Store Room',
   1, 'good', 'available', null, 'BRGY-EQP-001', null),

  ('BRGY-EQP-002',
   'Extension Cables and Adapter Set',
   'equipment',
   'Two 10m extension cords, three multi-adapters, one HDMI cable. Keep dry.',
   '{}',
   'Barangay Store Room',
   1, 'good', 'available', null, 'BRGY-EQP-002', null),

  -- Furniture ---------------------------------------------------------
  ('BRGY-FUR-001',
   'Stackable Chairs (set of 50)',
   'furniture',
   'White plastic chairs. Borrowed and returned as a complete set — the count is checked in and out.',
   '{}',
   'Barangay Hall',
   50, 'good', 'available', null, 'BRGY-FUR-001', null),

  ('BRGY-FUR-002',
   'Folding Tables (set of 6)',
   'furniture',
   'Six 6-foot folding tables. Braces are stored separately in the store room.',
   '{}',
   'Barangay Store Room',
   6, 'good', 'available', null, 'BRGY-FUR-002', null),

  -- Shelter -----------------------------------------------------------
  ('BRGY-SHL-001',
   'Canopy Tent 4x4 metres',
   'shelter',
   'Blue canopy with eight foldable legs and a cover. Two pegs are missing; the crew knows.',
   '{}',
   'Barangay Store Room',
   1, 'minor_damage', 'available', null, 'BRGY-SHL-001',
   'Two pegs missing — replacement requested.'),

  -- Electronics -------------------------------------------------------
  ('BRGY-ELE-001',
   'LED Projector with HDMI Cable',
   'electronics',
   '1080p projector, HDMI cable and 3m extension wire. Bulb life is rated at 20,000 hours.',
   '{}',
   'Barangay Store Room',
   1, 'good', 'available', null, 'BRGY-ELE-001', null),

  ('BRGY-ELE-002',
   'PA System (fixed, hall)',
   'electronics',
   'Installed speaker array in the multipurpose hall. Booked with the hall; not portable.',
   '{}',
   'Barangay Hall',
   1, 'serviceable', 'maintenance', null, 'BRGY-ELE-002',
   'Amplifier channel 2 is cutting out. Awaiting the technician.'),

  -- Power -------------------------------------------------------------
  ('BRGY-PWR-001',
   'Gasoline Generator 5.5 kVA',
   'power',
   'Honda-type generator. Fuel must be returned at the level it was released at; the officer records it on the transaction.',
   '{}',
   'Barangay Store Room',
   1, 'good', 'available', null, 'BRGY-PWR-001', null),

  -- Other -------------------------------------------------------------
  ('BRGY-OTH-001',
   'Emergency Response Kit',
   'other',
   'First-aid kit, two reflective vests, a megaphone and a rope. Officers only for the medical portion.',
   '{}',
   'Barangay Hall Office',
   1, 'good', 'available', null, 'BRGY-OTH-001', null)
on conflict (asset_code) do update
   set name             = excluded.name,
       category         = excluded.category,
       description      = excluded.description,
       location         = excluded.location,
       quantity         = excluded.quantity,
       maintenance_note = excluded.maintenance_note;

-- =====================================================================
-- 1b. One open maintenance record
-- ---------------------------------------------------------------------
-- Demonstrates the defect flow. `reported_by` is looked up from
-- auth.users by email, so it stays NULL if that person has not signed
-- up yet — no fake identities, and the row still works (the field is
-- nullable by design).
insert into public.maintenance_records (asset_id, issue_description, status, reported_by)
select a.id,
       'Amplifier channel 2 cuts out during announcements.',
       'open',
       (select u.id from auth.users u where u.email = 'capitan@example.com')
  from public.assets a
 where a.asset_code = 'BRGY-ELE-002'
   and not exists (
     select 1 from public.maintenance_records m
      where m.asset_id = a.id and m.status <> 'resolved'
   );

-- =====================================================================
-- 2. Creating the first administrator (the one manual step)
-- =====================================================================
-- Nothing in this file can create a user: auth.users is owned by
-- Supabase Auth, and every profile must trace back to a real,
-- email-verified sign-in. So the first admin is created by hand:
--
--   a. Supabase Dashboard > Authentication > Users > "Add user"
--        email        : admin@example.com      (use your own)
--        password     : something long
--        tick "Auto Confirm User" so you can sign in immediately
--        (optionally add Metadata > full_name / phone_number — the
--         profile trigger copies these across)
--
--   b. Dashboard > SQL Editor > New query, then run EXACTLY this,
--      with your own email substituted:
--
--      ------------------------------------------------------------------
--      update public.profiles
--         set role           = 'admin',
--             account_status = 'active'
--       where id = (select id from auth.users where email = 'admin@example.com');
--      ------------------------------------------------------------------
--
--      Notes:
--        * The UPDATE lands whether or not a profile row exists — but a
--          profile row is required, and the `on_auth_user_created`
--          trigger in schema.sql creates one at sign-up. If you do not
--          see a row, insert it first:
--
--              insert into public.profiles (id, full_name, email)
--              values ((select id from auth.users where email = 'admin@example.com'),
--                      'Your Name', 'admin@example.com');
--
--          (The profiles INSERT trigger forces role = 'resident' and
--           account_status = 'pending' no matter what you send, so the
--          promotion must be a separate UPDATE — that is the whole
--           point of the rule.)
--
--        * Running this from the dashboard works because the dashboard
--          session is `postgres`, the table owner, and therefore not
--          subject to the profiles UPDATE policy. Once the first admin
--          exists, promote the rest from inside the app — admins can,
--          residents cannot.
--
--   c. Sign in, then create the other accounts from the app's
--      registration screen. Every new sign-up arrives as
--      role = 'resident', account_status = 'pending'. Activate them
--      from the admin screen; promote to staff / approver as needed.
--
--   d. Verify:
--
--      select email, role, account_status
--        from public.profiles
--       order by created_at;

-- =====================================================================
-- 3. Sanity check
-- ---------------------------------------------------------------------
-- Every one of these reads through the RLS policies, so this also
-- doubles as a check that the catalogue is publicly visible.
select a.asset_code,
       a.name,
       a.category::text as category,
       a.status::text   as status,
       a.condition::text as condition,
       a.quantity,
       a.location,
       (select count(*) from public.maintenance_records m
         where m.asset_id = a.id and m.status <> 'resolved') as open_defects
  from public.assets a
 where a.archived_at is null
 order by a.category::text, a.asset_code;

commit;

-- =====================================================================
-- Expected result of section 3: 13 assets across all eight categories,
-- one of them under maintenance, one with missing pegs.
-- =====================================================================