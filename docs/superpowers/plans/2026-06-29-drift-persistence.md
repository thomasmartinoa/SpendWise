# Drift Persistence Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SpendWise's single-JSON-blob persistence with a Drift (SQLite) database behind a `SpendStore` interface, migrating existing on-device data once, without changing any UI or business logic.

**Architecture:** `AppState` keeps its in-memory model and all logic; it depends on an abstract `SpendStore` (load/save a `SpendSnapshot`). `DriftStore` (production, native SQLite via `drift_flutter`) and `MemoryStore` (tests) implement it. Saves are atomic snapshot replace-all; serialized so writes never race. Scalar prefs live in `shared_preferences` under their own keys. A one-time migration imports the legacy `exptrack_v3` blob.

**Tech Stack:** Flutter/Dart, Drift, drift_flutter, shared_preferences, provider.

## Global Constraints

- Persistence swap only — do NOT change UI, screens, or business logic (insights, recurring, CSV). Only the load/save layer and `AppState`'s persistence methods change.
- Add deps: `drift`, `drift_flutter` (runtime); `drift_dev`, `build_runner` (dev). Run `dart run build_runner build --delete-conflicting-outputs`; commit generated `lib/data/database.g.dart`.
- Drift tables: `Entries`, `Categories`, `Sources`, `RecurringItems`; `schemaVersion` = 1. Use `@DataClassName('EntryRow'|'CategoryRow'|'SourceRow'|'RecurringRow')` so generated row classes don't collide with the domain `Category` model and read cleanly.
- One `entries` table holds both expense and income, distinguished by the `type` column. On load, split into `transactions` (type `expense`) and `income` (type `income`).
- Prefs in `shared_preferences` keys: `pref_currency`, `pref_theme`, `pref_name`, `pref_onboarded`. Legacy blob key stays `exptrack_v3` (read-only, for migration; never deleted).
- Migration flag key: `drift_migrated` (bool). Migration is one-time and non-destructive.
- Native (mobile/desktop) runtime only. Web SQLite/WASM is out of scope. Per-row delta writes are out of scope (snapshot replace-all).
- The 25 existing tests must stay green. DriftStore/schema tests must skip gracefully (`markTestSkipped`) if `sqlite3` can't load on the test VM.
- Domain models (`Txn`, `Category`, `Recurring`, `Split`) are unchanged.

---

### Task 1: Drift dependencies, schema, and codegen

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/data/database.dart`
- Generated: `lib/data/database.g.dart` (via build_runner)
- Test: `test/data/database_test.dart`

**Interfaces:**
- Produces: `AppDatabase` (Drift database) with tables accessed as `db.entries`, `db.categories`, `db.sources`, `db.recurringItems`. Generated row classes: `EntryRow`, `CategoryRow`, `SourceRow`, `RecurringRow`. Companions: `EntriesCompanion`, `CategoriesCompanion`, `SourcesCompanion`, `RecurringItemsCompanion`. Constructor `AppDatabase([QueryExecutor? executor])` — defaults to `driftDatabase(name: 'spendwise')` for production, accepts `NativeDatabase.memory()` for tests.

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Under `dependencies:` (after the existing `path_provider: ^2.1.4` line), add:
```yaml
  # Local SQLite database
  drift: ^2.20.0
  drift_flutter: ^0.2.0
```
Under `dev_dependencies:` (after `flutter_lints:`), add:
```yaml
  drift_dev: ^2.20.0
  build_runner: ^2.4.13
```

- [ ] **Step 2: Run pub get**

Run: `flutter pub get`
Expected: resolves with drift packages added.

- [ ] **Step 3: Create the database schema**

Create `lib/data/database.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('EntryRow')
class Entries extends Table {
  IntColumn get id => integer()();
  TextColumn get date => text()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer()();
  IntColumn get splitTotal => integer().nullable()();
  IntColumn get splitCount => integer().nullable()();
  BoolColumn get recurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurEvery => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get key => text()();
  TextColumn get label => text()();
  IntColumn get color => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {name};
}

@DataClassName('RecurringRow')
class RecurringItems extends Table {
  IntColumn get id => integer()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer()();
  TextColumn get freq => text()();
  TextColumn get anchor => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Entries, Categories, Sources, RecurringItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'spendwise'));

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 4: Generate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `[INFO] Succeeded`, creates `lib/data/database.g.dart`.

- [ ] **Step 5: Write the schema test**

