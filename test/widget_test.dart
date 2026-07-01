import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/app_state.dart';
import 'package:spendwise/data/memory_store.dart';
import 'package:spendwise/main.dart';
import 'package:spendwise/models.dart';
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

    test('switching currency leaves amounts unchanged (display-only)', () {
      final app = AppState();
      app.openEntry('expense', false);
      app.amount = '1000';
      app.save();
      expect(app.monthSpent, 1000);
      app.setCurrency('USD');
      expect(app.currencyCode, 'USD');
      expect(app.monthSpent, 1000); // amounts are NOT rewritten
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

    test('a successful save raises then clears the success tick', () {
      final app = AppState();
      expect(app.saveTick, isFalse);
      app.openEntry('expense', false);
      app.amount = '50';
      app.save();
      expect(app.saveTick, isTrue); // tick shown after a real save
      app.dismissTick();
      expect(app.saveTick, isFalse);

      // a no-op save (amount 0) must NOT raise the tick
      app.openEntry('expense', false);
      app.amount = '0';
      app.save();
      expect(app.saveTick, isFalse);
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

    test('persists entries through an injected store and reloads them', () async {
      final store = MemoryStore();
      final a = AppState(store: store);
      a.openEntry('expense', false);
      a.cat = 'Food';
      a.amount = '321';
      a.save();
      // a fresh AppState on the same store should see the saved entry
      final b = AppState(store: store);
      await b.load();
      expect(b.transactions.any((t) => t.amount == 321), isTrue);
    });

    test('migrates the legacy exptrack_v3 blob into the store + prefs', () async {
      SharedPreferences.setMockInitialValues({
        'exptrack_v3': jsonEncode({
          'transactions': [
            {'id': 1, 'date': '2026-06-20', 'type': 'expense', 'category': 'Gym', 'title': 'Pass', 'amount': 200},
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
      final app = AppState(store: MemoryStore());
      await app.load();

      expect(app.transactions.any((t) => t.category == 'Gym'), isTrue);
      expect(app.cats.any((c) => c.key == 'Gym'), isTrue);
      expect(app.currencyCode, 'USD');
      expect(app.themeMode, 'dark');
      expect(app.name, 'Thomas');
      expect(app.onboardingComplete, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('drift_migrated'), isTrue);
    });

    test('insight cards default on and toggle flips them', () {
      final app = AppState();
      expect(app.insightOn('calendar'), isTrue);
      expect(app.insightOn('trend'), isTrue);
      app.toggleInsight('calendar');
      expect(app.insightOn('calendar'), isFalse);
      app.toggleInsight('calendar');
      expect(app.insightOn('calendar'), isTrue);
    });

    test('load restores insight visibility from prefs', () async {
      SharedPreferences.setMockInitialValues(
          {'insight_cards': jsonEncode({'trend': false})});
      final app = AppState();
      await app.load();
      expect(app.insightOn('trend'), isFalse);
      expect(app.insightOn('daily'), isTrue); // unspecified keys stay default
    });

    test('dayEntryCount counts expenses on a date', () {
      final app = AppState()..loadSampleData();
      final d = app.transactions.first.date;
      expect(app.dayEntryCount(d), greaterThanOrEqualTo(1));
      expect(app.dayEntryCount('1999-01-01'), 0);
    });

    test('backupMap round-trips through restoreFromBackup', () {
      final a = AppState()..loadSampleData();
      final map = a.backupMap();
      final b = AppState();
      b.restoreFromBackup(map);
      expect(b.transactions.length, a.transactions.length);
      expect(b.income.length, a.income.length);
      expect(b.recurring.length, a.recurring.length);
      expect(b.cats.map((c) => c.key).toSet(), a.cats.map((c) => c.key).toSet());
      final aFood = a.cats.firstWhere((c) => c.key == 'Food');
      final bFood = b.cats.firstWhere((c) => c.key == 'Food');
      expect(bFood.color.toARGB32(), aFood.color.toARGB32()); // colour preserved
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

  group('Insights value types', () {
    test('CatSlice constructs correctly', () {
      const s = CatSlice(
          key: 'Food', label: 'Food', color: Color(0xFFE0533D), amount: 500, pct: 0.5);
      expect(s.amount, 500);
      expect(s.pct, 0.5);
    });

    test('MonthTotals constructs correctly', () {
      const m = MonthTotals(
          monthKey: '2026-06', label: 'Jun', income: 20000, spent: 5000);
      expect(m.income - m.spent, 15000);
    });

    test('InsightStats constructs correctly', () {
      const s = InsightStats(
          savingsRate: 0.75, avgPerDay: 167, biggestExpense: 2000,
          prevMonthSpent: 4000, deltaPct: 0.25);
      expect(s.savingsRate, 0.75);
      expect(s.deltaPct, 0.25);
    });
  });

  group('AppState aggregation helpers', () {
    late AppState app;
    setUp(() {
      app = AppState();
      app.set(() {
        app.transactions = [
          Txn(id: 1, date: '2026-06-01', type: 'expense', category: 'Food', title: 'Lunch', amount: 300),
          Txn(id: 2, date: '2026-06-01', type: 'expense', category: 'Food', title: 'Dinner', amount: 200),
          Txn(id: 3, date: '2026-06-15', type: 'expense', category: 'Transport', title: 'Bus', amount: 50),
          Txn(id: 4, date: '2026-05-10', type: 'expense', category: 'Food', title: 'May lunch', amount: 400),
        ];
        app.income = [
          Txn(id: 101, date: '2026-06-01', type: 'income', category: 'Salary', title: 'Pay', amount: 10000),
        ];
        app.viewMonth = '2026-06';
      });
    });

    test('categoryBreakdown returns slices sorted desc', () {
      final slices = app.categoryBreakdown('2026-06');
      expect(slices.length, 2);
      expect(slices.first.key, 'Food');
      expect(slices.first.amount, 500);
      expect(slices.last.key, 'Transport');
      expect(slices.last.amount, 50);
      expect(slices.fold(0.0, (a, s) => a + s.pct), closeTo(1.0, 0.001));
    });

    test('categoryBreakdown returns empty when no expenses', () {
      expect(app.categoryBreakdown('2025-01'), isEmpty);
    });

    test('monthlyTotals returns N months ending at viewMonth', () {
      final totals = app.monthlyTotals(months: 2);
      expect(totals.length, 2);
      expect(totals.last.monthKey, '2026-06');
      expect(totals.last.spent, 550);
      expect(totals.last.income, 10000);
      expect(totals.first.monthKey, '2026-05');
      expect(totals.first.spent, 400);
    });

    test('dailyTotals returns correct length and values', () {
      final daily = app.dailyTotals('2026-06');
      expect(daily.length, 30);   // June has 30 days
      expect(daily[0], 500);      // day 1: 300+200
      expect(daily[14], 50);      // day 15
      expect(daily[2], 0);        // day 3: no spending
    });

    test('insightStats computes correctly', () {
      final stats = app.insightStats('2026-06');
      expect(stats.savingsRate, closeTo((10000 - 550) / 10000, 0.001));
      expect(stats.biggestExpense, 300);
      expect(stats.prevMonthSpent, 400);
      expect(stats.deltaPct, closeTo((550 - 400) / 400, 0.001));
    });
  });

  group('InsightsScreen smoke', () {
    Widget buildApp(AppState app) => ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(theme: buildTheme(false), home: const RootScaffold()),
        );

    testWidgets('renders all four cards with sample data', (tester) async {
      tester.view.physicalSize = const Size(440, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = AppState()..loadSampleData();
      app.set(() => app.screen = 'insights');
      await tester.pumpWidget(buildApp(app));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Income vs spending'), findsOneWidget);
      expect(find.text('Spending by category'), findsOneWidget);
      expect(find.text('Daily spending'), findsOneWidget);
    });

    testWidgets('shows empty states with no data', (tester) async {
      tester.view.physicalSize = const Size(440, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = AppState();
      app.completeOnboarding(name: 'T', currencyCode: 'INR', themeMode: 'light');
      app.set(() => app.screen = 'insights');
      await tester.pumpWidget(buildApp(app));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Spending by category'), findsOneWidget);
      expect(find.text('No spending recorded this month.'), findsNWidgets(3));
    });

    testWidgets('honors per-card visibility toggles', (tester) async {
      tester.view.physicalSize = const Size(440, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = AppState()..loadSampleData();
      app.set(() => app.screen = 'insights');
      await tester.pumpWidget(buildApp(app));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Spending by category'), findsOneWidget);

      app.toggleInsight('category');
      await tester.pump();
      expect(find.text('Spending by category'), findsNothing);
    });

    testWidgets('shows the all-hidden message when every card is off',
        (tester) async {
      tester.view.physicalSize = const Size(440, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = AppState()..loadSampleData();
      for (final k in ['summary', 'category', 'trend', 'daily', 'calendar']) {
        app.toggleInsight(k);
      }
      app.set(() => app.screen = 'insights');
      await tester.pumpWidget(buildApp(app));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('All insights are hidden.'), findsOneWidget);
    });
  });
}
