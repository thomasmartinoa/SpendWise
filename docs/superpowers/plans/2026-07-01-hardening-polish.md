# Hardening & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the currency/recurring bug (currency → display-only), surface persistence errors in dev, add lossless JSON backup + a "last backup" reminder, separate donut slices, de-congest Settings into sub-pages, and lightly split `app_state.dart`.

**Architecture:** Small additive logic on `AppState` (backup map/restore, backup timestamp, unused-colour helper), a thin `backup_io.dart` IO wrapper, a donut styling tweak, relocation of Settings' heavy sections into pushed sub-pages, and a `part`-file split of two method groups.

**Tech Stack:** Flutter/Dart, provider, shared_preferences, file_picker, share_plus, fl_chart.

## Global Constraints

- **Currency is display-only:** `setCurrency` must NOT rewrite any amounts; it only sets `currencyCode`. `Currency.rate` stays but is unused.
- Backup JSON shape is `{transactions, income, cats, sources, recurring, currency, theme, name}` (same as the legacy blob), built from the models' `toJson`.
- Backup timestamp persists under `shared_preferences` key `pref_last_backup` (ISO-8601 string).
- Keep CSV export/import; ADD JSON export/import. Any successful export calls `app.markBackedUp()`.
- Donut: each `PieChartSectionData` gets `borderSide: BorderSide(color: c.card, width: 2)` and `sectionsSpace` becomes `3`.
- New categories default to `firstUnusedCatColor()` (first `kPalette` colour not already used).
- Settings sub-pages live in `lib/screens/settings/`; shared settings widgets in `lib/screens/settings/settings_widgets.dart` as public `MiniBox`/`DeleteX`/`AddButton`/`BackupRow`.
- Refactor is zero-behaviour-change: `part` files, no logic edits, call sites unchanged.
- `flutter analyze` clean and the full `flutter test` green after every task. No hardcoded hex (use `AppColors`/`Brand`).

---

### Task 1: Currency display-only + persistence error logging

