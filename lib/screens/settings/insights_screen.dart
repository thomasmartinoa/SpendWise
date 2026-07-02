import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';

/// Per-card visibility toggles for the Insights tab.
class InsightsSettingsScreen extends StatelessWidget {
  const InsightsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Insights',
            style: manrope(size: 18, weight: FontWeight.w700, color: c.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text('Choose which cards show on the Insights tab.',
              style: manrope(size: 12.5, weight: FontWeight.w600, color: c.ink2)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: const Column(
              children: [
                _InsightToggle(label: 'Summary stats', k: 'summary'),
                _InsightToggle(label: 'Category donut', k: 'category'),
                _InsightToggle(label: 'Monthly trend', k: 'trend'),
                _InsightToggle(label: 'Daily spending', k: 'daily'),
                _InsightToggle(label: 'Calendar', k: 'calendar', last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightToggle extends StatelessWidget {
  final String label;
  final String k;
  final bool last;
  const _InsightToggle(
      {required this.label, required this.k, this.last = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    return Container(
      decoration: last
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: c.line2))),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    manrope(size: 14.5, weight: FontWeight.w700, color: c.ink)),
          ),
          Switch(
            value: app.insightOn(k),
            onChanged: (_) => app.toggleInsight(k),
            activeTrackColor: Brand.accent,
          ),
        ],
      ),
    );
  }
}