Create `test/data/database_test.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/data/database.dart';

void main() {
  test('AppDatabase stores and reads an entry row', () async {
    late AppDatabase db;
    try {
      db = AppDatabase(NativeDatabase.memory());
      await db.select(db.entries).get(); // force-open; throws if sqlite3 absent
    } catch (e) {
      markTestSkipped('sqlite3 not loadable on this VM: $e');
      return;
    }

    await db.into(db.entries).insert(EntriesCompanion.insert(
          id: 1,
          date: '2026-06-29',
          type: 'expense',
          category: 'Food',
          title: 'Lunch',
          amount: 100,
        ));
    final rows = await db.select(db.entries).get();
    expect(rows, hasLength(1));
    expect(rows.first.amount, 100);
    expect(rows.first.category, 'Food');
    await db.close();
  });
}
```

- [ ] **Step 6: Run the test**

Run: `flutter test test/data/database_test.dart`
Expected: PASS (or "skipped" with the sqlite3 message — both acceptable).

- [ ] **Step 7: Verify analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/database.dart lib/data/database.g.dart test/data/database_test.dart
git commit -m "feat: add Drift database schema (entries/categories/sources/recurring)"
```

---

### Task 2: SpendStore interface, SpendSnapshot, MemoryStore

**Files:**
- Create: `lib/data/spend_store.dart`
- Create: `lib/data/memory_store.dart`
- Test: `test/data/memory_store_test.dart`

**Interfaces:**
- Consumes: domain models `Txn`, `Category`, `Recurring` from `lib/models.dart`.
- Produces:
  - `class SpendSnapshot` with fields `List<Txn> entries`, `List<Category> categories`, `List<String> sources`, `List<Recurring> recurring` (all `final`, const constructor with named required params).
  - `abstract class SpendStore { Future<SpendSnapshot> load(); Future<void> save(SpendSnapshot snapshot); }`
  - `class MemoryStore implements SpendStore` — holds the last saved snapshot in memory.

- [ ] **Step 1: Write the MemoryStore test**

Create `test/data/memory_store_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/data/memory_store.dart';
import 'package:spendwise/data/spend_store.dart';
import 'package:spendwise/models.dart';

void main() {
  test('MemoryStore round-trips a snapshot', () async {
    final store = MemoryStore();
    final snap = SpendSnapshot(
      entries: const [
        Txn(id: 1, date: '2026-06-29', type: 'expense', category: 'Food', title: 'Lunch', amount: 100),
      ],
      categories: const [Category(key: 'Food', label: 'Food', color: Color(0xFFE0533D))],
      sources: const ['Salary'],
      recurring: const [],
    );
    await store.save(snap);
    final loaded = await store.load();
    expect(loaded.entries, hasLength(1));
    expect(loaded.entries.first.category, 'Food');
    expect(loaded.categories.first.key, 'Food');
    expect(loaded.sources, ['Salary']);
  });

  test('MemoryStore starts empty', () async {
    final loaded = await MemoryStore().load();
    expect(loaded.entries, isEmpty);
    expect(loaded.categories, isEmpty);
    expect(loaded.sources, isEmpty);
    expect(loaded.recurring, isEmpty);
  });
}
```
(`Color` comes from `package:flutter/material.dart`, imported above.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/memory_store_test.dart`
Expected: FAIL — `spend_store.dart` / `memory_store.dart` not found.

- [ ] **Step 3: Create the store interface**

Create `lib/data/spend_store.dart`:
```dart
import '../models.dart';

/// A complete snapshot of the app's relational data (everything except the
/// scalar preferences, which live in shared_preferences). `entries` holds both
/// expenses and income — the `type` field distinguishes them.
class SpendSnapshot {
  final List<Txn> entries;
  final List<Category> categories;
  final List<String> sources;
  final List<Recurring> recurring;
  const SpendSnapshot({
    required this.entries,
    required this.categories,
    required this.sources,
    required this.recurring,
  });
}

/// Persistence boundary. Implemented by DriftStore (production) and
/// MemoryStore (tests / fallback).
abstract class SpendStore {
  Future<SpendSnapshot> load();
  Future<void> save(SpendSnapshot snapshot);
}
```

- [ ] **Step 4: Create MemoryStore**