**Files:**
- Modify: `lib/app_state.dart`, `lib/screens/settings_screen.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces: `setCurrency(String code)` no longer converts amounts.

- [ ] **Step 1: Rewrite the currency test**

In `test/widget_test.dart`, replace the whole `test('currency conversion scales stored amounts', ...)` with:
```dart
    test('switching currency leaves amounts unchanged (display-only)', () {
      final app = AppState();
      app.openEntry('expense', false);
      app.amount = '1000';
      app.save();
      expect(app.monthSpent, 1000);
      app.setCurrency('USD');
      expect(app.currencyCode, 'USD');
      expect(app.monthSpent, 1000); // amounts are NOT rewritten
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test --plain-name "switching currency leaves amounts unchanged"`
Expected: FAIL — current `setCurrency` still scales, so `monthSpent` becomes 12.

- [ ] **Step 3: Make `setCurrency` display-only**

In `lib/app_state.dart`, replace the ENTIRE `void setCurrency(String code) { ... }` method (it currently computes `f`, `cv`, and rewrites `transactions`/`income`/`recurring`) with:
```dart
  /// Currency is display-only: switching changes the symbol/format used by
  /// [fmt], it never rewrites stored amounts.
  void setCurrency(String code) => _commit(() => currencyCode = code);
```

- [ ] **Step 4: Log persistence errors in debug**

In `lib/app_state.dart`, in each of `load()`, `_savePrefs()`, `_migrateLegacy()`, and `resetAll()`, change the swallowing catch clause (`catch (_) {}` or `catch (_) {/* ... */}`) to:
```dart
    } catch (e) {
      if (kDebugMode) debugPrint('SpendWise persistence: $e');
    }
```
(`kDebugMode` and `debugPrint` are already available via the file's `package:flutter/material.dart` import. Do NOT change the `catch (_)` inside `importCsv`, which returns `false`.)

- [ ] **Step 5: Update the stale currency caption**

In `lib/screens/settings_screen.dart`, change the string `'Converts all amounts at indicative rates'` to `'Sets the currency symbol used across the app.'`.

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test` (all pass, including the rewritten currency test) and `flutter analyze` (clean).

- [ ] **Step 7: Commit**

```bash
git add lib/app_state.dart lib/screens/settings_screen.dart test/widget_test.dart
git commit -m "fix: make currency display-only (no amount rewrite) + log persistence errors in debug"
```

---

### Task 2: Backup core on AppState

**Files:**
- Modify: `lib/app_state.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces: `Map<String,dynamic> backupMap()`, `void restoreFromBackup(Map<String,dynamic> d)`, `String? lastBackup`, `void markBackedUp()`.

- [ ] **Step 1: Write the round-trip test**

In `test/widget_test.dart`, inside the `'AppState logic'` group, add:
```dart
    test('backupMap round-trips through restoreFromBackup', () {
      final a = AppState()..loadSampleData();
      final map = a.backupMap();
      final b = AppState();
      b.restoreFromBackup(map);
      expect(b.transactions.length, a.transactions.length);
      expect(b.income.length, a.income.length);
      expect(b.recurring.length, a.recurring.length);
      expect(b.cats.map((c) => c.key).toSet(), a.cats.map((c) => c.key).toSet());
      final aFood = a.cats.firstWhere((c) => c.key == 'Food');
      final bFood = b.cats.firstWhere((c) => c.key == 'Food');
      expect(bFood.color.toARGB32(), aFood.color.toARGB32()); // colour preserved
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test --plain-name "backupMap round-trips"`
Expected: FAIL — `backupMap`/`restoreFromBackup` undefined.

- [ ] **Step 3: Add the backup methods + `lastBackup` field**

In `lib/app_state.dart`, add a `String? lastBackup;` field in the `// ---- preferences` group (after `bool onboardingComplete = false;`), and add these methods (e.g. just after `resetAll`):
```dart
  /// Full, lossless snapshot for JSON backup (same shape as the legacy blob).
  Map<String, dynamic> backupMap() => {
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'income': income.map((t) => t.toJson()).toList(),
        'cats': cats.map((c) => c.toJson()).toList(),
        'sources': sources,
        'recurring': recurring.map((r) => r.toJson()).toList(),
        'currency': currencyCode,
        'theme': themeMode,
        'name': name,
      };

  /// Replaces all data + prefs from a backup map (type-guarded per field).
  void restoreFromBackup(Map<String, dynamic> d) {
    List<Txn> txns(String k) => d[k] is List
        ? (d[k] as List)
            .map((e) => Txn.fromJson((e as Map).cast<String, dynamic>()))
            .toList()
        : <Txn>[];
    _commit(() {
      transactions = txns('transactions');
      income = txns('income');
      if (d['cats'] is List) {
        cats = (d['cats'] as List)
            .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      if (d['sources'] is List) {
        sources = (d['sources'] as List).map((e) => e.toString()).toList();
      }
      if (d['recurring'] is List) {
        recurring = (d['recurring'] as List)
            .map((e) => Recurring.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      if (d['currency'] is String) currencyCode = d['currency'] as String;
      if (d['theme'] is String) {
        final t = d['theme'] as String;
        themeMode = (t == 'light' || t == 'dark') ? t : 'system';
      }
      if (d['name'] is String) name = d['name'] as String;
      screen = 'home';
    });
  }

  /// Records that a backup export just happened (drives the reminder).
  void markBackedUp() {
    lastBackup = DateTime.now().toIso8601String();
    _savePrefs();
    notifyListeners();
  }
```

- [ ] **Step 4: Persist `lastBackup`**

In `load()`, after the `pref_onboarded`/`insight_cards` reads, add:
```dart
      lastBackup = prefs.getString('pref_last_backup');
```
In `_savePrefs()`, before the closing `}`, add:
```dart
      if (lastBackup != null) {
        await prefs.setString('pref_last_backup', lastBackup!);
      }
```

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test --plain-name "backupMap round-trips"` (PASS), then `flutter test` (all pass) and `flutter analyze` (clean).

- [ ] **Step 6: Commit**

```bash
git add lib/app_state.dart test/widget_test.dart
git commit -m "feat: add lossless backup map/restore + last-backup timestamp on AppState"
```

---

### Task 3: JSON backup IO + CSV mark-backed-up

**Files:**
- Create: `lib/backup_io.dart`
- Modify: `lib/csv_io.dart`

**Interfaces:**
- Consumes: `AppState.backupMap`, `restoreFromBackup`, `markBackedUp` (Task 2).
- Produces: `Future<void> exportJson(AppState)`, `Future<bool?> importJson(AppState)`.

- [ ] **Step 1: Create `lib/backup_io.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';

/// Exports the full app state as a lossless JSON file via the share sheet.
Future<void> exportJson(AppState app) async {
  final json = jsonEncode(app.backupMap());
  final bytes = Uint8List.fromList(utf8.encode(json));
  final file = XFile.fromData(bytes,
      mimeType: 'application/json', name: 'spendwise-backup.json');
  await Share.shareXFiles([file]);
  app.markBackedUp();
}

/// Picks a JSON backup and restores it. Returns null if cancelled,
/// else true/false for parse success.
Future<bool?> importJson(AppState app) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  final bytes = res?.files.single.bytes;
  if (bytes == null) return null;
  try {
    final map = jsonDecode(utf8.decode(bytes, allowMalformed: true))
        as Map<String, dynamic>;
    app.restoreFromBackup(map);
    return true;
  } catch (_) {
    return false;
  }
}
```

- [ ] **Step 2: Mark backed-up on CSV export too**

In `lib/csv_io.dart`, in `exportCsv`, add `app.markBackedUp();` as the last line after `await Share.shareXFiles([file]);`.

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: No issues found. (No unit test — file/share IO isn't unit-testable; the backup core is covered by Task 2.)

- [ ] **Step 4: Commit**

```bash
git add lib/backup_io.dart lib/csv_io.dart
git commit -m "feat: add JSON backup export/import IO; CSV export marks backed-up"
```

---

### Task 4: Donut slice separation + unused default category colour

**Files:**
- Modify: `lib/widgets/charts/category_donut_card.dart`, `lib/app_state.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces: `Color firstUnusedCatColor()`.

- [ ] **Step 1: Write the colour test**

In `test/widget_test.dart` `'AppState logic'` group, add:
```dart
    test('firstUnusedCatColor avoids colours already used', () {
      final app = AppState(); // default cats already use several palette colours
      final col = app.firstUnusedCatColor();
      expect(
        app.cats.any((cat) => cat.color.toARGB32() == col.toARGB32()),
        isFalse,
      );
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test --plain-name "firstUnusedCatColor"`
Expected: FAIL — method undefined.

- [ ] **Step 3: Add `firstUnusedCatColor` + use it in `addCat`**

In `lib/app_state.dart`, add:
```dart
  /// First palette colour not already used by a category (fallback: first).
  Color firstUnusedCatColor() {
    final used = cats.map((c) => c.color.toARGB32()).toSet();
    for (final col in kPalette) {
      if (!used.contains(col.toARGB32())) return col;
    }
    return kPalette.first;
  }
```
In `addCat()`, inside the successful `_commit(() { ... })` closure, after `newCatName = '';`, add:
```dart
      newCatColor = firstUnusedCatColor();
```

- [ ] **Step 4: Separate the donut slices**

In `lib/widgets/charts/category_donut_card.dart`, in the `PieChartSectionData(...)` returned per slice, add `borderSide: BorderSide(color: c.card, width: 2),`, and change `sectionsSpace: 2,` to `sectionsSpace: 3,`.

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test` (all pass) and `flutter analyze` (clean).

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/charts/category_donut_card.dart lib/app_state.dart test/widget_test.dart
git commit -m "fix: separate donut slices + default new category to an unused colour"
```

---

### Task 5: Settings sub-pages + shared widgets

**Files:**
- Create: `lib/screens/settings/settings_widgets.dart`, `lib/screens/settings/categories_screen.dart`, `lib/screens/settings/sources_screen.dart`, `lib/screens/settings/recurring_screen.dart`, `lib/screens/settings/backup_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (remove the four moved blocks + the now-shared private widgets)
- Test: `test/data/settings_pages_test.dart` (new)

**Interfaces:**
- Consumes: `AppState` (`cats`, `sources`, `recurring`, `addCat`, `delCat`, `addSource`, `delSource`, `logRecurring`, `delRecurring`, `newCatName`, `newCatColor`, `firstUnusedCatColor`, `lastBackup`), `exportCsv`/`importCsv` (`csv_io.dart`), `exportJson`/`importJson` (`backup_io.dart`), `confirmDialog` (`ui.dart`).
- Produces: `CategoriesScreen`, `SourcesScreen`, `RecurringScreen`, `BackupScreen`; public `MiniBox`, `DeleteX`, `AddButton`, `BackupRow`.

- [ ] **Step 1: Extract shared widgets**

Create `lib/screens/settings/settings_widgets.dart`. MOVE the private widget classes `_MiniBox`, `_DeleteX`, `_AddButton`, and `_BackupRow` out of `settings_screen.dart` into this file, renaming them to public `MiniBox`, `DeleteX`, `AddButton`, `BackupRow` (drop the leading underscore; keep their code otherwise identical). Add the file's imports (`package:flutter/material.dart`, `../../theme.dart`). In `settings_screen.dart`, add `import 'settings/settings_widgets.dart';` and update its remaining references (`_MiniBox`→`MiniBox`, etc.).

- [ ] **Step 2: Create a page scaffold + the four screens**

Each screen is a `StatelessWidget` (Categories is `StatefulWidget` — see below) returning:
```dart
Scaffold(
  backgroundColor: AppColors.of(context).bg,
  appBar: AppBar(
    backgroundColor: AppColors.of(context).bg,
    surfaceTintColor: Colors.transparent,
    title: Text('<Title>', style: manrope(size: 18, weight: FontWeight.w700, color: AppColors.of(context).ink)),
  ),
  body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [ <moved content> ]),
);
```
Move the corresponding block out of `settings_screen.dart` into each screen's `children`, using the now-public `MiniBox`/`DeleteX`/`AddButton`/`BackupRow` and the existing `SoftField` (`../../widgets/ui.dart`), `Brand`, `manrope`, `AppColors`:
- `categories_screen.dart` (`CategoriesScreen`, **StatefulWidget**): the `// ---- categories` `Container` (list + palette + add). In `initState`, call `WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().set(() => context.read<AppState>().newCatColor = context.read<AppState>().firstUnusedCatColor()));` so the palette defaults to an unused colour.
- `sources_screen.dart` (`SourcesScreen`): the `// ---- income sources` `Container`.
- `recurring_screen.dart` (`RecurringScreen`): the `// ---- recurring` `Container` (list, "Log now", delete). If the recurring list is empty, show `EmptyHint(icon: Icons.repeat, text: 'No recurring items yet.')` (import from `../../widgets/charts/insight_card.dart`).
- `backup_screen.dart` (`BackupScreen`): the `// ---- backup` rows (CSV export/import via `exportCsv`/`importCsv`) PLUS two new `BackupRow`s — **Export backup (JSON)** (`onTap: () => exportJson(app)`) and **Restore backup (JSON)** (confirm dialog, then `importJson(app)`, snackbar on result) — and a status line at the top: `Text(app.lastBackup == null ? 'Never backed up.' : 'Last backup: ${_ago(app.lastBackup!)}', style: manrope(size: 12.5, weight: FontWeight.w600, color: app.lastBackup == null ? Brand.accent : AppColors.of(context).ink2))`, where `_ago` is a top-level helper in this file:
```dart
String _ago(String iso) {
  final d = DateTime.now().difference(DateTime.parse(iso)).inDays;
  if (d <= 0) return 'today';
  if (d == 1) return 'yesterday';
  return '$d days ago';
}
```
Each screen reads state via `final app = context.watch<AppState>();`.

- [ ] **Step 3: Smoke test the pages**

Create `test/data/settings_pages_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';
import 'package:spendwise/screens/settings/categories_screen.dart';
import 'package:spendwise/screens/settings/backup_screen.dart';
import 'package:spendwise/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(AppState app, Widget child) =>
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(theme: buildTheme(false), home: child),
      );

  testWidgets('CategoriesScreen lists categories', (tester) async {
    final app = AppState();
    await tester.pumpWidget(host(app, const CategoriesScreen()));
    await tester.pump();
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('BackupScreen shows the never-backed-up hint', (tester) async {
    final app = AppState();
    await tester.pumpWidget(host(app, const BackupScreen()));
    await tester.pump();
    expect(find.text('Never backed up.'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/data/settings_pages_test.dart` (PASS), `flutter test` (all pass), `flutter analyze` (clean). NOTE: `settings_screen.dart` will still reference the moved category/source/recurring/backup blocks until Task 6; if Step 1's extraction leaves `settings_screen.dart` temporarily broken, that's fine only if it still compiles — so in this task, LEAVE the four inline blocks in `settings_screen.dart` as-is (just extract the shared widgets in Step 1); Task 6 removes them. The new screen files duplicate the block content; the duplication is removed from `settings_screen.dart` in Task 6.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings/ test/data/settings_pages_test.dart lib/screens/settings_screen.dart
git commit -m "feat: add Settings sub-pages (categories/sources/recurring/backup) + shared widgets"
```

---

### Task 6: Rewrite SettingsScreen as a short nav list

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Test: `test/data/settings_pages_test.dart`

**Interfaces:**
- Consumes: the four screens from Task 5.

- [ ] **Step 1: Add a navigation-row test**

In `test/data/settings_pages_test.dart`, add:
```dart
  testWidgets('Settings row opens the Categories sub-page', (tester) async {
    tester.view.physicalSize = const Size(440, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState()
      ..completeOnboarding(name: 'T', currencyCode: 'INR', themeMode: 'light');
    await tester.pumpWidget(host(app, const SettingsScreen()));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Categories'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
  });
```
Add the imports `package:spendwise/screens/settings_screen.dart;` and (already present) `categories_screen.dart`.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test --plain-name "Settings row opens the Categories"`
Expected: FAIL — no "Categories" nav row yet (the category list is still inline).

- [ ] **Step 3: Replace the four inline blocks with nav rows**

In `lib/screens/settings_screen.dart`: delete the `// ---- categories`, `// ---- income sources`, `// ---- recurring`, and `// ---- backup` `Container` blocks (and their `SectionLabel`s and trailing `SizedBox`es). In their place (after the Currency section), add:
```dart
        const SizedBox(height: 24),
        const SectionLabel('Manage'),
        _NavRow(
            icon: Icons.category_outlined,
            label: 'Categories',
            subtitle: '${app.cats.length} categories',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CategoriesScreen()))),
        _NavRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Income sources',
            subtitle: '${app.sources.length} sources',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SourcesScreen()))),
        _NavRow(
            icon: Icons.repeat,
            label: 'Recurring',
            subtitle: '${app.recurring.length} items',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const RecurringScreen()))),
        _NavRow(
            icon: Icons.backup_outlined,
            label: 'Backup & restore',
            subtitle:
                app.lastBackup == null ? 'never backed up' : 'backed up',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const BackupScreen()))),
        const SizedBox(height: 22),
```
Add imports at the top of `settings_screen.dart`:
```dart
import 'settings/backup_screen.dart';
import 'settings/categories_screen.dart';
import 'settings/recurring_screen.dart';
import 'settings/sources_screen.dart';
```
Add the `_NavRow` widget at the end of `settings_screen.dart`:
```dart
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _NavRow(
      {required this.icon,
      required this.label,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.ink2),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: manrope(
                            size: 14.5, weight: FontWeight.w700, color: c.ink)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: manrope(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: c.ink2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: c.ink2),
            ],
          ),
        ),
      ),
    );
  }
}
```
Remove any now-unused imports/helpers in `settings_screen.dart` that only the deleted blocks used (e.g. `csv_io.dart`, `_BackupRow` reference) — `flutter analyze` will flag them.

- [ ] **Step 4: Run the full suite + analyze + build**

Run: `flutter test` (all pass incl. the new nav test), `flutter analyze` (clean), `flutter build web` (compiles).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart test/data/settings_pages_test.dart
git commit -m "feat: de-congest Settings into a short nav list linking to sub-pages"
```

---

### Task 7: Light `part`-file split of app_state.dart

**Files:**
- Modify: `lib/app_state.dart`
- Create: `lib/app_state_insights.dart`, `lib/app_state_csv.dart`

**Interfaces:**
- Zero behaviour change; all call sites unchanged.

- [ ] **Step 1: Add part directives**

In `lib/app_state.dart`, directly after the `import 'models.dart';` (and other imports), add:
```dart
part 'app_state_insights.dart';
part 'app_state_csv.dart';
```

- [ ] **Step 2: Move the insights group into a part extension**

Create `lib/app_state_insights.dart` starting with `part of 'app_state.dart';` (NO other imports — parts inherit the library's). MOVE these members out of the `AppState` class body in `app_state.dart` and into a single `extension AppStateInsights on AppState { ... }` in the new part file, verbatim: `greeting` (getter), `monthTx`, `monthInc`, `monthIncome`, `monthSpent`, `sortDesc`, `groupOf`, `row`, `categoryBreakdown`, `monthlyTotals`, `dailyTotals`, `insightStats`, `dayEntryCount`. Keep them together so their mutual calls resolve.

- [ ] **Step 3: Move the CSV group into a part extension**

Create `lib/app_state_csv.dart` starting with `part of 'app_state.dart';`. MOVE `buildCsv`, `parseCsvLine`, and `importCsv` out of the class into `extension AppStateCsv on AppState { ... }` in this part file, verbatim.

- [ ] **Step 4: Fix any resolution errors, then run the suite**

Run: `flutter analyze`. If it reports an unqualified reference inside a moved method that no longer resolves (a sibling method now on the extension), prefix it with `this.` — this is the only allowed edit; do not change logic. Repeat until clean.
Run: `flutter test`
Expected: all pass (behaviour is identical; the 42+ tests are the guard).

- [ ] **Step 5: Verify size + build**

Run: `flutter build web` (compiles). `app_state.dart` should be ~200 lines shorter.

- [ ] **Step 6: Commit**

```bash
git add lib/app_state.dart lib/app_state_insights.dart lib/app_state_csv.dart
git commit -m "refactor: split insights + CSV logic into app_state part files (no behaviour change)"
```

---

## Verification (whole feature)

- `flutter analyze` clean; `flutter test` green (existing + new currency/backup/colour/settings tests); `flutter build web` compiles.
- Manual: switch currency → amounts unchanged, symbol changes; Export/Restore JSON round-trips (incl. category colours); donut slices visibly separated; Settings is a short list with working Categories/Sources/Recurring/Backup sub-pages; "Last backup" reminder updates after an export.
