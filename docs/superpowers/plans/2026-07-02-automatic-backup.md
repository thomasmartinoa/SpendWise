# Automatic Backup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add silent, rotating local JSON snapshots (keep the newest 5, deduped) written on app-background, a restore list on the Backup screen, and Android/iOS OS-level device-backup config.

**Architecture:** A self-contained `SnapshotStore` owns the local snapshot lifecycle (write/list/read) against the app documents directory, taking/returning plain maps so it has no `AppState` coupling and is unit-testable via a `baseDirOverride`. `AppState` gains a one-line `writeAutoSnapshot()` delegate, triggered from the existing `paused`/`detached` lifecycle hook in `main.dart`. The Backup screen gains a snapshots section that restores via the existing lossless `restoreFromBackup`. OS backup is config-only; the Drift DB and snapshots both live in the app's private data dir, which Android Auto Backup and iOS iCloud already capture.

**Tech Stack:** Flutter/Dart, `path_provider` (already a dependency), `dart:io`, `dart:convert`, provider, `flutter_test`.

## Global Constraints

- Do not break the existing suite: **47 tests currently pass**; keep them green.
- `flutter analyze` must stay clean; `flutter build web` must still compile (web tolerates the no-op snapshot path — `path_provider` has no dir there, so snapshot I/O fails and is swallowed).
- File I/O errors must be **non-fatal** and logged only in debug, matching the existing pattern: `if (kDebugMode) debugPrint('SpendWise ...: $e');`.
- Retention: keep the newest **5** snapshots; prune older.
- **Dedupe:** skip a write when the serialized JSON equals the newest existing snapshot.
- Snapshot filename format: `spendwise-YYYY-MM-DDTHH-MM-SS-mmm.json` (filesystem-safe; colons replaced by `-`).
- Restore reuses the existing `restoreFromBackup(Map)`, `confirmDialog(...)`, `BackupRow`, and `EmptyHint` — do not duplicate them.
- No new dependencies. No cloud sync, no encryption, no `_commit` perf refactor (all out of scope).

---

### Task 1: `SnapshotStore` core

**Files:**
- Create: `lib/data/snapshot_store.dart`
- Test: `test/data/snapshot_store_test.dart`

**Interfaces:**
- Consumes: nothing (leaf module).
- Produces:
  - `class SnapshotInfo { final String filename; final DateTime time; const SnapshotInfo(this.filename, this.time); }`
  - `class SnapshotStore { SnapshotStore({Directory? baseDirOverride}); Future<void> write(Map<String,dynamic> backupMap, {DateTime? at}); Future<List<SnapshotInfo>> list(); Future<Map<String,dynamic>?> read(String filename); }`
  - `write` writes newest-wins, dedupes against the newest existing file, prunes to 5. `list` returns newest-first. `read` returns null on any read/parse error.

- [ ] **Step 1: Write the failing tests**

Create `test/data/snapshot_store_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/data/snapshot_store.dart';

void main() {
  late Directory tmp;
  late SnapshotStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('spendwise_snap_test');
    store = SnapshotStore(baseDirOverride: tmp);
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('write then list returns the snapshot', () async {
    await store.write({'name': 'A'}, at: DateTime(2026, 1, 1, 9, 0, 0));
    final items = await store.list();
    expect(items.length, 1);
  });

  test('keeps only the newest 5', () async {
    for (var i = 0; i < 6; i++) {
      await store.write({'name': 'v$i'}, at: DateTime(2026, 1, 1, 9, i, 0));
    }
    final items = await store.list();
    expect(items.length, 5);
    expect(items.first.time.minute, 5); // newest (v5)
    expect(items.last.time.minute, 1);  // v0 (minute 0) pruned
  });

  test('dedupe skips an identical consecutive map', () async {
    await store.write({'name': 'same'}, at: DateTime(2026, 1, 1, 9, 0, 0));
    await store.write({'name': 'same'}, at: DateTime(2026, 1, 1, 9, 1, 0));
    final items = await store.list();
    expect(items.length, 1);
  });

  test('list orders newest first', () async {
    await store.write({'k': 1}, at: DateTime(2026, 1, 1, 8, 0, 0));
    await store.write({'k': 2}, at: DateTime(2026, 1, 1, 10, 0, 0));
    await store.write({'k': 3}, at: DateTime(2026, 1, 1, 9, 0, 0));
    final items = await store.list();
    expect(items.map((e) => e.time.hour).toList(), [10, 9, 8]);
  });

  test('read round-trips a written map', () async {
    await store.write({'name': 'Round', 'n': 3}, at: DateTime(2026, 1, 1, 9, 0, 0));
    final items = await store.list();
    final map = await store.read(items.first.filename);
    expect(map, {'name': 'Round', 'n': 3});
  });

  test('read returns null for missing or corrupt files', () async {
    expect(await store.read('spendwise-nope.json'), isNull);
    final bad =
        File('${tmp.path}/snapshots/spendwise-2026-01-01T09-00-00-000.json');
    await bad.parent.create(recursive: true);
    await bad.writeAsString('{not json');
    expect(await store.read(bad.uri.pathSegments.last), isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/snapshot_store_test.dart`
