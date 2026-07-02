# Richer Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat Insights screen with four data-rich cards — summary stats, category donut, 6-month income/expense trend, and daily spending — powered by `fl_chart`.

**Architecture:** Pure derived aggregation helpers on `AppState` (no new stored state) produce small value types (`CatSlice`, `MonthTotals`, `InsightStats`) that feed self-contained chart widgets in `lib/widgets/charts/`, all composed in a rewritten `InsightsScreen` `ListView`.

**Tech Stack:** `fl_chart ^0.69.0`, existing `provider`/`AppState`/`ChangeNotifier`, `Brand`/`AppColors` theming, `manrope()` text styles.

## Global Constraints
- Flutter 3.41+, Dart 3.11+
- All chart colors MUST come from `Brand.*` or `AppColors.*` — never hardcode hex in chart widgets
- Max 480 px width (existing `ConstrainedBox` shell, no change needed)
- Every chart card MUST show a friendly empty-state text (not crash) when no data exists for the period
- Run `flutter analyze` and `flutter test` before every commit; existing 15 tests must keep passing
- TDD: write each test before its implementation, confirm it fails first, then implement

---

### Task 1: Add fl_chart + value types

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/models.dart` — add `CatSlice`, `MonthTotals`, `InsightStats` before `_colorFrom`
- Modify: `test/widget_test.dart` — add constructibility tests

**Interfaces:**
- Produces:
  - `CatSlice({required String key, required String label, required Color color, required int amount, required double pct})`
  - `MonthTotals({required String monthKey, required String label, required int income, required int spent})`
  - `InsightStats({required double savingsRate, required int avgPerDay, required int biggestExpense, required int prevMonthSpent, required double deltaPct})`

- [ ] **Step 1: Write failing tests**

In `test/widget_test.dart`, add this group inside `main()` after the last existing test:

```dart
group('Insights value types', () {
  test('CatSlice constructs correctly', () {
    const s = CatSlice(
        key: 'Food', label: 'Food', color: Color(0xFFE0533D), amount: 500, pct: 0.5);
    expect(s.amount, 500);
    expect(s.pct, 0.5);
  });

  test('MonthTotals constructs correctly', () {
    const m = MonthTotals(
        monthKey: '2026-06', label: 'Jun', income: 20000, spent: 5000);
    expect(m.income - m.spent, 15000);
  });

  test('InsightStats constructs correctly', () {
    const s = InsightStats(
        savingsRate: 0.75, avgPerDay: 167, biggestExpense: 2000,
        prevMonthSpent: 4000, deltaPct: 0.25);
    expect(s.savingsRate, 0.75);
    expect(s.deltaPct, 0.25);
  });
});
```

Also add this import at the top of `test/widget_test.dart`:
```dart
import 'package:spendwise/models.dart';
```

Run: `flutter test --plain-name "Insights value types"`
Expected: FAIL — types not defined yet.

- [ ] **Step 2: Add fl_chart to pubspec.yaml**

Open `pubspec.yaml`. After the `path_provider: ^2.1.4` line add:
```yaml
  # Charts for the Insights screen
  fl_chart: ^0.69.0
```

Run: `flutter pub get`
Expected: resolves without errors.

- [ ] **Step 3: Add value types to lib/models.dart**

Insert the following three classes **immediately before** the `int _colorFrom(dynamic v)` function at the bottom of `lib/models.dart`:

```dart
/// Aggregated category spending slice for one month (Insights donut).
class CatSlice {
  final String key;
  final String label;
  final Color color;
  final int amount;
  final double pct; // 0..1 fraction of total monthly spending
  const CatSlice({
    required this.key,
    required this.label,
    required this.color,
    required this.amount,
    required this.pct,
  });
}

/// Income vs spent totals for one calendar month (Insights trend chart).
class MonthTotals {
  final String monthKey; // 'YYYY-MM'
  final String label;   // 3-letter abbreviation, e.g. 'Jun'
  final int income;
  final int spent;
  const MonthTotals({
    required this.monthKey,
    required this.label,
    required this.income,
    required this.spent,
  });
}

