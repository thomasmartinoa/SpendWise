import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    return SizedBox(
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.card,
              border: Border(top: BorderSide(color: c.line)),
            ),
            padding: const EdgeInsets.only(top: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const Spacer(),
                _NavItem(
                    icon: Icons.schedule,
                    label: 'History',
                    active: app.screen == 'history',
                    onTap: () => app.go('history')),
                _NavItem(
                    icon: Icons.tune,
                    label: 'More',
                    active: app.screen == 'settings',
                    onTap: () => app.go('settings')),
              ],
            ),
          ),
          Positioned(
            top: -24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => app.openEntry('expense', false),
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Brand.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Brand.accent.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
              ),
            ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 4),
            Text(label,
                style:
                    manrope(size: 10.5, weight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
