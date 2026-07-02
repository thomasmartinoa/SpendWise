# Richer Insights — Design

**Date:** 2026-06-28
**Status:** Approved (design)
**Scope:** Insights screen only. The Drift database migration is a separate, later effort and is explicitly **out of scope** here.

## Context

The current Insights screen ([lib/screens/insights_screen.dart](../../../lib/screens/insights_screen.dart))
shows a month switcher, an Income / Spent / Saved summary, and a list of
horizontal "spending by category" bars. It's functional but flat — no charts,
no trends, no comparison over time. This redesign turns it into a proper
analytics screen using `fl_chart`, while keeping the app's existing card
aesthetic and the `AppState`-centric architecture (all data derived in memory
from `transactions` / `income`).

## Goals

- Replace the flat category bars with real visualizations.
- Show where money goes (donut), how it trends over time (6-month bars), and
  intra-month patterns (daily bars), plus key summary stats.
- Keep everything reactive off the existing `AppState`; add only **pure derived
  helpers** (no new stored state) so the future Drift migration won't disturb it.
- Work correctly in light **and** dark themes, and degrade to friendly empty
  states with no data.

## Library

**`fl_chart`** (latest stable). Chosen over `syncfusion_flutter_charts`
(heavier, licensing) and hand-rolled `CustomPaint` (reinventing axes/touch).
Supports donut (`PieChart`), grouped bars (`BarChart`), touch interaction, and
theming via colors we already define in `Brand` / `AppColors`.

## Architecture

Rewrite `InsightsScreen` as a single scrollable `ListView` of cards (no tabs —
everything visible by scrolling, consistent with the rest of the app). The
month switcher continues to drive the "this month" cards; the trend card looks
back 6 months ending at the viewed month.

```
InsightsScreen (ListView)
├── Month switcher          (existing MonthSwitch)
├── SummaryStatsCard        (income/spent/saved + savings rate, avg/day, biggest, Δ vs last month)
├── CategoryDonutCard       (fl_chart PieChart donut + ranked legend)
├── MonthlyTrendCard        (fl_chart grouped BarChart, income vs expense, 6 months)
└── DailySpendingCard       (fl_chart BarChart, expense per day this month)
```

New chart widgets live in `lib/widgets/charts/` (one file per card) so each is
small, self-contained, and testable. They receive plain data structures from
`AppState` and render — they hold no business logic.

## Cards

### 1. Summary stats
Keep the existing 3-up Income / Spent / Saved row. Add a second row:
- **Savings rate** = saved / income (%, 0 if no income)
- **Avg / day** = spent / days elapsed in the viewed month (full days if past month)
- **Biggest expense** = largest single expense this month
- **vs last month** = spending delta with ▲/▼ and color (up = orange, down = green)

### 2. Spending by category (donut)
- `PieChart` donut; **center shows total spent** (or the selected slice's value).
- Ranked legend below: color dot · label · amount · %.
- Touch: tapping a slice emphasizes it and shows its value in the center.
- Replaces the old horizontal bars (the legend is the breakdown).
- Empty: "No spending recorded this month."

### 3. Income vs spending (6-month trend)
- Grouped `BarChart`: income (Brand.green) and expense (Brand.accent) per month,
  for the 6 months ending at the viewed month.
- X labels = 3-letter month abbreviations (`kMon`); Y auto-scaled.
- Empty: shown only if all six months are zero.

### 4. Daily spending (this month)
- `BarChart`, one bar per day of the selected month (expense totals).
- Sparse X labels (e.g. every 5th day); zero-spend days render as gaps.
- Empty: "No spending recorded this month."

## AppState additions (pure, derived)

No new stored fields. New read-only helpers computed from `transactions` /
`income`, reusing existing `monthKey`, `catOf`, `fmt`:

- `List<CatSlice> categoryBreakdown(String monthKey)` — `{key, label, color, amount, pct}` sorted desc.
- `List<MonthTotals> monthlyTotals({int months = 6})` — trailing N months ending at `viewMonth`: `{monthKey, label, income, spent}`.
- `List<int> dailyTotals(String monthKey)` — expense total per day-of-month (index 0 = day 1).
- `InsightStats insightStats(String monthKey)` — `{savingsRate, avgPerDay, biggestExpense, prevMonthSpent, deltaPct}`.

Small value types (`CatSlice`, `MonthTotals`, `InsightStats`) live in
`lib/models.dart` or alongside the helpers.

## Theming & responsiveness

All chart colors come from `Brand` (category colors, accent, green) and
`AppColors` (grid/labels via `ink2`/`line`). Text uses `manrope()` (already
weight-softened globally). Cards keep the existing `AppCard`/radius styling and
the 480-px max-width shell.

## Testing

- Unit tests for each aggregation helper with a deterministic dataset:
  `categoryBreakdown`, `monthlyTotals`, `dailyTotals`, `insightStats`
  (savings rate, avg/day, biggest, delta).
- Widget smoke test: Insights renders with sample data (no exceptions) and
  shows each card; and renders the empty states with no data.

## Out of scope

- Drift / database migration (separate spec).
- Budgets, exporting charts, custom date ranges beyond month navigation.
- Per-slice drill-down screens.

## Verification

`flutter analyze` clean · `flutter test` green (new helper + smoke tests) ·
`flutter build web` compiles · manual check of all four cards in light/dark and
with empty data.
