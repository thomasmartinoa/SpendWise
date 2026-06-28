import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';

/// Two-row summary card at the top of the Insights screen.
/// Row 1: Income / Spent / Saved.
/// Row 2: Savings rate / Avg per day / Biggest expense / vs last month.
class SummaryStatsCard extends StatelessWidget {
  const SummaryStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final stats = app.insightStats(app.viewMonth);
    final saved = app.monthIncome - app.monthSpent;

    final pct = stats.deltaPct;
    final up = pct > 0;
    final noHistory = stats.prevMonthSpent == 0;
    final deltaColor =
        noHistory ? c.ink2 : (up ? Brand.accent : Brand.green);
    final deltaText = noHistory
        ? '—'
        : '${up ? '▲' : '▼'} ${(pct.abs() * 100).toStringAsFixed(0)}%';

    return Container(
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line)),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // row 1
          IntrinsicHeight(
            child: Row(
              children: [
                _Cell(label: 'Income', value: app.fmt(app.monthIncome),
                    color: Brand.green),
                _Vline(),
                _Cell(label: 'Spent', value: app.fmt(app.monthSpent),
                    color: Brand.accent),
                _Vline(),
                _Cell(label: 'Saved', value: app.fmt(saved),
                    color: saved >= 0 ? Brand.green : Brand.accent),
              ],
            ),
          ),
          Divider(color: c.line, height: 24),
          // row 2
          Row(
            children: [
              _Cell(
                  label: 'Savings',
                  value: '${(stats.savingsRate * 100).toStringAsFixed(0)}%',
                  color: stats.savingsRate >= 0 ? Brand.green : Brand.accent),
              _Vline(),
              _Cell(label: 'Avg/day', value: app.fmt(stats.avgPerDay)),
              _Vline(),
              _Cell(label: 'Biggest', value: app.fmt(stats.biggestExpense)),
              _Vline(),
              _Cell(label: 'vs last mo.', value: deltaText,
                  color: deltaColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _Cell({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: manrope(size: 11, weight: FontWeight.w600, color: c.ink2)),
        const SizedBox(height: 4),
        Text(value,
            style: manrope(
                size: 14, weight: FontWeight.w700, color: color ?? c.ink)),
      ]),
    );
  }
}

class _Vline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
        width: 1,
        color: c.line,
        margin: const EdgeInsets.symmetric(horizontal: 6));
  }
}
