# Drift Persistence Migration — Design

**Date:** 2026-06-29
**Status:** Approved (design)
**Scope:** Replace the JSON-blob persistence layer with a Drift (SQLite) database, behind a store interface. The in-memory `AppState` model, all UI, and all business logic (insights, recurring, CSV) stay unchanged.

## Context

SpendWise currently persists everything as a single JSON string in
`shared_preferences` under the key `exptrack_v3`. `AppState` (a `ChangeNotifier`)
holds all data in memory and rewrites that whole blob on every `_commit`. This
works but is fragile (one malformed blob loses everything), unstructured, and
not a foundation for future querying or sync.

We are introducing **Drift** as a proper relational store. Decisions confirmed
with the user:

- **Persistence swap**, not a reactive rewrite: keep `AppState`'s in-memory
  model and all logic; only the load/save layer changes.
- **Preferences** (`currency`, `theme`, `name`, `onboarded`) stay in
  `shared_preferences` (their own keys). Drift holds only relational records.
- **Platforms**: native mobile + desktop (Android/iOS/Windows) via
  `drift_flutter`. `flutter build web` still compiles, but the DB is **not**
  wired for the browser runtime (web SQLite/WASM is out of scope).

## Goals

- Move transactions, income, categories, sources, and recurring templates into
  a typed, transactional SQLite database.
- Preserve every existing behavior and all 25 tests.
- Migrate existing on-device data (the legacy `exptrack_v3` blob) automatically
  on first launch, without data loss.
- Introduce a clean persistence seam so unit tests need no native SQLite.

## Architecture

A `SpendStore` interface decouples `AppState` from the storage backend:

```
AppState (in-memory lists + all logic, unchanged)
   │  load() → SpendSnapshot ;  save(SpendSnapshot)
   ▼
abstract SpendStore
   ├── DriftStore   → real SQLite via drift_flutter (production)
   └── MemoryStore  → pure-Dart map (unit tests / fallback)
```

- **Load:** `store.load()` returns a `SpendSnapshot` (entries, categories,
  sources, recurring). `AppState` fills its lists, splitting `entries` into
  `transactions` (type `expense`) and `income` (type `income`).
- **Save:** the existing `_commit` calls `store.save(snapshot)` where the
  snapshot is built from current in-memory lists. `DriftStore.save` runs an
  **atomic transaction** that replaces all four tables (snapshot/replace-all).
  This matches today's "rewrite on every change" semantics but is transactional
  and structured.
- **Serialized writes:** `DriftStore` serializes saves (a write-in-progress
  guard that re-runs if a newer snapshot arrived) so overlapping async writes
  never race to a stale result.

Per-row delta writes are a deliberate **future optimization**, out of scope.

### `SpendSnapshot`

A plain value type holding `List<Txn> entries`, `List<Category> categories`,
`List<String> sources`, `List<Recurring> recurring`. (Prefs are NOT part of the
snapshot — they live in `shared_preferences`.)

## Schema (Drift)

Four tables in `lib/data/database.dart`:

- **entries** — `id` (int PK), `date` (text), `type` (text: `expense`|`income`),
  `category` (text), `title` (text), `amount` (int), `splitTotal` (int, nullable),
  `splitCount` (int, nullable), `recurring` (bool), `recurEvery` (text, nullable).
  One table for both `transactions` and `income`; the `type` column distinguishes
  them and load filters into the two lists.
- **categories** — `key` (text PK), `label` (text), `color` (int).
- **sources** — `name` (text PK).
- **recurringItems** — `id` (int PK), `type` (text), `category` (text),
  `title` (text), `amount` (int), `freq` (text), `anchor` (text).

Schema version starts at 1. The domain models (`Txn`, `Category`, `Recurring`)
are unchanged; thin mapper functions in `lib/data/mappers.dart` convert Drift
rows ↔ domain models so the rest of the app is untouched.

## Preferences

