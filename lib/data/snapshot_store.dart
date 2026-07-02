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
