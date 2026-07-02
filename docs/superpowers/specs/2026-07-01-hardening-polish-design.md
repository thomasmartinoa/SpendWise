# Hardening & Polish — Design

**Date:** 2026-07-01
**Status:** Approved (design)
**Scope:** Bug fixes, data-safety, two UI fixes, and a low-risk refactor. Local single-user app; no cloud, no app-lock (deferred).

## Context

Review of the current app surfaced a real bug (currency conversion is lossy/one-way and wipes recurring schedules), no lossless backup, a 1024-line `app_state.dart`, a donut where same-coloured slices merge, and a congested Settings screen. This batch addresses all of it.

Decisions confirmed with the user:
- **Currency = display-only** (never rewrite amounts).
- **App lock = skipped** for now.
- **Backup = add lossless JSON** export/import (keep CSV) + a "last backed up" reminder.
- **Refactor = light, zero-behaviour-change** (`part` files).
- **Settings = move heavy sections to sub-pages.**
- **Donut = add a small gap/separator** between slices; new categories default to an unused colour.

## 1. Currency becomes display-only

`AppState.setCurrency(code)` becomes just `_commit(() => currencyCode = code)` — delete the rate-conversion block entirely. `fmt`/`fmtType` already format via the selected currency's symbol + locale, so amounts stay exactly as entered and switching is instant, reversible, and non-destructive. Side effect: the recurring `freq`/`anchor`-loss bug disappears (nothing is rewritten). `Currency.rate` stays as an unused field with a `// unused: currency is display-only` comment. The Settings currency caption changes from "Converts all amounts at indicative rates" to **"Sets the currency symbol used across the app."**

## 2. Persistence errors visible in dev

The `catch (_) {}` blocks in `load()`, `_savePrefs()`, `_migrateLegacy()`, and `resetAll()` become `catch (e) { if (kDebugMode) debugPrint('SpendWise <op>: $e'); }` (`kDebugMode`/`debugPrint` come via the existing `package:flutter/material.dart` import). Release behaviour is unchanged — still never crashes.

## 3. Lossless JSON backup + reminder

**Pure, testable core on `AppState`:**
- `Map<String, dynamic> backupMap()` — `{transactions, income, cats, sources, recurring, currency, theme, name}` using the models' existing `toJson`. (Same shape as the legacy blob.)
- `void restoreFromBackup(Map<String, dynamic> d)` — rebuilds the lists (reusing `Txn.fromJson`, `Category.fromJson`, `Recurring.fromJson`) + prefs from the map, assigns state, persists (store + prefs), `notifyListeners()`. Type-guarded per field; ignores malformed entries.
- `String? lastBackup` (ISO datetime) loaded from pref key `pref_last_backup`; `void markBackedUp()` sets it to `DateTime.now().toIso8601String()`, persists, notifies. `load()` reads it; `_savePrefs()` writes it when non-null.

**IO wrapper — `lib/backup_io.dart`:**
- `Future<void> exportJson(AppState app)` — `jsonEncode(app.backupMap())` → temp file → `Share.shareXFiles` (mirrors the existing CSV export in `csv_io.dart`); calls `app.markBackedUp()` on success.
- `Future<bool?> importJson(AppState app)` — `FilePicker` (`.json`, `withData: true`) → decode → `app.restoreFromBackup(map)`; returns `null` if cancelled, `true`/`false` on success/parse-failure.
- The existing `exportCsv` also calls `app.markBackedUp()`.

**UI:** on the Backup sub-page (see §5): rows **Export CSV**, **Import CSV**, **Export backup (JSON)**, **Restore backup (JSON)**, each behind the existing confirm dialog for the destructive import; plus a status line **"Last backup: 3 days ago"** (or "Never backed up." in `Brand.accent`). The main Settings "Backup" nav row shows the same as a subtitle.

## 4. Donut slice separation + smart default colour

In `lib/widgets/charts/category_donut_card.dart`, each `PieChartSectionData` gains `borderSide: BorderSide(color: c.card, width: 2)` and `sectionsSpace` goes `2 → 3`. The card-coloured border draws a clean gap between adjacent slices so same-coloured categories no longer visually merge.

Root-cause guard: `AppState.firstUnusedCatColor()` returns the first `kPalette` colour not already used by a category (fallback `kPalette.first`). The Categories screen sets `newCatColor = firstUnusedCatColor()` when it opens, and `addCat()` resets `newCatColor` to `firstUnusedCatColor()` after adding — so a new category no longer defaults to Food's red.