`currency`, `theme`, `name`, `onboarded` are read/written by `AppState` as
individual `shared_preferences` keys: `pref_currency`, `pref_theme`,
`pref_name`, `pref_onboarded`. `AppState` persists a pref immediately when it
changes (a small `_savePrefs()` helper).

## One-time migration

On startup, before normal load:

1. If `shared_preferences` flag `drift_migrated` is already `true`, skip.
2. Else, read the legacy `exptrack_v3` JSON blob. If present and parseable:
   - Build a `SpendSnapshot` from its `transactions`+`income`, `cats`,
     `sources`, `recurring` (reusing the existing `fromJson` constructors) and
     call `store.save(snapshot)` — so migration goes through the same store seam
     and is testable with `MemoryStore`.
   - Write its `currency`/`theme`/`name`/`onboarded` values to the new pref keys.
3. Set `drift_migrated = true`. **Leave the legacy blob untouched** as a backup
   (do not delete).

`load()` then proceeds with the normal `store.load()` path, so migrated data is
read straight back into the in-memory lists.

This guarantees existing users keep their data and settings after upgrading.
A fresh install (no legacy blob) simply starts empty with default categories +
sources, exactly as today.

## AppState changes

- Constructor gains an injected store: `AppState({SpendStore? store})`,
  defaulting to `MemoryStore()` when null (so existing test construction barely
  changes; production injects `DriftStore`).
- `load()`: run migration check → `store.load()` → fill lists; read prefs from
  the new keys; then run the existing `_applyRecurring()`; `notifyListeners()`.
- `_persist()`: build a `SpendSnapshot` and call `store.save(...)`
  (fire-and-forget, serialized inside the store). Pref changes call
  `_savePrefs()` instead.
- No change to any other method (`save`, `remove`, `importCsv`, recurring,
  insights aggregations, etc.) — they mutate the in-memory lists and the
  unchanged `_commit` path persists them.

## main.dart

Open the Drift database and construct `DriftStore` before `runApp`, pass it to
`AppState`, then `await app.load()` (as today).

## File structure

- Create: `lib/data/database.dart` (+ generated `database.g.dart`),
  `lib/data/spend_store.dart` (interface + `SpendSnapshot`),
  `lib/data/drift_store.dart`, `lib/data/memory_store.dart`,
  `lib/data/mappers.dart`.
- Modify: `lib/app_state.dart` (store injection, load/save/prefs/migration),
  `lib/main.dart`, `pubspec.yaml`, `test/widget_test.dart` (store/prefs setup).

## Dependencies & codegen

- Runtime: `drift`, `drift_flutter`.
- Dev: `drift_dev`, `build_runner`.
- Generate with `dart run build_runner build --delete-conflicting-outputs`;
  commit `database.g.dart`.

## Testing

- The 25 existing tests inject `MemoryStore` (default), needing no native
  SQLite — they stay fast and unchanged in spirit. Tests that assert pref
  behavior (theme migration, onboarding) set the new pref keys / legacy blob via
  `SharedPreferences.setMockInitialValues`.
- New tests:
  - `DriftStore` round-trip: save a snapshot, reload, assert equality — using
    Drift's in-memory `NativeDatabase` (skipped gracefully if the test VM lacks
    a loadable `sqlite3`).
  - Migration: seed a legacy `exptrack_v3` blob, construct `AppState` with a
    `MemoryStore`, `load()`, assert data + prefs migrated and `drift_migrated`
    flag set.

## Verification

`flutter analyze` clean · `flutter test` green (25 existing + new store/migration
tests) · `dart run build_runner build` succeeds · `flutter build apk` (or
`flutter build windows`) compiles · manual smoke: existing data survives an
upgrade; new entries persist across restarts.

## Out of scope

- Web/WASM SQLite runtime.
- Per-row delta writes (snapshot replace-all for now).
- Reactive Drift streams to the UI.
- Any schema beyond the four tables (no sync metadata yet).
