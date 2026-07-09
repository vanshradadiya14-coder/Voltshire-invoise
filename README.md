# Builder CRM & Invoice App

A professional, production-ready **Flutter** application for a UK building
company (single business owner). Manage customers, jobs, quotations, invoices,
payments, expenses, photos and documents — with **Firebase** backend, **offline
support**, **Material 3** light/dark themes and **PDF invoice generation**.

Built for Android **and** iOS from one codebase.

---

## Features

- **Firebase Auth** (email & password) with sign-up, sign-in and password reset
- **First-run Business Setup Wizard** — company profile, logo, bank details,
  invoice/quote prefixes, default VAT, currency and payment terms
- **Dashboard** — active/completed jobs, pending payments, monthly revenue,
  outstanding total, customer count, recent jobs & invoices
- **Customers** — add / edit / delete / search, with call & email shortcuts
- **Jobs** — per-customer jobs, statuses (Quote → Accepted → In Progress →
  Completed / Cancelled), start/completion dates, photos and expenses
- **Quotations** — unlimited line items (qty, unit price, discount %, VAT %),
  automatic totals, duplicate, convert-to-invoice, PDF share/print
- **Invoices** — automatic numbering (e.g. `INV-000001`), work description,
  line items, subtotal / VAT / grand total / balance due
- **Payments** — record part/full payments; invoice status updates automatically
- **Expenses** — categories (materials, fuel, equipment, labour, skip hire…),
  supplier, receipt photo, optional job link
- **Photos** — before / progress / completed work photos per job
- **Documents** — attach contracts, certificates, guarantees, planning docs
- **Reports** — yearly revenue, expenses, profit, outstanding, monthly breakdown,
  expense summary
- **Global search** across customers, jobs, quotes, invoices and payments
- **Settings** — theme (system/light/dark), company & bank details, invoice
  defaults
- **Offline-first** — Firestore offline persistence; writes sync automatically
- **Security** — every document is scoped to the signed-in user's UID via
  Firestore & Storage security rules

The generated PDF layout mirrors the reference invoice provided (logo, company
block, BILL TO, meta panel, item table, totals, bank details, terms and a
signature area).

---

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter (Material 3) |
| State management | Riverpod (`flutter_riverpod`) |
| Backend | Firebase |
| Auth | Firebase Authentication |
| Database | Cloud Firestore (offline persistence on) |
| Storage | Firebase Storage |
| Routing | `go_router` |
| PDF | `pdf` + `printing` |
| Sharing | `share_plus` |
| Images / files | `image_picker`, `file_picker`, `cached_network_image` |

Requires a current stable Flutter (**3.32+**) / Dart 3.5+.

---

## Project structure (clean architecture)

```
lib/
  core/          constants, errors, utils (formatters, validators, calculations)
  models/        data models (+ enums, embedded line items)
  firebase/      Firebase init + generated options
  services/      thin SDK wrappers (auth, storage, share)
  repositories/  data access per collection (owner-scoped queries, numbering)
  providers/     Riverpod providers (core, auth, repositories, data, dashboard,
                 search, theme)
  routes/        go_router configuration + route constants
  theme/         Material 3 light/dark themes + palette
  widgets/       reusable UI (cards, chips, pickers, line-item editor, dialogs)
  screens/       feature screens grouped by area
  pdf/           invoice & quotation PDF builders
```

### Firestore collections
`users`, `settings` (company profile), `customers`, `jobs`, `quotes`,
`invoices`, `payments`, `expenses`, `documents`, `photos`.

Line items are embedded inside their quote/invoice document (as an array) so a
document reads/writes atomically and works offline and in PDF generation.

---

## Getting started

### 1. Prerequisites
- Flutter SDK 3.32+ (`flutter doctor` should be clean)
- A Firebase project (free Spark plan is fine)
- The FlutterFire CLI:
  ```bash
  dart pub global activate flutterfire_cli
  ```

### 2. Generate the native platform folders
This repository contains only the Dart source, config and Firebase rules. Add
the Android/iOS scaffolding without touching `lib/`:
```bash
cd voltshire
flutter create --platforms=android,ios .
```

### 3. Install dependencies
```bash
flutter pub get
```

### 4. Configure Firebase
Run from the project root and follow the prompts (select your Firebase project):
```bash
flutterfire configure
```
This overwrites `lib/firebase/firebase_options.dart` with real values and adds
the platform config files (`google-services.json`, `GoogleService-Info.plist`).

In the [Firebase console](https://console.firebase.google.com/):
- **Authentication → Sign-in method →** enable **Email/Password**
- **Firestore Database →** create a database (production mode)
- **Storage →** enable Storage

### 5. Deploy the security rules & indexes
Using the Firebase CLI (`npm i -g firebase-tools`, then `firebase login`):
```bash
firebase use <your-project-id>
firebase deploy --only firestore:rules,firestore:indexes,storage
```
(Or paste `firestore.rules` and `storage.rules` into the console, and let the
app prompt you to create indexes on first use.)

### 6. Run
```bash
flutter run
```
On first launch you'll register an account and complete the **Business Setup
Wizard**. After that the full app is available.

---

## Notes & conventions

- **Auto-numbering**: invoice/quote numbers are reserved atomically via a
  Firestore transaction on the `settings/{uid}` document, so concurrent creates
  never collide.
- **Money maths** lives in `core/utils/calculations.dart` so the on-screen
  editor, the saved document and the PDF always agree to the penny.
- **Currency** is driven by the company profile (default GBP £). Change it in
  Settings → Company details.
- **Fonts**: the app uses the platform default font. To make PDFs byte-identical
  across devices, add a `.ttf` under `assets/fonts/` and follow the commented
  block in `pubspec.yaml` + `lib/theme/app_theme.dart`.

## Future-ready

The architecture (repositories + providers + owner-scoped documents) is designed
to extend toward multiple employees & roles, digital signatures, online
payments, a customer portal, and desktop/web builds with minimal churn.