Create `lib/data/memory_store.dart`:
```dart
import 'spend_store.dart';

/// In-memory SpendStore. Used by unit tests and as a safe fallback.
class MemoryStore implements SpendStore {
  SpendSnapshot _data = const SpendSnapshot(
    entries: [],
    categories: [],
    sources: [],
    recurring: [],
  );

  @override
  Future<SpendSnapshot> load() async => _data;

  @override
  Future<void> save(SpendSnapshot snapshot) async {
    _data = snapshot;
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/memory_store_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/spend_store.dart lib/data/memory_store.dart test/data/memory_store_test.dart
git commit -m "feat: add SpendStore interface, SpendSnapshot, and MemoryStore"
```

---

### Task 3: Mappers + DriftStore

**Files:**
- Create: `lib/data/mappers.dart`
- Create: `lib/data/drift_store.dart`
- Test: `test/data/drift_store_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` + row classes (Task 1); `SpendStore`/`SpendSnapshot` (Task 2); models.
- Produces:
  - `mappers.dart`: `Txn entryRowToTxn(EntryRow r)`, `EntriesCompanion txnToEntryCompanion(Txn t)`, `Category categoryRowToCategory(CategoryRow r)`, `CategoriesCompanion categoryToCompanion(Category c)`, `Recurring recurringRowToRecurring(RecurringRow r)`, `RecurringItemsCompanion recurringToCompanion(Recurring r)`.
  - `class DriftStore implements SpendStore` with constructor `DriftStore(this.db)` taking an `AppDatabase`.

- [ ] **Step 1: Write the DriftStore test**

Create `test/data/drift_store_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:spendwise/data/database.dart';
import 'package:spendwise/data/drift_store.dart';
import 'package:spendwise/data/spend_store.dart';
import 'package:spendwise/models.dart';

void main() {
  test('DriftStore round-trips a snapshot via SQLite', () async {
    late AppDatabase db;
    try {
      db = AppDatabase(NativeDatabase.memory());
      await db.select(db.entries).get();
    } catch (e) {
      markTestSkipped('sqlite3 not loadable on this VM: $e');
      return;
    }
    final store = DriftStore(db);

    final snap = SpendSnapshot(
      entries: const [
        Txn(id: 1, date: '2026-06-29', type: 'expense', category: 'Food', title: 'Lunch', amount: 100, split: Split(total: 400, count: 4)),
        Txn(id: 2, date: '2026-06-28', type: 'income', category: 'Salary', title: 'Pay', amount: 5000, recurring: true, recurEvery: 'month'),
      ],
      categories: const [Category(key: 'Food', label: 'Food', color: Color(0xFFE0533D))],
      sources: const ['Salary'],
      recurring: const [Recurring(id: 9, type: 'income', category: 'Salary', title: 'Pay', amount: 5000, freq: 'month', anchor: '2026-06-28')],
    );
    await store.save(snap);

    final loaded = await store.load();
    expect(loaded.entries, hasLength(2));
    final exp = loaded.entries.firstWhere((e) => e.type == 'expense');
    expect(exp.split?.total, 400);
    expect(exp.split?.count, 4);
    final inc = loaded.entries.firstWhere((e) => e.type == 'income');
    expect(inc.recurring, isTrue);
    expect(inc.recurEvery, 'month');
    expect(loaded.categories.single.key, 'Food');
    expect(loaded.sources, ['Salary']);
    expect(loaded.recurring.single.freq, 'month');

    // save again replaces (not appends)
    await store.save(const SpendSnapshot(entries: [], categories: [], sources: [], recurring: []));
    final empty = await store.load();
    expect(empty.entries, isEmpty);

    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/drift_store_test.dart`
Expected: FAIL — `drift_store.dart` / `mappers.dart` not found (or skip if no sqlite3).

- [ ] **Step 3: Create the mappers**

Create `lib/data/mappers.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color;

import '../models.dart';
import 'database.dart';

Txn entryRowToTxn(EntryRow r) => Txn(
      id: r.id,
      date: r.date,
      type: r.type,
      category: r.category,
      title: r.title,
      amount: r.amount,
      split: r.splitTotal != null
          ? Split(total: r.splitTotal!, count: r.splitCount ?? 1)
          : null,
      recurring: r.recurring,
      recurEvery: r.recurEvery,
    );

EntriesCompanion txnToEntryCompanion(Txn t) => EntriesCompanion.insert(
      id: t.id,
      date: t.date,
      type: t.type,
      category: t.category,
      title: t.title,
      amount: t.amount,
      splitTotal: Value(t.split?.total),
      splitCount: Value(t.split?.count),
      recurring: Value(t.recurring),
      recurEvery: Value(t.recurEvery),
    );

Category categoryRowToCategory(CategoryRow r) =>
    Category(key: r.key, label: r.label, color: Color(r.color));

CategoriesCompanion categoryToCompanion(Category c) => CategoriesCompanion.insert(
      key: c.key,
      label: c.label,
      color: c.color.toARGB32(),
    );

Recurring recurringRowToRecurring(RecurringRow r) => Recurring(
      id: r.id,
      type: r.type,
      category: r.category,
      title: r.title,
      amount: r.amount,
      freq: r.freq,
      anchor: r.anchor,
    );

RecurringItemsCompanion recurringToCompanion(Recurring r) =>
    RecurringItemsCompanion.insert(
      id: r.id,
      type: r.type,
      category: r.category,
      title: r.title,
      amount: r.amount,
      freq: r.freq,
      anchor: r.anchor,
    );
```

