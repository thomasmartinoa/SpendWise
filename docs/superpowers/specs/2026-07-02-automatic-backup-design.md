# Automatic Backup — Design

**Date:** 2026-07-02
**Status:** Approved
**Scope:** Add automatic, silent local snapshots (rotating, keep last 5) plus
OS-level device backup config. Manual CSV/JSON export already exists and is
unchanged. Cloud sync, snapshot encryption, and the `_commit` perf refactor are
explicitly out of scope.

## Problem

Backup today is fully manual: the user must open Settings → Backup and tap
Export (CSV or JSON), which fires the share sheet and records a timestamp via
`markBackedUp()`. If they never do this and then delete the wrong entry, do a
bad import, or lose the device, the data is gone. We want protection that
happens on its own, with no user action.

## Decisions (locked)

- **Trigger:** write one snapshot each time the app goes to background/closed,
  reusing the existing lifecycle observer in `main.dart`. Dedupe: skip the write
  when the serialized state is byte-identical to the newest existing snapshot.
- **Retention:** keep the newest 5, prune older (rotation).
- **Restore UX:** a list of snapshots on the existing Backup screen, tap to
  restore behind the existing confirm dialog.
- **OS device backup:** enable/confirm Android Auto Backup and iOS iCloud so a
  device restore brings data back.

## Architecture

The snapshots reinforce the OS backup: the Drift SQLite DB (`driftDatabase(name:
'spendwise')`) and `path_provider`'s documents directory both live inside the
app's private data area, which is exactly what Android Auto Backup and iOS
iCloud capture. So local snapshots and OS backup are complementary and the
Drift config does **not** need to change.

### Component 1 — `SnapshotStore` (new: `lib/data/snapshot_store.dart`)

Self-contained; owns the local snapshot lifecycle. Depends only on
`path_provider` (already a dep), `dart:io`, `dart:convert`. No `AppState`
coupling — it takes/returns plain maps, so it is fully unit-testable against a
temporary directory.

```dart
class SnapshotInfo {
  final String filename;   // spendwise-2026-07-02T14-32-05.json
  final DateTime time;     // parsed from the filename
  const SnapshotInfo(this.filename, this.time);
}

class SnapshotStore {
  static const _maxKept = 5;
  static const _dirName = 'snapshots';

  /// Optional base directory override for tests. When null, resolves to
  /// path_provider's application documents directory at runtime.
  final Directory? baseDirOverride;
  SnapshotStore({this.baseDirOverride});

  /// Resolves <base>/snapshots, creating it if needed.
  Future<Directory> _dir();

  /// Serialize [backupMap] to JSON and write it as
  /// spendwise-<ISO>.json, then prune to the newest [_maxKept].
  /// Skips the write if the JSON equals the newest existing snapshot
  /// (so opening/closing without changes does not churn/rotate).
  Future<void> write(Map<String, dynamic> backupMap);

  /// Existing snapshots, newest first.
  Future<List<SnapshotInfo>> list();

  /// Parse one snapshot back into a map for restore (null on read/parse error).
  Future<Map<String, dynamic>?> read(String filename);
}
```

Filename timestamp uses a filesystem-safe form (colons replaced), e.g.
`spendwise-2026-07-02T14-32-05.json`. Ordering is by the parsed time, newest
first. Dedupe compares the candidate JSON string against the newest file's
contents.

### Component 2 — Auto-trigger (wire into existing hook)

`AppState` gains one thin method:

```dart
final SnapshotStore _snapshots = SnapshotStore();
Future<void> writeAutoSnapshot() => _snapshots.write(backupMap());
```

In `main.dart`, the `paused`/`detached` lifecycle branch already calls
`app.flush()`. Add `app.writeAutoSnapshot()` immediately after (awaited within
the async handler). This is the entire trigger: one deduped snapshot per
app-background, keep 5.

The `SnapshotStore` instance is constructed unconditionally; on web (where
`path_provider` has no real directory) the write simply fails and is swallowed
(see error handling) — consistent with the existing web `MemoryStore` fallback.

### Component 3 — Restore UI (extend `BackupScreen`)

