import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/app_state.dart';
import 'package:spendwise/main.dart';
import 'package:spendwise/root.dart';
import 'package:spendwise/screens/onboarding_screen.dart';
import 'package:spendwise/theme.dart';
import 'package:spendwise/widgets/transaction_detail.dart';
import 'package:spendwise/widgets/txn_row.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppState logic', () {
    test('starts empty for new users', () {
      final app = AppState();
      expect(app.transactions, isEmpty);
      expect(app.income, isEmpty);
      expect(app.recurring, isEmpty);
      expect(app.cats, isNotEmpty); // default categories kept
      expect(app.onboardingComplete, isFalse);
    });

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

    test('shiftMonth moves one month forward and back', () {
      final app = AppState();
      final start = app.viewMonth;
      app.shiftMonth(1);
      expect(app.viewMonth, isNot(start)); // forward must actually move
      app.shiftMonth(-1);
      expect(app.viewMonth, start); // and be reversible
    });

    test('split expense records only the per-person share', () {
      final app = AppState();
      app.openEntry('expense', true);
      app.splitCount = 4;
      app.amount = '400';
      app.save();
      expect(app.transactions.length, 1);
      final row = app.transactions.first;
      expect(row.amount, 100); // 400 / 4
      expect(row.split?.total, 400);
      expect(row.split?.count, 4);
    });

    test('currency conversion scales stored amounts', () {
      final app = AppState();
      app.openEntry('expense', false);
      app.amount = '1000';
      app.save();
      final inrSpent = app.monthSpent;
      expect(inrSpent, 1000);
      app.setCurrency('USD');
      expect(app.currencyCode, 'USD');
      expect(app.monthSpent < inrSpent, isTrue); // 1000 * 0.012
    });

    test('CSV round-trips an entry', () {
      final app = AppState();
      app.openEntry('expense', false);
      app.amount = '250';
      app.save();
      final csv = app.buildCsv();
      final ok = app.importCsv(csv);
      expect(ok, isTrue);
      expect(app.transactions.length, 1);
    });

    test('CSV import reconstructs categories and recurring templates', () {
      final app = AppState();
      // a recurring monthly Food expense
      app.openEntry('expense', false);
      app.recurringOn = true;
      app.recurEverySel = 'month';
      app.cat = 'Food';
      app.amount = '500';
      app.save();
      // an expense under a custom category
      app.set(() => app.newCatName = 'Gym');
      app.addCat();
      app.openEntry('expense', false);
      app.cat = 'Gym';
      app.amount = '200';
      app.save();

      final csv = app.buildCsv();

      final restored = AppState();
      expect(restored.importCsv(csv), isTrue);
      expect(restored.cats.any((c) => c.key == 'Gym'), isTrue);
      expect(restored.recurring, isNotEmpty);
      expect(restored.recurring.first.freq, 'month');
    });

    test('recurring auto-posts due occurrences on app open', () async {
      final past = DateTime.now().subtract(const Duration(days: 40));
      String two(int n) => n.toString().padLeft(2, '0');
      final anchor = '${past.year}-${two(past.month)}-${two(past.day)}';
      SharedPreferences.setMockInitialValues({
        'exptrack_v3': jsonEncode({
          'transactions': <dynamic>[],
          'income': <dynamic>[],
          'recurring': [
            {
              'id': 1,
              'type': 'expense',
              'category': 'Bills',
              'title': 'Rent',
              'amount': 1000,
              'freq': 'week',
              'anchor': anchor,
            }
          ],
          'onboarded': true,
        }),
      });
      final app = AppState();
      await app.load();
      expect(app.transactions, isNotEmpty); // weekly occurrences backfilled
      expect(app.transactions.every((t) => t.recurring), isTrue);
    });

    test('editFromDetail closes the detail and opens the editor', () {
      final app = AppState()..loadSampleData();
      app.openDetail(app.transactions.first);
      expect(app.detailTxn, isNotNull);
      app.editFromDetail();
      expect(app.detailTxn, isNull);
      expect(app.entryOpen, isTrue);
    });

    test('completeOnboarding sets preferences and flag', () {
      final app = AppState();
      app.completeOnboarding(
          name: 'Alex', currencyCode: 'USD', themeMode: 'dark');
      expect(app.onboardingComplete, isTrue);
      expect(app.name, 'Alex');
      expect(app.currencyCode, 'USD');
      expect(app.themeMode, 'dark');
    });

    test('resetAll clears data and returns to onboarding', () async {
      final app = AppState();
      app.loadSampleData();
      expect(app.transactions, isNotEmpty);
      app.completeOnboarding(name: 'A', currencyCode: 'INR', themeMode: 'light');
      await app.resetAll();
      expect(app.transactions, isEmpty);
      expect(app.onboardingComplete, isFalse);
      expect(app.name, '');
      expect(app.themeMode, 'system');
    });

    test('load migrates legacy theme + onboarded flag', () async {
      SharedPreferences.setMockInitialValues({
        'exptrack_v3': jsonEncode({'theme': 'dark', 'onboarded': true, 'name': 'Sam'}),
      });
      final app = AppState();
      await app.load();
      expect(app.themeMode, 'dark');
      expect(app.onboardingComplete, isTrue);
      expect(app.name, 'Sam');
    });
  });

  group('routing', () {
    testWidgets('fresh install shows onboarding, then Home after setup',
        (tester) async {
      final app = AppState();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: app,
          child: const SpendWiseApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(RootScaffold), findsNothing);

      app.completeOnboarding(
          name: 'Alex', currencyCode: 'INR', themeMode: 'system');
      await tester.pump();
      expect(find.byType(RootScaffold), findsOneWidget);
      expect(find.text('Left to spend'.toUpperCase()), findsOneWidget);
    });
  });

  testWidgets('Home renders with sample data', (tester) async {
    final app = AppState()..loadSampleData();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(theme: buildTheme(false), home: const RootScaffold()),
      ),
    );
    await tester.pump();
    expect(find.text('Recent activity'), findsOneWidget);
  });

  testWidgets('tapping a row opens the read-only detail (not the editor)',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = AppState()..loadSampleData();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(theme: buildTheme(false), home: const RootScaffold()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TxnRow).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(app.detailTxn, isNotNull); // detail open, not the editor
    expect(app.entryOpen, isFalse);
    expect(find.byType(TransactionDetail), findsOneWidget);
  });
}
