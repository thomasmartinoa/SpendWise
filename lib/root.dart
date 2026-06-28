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
import 'widgets/transaction_detail.dart';

/// The single app shell: active screen + notched bottom nav with a docked FAB,
/// the entry editor and the read-only detail sheet layered on top. Capped to a
/// phone-width column so it stays faithful on tablet / desktop / web.
class RootScaffold extends StatelessWidget {
  const RootScaffold({super.key});

  static const _screens = ['home', 'insights', 'history', 'settings'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final index = _screens.indexOf(app.screen).clamp(0, 3);

    return PopScope(
      // Let the system pop (exit) only on the Home tab with nothing open;
      // otherwise intercept Back to close sheets / return to Home.
      canPop: app.screen == 'home' && !app.entryOpen && app.detailTxn == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (app.entryOpen) {
          app.close();
        } else if (app.detailTxn != null) {
          app.closeDetail();
        } else if (app.screen != 'home') {
          app.go('home');
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: c.bg,
                resizeToAvoidBottomInset: false,
                body: SafeArea(
                  bottom: false,
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
                bottomNavigationBar: const BottomNav(),
                floatingActionButton: const SpendFab(),
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.centerDocked,
              ),
              if (app.detailTxn != null)
                const Positioned.fill(child: TransactionDetail()),
              if (app.entryOpen) const Positioned.fill(child: EntrySheet()),
            ],
          ),
        ),
      ),
    );
  }
}
