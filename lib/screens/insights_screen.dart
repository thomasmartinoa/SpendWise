import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/charts/category_donut_card.dart';
import '../widgets/charts/daily_spending_card.dart';
import '../widgets/charts/monthly_trend_card.dart';
import '../widgets/charts/summary_stats_card.dart';
import '../widgets/ui.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
      children: [
        Text('Insights',
            style: manrope(
                size: 24,
                weight: FontWeight.w800,
                color: c.ink,
                letterSpacing: -0.5)),
        const SizedBox(height: 10),
        const MonthSwitch(),
        const SizedBox(height: 16),
        const SummaryStatsCard(),
        const SizedBox(height: 14),
        const CategoryDonutCard(),
        const SizedBox(height: 14),
        const MonthlyTrendCard(),
        const SizedBox(height: 14),
        const DailySpendingCard(),
      ],
    );
  }
}
