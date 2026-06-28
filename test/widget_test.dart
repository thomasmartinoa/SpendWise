import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/app_state.dart';
import 'package:spendwise/root.dart';
import 'package:spendwise/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppState logic', () {
    test('keypad press builds the amount string', () {
      final app = AppState();
      app.press('1');
      app.press('2');
      app.press('.');
      app.press('5');
      expect(app.amount, '12.5');
      app.press('back');
      expect(app.amount, '12.');
    });

    test('split expense records only the per-person share', () {
      final app = AppState();
      app.openEntry('expense', true);
      app.splitCount = 4;
      app.amount = '400';
      final before = app.transactions.length;
      app.save();
      expect(app.transactions.length, before + 1);
      final row = app.transactions.first;
      expect(row.amount, 100); // 400 / 4
      expect(row.split?.total, 400);
      expect(row.split?.count, 4);
    });

    test('currency conversion scales stored amounts', () {
      final app = AppState();
      final inrSpent = app.monthSpent;
      app.setCurrency('USD');
      expect(app.currencyCode, 'USD');
      // 0.012 rate => spent should shrink dramatically
      expect(app.monthSpent < inrSpent, isTrue);
    });

    test('CSV round-trips transactions', () {
      final app = AppState();
      final csv = app.buildCsv();
      final ok = app.importCsv(csv);
      expect(ok, isTrue);
      expect(app.transactions.isNotEmpty || app.income.isNotEmpty, isTrue);
    });
  });

  testWidgets('App boots to the Home screen', (tester) async {
    final app = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: buildTheme(false),
          home: const RootScaffold(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Left to spend'.toUpperCase()), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
  });
}
