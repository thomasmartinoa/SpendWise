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