- [ ] **Step 4: Create DriftStore**

Create `lib/data/drift_store.dart`:
```dart
import 'package:drift/drift.dart';

import 'database.dart';
import 'mappers.dart';
import 'spend_store.dart';

/// SpendStore backed by SQLite. `save` replaces all four tables in a single
/// transaction (snapshot semantics) and serializes overlapping writes so a
/// slower write can never clobber a newer snapshot.
class DriftStore implements SpendStore {
  final AppDatabase db;
  DriftStore(this.db);

  bool _writing = false;
  SpendSnapshot? _pending;

  @override
  Future<SpendSnapshot> load() async {
    final entries = await db.select(db.entries).get();
    final cats = await db.select(db.categories).get();
    final srcs = await db.select(db.sources).get();
    final recs = await db.select(db.recurringItems).get();
    return SpendSnapshot(
      entries: entries.map(entryRowToTxn).toList(),
      categories: cats.map(categoryRowToCategory).toList(),
      sources: srcs.map((s) => s.name).toList(),
      recurring: recs.map(recurringRowToRecurring).toList(),
    );
  }

  @override
  Future<void> save(SpendSnapshot snapshot) async {
    _pending = snapshot;
    if (_writing) return; // an in-flight write will pick up _pending
    _writing = true;
    try {
      while (_pending != null) {
        final snap = _pending!;
        _pending = null;
        await db.transaction(() async {
          await db.delete(db.entries).go();
          await db.delete(db.categories).go();
          await db.delete(db.sources).go();
          await db.delete(db.recurringItems).go();
          await db.batch((b) {
            b.insertAll(db.entries, snap.entries.map(txnToEntryCompanion).toList());
            b.insertAll(db.categories, snap.categories.map(categoryToCompanion).toList());
            b.insertAll(db.sources,
                snap.sources.map((s) => SourcesCompanion.insert(name: s)).toList());
            b.insertAll(db.recurringItems,
                snap.recurring.map(recurringToCompanion).toList());
          });
        });
      }
    } finally {
      _writing = false;
    }
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/drift_store_test.dart`
Expected: PASS (or skip if no sqlite3).

- [ ] **Step 6: Verify analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/data/mappers.dart lib/data/drift_store.dart test/data/drift_store_test.dart
git commit -m "feat: add Drift row mappers and DriftStore (transactional snapshot save)"
```

---

### Task 4: AppState integration — store injection, load + migration, prefs split

**Files:**
- Modify: `lib/app_state.dart` (constructor; `load`; `_persist`; `_commit`; `resetAll`; add `_savePrefs`, `_migrateLegacy`)
- Test: `test/widget_test.dart` (add 2 tests)

**Interfaces:**
- Consumes: `SpendStore`, `SpendSnapshot`, `MemoryStore` (Tasks 2/3).
- Produces: `AppState({SpendStore? store})` — `store` defaults to `MemoryStore()`. Persistence now flows through `store`; prefs through individual `shared_preferences` keys; legacy blob imported once.

- [ ] **Step 1: Write the two new tests**

In `test/widget_test.dart`, inside `main()`, after the existing `'AppState logic'` group's tests but still inside that group (before the group's closing `});`), add:
```dart
    test('persists entries through an injected store and reloads them', () async {
      final store = MemoryStore();
      final a = AppState(store: store);
      a.openEntry('expense', false);
      a.cat = 'Food';
      a.amount = '321';
      a.save();
      // a fresh AppState on the same store should see the saved entry
      final b = AppState(store: store);
      await b.load();
      expect(b.transactions.any((t) => t.amount == 321), isTrue);
    });

    test('migrates the legacy exptrack_v3 blob into the store + prefs', () async {
      SharedPreferences.setMockInitialValues({
        'exptrack_v3': jsonEncode({
          'transactions': [
            {'id': 1, 'date': '2026-06-20', 'type': 'expense', 'category': 'Gym', 'title': 'Pass', 'amount': 200},
          ],
          'income': <dynamic>[],
          'cats': [
            {'key': 'Gym', 'label': 'Gym', 'color': 0xFF2A6FDB},
          ],
          'sources': ['Salary'],
          'recurring': <dynamic>[],
          'currency': 'USD',
          'theme': 'dark',
          'name': 'Thomas',
          'onboarded': true,
        }),
      });
      final app = AppState(store: MemoryStore());
      await app.load();

      expect(app.transactions.any((t) => t.category == 'Gym'), isTrue);
      expect(app.cats.any((c) => c.key == 'Gym'), isTrue);
      expect(app.currencyCode, 'USD');
      expect(app.themeMode, 'dark');
      expect(app.name, 'Thomas');
      expect(app.onboardingComplete, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('drift_migrated'), isTrue);
    });
