import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';
import 'package:spendwise/models.dart';
import 'package:spendwise/theme.dart';
import 'package:spendwise/widgets/charts/calendar_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(AppState app) => ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: buildTheme(false),
          home: const Scaffold(
              body: SingleChildScrollView(child: CalendarCard())),
        ),
      );

  testWidgets('renders the calendar with data', (tester) async {
    final app = AppState()..loadSampleData();
    await tester.pumpWidget(host(app));
    await tester.pump();
    expect(find.text('Spending calendar'), findsOneWidget);
  });

  testWidgets('shows the empty hint with no data', (tester) async {
    final app = AppState();
    await tester.pumpWidget(host(app));
    await tester.pump();
    expect(find.text('No spending recorded this month.'), findsOneWidget);
  });

  testWidgets('selecting a day then changing to a shorter month does not crash',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = AppState();
    app.set(() {
      app.viewMonth = '2026-01'; // 31-day month
      app.transactions = [
        const Txn(
            id: 1,
            date: '2026-01-31',
            type: 'expense',
            category: 'Food',
            title: 'x',
            amount: 100),
        const Txn(
            id: 2,
            date: '2026-02-10',
            type: 'expense',
            category: 'Food',
            title: 'y',
            amount: 50), // so Feb also has data
      ];
    });
    await tester.pumpWidget(host(app));
    await tester.pump();

    await tester.tap(find.text('31')); // select day 31 in January
    await tester.pump();

    app.set(() => app.viewMonth = '2026-02'); // 28 days, also has spending
    await tester.pump();

    expect(tester.takeException(), isNull); // no RangeError from a stale day 31
  });
}
