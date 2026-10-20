# Barangay Borrow Tracker

An Android app for managing barangay-owned assets — vehicles, courts, halls,
sound systems, furniture, tents, projectors and generators — from request
through approval, release, return and reporting.

**The app runs entirely offline.** Accounts, assets, bookings, notifications and
photos are stored on the phone. There is no Supabase project, no database
server, no login API and no internet requirement. Install the APK, and it works.

Built with Flutter and Material 3 by **Merjohn Pagente (MerjDev)**.

---

## Download and install the APK

You do **not** need Flutter installed. GitHub Actions builds the APK.

1. Open the repository's **Actions** tab → **Build Android APK**.
2. Either wait for the run triggered by the latest push, or use **Run workflow**.
3. Wait for the run to finish green.
4. Open the run and download the artifact **`barangay-borrow-tracker-apk`**.
5. Unzip it, copy the `.apk` to the phone and install it. Android will ask you
   to allow installs from this source.

The APK is a prototype build and is available **only from the Actions
artifact**. This repository does not publish GitHub releases or a “Latest”
release.

The pipeline runs `flutter analyze` and `flutter test` **before** it builds, so
an APK is never produced from code that failed analysis or tests. The build is
phones-only: one APK contains 64-bit and 32-bit ARM binaries. Emulator x86
binaries are deliberately excluded.

---

## First launch

The first run creates a demo catalogue and three accounts, so the app is usable
immediately:

| Role     | Email                    | Password      |
| -------- | ------------------------ | ------------- |
| Admin    | `admin@barangay.local`   | `admin123`    |
| Staff    | `staff@barangay.local`   | `staff123`    |
| Resident | `resident@barangay.local`| `resident123` |

They are ordinary local accounts with the same permissions as accounts created
in the app. **Change the admin password after installing** — Profile → Settings
→ Change password.

New residents can register from the login screen. Local sign-ups are active
immediately and are always residents; only an admin can promote an account to
staff, approver or admin via **Profile → Manage users**.

### Resetting the demo

Clearing the app's data (Android Settings → Apps → Barangay Borrow Tracker →
Storage → Clear data) or uninstalling the app removes the database and photos.
The next launch seeds a fresh demo. There is no cloud copy to restore from.

---

## How data is stored

```
<app documents folder>/barangay_borrow_tracker/database.json
<app documents folder>/barangay_borrow_tracker/photos/…
```

* One JSON file holds profiles, assets, bookings, custody records and
  notifications. Writes go to a temporary file and are renamed into place, so a
  crash cannot leave a half-written database.
* Asset photos are copied out of the image picker into `photos/`. The asset row
  stores the file path, not a base64 blob.
* Passwords are never stored in clear text: each account has a random salt and
  a SHA-256 hash of `salt:password`.
* The seeded photographs in `assets/images/` are bundled into the APK and used
  when an asset has no photo of its own.

This is a single-device app: two phones do not share a database. There is no
sync, no cloud backup and no server-side recovery. Keep the phone safe, and use
Android's own data backup tools if your device supports them.

---

## Roles

| Role         | Can do |
| ------------ | ------ |
| **Resident** | Browse the catalogue, request an asset, withdraw a request, see own history |
| **Staff**    | Everything a resident can do, plus release and receive assets, view all requests and reports |
| **Approver** | Everything a resident can do, plus approve or reject requests, view all requests and reports |
| **Admin**    | Everything staff and approvers can do, plus add/edit/archive assets and manage user roles |

Hiding a button is not the security boundary. The repositories check the signed-in
role before every workflow action, so a stale screen cannot approve a request
after the account's role changes.

---

## Request workflow

```
pending ──approve──▶ approved ──release──▶ released ──return──▶ completed
   │                    │                      │
   ├──reject──▶ rejected│                      └──past due──▶ overdue ──return──▶ completed
   └──cancel──▶ cancelled
                        └──cancel──▶ cancelled
```

* **No overlapping approved bookings.** A window is half-open `[start, end)`, so
  back-to-back bookings are allowed. Availability checks confirmed bookings
  (`approved`, `released`, `overdue`) and is run again at approval time, not
  just when the request form is filled in.
