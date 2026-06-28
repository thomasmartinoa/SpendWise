import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';

/// Bar chart of expense total per day for the selected month.
/// Zero-spend days are shown as invisible bars (color = transparent).
class DailySpendingCard extends StatelessWidget {
  const DailySpendingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final daily = app.dailyTotals(app.viewMonth);
    final hasData = daily.any((v) => v > 0);
    final maxVal =
        hasData ? daily.reduce((a, b) => a > b ? a : b).toDouble() : 1.0;
    final barWidth = daily.length > 20 ? 6.0 : 10.0;

    return Container(
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line)),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily spending',
              style: manrope(size: 15, weight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 2),
          Text('this month',
              style:
                  manrope(size: 11.5, weight: FontWeight.w600, color: c.ink2)),
          const SizedBox(height: 16),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text('No spending recorded this month.',
                    style: manrope(
                        size: 13.5, weight: FontWeight.w600, color: c.ink2)),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.25,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => c.card,
                      getTooltipItem: (group, _, rod, _) {
                        final v = daily[group.x];
                        if (v == 0) return null;
                        return BarTooltipItem(
                          'Day ${group.x + 1}\n${app.fmt(v)}',
                          manrope(
                              size: 11,
                              weight: FontWeight.w600,
                              color: c.ink),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final day = value.toInt() + 1;
                          if (day != 1 &&
                              day % 10 != 0 &&
                              day != daily.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text('$day',
                                style: manrope(
                                    size: 10,
                                    weight: FontWeight.w600,
                                    color: c.ink2)),
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
                  barGroups: daily.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.toDouble(),
                          color:
                              e.value > 0 ? Brand.accent : Colors.transparent,
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