Expected: FAIL — `snapshot_store.dart` / `SnapshotStore` not found (compile error).

- [ ] **Step 3: Write the implementation**

Create `lib/data/snapshot_store.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:path_provider/path_provider.dart';

/// One stored snapshot: its filename and the timestamp parsed from that name.
class SnapshotInfo {
  final String filename;
  final DateTime time;
  const SnapshotInfo(this.filename, this.time);
}

/// Owns the rotating local JSON snapshot lifecycle. Takes/returns plain maps
/// (no AppState coupling). All file I/O is non-fatal. Point [baseDirOverride]
/// at a temp dir in tests; in production it resolves the app documents dir.
class SnapshotStore {
  static const _maxKept = 5;
  static const _dirName = 'snapshots';
  static const _prefix = 'spendwise-';
  static const _suffix = '.json';

  final Directory? baseDirOverride;
  SnapshotStore({this.baseDirOverride});

  Future<Directory> _dir() async {
    final base = baseDirOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _stamp(DateTime t) {
    String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
    return '${t.year}-${p(t.month)}-${p(t.day)}T'
        '${p(t.hour)}-${p(t.minute)}-${p(t.second)}-${p(t.millisecond, 3)}';
  }

  DateTime? _parseStamp(String filename) {
    if (!filename.startsWith(_prefix) || !filename.endsWith(_suffix)) return null;
    final core =
        filename.substring(_prefix.length, filename.length - _suffix.length);
    final tp = core.split('T');
    if (tp.length != 2) return null;
    final d = tp[0].split('-');
    final tm = tp[1].split('-');
    if (d.length != 3 || (tm.length != 3 && tm.length != 4)) return null;
    try {
      return DateTime(
        int.parse(d[0]), int.parse(d[1]), int.parse(d[2]),
        int.parse(tm[0]), int.parse(tm[1]), int.parse(tm[2]),
        tm.length == 4 ? int.parse(tm[3]) : 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Files in [dir] that parse as snapshots, newest first.
  List<File> _sortedFiles(Directory dir) {
    final entries = <MapEntry<File, DateTime>>[];
    for (final e in dir.listSync()) {
      if (e is File) {
        final name = e.uri.pathSegments.last;
        final t = _parseStamp(name);
        if (t != null) entries.add(MapEntry(e, t));
      }
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  Future<void> write(Map<String, dynamic> backupMap, {DateTime? at}) async {
    try {
      final dir = await _dir();
      final json = jsonEncode(backupMap);
      final existing = _sortedFiles(dir);
      if (existing.isNotEmpty && await existing.first.readAsString() == json) {
        return; // dedupe: identical to the newest snapshot
      }
      final now = at ?? DateTime.now();
      await File('${dir.path}/$_prefix${_stamp(now)}$_suffix').writeAsString(json);
      for (final f in _sortedFiles(dir).skip(_maxKept)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SpendWise snapshot write: $e');
    }
  }

  Future<List<SnapshotInfo>> list() async {
    try {
      final dir = await _dir();
      return _sortedFiles(dir)
          .map((f) {
            final name = f.uri.pathSegments.last;
            return SnapshotInfo(name, _parseStamp(name)!);
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> read(String filename) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$filename');
      if (!await file.exists()) return null;
      return (jsonDecode(await file.readAsString()) as Map)
          .cast<String, dynamic>();
    } catch (e) {
      if (kDebugMode) debugPrint('SpendWise snapshot read: $e');
      return null;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/snapshot_store_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Verify analyze clean**

Run: `flutter analyze lib/data/snapshot_store.dart test/data/snapshot_store_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/data/snapshot_store.dart test/data/snapshot_store_test.dart
git commit -m "feat: add SnapshotStore for rotating local JSON snapshots"
```

---

### Task 2: Auto-trigger on app background

**Files:**
- Modify: `lib/app_state.dart` (add field + `writeAutoSnapshot`)
- Modify: `lib/main.dart:51-58` (call it from the lifecycle handler)
- Test: `test/data/snapshot_trigger_test.dart`

**Interfaces:**
- Consumes: `SnapshotStore` from Task 1; `AppState.backupMap()` (existing, returns `Map<String,dynamic>`).
- Produces: `Future<void> AppState.writeAutoSnapshot()` — writes one deduped snapshot of the current state.

- [ ] **Step 1: Write the failing test**

Create `test/data/snapshot_trigger_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('writeAutoSnapshot completes without throwing', () async {
    final app = AppState();
    // In the test host there is no path_provider dir; the snapshot write must
    // fail silently and never throw.
    await app.writeAutoSnapshot();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/snapshot_trigger_test.dart`
Expected: FAIL — `writeAutoSnapshot` is not defined on `AppState`.

- [ ] **Step 3: Add the field + method to `AppState`**

In `lib/app_state.dart`, add the import near the other data-layer imports (after `import 'data/spend_store.dart';`):

```dart
import 'data/snapshot_store.dart';
```

Add the field just below `final SpendStore store;` (line ~75):

```dart
  final SnapshotStore _snapshots = SnapshotStore();
```

Add the method immediately after `markBackedUp()` (after line ~393):

```dart
  /// Writes one deduped local snapshot of the current state. Called from the
  /// app-background lifecycle hook. Non-fatal: failures are swallowed by the
  /// store, so this never throws.
  Future<void> writeAutoSnapshot() => _snapshots.write(backupMap());
```

- [ ] **Step 4: Wire it into the lifecycle handler**

In `lib/main.dart`, replace the body of the `if` in `didChangeAppLifecycleState` (lines ~54-57):

```dart
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final app = context.read<AppState>();
      app.flush();
      app.writeAutoSnapshot();
    }
```

- [ ] **Step 5: Run the trigger test + full suite**

Run: `flutter test test/data/snapshot_trigger_test.dart`
Expected: PASS.

Run: `flutter test`
Expected: PASS — 54 tests (47 existing + 6 from Task 1 + 1 here).

- [ ] **Step 6: Verify analyze clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/app_state.dart lib/main.dart test/data/snapshot_trigger_test.dart
git commit -m "feat: write an automatic snapshot when the app is backgrounded"
```

---

### Task 3: Restore list on the Backup screen

**Files:**
- Modify: `lib/screens/settings/backup_screen.dart` (add snapshots section + helpers)
- Test: `test/data/settings_pages_test.dart` (add one widget test)

**Interfaces:**
- Consumes: `SnapshotStore` (`list`, `read`), `SnapshotInfo` from Task 1; `AppState.restoreFromBackup(Map)` (existing); `confirmDialog(...)` from `lib/widgets/ui.dart` (existing); `EmptyHint` from `lib/widgets/charts/insight_card.dart` (existing); `kMon` from `lib/app_state.dart` (existing top-level const).
- Produces: an "Automatic snapshots" section rendered at the bottom of `BackupScreen`.

- [ ] **Step 1: Write the failing widget test**

Add to `test/data/settings_pages_test.dart` (inside `main()`, after the existing BackupScreen test):

```dart
  testWidgets('BackupScreen shows the auto-snapshot empty hint', (tester) async {
    final app = AppState();
    await tester.pumpWidget(host(app, const BackupScreen()));
    await tester.pumpAndSettle();
    expect(
        find.text('Snapshots appear here automatically as you use the app.'),
        findsOneWidget);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/settings_pages_test.dart`
Expected: FAIL — the hint text is not found (section not built yet).

- [ ] **Step 3: Add the snapshots section to `BackupScreen`**

In `lib/screens/settings/backup_screen.dart`, add imports at the top (after the existing imports):

```dart
import '../../data/snapshot_store.dart';
import '../../widgets/charts/insight_card.dart';
```

In the `ListView`'s `children`, add after the existing `Container(...)` that holds the `BackupRow`s (i.e. as the last child, before the closing `],`):

```dart
          const SizedBox(height: 24),
          Text('Automatic snapshots',
              style: manrope(size: 12.5, weight: FontWeight.w700, color: c.ink2)),
          const SizedBox(height: 10),
          const _SnapshotSection(),
```

Then add these below the existing `_ago(...)` top-level function at the end of the file:

```dart
String _snapshotLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return 'Today $hm';
  if (diff == 1) return 'Yesterday $hm';
  return '${t.day} ${kMon[t.month - 1]} $hm';
}

/// Loads the local snapshot list once and renders it as tappable restore rows.
class _SnapshotSection extends StatefulWidget {
  const _SnapshotSection();
  @override
  State<_SnapshotSection> createState() => _SnapshotSectionState();
}

class _SnapshotSectionState extends State<_SnapshotSection> {
  final _store = SnapshotStore();
  late final Future<List<SnapshotInfo>> _future = _store.list();

  Future<void> _restore(BuildContext context, SnapshotInfo s) async {
    final app = context.read<AppState>();
    final go = await confirmDialog(
      context,
      title: 'Restore snapshot?',
      message:
          'Restoring this snapshot replaces all of your current data. This cannot be undone.',
      confirmLabel: 'Restore',
    );
    if (!go || !context.mounted) return;
    final map = await _store.read(s.filename);
    if (!context.mounted) return;
    if (map == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that snapshot.')));
      return;
    }
    app.restoreFromBackup(map);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Snapshot restored.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FutureBuilder<List<SnapshotInfo>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final items = snap.data ?? const <SnapshotInfo>[];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: items.isEmpty
              ? const EmptyHint(
                  icon: Icons.history,
                  text: 'Snapshots appear here automatically as you use the app.')
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      InkWell(
                        onTap: () => _restore(context, items[i]),
                        child: Container(
                          decoration: i == items.length - 1
                              ? null
                              : BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(color: c.line2))),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.restore, size: 20, color: c.ink2),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(_snapshotLabel(items[i].time),
                                    style: manrope(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: c.ink)),
                              ),
                              Icon(Icons.chevron_right, size: 20, color: c.ink2),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
```

Note: `provider`'s `context.read` requires `import 'package:provider/provider.dart';` — it is already imported in this file.

- [ ] **Step 4: Run the settings-pages test + full suite**

Run: `flutter test test/data/settings_pages_test.dart`
Expected: PASS (existing 3 + new 1).

Run: `flutter test`
Expected: PASS — 55 tests.

- [ ] **Step 5: Verify analyze clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings/backup_screen.dart test/data/settings_pages_test.dart
git commit -m "feat: show automatic snapshots with tap-to-restore on the Backup screen"
```

---

### Task 4: OS device-backup config (Android + iOS)

**Files:**
- Create: `android/app/src/main/res/xml/backup_rules.xml`
- Create: `android/app/src/main/res/xml/data_extraction_rules.xml`
- Modify: `android/app/src/main/AndroidManifest.xml:2-5` (`<application>` attributes)
- Verify: `ios/Runner/Info.plist` (no backup-exclusion key)

**Interfaces:**
- Consumes: nothing at the Dart level (config only).
- Produces: OS backup includes the app's data dir (Drift DB + shared_preferences + `snapshots/`).

- [ ] **Step 1: Create the Auto Backup rules (API ≤ 30)**

Create `android/app/src/main/res/xml/backup_rules.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Android Auto Backup (API <= 30). Include the app's private data so the
     Drift SQLite database, shared_preferences, and local snapshots are backed
     up to the user's Google Drive. -->
<full-backup-content>
    <include domain="file" path="." />
    <include domain="database" path="." />
    <include domain="sharedpref" path="." />
</full-backup-content>
```

- [ ] **Step 2: Create the data-extraction rules (API 31+)**

Create `android/app/src/main/res/xml/data_extraction_rules.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Android 12+ (API 31+) backup/transfer rules. Cloud backup mirrors the
     Auto Backup content above. -->
<data-extraction-rules>
    <cloud-backup>
        <include domain="file" path="." />
        <include domain="database" path="." />
        <include domain="sharedpref" path="." />
    </cloud-backup>
</data-extraction-rules>
```

- [ ] **Step 3: Reference the rules from the manifest**

In `android/app/src/main/AndroidManifest.xml`, change the `<application>` opening tag (currently lines 2-5) to add three attributes:

```xml
    <application
        android:label="spendwise"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="true"
        android:fullBackupContent="@xml/backup_rules"
        android:dataExtractionRules="@xml/data_extraction_rules">
```

- [ ] **Step 4: Verify iOS does not exclude the documents dir**

Run: `grep -i "ExcludedFromBackup\|NSURLIsExcludedFromBackupKey" ios/Runner/Info.plist ios/Runner/*.swift 2>/dev/null; echo "exit: $?"`
Expected: no matches (the app Documents dir is iCloud-backed by default — no change required). If a match is found, remove that exclusion.

- [ ] **Step 5: Verify the project still analyzes and the new files exist**

Run: `flutter analyze`
Expected: `No issues found!` (manifest/XML changes do not affect Dart analysis).

Run: `ls android/app/src/main/res/xml/backup_rules.xml android/app/src/main/res/xml/data_extraction_rules.xml`
Expected: both paths listed (files created).

Manifest/XML correctness is validated by the Android build itself. If the
Android SDK toolchain is available, run `flutter build apk --debug` and expect
it to succeed (a malformed manifest or missing `@xml/...` resource fails the
build). This build is the authoritative check but is not required in
environments without the Android toolchain.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/res/xml/backup_rules.xml android/app/src/main/res/xml/data_extraction_rules.xml android/app/src/main/AndroidManifest.xml
git commit -m "feat: enable Android Auto Backup + explicit backup rules for app data"
```

---

## Final verification (after all tasks)

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → all pass (55 total).
- [ ] `flutter build web` → compiles.
- [ ] Manual (device): background/foreground the app, open Settings → Backup, confirm a snapshot row appears; delete an entry, restore the prior snapshot, confirm the entry returns.
