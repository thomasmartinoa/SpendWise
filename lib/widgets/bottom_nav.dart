import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Bottom navigation bar with a circular notch for the docked add button.
/// Use together with [SpendFab] as the Scaffold's floatingActionButton
/// (centerDocked) so the FAB sits cleanly in the notch — no hard cut.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    return BottomAppBar(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: c.dark ? 0.55 : 0.12),
      elevation: 12,
      shape: const CircularNotchedRectangle(),
      notchMargin: 9,
      height: 64,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              active: app.screen == 'home',
              onTap: () => app.go('home')),
          _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Insights',
              active: app.screen == 'insights',
              onTap: () => app.go('insights')),
          const SizedBox(width: 64), // notch gap
          _NavItem(
              icon: Icons.history,
              label: 'History',
              active: app.screen == 'history',
              onTap: () => app.go('history')),
          _NavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              active: app.screen == 'settings',
              onTap: () => app.go('settings')),
        ],
      ),
    );
  }
}

/// The orange add button, docked into the [BottomNav] notch.
///
/// The FAB itself stays the default 56x56 size (so the notch geometry is
/// identical to before), but a card-colored backdrop disc — matching the
/// bar's own 56 + notchMargin(9) halo — renders behind it and overflows the
/// FAB's own bounds. It fills the notch cutout with an opaque, bar-matching
/// color instead of letting the notch expose the Scaffold's darker (and
/// mismatched) background.
class SpendFab extends StatelessWidget {
  const SpendFab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final c = AppColors.of(context);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.card),
          ),
          FloatingActionButton(
            onPressed: () => app.openEntry('expense', false),
            backgroundColor: Brand.accent,
            foregroundColor: Colors.white,
            elevation: 3,
            highlightElevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, size: 30),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? Brand.accent : const Color(0xFF9A9A92);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label,
                style:
                    manrope(size: 10.5, weight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
