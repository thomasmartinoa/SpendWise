import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';
import 'package:spendwise/screens/settings/categories_screen.dart';
import 'package:spendwise/screens/settings/backup_screen.dart';
import 'package:spendwise/screens/settings_screen.dart';
import 'package:spendwise/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(AppState app, Widget child) =>
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(theme: buildTheme(false), home: child),
      );

  testWidgets('CategoriesScreen lists categories', (tester) async {
    final app = AppState();
    await tester.pumpWidget(host(app, const CategoriesScreen()));
    await tester.pump();
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('BackupScreen shows the never-backed-up hint', (tester) async {
    final app = AppState();
    await tester.pumpWidget(host(app, const BackupScreen()));
    await tester.pump();
    expect(find.text('Never backed up.'), findsOneWidget);
  });

  testWidgets('Settings row opens the Categories sub-page', (tester) async {
    tester.view.physicalSize = const Size(440, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState()
      ..completeOnboarding(name: 'T', currencyCode: 'INR', themeMode: 'light');
    await tester.pumpWidget(host(app, const SettingsScreen()));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Categories'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
  });
}
