import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' hide Split;
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