/// Derived summary stats for one calendar month (Insights summary card).
class InsightStats {
  final double savingsRate; // fraction 0..1 (negative if overspent)
  final int avgPerDay;      // average daily spend (integer amount in local currency)
  final int biggestExpense; // largest single expense amount that month
  final int prevMonthSpent; // total spent in the immediately preceding month
  final double deltaPct;    // (spent - prevSpent) / prevSpent; positive = more than last month
  const InsightStats({
    required this.savingsRate,
    required this.avgPerDay,
    required this.biggestExpense,
    required this.prevMonthSpent,
    required this.deltaPct,
  });
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test --plain-name "Insights value types"
```
Expected: 3 PASS.

- [ ] **Step 5: Analyze**

```bash
flutter analyze
```
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/models.dart test/widget_test.dart
git commit -m "feat: add fl_chart dependency and Insights value types (CatSlice/MonthTotals/InsightStats)"
```

---

### Task 2: AppState aggregation helpers

**Files:**
- Modify: `lib/app_state.dart` — add `dart:math` import + four helper methods

**Interfaces:**
- Consumes: `CatSlice`, `MonthTotals`, `InsightStats` from Task 1; existing fields `transactions`, `income`, `viewMonth` and methods `monthKey()`, `catOf()`, `_pad()`, `kMon`
- Produces:
  - `List<CatSlice> categoryBreakdown(String mk)` — sorted desc by amount, empty list when no expenses
  - `List<MonthTotals> monthlyTotals({int months = 6})` — trailing N months ending at viewMonth, oldest first
  - `List<int> dailyTotals(String mk)` — length == days in month, index 0 = day 1, 0 for zero-spend days
  - `InsightStats insightStats(String mk)` — all stats for the given month key

- [ ] **Step 1: Write failing tests**

In `test/widget_test.dart`, add after the `'Insights value types'` group:

```dart
group('AppState aggregation helpers', () {
  late AppState app;
  setUp(() {
    app = AppState();
    app.set(() {
      app.transactions = [
        Txn(id: 1, date: '2026-06-01', type: 'expense', category: 'Food', title: 'Lunch', amount: 300),
        Txn(id: 2, date: '2026-06-01', type: 'expense', category: 'Food', title: 'Dinner', amount: 200),
        Txn(id: 3, date: '2026-06-15', type: 'expense', category: 'Transport', title: 'Bus', amount: 50),
        Txn(id: 4, date: '2026-05-10', type: 'expense', category: 'Food', title: 'May lunch', amount: 400),
      ];
      app.income = [
        Txn(id: 101, date: '2026-06-01', type: 'income', category: 'Salary', title: 'Pay', amount: 10000),
      ];
      app.viewMonth = '2026-06';
    });
  });

  test('categoryBreakdown returns slices sorted desc', () {
    final slices = app.categoryBreakdown('2026-06');
    expect(slices.length, 2);
    expect(slices.first.key, 'Food');
    expect(slices.first.amount, 500);
    expect(slices.last.key, 'Transport');
    expect(slices.last.amount, 50);
    expect(slices.fold(0.0, (a, s) => a + s.pct), closeTo(1.0, 0.001));
  });

  test('categoryBreakdown returns empty when no expenses', () {
    expect(app.categoryBreakdown('2025-01'), isEmpty);
  });

  test('monthlyTotals returns N months ending at viewMonth', () {
    final totals = app.monthlyTotals(months: 2);
    expect(totals.length, 2);
    expect(totals.last.monthKey, '2026-06');
    expect(totals.last.spent, 550);
    expect(totals.last.income, 10000);
    expect(totals.first.monthKey, '2026-05');
    expect(totals.first.spent, 400);
  });

  test('dailyTotals returns correct length and values', () {
    final daily = app.dailyTotals('2026-06');
    expect(daily.length, 30);   // June has 30 days
    expect(daily[0], 500);      // day 1: 300+200
    expect(daily[14], 50);      // day 15
    expect(daily[2], 0);        // day 3: no spending
  });

  test('insightStats computes correctly', () {
    final stats = app.insightStats('2026-06');
    expect(stats.savingsRate, closeTo((10000 - 550) / 10000, 0.001));
    expect(stats.biggestExpense, 300);
    expect(stats.prevMonthSpent, 400);
    expect(stats.deltaPct, closeTo((550 - 400) / 400, 0.001));
  });
});
```

Run: `flutter test --plain-name "AppState aggregation helpers"`
Expected: FAIL — methods not defined.

- [ ] **Step 2: Add dart:math import**

At the very top of `lib/app_state.dart` (before any other imports), add:
```dart
import 'dart:math' as math;
```

- [ ] **Step 3: Add the four helpers to AppState**

Find the line `// ============================ derived views ============================` near the bottom of `lib/app_state.dart`. Add the following **after** the `nameInitial` getter (end of the derived-views block), before the closing `}` of the class:

```dart
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
```

- [ ] **Step 4: Run aggregation tests**

```bash
flutter test --plain-name "AppState aggregation helpers"
```
Expected: 5 PASS.

- [ ] **Step 5: Run all tests**

```bash
flutter test
```
Expected: all tests PASS (15 original + 3 value types + 5 aggregation = 23 total).

- [ ] **Step 6: Analyze**

```bash
flutter analyze
```
Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/app_state.dart test/widget_test.dart
git commit -m "feat: add Insights aggregation helpers to AppState"
```

---

### Task 3: SummaryStatsCard widget

**Files:**
- Create: `lib/widgets/charts/summary_stats_card.dart`

**Interfaces:**
- Consumes: `InsightStats` (Task 1); `AppState.insightStats()`, `AppState.monthIncome`, `AppState.monthSpent`, `AppState.fmt()`, `AppColors`, `Brand`, `manrope()`
- Produces: `SummaryStatsCard` — stateless, reads via `context.watch<AppState>()`

- [ ] **Step 1: Create lib/widgets/charts/summary_stats_card.dart**

```dart
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
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/widgets/charts/summary_stats_card.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/charts/summary_stats_card.dart
git commit -m "feat: add SummaryStatsCard widget"
```

---

### Task 4: CategoryDonutCard widget

**Files:**
- Create: `lib/widgets/charts/category_donut_card.dart`

**Interfaces:**
- Consumes: `CatSlice` (Task 1); `AppState.categoryBreakdown()`, `AppState.monthSpent`, `AppState.fmt()`, `AppColors`, `Brand`, `manrope()`, `fl_chart` — `PieChart`, `PieChartData`, `PieChartSectionData`, `PieTouchData`
- Produces: `CategoryDonutCard` — stateful (tracks touched slice), reads via `context.watch<AppState>()`

- [ ] **Step 1: Create lib/widgets/charts/category_donut_card.dart**

```dart
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
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/widgets/charts/category_donut_card.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/charts/category_donut_card.dart
git commit -m "feat: add CategoryDonutCard with touch interaction and legend"
```

---

### Task 5: MonthlyTrendCard widget

**Files:**
- Create: `lib/widgets/charts/monthly_trend_card.dart`

**Interfaces:**
- Consumes: `MonthTotals` (Task 1); `AppState.monthlyTotals()`, `AppState.fmt()`, `AppColors`, `Brand`, `manrope()`, `fl_chart` — `BarChart`, `BarChartData`, `BarChartGroupData`, `BarChartRodData`, `FlTitlesData`, `AxisTitles`, `SideTitles`, `FlBorderData`, `FlGridData`, `FlLine`, `BarTouchData`, `BarTouchTooltipData`, `BarTooltipItem`
- Produces: `MonthlyTrendCard` — stateless

- [ ] **Step 1: Create lib/widgets/charts/monthly_trend_card.dart**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';

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

    return Container(
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line)),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs spending',
              style: manrope(size: 15, weight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 2),
          Text('last 6 months',
              style:
                  manrope(size: 11.5, weight: FontWeight.w600, color: c.ink2)),
          const SizedBox(height: 16),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text('No data for the last 6 months.',
                    style: manrope(
                        size: 13.5, weight: FontWeight.w600, color: c.ink2)),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data
                          .map((m) => m.income > m.spent ? m.income : m.spent)
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
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(data[i].label,
                                style: manrope(
                                    size: 10.5,
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
                                top: Radius.circular(4))),
                        BarChartRodData(
                            toY: m.spent.toDouble(),
                            color: Brand.accent,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(children: [
            _Dot(color: Brand.green, label: 'Income'),
            const SizedBox(width: 16),
            _Dot(color: Brand.accent, label: 'Spending'),
          ]),
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: manrope(size: 12, weight: FontWeight.w600, color: c.ink2)),
    ]);
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/widgets/charts/monthly_trend_card.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/charts/monthly_trend_card.dart
git commit -m "feat: add MonthlyTrendCard (6-month grouped bar chart)"
```

---

### Task 6: DailySpendingCard widget

**Files:**
- Create: `lib/widgets/charts/daily_spending_card.dart`

**Interfaces:**
- Consumes: `AppState.dailyTotals()`, `AppState.fmt()`, `AppColors`, `Brand`, `manrope()`, `fl_chart` — `BarChart`, `BarChartData`, `BarChartGroupData`, `BarChartRodData`, `FlTitlesData`, `AxisTitles`, `SideTitles`, `FlBorderData`, `FlGridData`, `FlLine`, `BarTouchData`, `BarTouchTooltipData`, `BarTooltipItem`
- Produces: `DailySpendingCard` — stateless

- [ ] **Step 1: Create lib/widgets/charts/daily_spending_card.dart**

```dart
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
                      getTooltipItem: (group, _, rod, __) {
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
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/widgets/charts/daily_spending_card.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/charts/daily_spending_card.dart
git commit -m "feat: add DailySpendingCard (per-day expense bars)"
```

---

### Task 7: Rewrite InsightsScreen + smoke tests

**Files:**
- Modify: `lib/screens/insights_screen.dart` — full rewrite
- Modify: `test/widget_test.dart` — add two smoke tests

**Interfaces:**
- Consumes: `SummaryStatsCard` (Task 3), `CategoryDonutCard` (Task 4), `MonthlyTrendCard` (Task 5), `DailySpendingCard` (Task 6); `MonthSwitch` from `lib/widgets/ui.dart`; `AppState`, `AppColors`, `manrope()`

- [ ] **Step 1: Write failing smoke tests**

In `test/widget_test.dart`, add after the aggregation-helpers group:

```dart
group('InsightsScreen smoke', () {
  Widget wrap(AppState app) => ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
            theme: buildTheme(false), home: const RootScaffold()),
      );

  testWidgets('renders all four cards with sample data', (tester) async {
    tester.view.physicalSize = const Size(440, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState()..loadSampleData();
    app.set(() => app.screen = 'insights');
    await tester.pumpWidget(wrap(app));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Income vs spending'), findsOneWidget);
    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.text('Daily spending'), findsOneWidget);
  });

  testWidgets('shows empty states with no data', (tester) async {
    tester.view.physicalSize = const Size(440, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState();
    app.completeOnboarding(
        name: 'T', currencyCode: 'INR', themeMode: 'light');
    app.set(() => app.screen = 'insights');
    await tester.pumpWidget(wrap(app));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.text('No spending recorded this month.'), findsNWidgets(2));
  });
});
```

Run: `flutter test --plain-name "InsightsScreen smoke"`
Expected: FAIL — screen not rewritten yet.

- [ ] **Step 2: Rewrite lib/screens/insights_screen.dart**

Replace the **entire** contents of the file with:

```dart
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/charts/category_donut_card.dart';
import '../widgets/charts/daily_spending_card.dart';
import '../widgets/charts/monthly_trend_card.dart';
import '../widgets/charts/summary_stats_card.dart';
import '../widgets/ui.dart';

/// Insights screen: scrollable stack of four analytics cards.
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
```

- [ ] **Step 3: Run smoke tests**

```bash
flutter test --plain-name "InsightsScreen smoke"
```
Expected: 2 PASS.

- [ ] **Step 4: Run all tests**

```bash
flutter test
```
Expected: all PASS (23 previous + 2 smoke = 25 total).

- [ ] **Step 5: Analyze**

```bash
flutter analyze
```
Expected: no issues.

- [ ] **Step 6: Build**

```bash
flutter build web
```
Expected: `✓ Built build/web`

- [ ] **Step 7: Commit**

```bash
git add lib/screens/insights_screen.dart \
        lib/widgets/charts/ \
        test/widget_test.dart
git commit -m "feat: richer Insights screen — donut, trend, daily, and summary stats cards"
```

---

## Self-Review

**Spec coverage:**
- ✅ `fl_chart` — Task 1
- ✅ `CatSlice`, `MonthTotals`, `InsightStats` value types — Task 1
- ✅ All four aggregation helpers — Task 2
- ✅ Summary stats (income/spent/saved + 4 quick stats) — Task 3
- ✅ Category donut with touch + ranked legend — Task 4
- ✅ 6-month income vs spending trend — Task 5
- ✅ Daily spending bars — Task 6
- ✅ Rewritten `InsightsScreen` — Task 7
- ✅ Empty states on every card — Tasks 4, 5, 6
- ✅ Light/dark via `Brand.*`/`AppColors.*` everywhere — all chart tasks
- ✅ Unit tests for all four helpers — Task 2
- ✅ Smoke tests (with data + empty) — Task 7
- ✅ `flutter analyze` + `flutter test` + `flutter build web` at each commit

**Placeholder scan:** None. All code blocks are complete and self-contained.

**Type consistency:** `CatSlice`/`MonthTotals`/`InsightStats` defined in Task 1, used identically in Tasks 2–7. `categoryBreakdown(String mk)`, `monthlyTotals({int months})`, `dailyTotals(String mk)`, `insightStats(String mk)` defined in Task 2 and called by the same names and signatures in Tasks 3–6. No mismatches.
