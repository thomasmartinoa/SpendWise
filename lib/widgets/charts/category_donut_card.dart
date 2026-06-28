import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';

/// Donut chart of spending by category. Tapping a slice shows its amount
/// in the center. Below the chart: ranked legend (dot · name · amount · %).
class CategoryDonutCard extends StatefulWidget {
  const CategoryDonutCard({super.key});

  @override
  State<CategoryDonutCard> createState() => _CategoryDonutCardState();
}

class _CategoryDonutCardState extends State<CategoryDonutCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final slices = app.categoryBreakdown(app.viewMonth);

    return Container(
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line)),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by category',
              style: manrope(size: 15, weight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 16),
          if (slices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text('No spending recorded this month.',
                    style: manrope(
                        size: 13.5, weight: FontWeight.w600, color: c.ink2)),
              ),
            )
          else ...[
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
                                  .touchedSection!.touchedSectionIndex;
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
                            size: 16, weight: FontWeight.w700, color: c.ink),
                      ),
                      Text(
                        _touched >= 0 && _touched < slices.length
                            ? slices[_touched].label
                            : 'total',
                        style: manrope(
                            size: 11, weight: FontWeight.w600, color: c.ink2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...slices.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(s.label,
                            style: manrope(
                                size: 13.5,
                                weight: FontWeight.w600,
                                color: c.ink))),
                    Text(app.fmt(s.amount),
                        style: manrope(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: c.ink)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(
                          '${(s.pct * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: manrope(
                              size: 12,
                              weight: FontWeight.w600,
                              color: c.ink2)),
                    ),
                  ]),
                )),
          ],
        ],
      ),
    );
  }
}
