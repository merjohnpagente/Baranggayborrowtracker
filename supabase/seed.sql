-- =====================================================================
-- Barangay Borrow Tracker - demo data
-- Run AFTER supabase/migrations/20260101000000_init.sql
--
-- 1. Create your test accounts first:
--    Supabase Dashboard > Authentication > Users > Add user
--      admin@barangay.gov.ph    -> administrator
--      capitan@barangay.gov.ph  -> barangay official
--      resident@example.com     -> resident
--    (Use "Auto Confirm User" so they can sign in immediately.)
-- 2. Run the role statements below with the emails you actually created.
-- 3. Then run the rest of this file to load categories + sample assets.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Roles
-- ---------------------------------------------------------------------
update public.profiles set role = 'admin'
 where id = (select id from auth.users where email = 'admin@barangay.gov.ph');

update public.profiles set role = 'official'
 where id = (select id from auth.users where email = 'capitan@barangay.gov.ph');

update public.profiles set role = 'resident'
 where id = (select id from auth.users where email = 'resident@example.com');

-- ---------------------------------------------------------------------
-- 2. Categories
-- ---------------------------------------------------------------------
insert into public.asset_categories (name, icon, description) values
  ('Vehicles',       'directions_car', 'Barangay service vehicles and motorcycles'),
  ('Sports &amp; Recreation', 'sports_basketball', 'Courts, balls and training equipment'),
  'Events &amp; Venue',      'celebration',       'Halls, tents, canopies and chairs'),
  ('Audio &amp; Visual',     'campaign',          'Sound systems, microphones and projectors'),
  ('Power &amp; Tools',      'power',             'Generators, extension cords and hand tools')
on conflict (name) do update
  set description = excluded.description;

-- ---------------------------------------------------------------------
-- 3. Sample assets (fixed UUIDs keep re-runs idempotent)
-- ---------------------------------------------------------------------
insert into public.assets
  (id, code, name, category_id, description, status, condition, location, requires_approval, deposit_amount)
values
  ('11111111-1111-4111-8111-111111111111', 'BRGY-VEH-001', 'Barangay Service Vehicle (Toyota Hilux)',
   (select id from public.asset_categories where name = 'Vehicles'),
   'White Hilux with orange stripe. Seats 5 plus cargo bed. Requires a licensed driver.',
   'available', 'good', 'Barangay Hall Parking', true, 0),

  ('22222222-2222-4222-8222-222222222222', 'BRGY-VEN-002', 'Barangay Covered Court',
   (select id from public.asset_categories where name = 'Sports &amp; Recreation'),
   'Covered basketball court with lighting. Reservation is per 3-hour block.',
   'available', 'good', 'Court A, Purok 3', true, 500),

  ('33333333-3333-4333-8333-333333333333', 'BRGY-HAL-001', 'Multipurpose Hall',
   (select id from public.asset_categories where name = 'Events &amp; Venue'),
   'Main hall, capacity 300. Includes 20 folding chairs and 4 tables.',
   'available', 'good', 'Barangay Hall', true, 1000),

  ('44444444-4444-4444-8444-444444444444', 'BRGY-AUD-001', 'Sound System with 2 Wireless Mics',
   (select id from public.asset_categories where name = 'Audio &amp; Visual'),
   'Two-way speaker set, mixer, 2 wireless microphones, 1 stand.',
   'available', 'fair', 'Barangay Store Room', true, 500),

  ('55555555-5555-4555-8555-555555555555', 'BRGY-PRJ-001', 'Projector with HDMI Cable',
   (select id from public.asset_categories where name = 'Audio &amp; Visual'),
   '1080p projector, HDMI cable and extension wire included.',
   'maintenance', 'needs_repair', 'Barangay Store Room', true, 200),

  ('66666666-6666-4666-8666-666666666666', 'BRGY-TNT-001', 'Canopy Tent (4x4 meters)',
   (select id from public.asset_categories where name = 'Events &amp; Venue'),
   'Blue canopy with 8 foldable legs and cover.',
   'available', 'good', 'Barangay Store Room', false, 0),

  ('77777777-7777-4777-8777-777777777777', 'BRGY-CHR-001', 'Stackable Chairs (set of 50)',
   (select id from public.asset_categories where name = 'Events &amp; Venue'),
   'White plastic chairs. Borrowed as a set, returned as a set.',
   'available', 'good', 'Barangay Hall', false, 300),

  ('88888888-8888-4888-8888-888888888888', 'BRGY-GEN-001', 'Gasoline Generator 5.5kVA',
   (select id from public.asset_categories where name = 'Power &amp; Tools'),
   'Honda-type generator. Fuel must be returned at the same level.',
   'available', 'good', 'Barangay Store Room', true, 0)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 4. Quick sanity check
-- ---------------------------------------------------------------------
select p.full_name, p.role, count(br.id) as requests
from public.profiles p
left join public.borrow_requests br on br.user_id = p.id
group by p.full_name, p.role
order by p.role desc;