```
(`dart:convert` and `shared_preferences` are already imported in this test file. Add exactly one import — `import 'package:spendwise/data/memory_store.dart';` — since only `MemoryStore` is referenced. Do NOT import `spend_store.dart` here; it would be an unused import and fail analyze.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --plain-name "persists entries through an injected store"`
Expected: FAIL — `AppState` has no `store` parameter / `MemoryStore` unresolved.

- [ ] **Step 3: Add imports and the store field/constructor param**

In `lib/app_state.dart`, add these imports near the top (after `import 'models.dart';`):
```dart
import 'data/memory_store.dart';
import 'data/spend_store.dart';
```
Change the constructor signature from:
```dart
  AppState() {
```
to:
```dart
  final SpendStore store;

  AppState({SpendStore? store}) : store = store ?? MemoryStore() {
```
(Leave the constructor body exactly as-is.)

- [ ] **Step 4: Replace `load()` with the store + migration version**

Replace the entire existing `Future<void> load() async { ... }` method with:
```dart
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // one-time migration from the legacy JSON blob
      if (prefs.getBool('drift_migrated') != true) {
        await _migrateLegacy(prefs);
        await prefs.setBool('drift_migrated', true);
      }

      // data from the store
      final snap = await store.load();
      transactions = snap.entries.where((t) => t.type == 'expense').toList();
      income = snap.entries.where((t) => t.type == 'income').toList();
      if (snap.categories.isNotEmpty) cats = snap.categories;
      if (snap.sources.isNotEmpty) sources = snap.sources;
      recurring = snap.recurring;

      // scalar prefs
      final cur = prefs.getString('pref_currency');
      if (cur != null) currencyCode = cur;
      final th = prefs.getString('pref_theme');
      if (th != null) themeMode = (th == 'light' || th == 'dark') ? th : 'system';
      final nm = prefs.getString('pref_name');
      if (nm != null) name = nm;
      if (prefs.getBool('pref_onboarded') == true) onboardingComplete = true;
    } catch (_) {/* ignore corrupt store */}
    _applyRecurring(); // post any occurrences due since the last open
    notifyListeners();
  }

  /// One-time import of the pre-Drift `exptrack_v3` JSON blob. Writes data
  /// through the store and prefs through their new keys. Non-destructive: the
  /// legacy blob is left in place as a backup.
  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_storeKey);
      if (raw == null) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final entries = <Txn>[];
      if (d['transactions'] is List) {
        entries.addAll((d['transactions'] as List)
            .map((e) => Txn.fromJson((e as Map).cast<String, dynamic>())));
      }
      if (d['income'] is List) {
        entries.addAll((d['income'] as List)
            .map((e) => Txn.fromJson((e as Map).cast<String, dynamic>())));
      }
      final cats2 = d['cats'] is List
          ? (d['cats'] as List)
              .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
              .toList()
          : kDefaultCats.map((c) => c).toList();
      final src2 = d['sources'] is List
          ? (d['sources'] as List).map((e) => e.toString()).toList()
          : List<String>.from(kDefaultSources);
      final rec2 = d['recurring'] is List
          ? (d['recurring'] as List)
              .map((e) => Recurring.fromJson((e as Map).cast<String, dynamic>()))
              .toList()
          : <Recurring>[];
      await store.save(SpendSnapshot(
          entries: entries, categories: cats2, sources: src2, recurring: rec2));

      if (d['currency'] is String) {
        await prefs.setString('pref_currency', d['currency'] as String);
      }
      if (d['theme'] is String) {
        final t = d['theme'] as String;
        await prefs.setString('pref_theme', (t == 'light' || t == 'dark') ? t : 'system');
      }
      if (d['name'] is String) {
        await prefs.setString('pref_name', d['name'] as String);
      }
      if (d['onboarded'] == true) {
        await prefs.setBool('pref_onboarded', true);
      }
    } catch (_) {/* ignore corrupt legacy blob */}
  }
```

