import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/entry_sheet.dart';

/// The single app shell: active screen + bottom nav, with the entry sheet
/// layered on top. Capped to a phone-width column so it stays faithful on
/// tablet / desktop / web while filling the viewport on phones.
class RootScaffold extends StatelessWidget {
  const RootScaffold({super.key});

  static const _screens = ['home', 'insights', 'history', 'settings'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final index = _screens.indexOf(app.screen).clamp(0, 3);

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: IndexedStack(
                        index: index,
                        children: const [
                          HomeScreen(),
                          InsightsScreen(),
                          HistoryScreen(),
                          SettingsScreen(),
                        ],
                      ),
                    ),
                    const BottomNav(),
                  ],
                ),
              ),
              if (app.entryOpen) const Positioned.fill(child: EntrySheet()),
            ],
          ),
        ),
      ),
    );
  }
}
