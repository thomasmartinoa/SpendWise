import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'data/database.dart';
import 'data/drift_store.dart';
import 'root.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DriftStore(AppDatabase());
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
      context.read<AppState>().flush();
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
