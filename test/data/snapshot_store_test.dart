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
