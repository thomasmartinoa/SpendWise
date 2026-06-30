import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';
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
}
