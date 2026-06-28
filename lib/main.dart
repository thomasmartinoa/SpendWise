import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'root.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  await app.load();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const SpendWiseApp(),
    ),
  );
}

class SpendWiseApp extends StatelessWidget {
  const SpendWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().dark;
    return MaterialApp(
      title: 'SpendWise',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(false),
      darkTheme: buildTheme(true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: const RootScaffold(),
    );
  }
}
