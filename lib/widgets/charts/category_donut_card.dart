import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';
import 'insight_card.dart';

/// Donut chart of spending by category. Tapping a slice shows its amount
/// in the center. Below the chart: ranked legend (dot · name · amount · %).
class CategoryDonutCard extends StatefulWidget {
  const CategoryDonutCard({super.key});

  @override
  State<CategoryDonutCard> createState() => _CategoryDonutCardState();
}

class _CategoryDonutCardState extends State<CategoryDonutCard> {
  int _touched = -1;
  String _lastMonth = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    // Reset touch state when the user navigates to a different month so the
    // wrong slice isn't highlighted in the new month's data.
    if (app.viewMonth != _lastMonth) {
      _lastMonth = app.viewMonth;
      _touched = -1;
    }
    final slices = app.categoryBreakdown(app.viewMonth);

    return InsightCard(
      title: 'Spending by category',
      child: slices.isEmpty
          ? const EmptyHint(
              icon: Icons.pie_chart_outline,
              text: 'No spending recorded this month.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: slices.asMap().entries.map((e) {
                            final isTouched = e.key == _touched;
                            return PieChartSectionData(
                              value: e.value.amount.toDouble(),
                              color: e.value.color,
                              radius: isTouched ? 72 : 62,
                              showTitle: false,
                            );
                          }).toList(),
                          centerSpaceRadius: 52,
                          sectionsSpace: 2,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    response?.touchedSection == null) {
                                  _touched = -1;
                                } else {
                                  _touched = response!
                                      .touchedSection!
                                      .touchedSectionIndex;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _touched >= 0 && _touched < slices.length
                                ? app.fmt(slices[_touched].amount)
                                : app.fmt(app.monthSpent),
                            style: manrope(
                              size: 16,
                              weight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            _touched >= 0 && _touched < slices.length
                                ? slices[_touched].label
                                : 'total',
                            style: manrope(
                              size: 11,
                              weight: FontWeight.w600,
                              color: c.ink2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...slices.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.label,
                            style: manrope(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Text(
                          app.fmt(s.amount),
                          style: manrope(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${(s.pct * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.right,
                            style: manrope(
                              size: 12,
                              weight: FontWeight.w600,
                              color: c.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