## 5. Settings → sub-pages

Heavy management sections move out of `settings_screen.dart` into their own pushed screens under `lib/screens/settings/`:
- `categories_screen.dart` (`CategoriesScreen`) — the expense-category list + palette + add field.
- `sources_screen.dart` (`SourcesScreen`) — income sources list + add field.
- `recurring_screen.dart` (`RecurringScreen`) — recurring items list (+ "Log now"/delete).
- `backup_screen.dart` (`BackupScreen`) — the CSV + JSON rows + last-backup line (§3).

Each is a `Scaffold(appBar: AppBar(title, back), body: <moved UI>)`, reads `AppState` via `context.watch` (provider is above the `MaterialApp` Navigator, so pushed routes see it), and reuses the existing small widgets (`_MiniBox`, `_DeleteX`, `_AddButton`, `SoftField`, etc.) — the shared settings-specific ones (`_MiniBox`, `_DeleteX`, `_AddButton`) move to a new `lib/screens/settings/settings_widgets.dart` as public widgets (`MiniBox`, `DeleteX`, `AddButton`) imported by the sub-pages; `SoftField` already lives in `lib/widgets/ui.dart`.

`SettingsScreen` becomes a short list: Profile · Appearance · Insights toggles · Currency (collapsed row) · then a group of nav rows — **Categories ›**, **Income sources ›**, **Recurring ›**, **Backup ›** (each with a count/status subtitle) — · version footer. A reusable `_NavRow(icon, label, subtitle?, onTap)` renders each; `onTap` does `Navigator.push(MaterialPageRoute(builder: (_) => const XScreen()))`.

## 6. Light refactor (zero behaviour change)

`app_state.dart` gains `part 'app_state_insights.dart';` and `part 'app_state_csv.dart';`. Two cohesive, externally-called method groups move into those part files as single extensions on `AppState` (same library ⇒ private members like `_pad`/`_now`/`_commit` remain accessible; call sites are unchanged):
- `app_state_insights.dart` → `extension AppStateInsights on AppState` with `categoryBreakdown`, `monthlyTotals`, `dailyTotals`, `insightStats`, `dayEntryCount`, and the month/derived views (`monthTx`, `monthInc`, `monthIncome`, `monthSpent`, `sortDesc`, `groupOf`, `row`, `greeting`) — keep any interdependent members together in the one extension so sibling calls resolve.
- `app_state_csv.dart` → `extension AppStateCsv on AppState` with `buildCsv`, `parseCsvLine`, `importCsv`.

Part files carry no imports of their own (they inherit the library's). Net: `app_state.dart` shrinks ~200 lines. The 42-test suite is the behavioural guard; the compiler flags any resolution gap (add `this.`), and `flutter analyze` must stay clean.

## File structure

- Create: `lib/backup_io.dart`, `lib/app_state_insights.dart`, `lib/app_state_csv.dart`, `lib/screens/settings/settings_widgets.dart`, `lib/screens/settings/categories_screen.dart`, `sources_screen.dart`, `recurring_screen.dart`, `backup_screen.dart`.
- Modify: `lib/app_state.dart`, `lib/screens/settings_screen.dart`, `lib/widgets/charts/category_donut_card.dart`, `lib/csv_io.dart`, `lib/widgets/ui.dart` (shared settings widgets), `test/widget_test.dart`.

## Testing

- Currency: rewrite the existing conversion test to assert **amounts unchanged** after `setCurrency('USD')` (and `currencyCode == 'USD'`).
- Backup: `backupMap()` → new `AppState` → `restoreFromBackup(...)` round-trips transactions, income, categories (incl. colour), sources, recurring (incl. `freq`/`anchor`), and prefs.
- `firstUnusedCatColor()` returns a colour not among existing categories; `addCat` uses it.
- Widget: tapping the "Categories" nav row pushes `CategoriesScreen` (`find.byType` after tap).
- Refactor: guarded by the full existing suite (no new test; behaviour identical).

## Verification

`flutter analyze` clean · `flutter test` green (existing + new) · `flutter build web` compiles · manual: switch currency (amounts unchanged, symbol changes); export/import JSON round-trips; donut slices visually separated; Settings is a short list with working sub-pages.

## Out of scope

- App lock / encryption, cloud sync, budgets/goals, base-currency conversion, deeper state-management restructure.
