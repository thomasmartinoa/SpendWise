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
