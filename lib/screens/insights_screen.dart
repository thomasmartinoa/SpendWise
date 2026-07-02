import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/charts/calendar_card.dart';
import '../widgets/charts/category_donut_card.dart';
import '../widgets/charts/daily_spending_card.dart';
import '../widgets/charts/monthly_trend_card.dart';
import '../widgets/charts/summary_stats_card.dart';
import '../widgets/ui.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final cards = <Widget>[
      if (app.insightOn('summary')) const SummaryStatsCard(),
      if (app.insightOn('category')) const CategoryDonutCard(),
      if (app.insightOn('trend')) const MonthlyTrendCard(),
      if (app.insightOn('daily')) const DailySpendingCard(),
      if (app.insightOn('calendar')) const CalendarCard(),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
      children: [
        // header — horizontal swipe changes the viewed month, same as Home.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -80) {
              HapticFeedback.selectionClick();
              app.shiftMonth(1); // swipe left → next month
            } else if (v > 80) {
              HapticFeedback.selectionClick();
              app.shiftMonth(-1); // swipe right → previous month
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Insights',
                  style: manrope(
                      size: 24,
                      weight: FontWeight.w800,
                      color: c.ink,
                      letterSpacing: -0.5)),
              const SizedBox(height: 10),
              const MonthSwitch(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.insights_outlined, size: 30, color: c.ink2),
                  const SizedBox(height: 10),
                  Text('All insights are hidden.',
                      style: manrope(
                          size: 15, weight: FontWeight.w700, color: c.ink)),
                  const SizedBox(height: 4),
                  Text('Turn them on in Settings.',
                      style: manrope(
                          size: 13, weight: FontWeight.w600, color: c.ink2)),
                ],
              ),
            ),
          ),
        for (var i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i != cards.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}