* **Approval and rejection** are limited to admins and approvers. A rejection
  requires a reason.
* **Release and return** are limited to admins and staff. Returning an asset
  records its condition, missing items and optional notes, and updates the asset
  condition.
* **Overdue** items are swept when requests are refreshed; the borrower gets an
  in-app notification.
* New requests notify active admins/approvers (never the applicant), and the
  applicant gets a “Request received” acknowledgement.
* Archived assets keep their borrowing history but can no longer be requested.
  Nothing is hard-deleted.

All of these rules live in `lib/data/repositories/borrow_repository.dart` and
`lib/data/local/local_store.dart`.

---

## QR codes

* **Asset QR** — generated from the asset detail screen; scanning it opens that
  asset. The resolver also accepts the human-readable asset code, so a typed
  code works too.
* **Request QR** — generated from a request's detail screen; scanning it opens
  that request.
* The scanner uses the phone camera. Camera permission is declared as optional,
  so the app still installs on a device without one.

QR payloads are self-contained (`BBT|asset|<id>`), which is why scanning still
works with no network.

---

## Settings and credits

Open **Profile → Settings**:

* **Version** — read from the installed build via `package_info_plus`, with a
  copy button.
* **Developer** — Merjohn Pagente, developed by MerjDev.
* **GitHub** — [github.com/merjohnpagente](https://github.com/merjohnpagente),
  opens in the browser.
* **Buy me a coffee** — GCash **0915 043 5696**; tapping copies the number for a
  broke developer. Thank you.
* **Storage** — a reminder that nothing leaves the phone.

The splash screen also credits **By MerjDev**.

---

## Build from source

The supported route is CI because no local Flutter SDK is required. To build
locally with Flutter stable and Java 17:

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release \
  --target-platform android-arm64,android-arm \
  --dart-define=BARANGAY_NAME="Your Barangay"
```

The APK is at `build/app/outputs/flutter-apk/app-release.apk`.

`android/` is git-ignored and generated by the workflow with `flutter create`;
the launcher icons are then regenerated from
`assets/icon/app_icon_1024.png`. Set the optional GitHub repository variable
**`BARANGAY_NAME`** to change the barangay name shown in the app. No database
credentials or secrets are needed.

---

## Project layout

```
lib/
  main.dart                  app entry, local store bootstrap, provider wiring
  core/
    config/app_config.dart   app name, barangay name, developer/support details
    theme/                   Material 3 palette and component styling
    utils/                   formatters, validators, QR payload, app version
    widgets/                 shared cards, photos, chips, empty/loading states
  data/
    local/                   JSON store, seed data, ids, password hashing
    models/                  assets, bookings, profiles, notifications, reports
    repositories/            local auth, assets, borrowing, notifications, reports
  state/                     Provider change notifiers
  features/                  auth, dashboard, assets, requests, approvals,
                             reports, notifications, profile, settings, splash, QR
assets/
  images/                    bundled demo photographs
  ATTRIBUTION.md             photo credits (also bundled into the APK)
test/                        model and utility tests
```

No code path calls an external service. The old Supabase client, SQL schema and
setup screen have been removed.

---

## Tests

```bash
flutter analyze --no-fatal-infos
flutter test
```

`flutter test` covers the model parsing and business-rule getters (status
transitions, availability rules, request length, notification handling) plus the
formatters, validators and QR payload parser. The test job in GitHub Actions
gates the APK build.

---

## Photo credits

The bundled photographs are Creative Commons images from Wikimedia Commons.
Their licences and source links are in
[`assets/ATTRIBUTION.md`](assets/ATTRIBUTION.md), which is also packaged into the
APK so the attribution travels with the pictures. Replace a bundled photo by
adding a real photo to the asset in the app; the uploaded image takes priority.

---

## Developer

**Merjohn Pagente** · [github.com/merjohnpagente](https://github.com/merjohnpagente)

If this app saved you some paperwork, you can buy the developer a coffee on
GCash: **0915 043 5696**.