Add an "Automatic snapshots" section below the existing manual rows in
`lib/screens/settings/backup_screen.dart`:

- Load `SnapshotStore.list()` (via a `FutureBuilder` or a small stateful
  wrapper).
- Each row: a friendly relative label ("Today 14:32", "Yesterday 09:10",
  "2 Jul 14:32") + tap target.
- Tapping → the existing `confirmDialog(...)` ("Restore this snapshot? This
  replaces all current data.") → on confirm, `SnapshotStore.read(filename)` →
  `app.restoreFromBackup(map)` → success/failure snackbar (mirrors the JSON
  restore row).
- Empty list → `EmptyHint(icon: Icons.history, text: 'Snapshots appear here
  automatically as you use the app.')`.

No new shared widgets required; reuse `BackupRow`/`confirmDialog`/`EmptyHint`.

### Component 4 — OS device backup (config only)

- **Android** (`android/app/src/main/AndroidManifest.xml` + a new
  `android/app/src/main/res/xml/` rules file):
  - Ensure `android:allowBackup="true"` on `<application>`.
  - Add explicit `android:fullBackupContent="@xml/backup_rules"` and
    `android:dataExtractionRules="@xml/data_extraction_rules"` including the
    app's data (Drift DB, shared_preferences, and the `snapshots/` folder — all
    under the private data dir). Explicit rules future-proof behaviour on API
    31+.
- **iOS** (`ios/Runner/Info.plist`): the app Documents directory is iCloud-
  backed by default; verify nothing sets `NSURLIsExcludedFromBackupKey` or
  otherwise excludes it. Expected: zero code change.

## Data flow

```
app backgrounded
  → main.dart lifecycle handler
      → app.flush()                 (existing: finish in-flight DB write)
      → app.writeAutoSnapshot()     (new)
          → SnapshotStore.write(app.backupMap())
              → if JSON == newest snapshot: return (dedupe)
              → else write spendwise-<ISO>.json, prune to newest 5

Settings → Backup → Automatic snapshots → tap a row
  → confirmDialog
      → SnapshotStore.read(filename)
          → app.restoreFromBackup(map)   (existing, lossless)
          → snackbar
```

## Error handling

- All `SnapshotStore` file I/O is wrapped so failures are non-fatal: `write`
  swallows and (in debug) `debugPrint`s, matching the existing persistence
  error-logging pattern in `AppState`. A failed snapshot must never crash
  app-background or block `flush()`.
- `read` returns `null` on any read/parse error; the UI shows "Could not read
  that snapshot."
- `list` returns `[]` if the directory is missing or unreadable.

## Testing

Unit tests for `SnapshotStore` against a temporary directory (inject/override
the base dir for tests):

1. `write` creates a file; a 6th write prunes the oldest so exactly 5 remain.
2. Dedupe: writing an identical map twice leaves a single file (no churn).
3. `list` returns snapshots newest-first.
4. `read` round-trips a written map back to an equal map.
5. Corrupt/misnamed file → `read` returns null, `list` ignores it gracefully.

`AppState.writeAutoSnapshot` is a thin delegation (no dedicated test needed
beyond the store's).

## Files

- **New:** `lib/data/snapshot_store.dart`
- **New:** `android/app/src/main/res/xml/backup_rules.xml`,
  `.../data_extraction_rules.xml`
- **Edit:** `lib/app_state.dart` (add `_snapshots` + `writeAutoSnapshot`)
- **Edit:** `lib/main.dart` (call `writeAutoSnapshot` in the lifecycle handler)
- **Edit:** `lib/screens/settings/backup_screen.dart` (snapshots section)
- **Edit:** `android/app/src/main/AndroidManifest.xml` (allowBackup + rules refs)
- **Verify:** `ios/Runner/Info.plist` (no backup exclusion)
- **New tests:** `test/data/snapshot_store_test.dart`

## Verification

1. `flutter analyze` → clean.
2. `flutter test` → all pass (existing 47 + new snapshot tests).
3. `flutter build web` → compiles (web tolerates the no-op snapshot path).
4. Manual: background/foreground the app, confirm a snapshot appears in the
   Backup screen list; delete an entry, restore the prior snapshot, confirm the
   entry returns.
