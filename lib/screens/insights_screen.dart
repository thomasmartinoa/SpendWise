import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    // aggregate spending by category for the viewed month
    final agg = <String, int>{};
    for (final t in app.monthTx) {
      agg[t.category] = (agg[t.category] ?? 0) + t.amount;
    }
    final catArr = agg.entries
        .map((e) => (cat: app.catOf(e.key), amt: e.value))
        .toList()
      ..sort((a, b) => b.amt - a.amt);
    final maxCat =
        catArr.isEmpty ? 1 : catArr.map((e) => e.amt).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      children: [
        Text('Insights',
            style: manrope(
                size: 24,
                weight: FontWeight.w800,
                color: c.ink,
                letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const MonthSwitch(),
        const SizedBox(height: 16),

        // summary
        AppCard(
          child: Row(
            children: [
              _Stat(label: 'Income', value: app.fmt(app.monthIncome), color: Brand.green),
              _vDivider(c.line),
              _Stat(label: 'Spent', value: app.fmt(app.monthSpent), color: Brand.accent, padLeft: true),
              _vDivider(c.line),
              _Stat(label: 'Saved', value: app.fmt(app.monthIncome - app.monthSpent), color: c.ink, padLeft: true),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // category bars
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spending by category',
                  style: manrope(
                      size: 15, weight: FontWeight.w800, color: c.ink)),
              if (catArr.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 22, bottom: 8),
                  child: Center(
                    child: Text('No spending recorded this month.',
                        style: manrope(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: c.ink2)),
                  ),
                )
              else
                ...catArr.map((e) {
                  final pct = (e.amt / maxCat * 100).round();
                  final clamped = pct < 6 ? 6 : pct;
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: e.cat.color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Text(e.cat.label,
                                    style: manrope(
                                        size: 13.5,
                                        weight: FontWeight.w700,
                                        color: c.ink)),
                              ],
                            ),
                            Text(app.fmt(e.amt),
                                style: manrope(
                                    size: 13.5,
                                    weight: FontWeight.w700,
                                    color: c.ink)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: clamped / 100,
                            minHeight: 9,
                            backgroundColor: c.key,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(e.cat.color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vDivider(Color color) =>
      Container(width: 1, height: 38, color: color, margin: const EdgeInsets.symmetric(horizontal: 2));
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool padLeft;
  const _Stat(
      {required this.label,
      required this.value,
      required this.color,
      this.padLeft = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: padLeft ? 14 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    manrope(size: 12, weight: FontWeight.w600, color: c.ink2)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    manrope(size: 18, weight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
