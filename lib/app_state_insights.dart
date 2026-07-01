part of 'app_state.dart';

extension AppStateInsights on AppState {
  // ============================ derived views ============================
  List<Txn> sortDesc(List<Txn> arr) {
    final copy = [...arr];
    copy.sort((a, b) {
      if (a.date != b.date) return a.date.compareTo(b.date) < 0 ? 1 : -1;
      return b.id - a.id;
    });
    return copy;
  }

  List<Txn> get monthTx =>
      transactions.where((t) => monthKey(t.date) == viewMonth).toList();
  List<Txn> get monthInc =>
      income.where((t) => monthKey(t.date) == viewMonth).toList();

  int get monthIncome => monthInc.fold(0, (a, t) => a + t.amount);
  int get monthSpent => monthTx.fold(0, (a, t) => a + t.amount);

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Number of expense entries dated exactly [isoDate] (for the calendar).
  int dayEntryCount(String isoDate) =>
      transactions.where((t) => t.date == isoDate).length;

  // ============================ insights aggregations ============================

  /// Expense breakdown by category for [mk] ('YYYY-MM'), sorted by amount desc.
  /// Returns an empty list when there are no expenses that month.
  List<CatSlice> categoryBreakdown(String mk) {
    final mtx = transactions.where((t) => monthKey(t.date) == mk).toList();
    if (mtx.isEmpty) return [];
    final agg = <String, int>{};
    for (final t in mtx) {
      agg[t.category] = (agg[t.category] ?? 0) + t.amount;
    }
    final total = agg.values.fold(0, (a, b) => a + b);
    if (total == 0) return [];
    return agg.entries.map((e) {
      final c = catOf(e.key);
      return CatSlice(
          key: e.key, label: c.label, color: c.color,
          amount: e.value, pct: e.value / total);
    }).toList()
      ..sort((a, b) => b.amount - a.amount);
  }

  /// Income vs spent for the trailing [months] calendar months ending at
  /// [viewMonth], returned oldest-first.
  List<MonthTotals> monthlyTotals({int months = 6}) {
    final p = viewMonth.split('-').map(int.parse).toList();
    return List.generate(months, (i) {
      final d = DateTime(p[0], p[1] - (months - 1 - i), 1);
      final mk = '${d.year}-${_pad(d.month)}';
      final inc = income
          .where((t) => monthKey(t.date) == mk)
          .fold(0, (a, t) => a + t.amount);
      final spent = transactions
          .where((t) => monthKey(t.date) == mk)
          .fold(0, (a, t) => a + t.amount);
      return MonthTotals(
          monthKey: mk, label: kMon[d.month - 1], income: inc, spent: spent);
    });
  }

  /// Daily expense totals for [mk]. Result length == days in that month;
  /// index 0 = day 1. Zero for days with no spending.
  List<int> dailyTotals(String mk) {
    final p = mk.split('-').map(int.parse).toList();
    final daysInMonth = DateTime(p[0], p[1] + 1, 0).day;
    final result = List<int>.filled(daysInMonth, 0);
    for (final t in transactions) {
      if (monthKey(t.date) == mk) {
        final day = int.parse(t.date.split('-')[2]);
        if (day >= 1 && day <= daysInMonth) result[day - 1] += t.amount;
      }
    }
    return result;
  }

  /// Derived stats for [mk]: savings rate, avg/day, biggest expense,
  /// previous month spent, and delta %.
  InsightStats insightStats(String mk) {
    final mtx = transactions.where((t) => monthKey(t.date) == mk).toList();
    final minc = income.where((t) => monthKey(t.date) == mk).toList();
    final spent = mtx.fold(0, (a, t) => a + t.amount);
    final inc = minc.fold(0, (a, t) => a + t.amount);
    final savingsRate = inc > 0 ? (inc - spent) / inc : 0.0;

    final p = mk.split('-').map(int.parse).toList();
    final now = DateTime.now();
    final isCurrent = p[0] == now.year && p[1] == now.month;
    final daysElapsed = isCurrent ? now.day : DateTime(p[0], p[1] + 1, 0).day;
    final avgPerDay = daysElapsed > 0 ? spent ~/ daysElapsed : 0;

    final biggestExpense =
        mtx.isEmpty ? 0 : mtx.map((t) => t.amount).reduce(math.max);

    final prevD = DateTime(p[0], p[1] - 1, 1);
    final prevMk = '${prevD.year}-${_pad(prevD.month)}';
    final prevSpent = transactions
        .where((t) => monthKey(t.date) == prevMk)
        .fold(0, (a, t) => a + t.amount);
    final deltaPct =
        prevSpent > 0 ? (spent - prevSpent) / prevSpent : 0.0;

    return InsightStats(
      savingsRate: savingsRate,
      avgPerDay: avgPerDay,
      biggestExpense: biggestExpense,
      prevMonthSpent: prevSpent,
      deltaPct: deltaPct,
    );
  }
}
