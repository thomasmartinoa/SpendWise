import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';
import 'package:spendwise/screens/settings/categories_screen.dart';
import 'package:spendwise/screens/settings/backup_screen.dart';
import 'package:spendwise/screens/settings_screen.dart';
import 'package:spendwise/theme.dart';

/// There's no real platform documents directory under `flutter test`, so
/// SnapshotStore's getApplicationDocumentsDirectory() call would otherwise
/// hang forever (real dart:io/platform I/O never resolves in the widget-test
/// fake-async zone without `runAsync`). This makes just that one call fail
/// fast so SnapshotStore's try/catch falls back to an empty list, while every
/// other path_provider method (notably getApplicationSupportPath, which
/// google_fonts uses for its font cache) still delegates to the real
/// platform implementation so unrelated behaviour is unaffected.
class _DocsFailFastPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final PathProviderPlatform _real;
  _DocsFailFastPathProviderPlatform(this._real);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    throw UnsupportedError('no path_provider in tests');
  }

  @override
  Future<String?> getTemporaryPath() => _real.getTemporaryPath();
  @override
  Future<String?> getApplicationSupportPath() => _real.getApplicationSupportPath();
  @override
  Future<String?> getLibraryPath() => _real.getLibraryPath();
  @override
  Future<String?> getApplicationCachePath() => _real.getApplicationCachePath();
  @override
  Future<String?> getExternalStoragePath() => _real.getExternalStoragePath();
  @override
  Future<List<String>?> getExternalCachePaths() => _real.getExternalCachePaths();
  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) =>
      _real.getExternalStoragePaths(type: type);
  @override
  Future<String?> getDownloadsPath() => _real.getDownloadsPath();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance =
        _DocsFailFastPathProviderPlatform(PathProviderPlatform.instance);
  });

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

  testWidgets('BackupScreen shows the auto-snapshot empty hint', (tester) async {
    final app = AppState();
    await tester.pumpWidget(host(app, const BackupScreen()));
    await tester.pumpAndSettle();
    expect(
        find.text('Snapshots appear here automatically as you use the app.'),
        findsOneWidget);
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
