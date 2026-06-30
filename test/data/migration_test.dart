import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';
import 'package:spendwise/data/database.dart';
import 'package:spendwise/data/drift_store.dart';

/// Closes the one integration seam no other test crosses: the legacy
/// `exptrack_v3` blob migration written all the way through to a real SQLite
/// database (every other migration test uses MemoryStore).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('migrates the legacy blob into a real DriftStore-backed AppState',
      () async {
    late AppDatabase db;
    try {
      db = AppDatabase(NativeDatabase.memory());
      await db.select(db.entries).get();
    } catch (e) {
      markTestSkipped('sqlite3 not loadable on this VM: $e');
      return;
    }

    SharedPreferences.setMockInitialValues({
      'exptrack_v3': jsonEncode({
        'transactions': [
          {
            'id': 1,
            'date': '2026-06-20',
            'type': 'expense',
            'category': 'Gym',
            'title': 'Pass',
            'amount': 200,
          },
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

    final store = DriftStore(db);
    final app = AppState(store: store);
    await app.load();

    expect(app.transactions.any((t) => t.category == 'Gym'), isTrue);
    expect(app.cats.any((c) => c.key == 'Gym'), isTrue);
    expect(app.currencyCode, 'USD');
    expect(app.themeMode, 'dark');
    expect(app.name, 'Thomas');
    expect(app.onboardingComplete, isTrue);

    // data actually landed in SQLite, not just the in-memory snapshot
    final reloaded = await store.load();
    expect(reloaded.entries.any((t) => t.category == 'Gym'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('drift_migrated'), isTrue);

    await db.close();
  });
}
