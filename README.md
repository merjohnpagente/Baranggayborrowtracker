# Barangay Borrow Tracker

An Android app for managing barangay-owned assets — vehicles, courts, halls,
sound systems, furniture, tents, projectors and generators — from request
through approval, release, return and reporting.

Built with Flutter, backed by Supabase (Postgres + Auth + Storage).

---

## Build the APK (no local Flutter SDK needed)

You do **not** need Flutter installed. GitHub Actions builds the APK for you.

1. Push this repository to GitHub (branch `main`).
2. Open the repo → **Actions** → **Build Android APK** → **Run workflow**.
3. Wait for the run to finish (green).
4. At the bottom of the run page, download the artifact
   **`barangay-borrow-tracker-apk`**.
5. Unzip it on your phone and install the `.apk`
   (Android will ask you to allow installs from this source).

The workflow runs `flutter analyze` and `flutter test` **before** it builds, so
a run that produces an APK has already passed both. A failing test fails the
build — the APK is never produced from broken code.

### Optional: configure Supabase at build time

The app builds and runs without any configuration, showing a *Setup required*
screen that explains what to do. To point it at a real database, add these as
repository **Settings → Secrets and variables → Actions → Variables**:

| Variable | Meaning |
| --- | --- |
| `SUPABASE_URL` | Project URL, e.g. `https://abc123.supabase.co` |
| `SUPABASE_ANON_KEY` | The **anon / publishable** key |
| `BARANGAY_NAME` | Optional display name, e.g. `Barangay San Isidro` |

They are read by the workflow as repo *variables* (`vars.*`) and passed to
`flutter build --dart-define=…`. Do **not** commit them.

> The anon key is safe to ship in a client — Row Level Security in Postgres is
> what actually protects the data. Never put the `service_role` key in the app.

---

## Database setup

1. Create a project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run `supabase/schema.sql` (one transaction, safe to
   re-run).
3. Optionally run `supabase/seed_demo.sql` for sample assets.
4. Create the first administrator — see below.

`schema.sql` is the security boundary. It defines the tables, the enums, the
indexes, **26 row-level-security policies**, the audit-log trigger, and the
functions that make approval safe:

| Function | Why it exists |
| --- | --- |
| `approve_booking` | Takes a row lock (`SELECT … FOR UPDATE`) and **re-checks** for overlapping approved bookings *inside the transaction*, so two approvers tapping Approve a second apart cannot both win. |
| `reject_booking` | Same lock discipline. |
| `release_asset` | Moves booking + asset + transaction row together, or not at all. |
| `return_asset` | Closes the transaction and flags it for inspection when damage is reported. |
| `dashboard_summary` | Every dashboard number is computed from real rows. |
| `mark_overdue_bookings` | Sweeps due dates into `overdue`. |

A `btree_gist` exclusion constraint additionally forbids overlapping *confirmed*
bookings for the same asset at the database level:

```sql
exclude using gist (asset_id with =, tstzrange(start_time, end_time, '[)') with &&)
  where (status in ('approved','released','overdue'))
```

It is half-open (`[)`), so a booking that ends at 5:00 PM and one that starts at
5:00 PM do **not** conflict — back-to-back slots stay bookable.

### Creating the first administrator

Sign up normally in the app (every new account is created as a `resident` with
`pending` status — the trigger in `schema.sql` enforces this, so public
registration cannot grant privileges). Then, in the Supabase SQL editor, using
the user's id from **Authentication → Users**:

```sql
update public.profiles
   set role = 'admin', account_status = 'active'
 where id = '<the-user-uuid>';
```

This has to be a separate step by design: the signup path is never allowed to
set a role.

---

## Project layout

```
lib/
  main.dart                  app entry, Supabase init, provider wiring
  core/
    app_assets.dart          every bundled image/icon path, in one place
    config/app_config.dart   build-time configuration (--dart-define)
    theme/app_theme.dart     Material 3 light + dark
    utils/                   formatters, validators, QR payload encoding
    widgets/                 shared cards, chips, empty states, photos
  data/
    models/                  Asset, BorrowRequest, UserProfile, NotificationItem,
                             DashboardSummary, AssetCategory
    repositories/            Supabase reads and writes
    supabase_service.dart    client bootstrap + error translation
  features/
    auth/                    login, register, forgot password
    dashboard/  assets/      inventory, detail, add/edit
    requests/  approvals/    request form, my requests, history
    notifications/           in-app inbox fed by database triggers
    reports/                 live operational summary for officials
    qr/                      scanner and code display
    profile/                 profile and user management
    setup/                   "not configured" + splash
    shell/                   bottom navigation
  routes/app_router.dart     go_router configuration
  state/                     ChangeNotifier providers (provider package)
supabase/
  schema.sql                 tables, enums, RLS, functions, triggers
  seed_demo.sql              optional sample data
test/                        model and rule tests
assets/
  images/                    placeholder photographs (see ATTRIBUTION.md)
  icons/                     original vector artwork
```

State management is `provider` + `ChangeNotifier`. Permissions are **not**
enforced by hiding buttons: the same role checks exist in the RLS policies, and
approval/release/return go through Postgres functions.

---

## Images

Photographs in `assets/images/` are placeholders from Wikimedia Commons, chosen
so each asset shows its actual subject (a pickup for the service vehicle, a PA
speaker stack for the sound system). They are **not** photographs of a real
barangay — replace them with approved local pictures before any public release.

Attribution and licences are in [`assets/ATTRIBUTION.md`](assets/ATTRIBUTION.md);
CC BY / CC BY-SA require that file to travel with the pictures, so it is
bundled into the APK as well as kept in the repository.

Icons in `assets/icons/` are original SVGs authored for this project.

---

## Known gaps

- Push notifications are not wired up. The in-app inbox records every event
  the database writes (submission, approval, rejection, return, overdue), but
  it does not ring the phone when the app is closed.
- Reports show the live operational summary from `dashboard_summary()`. There
  is no PDF/CSV export yet.
- No automated tests exercise the Supabase functions themselves; the SQL was
  verified separately against a real PostgreSQL 17 instance. The Dart tests
  cover the model parsing and the business rules mirrored in the client.