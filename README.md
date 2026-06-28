<div align="center">

# SpendWise

**Track every rupee, split bills fairly, and spend a little wiser.**

A polished, offline-first personal expense tracker built with Flutter — with bill splitting,
multi-currency support, spending insights, recurring entries, and CSV backup/restore.

`Track · Split · Save`

</div>

---

## Overview

SpendWise is a single-screen-shell mobile app for tracking day-to-day income and
expenses. It started life as a design prototype (`Expense Tracker.dc.html`) and was
ported to a production Flutter app. Everything runs **locally on the device** — no
account, no server, no network required.

Highlights:

- **Add income & expenses** with a custom amount keypad, categories, sources, dates and notes.
- **Split a bill** — enter the total and the number of people, and only *your share* is recorded.
- **Insights** — monthly income vs. spent, plus a spending-by-category breakdown.
- **History** — searchable, category-filtered, date-grouped transaction list.
- **Recurring entries** — daily / weekly / monthly / yearly, **auto-added when due** on app open.
- **Multi-currency** (INR, USD, EUR, GBP, JPY, AED) with locale-aware formatting and indicative conversion.
- **Light / Dark / System** themes.
- **CSV backup & restore** — export your data and re-import it (also available during first-run onboarding).
- **First-run onboarding** to set name, currency and theme.
- **Read-only transaction detail** view with Edit / Delete and undo-on-delete.

---

## Tech stack

| Area | Choice |
|------|--------|
| Framework | **Flutter** (Dart, Material 3) |
| Min SDK | Dart `^3.11.0` / Flutter 3.41+ |
| State management | **`provider`** + a single `ChangeNotifier` (`AppState`) |
| Persistence | **`shared_preferences`** (one JSON blob, the app's "localStorage") |
| Fonts | **`google_fonts`** (Manrope), weights softened centrally |
| Formatting | **`intl`** (locale-aware currency/number formatting) |
| Backup I/O | **`file_picker`** (import) + **`share_plus`** (export) |
| Platforms | Android, iOS, Web, Windows |

No backend, no database, no codegen — state lives in memory in `AppState` and is
mirrored to `shared_preferences` on every change.

---

## Architecture

State and business logic are centralised in **`AppState`** (a `ChangeNotifier`),
ported 1:1 from the original prototype's logic class. The UI is a thin, mostly
stateless layer that reads `AppState` via `provider` and calls its methods.

```
main()                     → loads persisted state, runs SpendWiseApp
 └─ SpendWiseApp           → MaterialApp; routes to Onboarding or RootScaffold
     ├─ OnboardingScreen   → first-run setup (name / currency / theme / import CSV)
     └─ RootScaffold       → app shell
         ├─ IndexedStack   → Home · Insights · History · Settings
         ├─ BottomNav      → notched bar + docked add (FAB)
         ├─ EntrySheet     → add/edit overlay (keypad, split, recurrence)
         └─ TransactionDetail → read-only overlay (Edit / Delete)
```

The add-entry sheet and detail view are overlays (`PopScope` makes the Android
back button close them → return to Home → exit, instead of quitting the app).

### Project layout

```
lib/
├── main.dart                 # entry point + MaterialApp wiring
├── app_state.dart            # ALL state + business logic (the core)
├── models.dart               # Category, Currency, Split, Txn, Recurring
├── theme.dart                # color tokens, Manrope text styles, ThemeData
├── csv_io.dart               # CSV export (share) / import (file picker)
├── root.dart                 # app shell: screens + nav + overlays + back handling
├── screens/
│   ├── onboarding_screen.dart
│   ├── home_screen.dart
│   ├── insights_screen.dart
│   ├── history_screen.dart
│   └── settings_screen.dart
└── widgets/
    ├── bottom_nav.dart       # notched BottomAppBar + docked FAB
    ├── entry_sheet.dart      # the add/edit bottom sheet + keypad
    ├── transaction_detail.dart
    ├── txn_row.dart          # shared transaction list row
    ├── logo_mark.dart        # the "S" app mark drawn via CustomPainter
    └── ui.dart               # small shared widgets + confirm dialog
branding/                     # SVG app icon + wordmark (light/dark)
test/widget_test.dart         # logic + widget tests
```

### Data model (`models.dart`)

- **`Txn`** — one income/expense entry: `date`, `type` (`expense`/`income`),
  `category` (or income source), `title`, `amount`, optional `split`, and
  `recurring` + `recurEvery` (`day`/`week`/`month`/`year`).
- **`Category`** — `key`, `label`, `color`.
- **`Currency`** — `code`, `symbol`, `locale`, indicative `rate`.
- **`Recurring`** — a template (`type`, `category`, `title`, `amount`) plus its
  `freq` and `anchor` (last posted date), used for auto-posting.
- **`Split`** — `total` + number of people.

### Persistence

All data (`transactions`, `income`, `cats`, `sources`, `recurring`) and prefs
(`currency`, `theme`, `name`, onboarding flag) are serialised to a single JSON
string under the `shared_preferences` key `exptrack_v3`, rewritten on every
mutation via `AppState._commit`.

### Recurring auto-posting

On every app open, `AppState._applyRecurring()` walks each recurring template and
posts any occurrences that have come due since its `anchor`, advancing the anchor
to the latest posted date (capped for safety). "Log now" in Settings remains a
manual shortcut.

---

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.41+ (Dart 3.11+)
- A device/emulator, or Chrome for web

### Run

```bash
flutter pub get
flutter run            # pick a device, or:
flutter run -d chrome  # web
flutter run -d windows # desktop
```

### Build

```bash
flutter build apk        # Android
flutter build appbundle  # Android (Play Store)
flutter build ios        # iOS (on macOS)
flutter build web        # Web
flutter build windows    # Windows
```

### Test & analyze

```bash
flutter analyze
flutter test
```

---

## Branding

Vector assets live in [`branding/`](branding/):

- `spendwise_icon.svg` — the app icon (bold "S" on the orange tile)
- `spendwise_logo.svg` / `spendwise_logo_dark.svg` — horizontal wordmark lockups

The in-app mark is also drawn natively by `LogoMark` (a dependency-free
`CustomPainter`), so the onboarding screen needs no SVG/raster asset.

> Note: the launcher icon and splash are not yet wired to the brand mark. To do
> so, export a PNG from the SVG and configure `flutter_launcher_icons` /
> `flutter_native_splash`.

---

## Notes & limitations

- **Offline-first / local-only** — there is no cloud sync; data lives on the device.
  Use CSV export for backups.
- **Currency conversion** uses fixed *indicative* rates (not live FX).
- **CSV** carries per-transaction rows; on import, categories, income sources and
  recurring templates are reconstructed from those rows (custom category colors
  are reassigned from the palette).
- Fonts are fetched at runtime by `google_fonts`; bundling Manrope as an asset is
  recommended for fully offline/cold-start use.

---

<div align="center">
SpendWise · v1.0 — built with Flutter
</div>
