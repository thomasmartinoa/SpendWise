import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'data/database.dart';
import 'data/drift_store.dart';
import 'data/memory_store.dart';
import 'data/spend_store.dart';
import 'root.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Native (Android/iOS/desktop) uses the real SQLite store. Web has no SQLite
  // runtime wired (out of scope), so it falls back to an ephemeral in-memory
  // store instead of crashing on startup.
  final SpendStore store = kIsWeb ? MemoryStore() : DriftStore(AppDatabase());
  final app = AppState(store: store);
  await app.load();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const SpendWiseApp(),
    ),
  );
}

class SpendWiseApp extends StatefulWidget {
  const SpendWiseApp({super.key});

  @override
  State<SpendWiseApp> createState() => _SpendWiseAppState();
}

class _SpendWiseAppState extends State<SpendWiseApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flush any in-flight write before the app is paused/killed so the last
    // mutation isn't lost if the process is terminated immediately after.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final app = context.read<AppState>();
      app.flush();
      app.writeAutoSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'SpendWise',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(false),
      darkTheme: buildTheme(true),
      themeMode: app.materialThemeMode,
      home: app.onboardingComplete
          ? const RootScaffold()
          : const OnboardingScreen(),
    );
  }
}