- [ ] **Step 5: Replace `_persist()` and update `_commit()`; add `_savePrefs()`**

Replace the entire existing `Future<void> _persist() async { ... }` method with:
```dart
  void _persist() {
    // fire-and-forget; the store serializes overlapping writes
    store.save(SpendSnapshot(
      entries: [...transactions, ...income],
      categories: cats,
      sources: sources,
      recurring: recurring,
    ));
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_currency', currencyCode);
      await prefs.setString('pref_theme', themeMode);
      await prefs.setString('pref_name', name);
      await prefs.setBool('pref_onboarded', onboardingComplete);
    } catch (_) {}
  }
```
Then update `_commit` from:
```dart
  void _commit(VoidCallback mutate) {
    mutate();
    _persist();
    notifyListeners();
  }
```
to:
```dart
  void _commit(VoidCallback mutate) {
    mutate();
    _persist();
    _savePrefs();
    notifyListeners();
  }
```

- [ ] **Step 6: Update `resetAll()` to clear the store + prefs**

Replace the body of `resetAll()` (the part from the `try {` block that removes `_storeKey`) so the whole method reads:
```dart
  Future<void> resetAll() async {
    transactions = [];
    income = [];
    recurring = [];
    cats = kDefaultCats.map((c) => c).toList();
    sources = List<String>.from(kDefaultSources);
    name = '';
    currencyCode = 'INR';
    themeMode = 'system';
    onboardingComplete = false;
    screen = 'home';
    await store.save(SpendSnapshot(
        entries: const [], categories: cats, sources: sources, recurring: const []));
    await _savePrefs();
    notifyListeners();
  }
```
(Removes the old `prefs.remove(_storeKey)` — the legacy blob stays as backup; `drift_migrated` stays set so reset never re-imports it.)

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: PASS — all existing tests plus the 2 new ones (29 total; the legacy-blob tests now pass via the migration path).

- [ ] **Step 8: Verify analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 9: Commit**

```bash
git add lib/app_state.dart test/widget_test.dart
git commit -m "feat: route AppState persistence through SpendStore + migrate legacy blob"
```

---

### Task 5: Wire DriftStore in main.dart + final verification

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 1), `DriftStore` (Task 3), `AppState({SpendStore? store})` (Task 4).

- [ ] **Step 1: Wire the production store**

In `lib/main.dart`, add imports (after `import 'app_state.dart';`):
```dart
import 'data/database.dart';
import 'data/drift_store.dart';
```
Replace the body of `main()`:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  await app.load();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const SpendWiseApp(),
    ),
  );
}
```
with:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DriftStore(AppDatabase());
  final app = AppState(store: store);
  await app.load();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const SpendWiseApp(),
    ),
  );
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS (all tests; DriftStore/schema tests pass or skip).

- [ ] **Step 4: Verify the app compiles (best-effort, non-gating)**

The hard gates are `flutter analyze` (Step 2) and `flutter test` (Step 3). As an
extra compile check, run `flutter build web`. Expected: `√ Built build/web`
(compiles; DriftStore won't run on web at runtime — out of scope). If the web
build fails for a web-SQLite/WASM reason, that is acceptable and non-blocking;
note it and rely on a native build / device install for runtime confirmation.
If `flutter build apk --debug` is available, prefer it as the native compile check.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: open DriftStore on startup (production persistence)"
```

---

## Verification (whole feature)

- `dart run build_runner build --delete-conflicting-outputs` succeeds and `database.g.dart` is committed.
- `flutter analyze` clean.
- `flutter test` green: 25 existing + MemoryStore (2) + AppState store/migration (2) tests; DriftStore + schema round-trip tests pass where sqlite3 loads, else skip.
- `flutter build web` compiles.
- Manual device smoke (real runtime DB): install over an existing build → confirm prior data is present (migration), add an entry, force-quit, reopen → entry persists.
