import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';
import 'insight_card.dart';

/// Grouped bar chart: green income bar + orange spending bar per month,
/// for the 6 months ending at the currently viewed month.
class MonthlyTrendCard extends StatelessWidget {
  const MonthlyTrendCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final data = app.monthlyTotals(months: 6);
    final hasData = data.any((m) => m.income > 0 || m.spent > 0);

    return InsightCard(
      title: 'Income vs spending',
      caption: 'last 6 months',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: !hasData
          ? const EmptyHint(
              icon: Icons.show_chart,
              text: 'Not enough history yet.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 190,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          data
                              .map(
                                (m) => m.income > m.spent ? m.income : m.spent,
                              )
                              .reduce((a, b) => a > b ? a : b)
                              .toDouble() *
                          1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => c.card,
                          getTooltipItem: (group, _, rod, ri) {
                            final m = data[group.x];
                            final val = ri == 0 ? m.income : m.spent;
                            final label = ri == 0 ? 'Income' : 'Spent';
                            return BarTooltipItem(
                              '$label\n${app.fmt(val)}',
                              manrope(
                                size: 11,
                                weight: FontWeight.w600,
                                color: c.ink,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final i = value.toInt();
                              if (i < 0 || i >= data.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  data[i].label,
                                  style: manrope(
                                    size: 10.5,
                                    weight: FontWeight.w600,
                                    color: c.ink2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: c.line, strokeWidth: 1),
                      ),
                      barGroups: data.asMap().entries.map((e) {
                        final m = e.value;
                        return BarChartGroupData(
                          x: e.key,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: m.income.toDouble(),
                              color: Brand.green,
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                            BarChartRodData(
                              toY: m.spent.toDouble(),
                              color: Brand.accent,
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Dot(color: Brand.green, label: 'Income'),
                    const SizedBox(width: 16),
                    _Dot(color: Brand.accent, label: 'Spending'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: manrope(size: 12, weight: FontWeight.w600, color: c.ink2),
        ),
      ],
    );
  }
}
