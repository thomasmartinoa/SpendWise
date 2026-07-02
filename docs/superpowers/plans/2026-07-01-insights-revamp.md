# Insights Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the Insights screen, add a tappable calendar-heatmap card, and let each insight card be shown/hidden from Settings.

**Architecture:** Additive UI plus a small visibility model on `AppState`. A shared `InsightCard` wrapper unifies card chrome; existing chart cards refactor onto it; a new `CalendarCard` reuses the existing `dailyTotals` aggregation; Settings gains an "Insights" section of Material switches bound to a persisted visibility map.

**Tech Stack:** Flutter/Dart, fl_chart (existing), provider, shared_preferences.

## Global Constraints

- Visibility keys are exactly `summary`, `category`, `trend`, `daily`, `calendar`; all default `true`.
- Visibility persists as a JSON string under the `shared_preferences` key `insight_cards`, read in `AppState.load()` and written in `AppState._savePrefs()`.
- Calendar is a 7-column month heatmap (Sun→Sat); spending only (expenses); day squares shaded `Brand.accent` opacity `0.30→1.0` by `amount/maxDayInMonth`; zero-spend day = `c.key`.
- Empty-state copy reused verbatim: donut, daily, AND calendar all use `'No spending recorded this month.'`; trend uses `'Not enough history yet.'`.
- Do NOT change the chart logic or the `AppState` aggregation helpers. Chart bodies stay byte-identical through the `InsightCard` refactor.
- Reuse existing theme helpers (`AppColors`, `manrope`, `Brand`) — no hardcoded hex.
- Keep the 33 existing tests green (one assertion in `widget_test.dart` is updated in Task 6, noted there).

---

### Task 1: AppState — visibility model + dayEntryCount

**Files:**
- Modify: `lib/app_state.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces: `Map<String, bool> insightCards`; `bool insightOn(String key)`; `void toggleInsight(String key)`; `int dayEntryCount(String isoDate)`.

- [ ] **Step 1: Write failing tests**

In `test/widget_test.dart`, inside the `'AppState logic'` group (before its closing `});`), add:
```dart
    test('insight cards default on and toggle flips them', () {
      final app = AppState();
      expect(app.insightOn('calendar'), isTrue);
      expect(app.insightOn('trend'), isTrue);
      app.toggleInsight('calendar');
      expect(app.insightOn('calendar'), isFalse);
      app.toggleInsight('calendar');
      expect(app.insightOn('calendar'), isTrue);
    });

    test('load restores insight visibility from prefs', () async {
      SharedPreferences.setMockInitialValues(
          {'insight_cards': jsonEncode({'trend': false})});
      final app = AppState();
      await app.load();
      expect(app.insightOn('trend'), isFalse);
      expect(app.insightOn('daily'), isTrue); // unspecified keys stay default
    });

    test('dayEntryCount counts expenses on a date', () {
      final app = AppState()..loadSampleData();
      final d = app.transactions.first.date;
      expect(app.dayEntryCount(d), greaterThanOrEqualTo(1));
      expect(app.dayEntryCount('1999-01-01'), 0);
    });
```
(`jsonEncode` and `SharedPreferences` are already imported in this test file.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --plain-name "insight cards default on"`
Expected: FAIL — `insightOn`/`toggleInsight` undefined.

- [ ] **Step 3: Add the visibility map + methods**

In `lib/app_state.dart`, in the `// ---- preferences` field group (right after the `bool onboardingComplete = false;` line), add:
```dart
  // which Insights cards are visible (default all on)
  final Map<String, bool> insightCards = {
    'summary': true,
    'category': true,
    'trend': true,
    'daily': true,
    'calendar': true,
  };
  bool insightOn(String key) => insightCards[key] ?? true;
  void toggleInsight(String key) {
    insightCards[key] = !insightOn(key);
    _savePrefs();
    notifyListeners();
  }
```

- [ ] **Step 4: Add dayEntryCount near the other derived getters**

In `lib/app_state.dart`, immediately after the `nameInitial` getter, add:
```dart
  /// Number of expense entries dated exactly [isoDate] (for the calendar).
  int dayEntryCount(String isoDate) =>
      transactions.where((t) => t.date == isoDate).length;
```

- [ ] **Step 5: Persist + restore the visibility map**

In `_savePrefs()`, before the closing `} catch (_) {}`, add (after the `pref_onboarded` line):
```dart
      await prefs.setString('insight_cards', jsonEncode(insightCards));
```
In `load()`, immediately after the line `if (prefs.getBool('pref_onboarded') == true) onboardingComplete = true;`, add:
```dart
      final ic = prefs.getString('insight_cards');
      if (ic != null) {
        try {
          final m = (jsonDecode(ic) as Map).cast<String, dynamic>();
          for (final k in insightCards.keys.toList()) {
            if (m[k] is bool) insightCards[k] = m[k] as bool;
          }
        } catch (_) {}
      }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test --plain-name "insight"` then `flutter test --plain-name "dayEntryCount"`
Expected: PASS.

- [ ] **Step 7: Analyze + full suite**

Run: `flutter analyze` (No issues) and `flutter test` (all pass).

- [ ] **Step 8: Commit**

```bash
git add lib/app_state.dart test/widget_test.dart
git commit -m "feat: add per-card Insights visibility model + dayEntryCount"
```

---

### Task 2: InsightCard + EmptyHint widgets

**Files:**
- Create: `lib/widgets/charts/insight_card.dart`
- Test: `test/data/insight_card_test.dart` (new)

**Interfaces:**
- Produces: `InsightCard({String? title, String? caption, EdgeInsets padding, required Widget child})`; `EmptyHint({required IconData icon, required String text})`.

- [ ] **Step 1: Write the failing test**

Create `test/data/insight_card_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/theme.dart';
import 'package:spendwise/widgets/charts/insight_card.dart';

void main() {
  testWidgets('InsightCard shows title and child; EmptyHint shows text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(false),
      home: const Scaffold(
        body: InsightCard(
          title: 'My Card',
          caption: 'a caption',
          child: Text('body-here'),
        ),
      ),
    ));
    expect(find.text('My Card'), findsOneWidget);
    expect(find.text('a caption'), findsOneWidget);
    expect(find.text('body-here'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(false),
      home: const Scaffold(
        body: EmptyHint(icon: Icons.info_outline, text: 'nothing here'),
      ),
    ));
    expect(find.text('nothing here'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/insight_card_test.dart`
Expected: FAIL — `insight_card.dart` not found.

- [ ] **Step 3: Create the widgets**

Create `lib/widgets/charts/insight_card.dart`:
```dart
import 'package:flutter/material.dart';

import '../../theme.dart';

/// Shared chrome for an Insights card: rounded card with an optional title +
/// caption above the body. Keeps every card visually consistent.
class InsightCard extends StatelessWidget {
  final String? title;
  final String? caption;
  final EdgeInsets padding;
  final Widget child;
  const InsightCard({
    super.key,
    this.title,
    this.caption,
    this.padding = const EdgeInsets.all(18),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(title!,
                style: manrope(size: 15, weight: FontWeight.w700, color: c.ink)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                style:
                    manrope(size: 11.5, weight: FontWeight.w600, color: c.ink2)),
          ],
          if (title != null) const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Centered icon + message used for a card's empty state.
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyHint({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 26, color: c.ink2),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style:
                    manrope(size: 13.5, weight: FontWeight.w600, color: c.ink2)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/insight_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze` (No issues).
```bash
git add lib/widgets/charts/insight_card.dart test/data/insight_card_test.dart
git commit -m "feat: add shared InsightCard + EmptyHint widgets"
```

---

### Task 3: Refactor the four existing cards onto InsightCard

**Files:**
- Modify: `lib/widgets/charts/daily_spending_card.dart`, `category_donut_card.dart`, `monthly_trend_card.dart`, `summary_stats_card.dart`

**Interfaces:**
- Consumes: `InsightCard`, `EmptyHint` (Task 2).

The transformation for each card is identical and purely structural: **delete the outer `Container(decoration: BoxDecoration(color: c.card, borderRadius..., border...), padding..., child: Column(... ))` plus the leading title `Text`, caption `Text`, and the `SizedBox(height: 16)` that separated header from body, and return an `InsightCard(...)` whose `child` is the SAME body widget (chart `SizedBox` / stats column) that was previously below the header.** The chart `SizedBox`, `BarChart`/`PieChart` config, and all data logic are unchanged. Replace each card's inline empty-state `Padding(Center(Text(...)))` with `EmptyHint`.

- [ ] **Step 1: Refactor `daily_spending_card.dart`**

Replace the `return Container(...)` block (the whole widget body from `return Container(` to its matching close) with:
```dart
    return InsightCard(
      title: 'Daily spending',
      caption: app.monthName(app.viewMonth),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: !hasData
          ? const EmptyHint(
              icon: Icons.bar_chart_rounded,
              text: 'No spending recorded this month.')
          : SizedBox(
              height: 160,
              child: BarChart(
                /* unchanged BarChartData(...) exactly as before */
              ),
            ),
    );
```
Keep the existing `BarChartData(...)` argument verbatim. Add `import 'insight_card.dart';` to the imports.

- [ ] **Step 2: Refactor `category_donut_card.dart`**

Wrap the body in `InsightCard(title: 'Spending by category', child: ...)`. Remove the old outer `Container` + the `Text('Spending by category', ...)` + its following `SizedBox(height: 16)`. The donut `SizedBox`/`PieChart` and the legend `Column` become the `InsightCard` child (wrap them in a `Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...])` if not already). Replace the empty-state branch with `const EmptyHint(icon: Icons.pie_chart_outline, text: 'No spending recorded this month.')`. Add `import 'insight_card.dart';`.

- [ ] **Step 3: Refactor `monthly_trend_card.dart`**

Wrap in `InsightCard(title: 'Income vs spending', caption: 'last 6 months', child: ...)`. Remove the old outer `Container` + the title/caption `Text`s + leading `SizedBox`. The chart `SizedBox` + legend row become the child. Replace the empty-state branch with `const EmptyHint(icon: Icons.show_chart, text: 'Not enough history yet.')`. Add `import 'insight_card.dart';`.

- [ ] **Step 4: Refactor `summary_stats_card.dart`**

This card has no title. Replace its outer `Container(decoration..., padding: const EdgeInsets.all(18), child: Column(...))` with `InsightCard(child: Column(...))` (no `title`/`caption`). The two-row stats `Column` is unchanged. Add `import 'insight_card.dart';`.

- [ ] **Step 5: Run the existing smoke tests (safety net)**

Run: `flutter test --plain-name "InsightsScreen smoke"`
Expected: PASS — `'Income vs spending'`, `'Spending by category'`, `'Daily spending'` still found (titles now rendered by `InsightCard`).

- [ ] **Step 6: Analyze + full suite + commit**

Run: `flutter analyze` (No issues) and `flutter test` (all pass).
```bash
git add lib/widgets/charts/daily_spending_card.dart lib/widgets/charts/category_donut_card.dart lib/widgets/charts/monthly_trend_card.dart lib/widgets/charts/summary_stats_card.dart
git commit -m "refactor: move Insights cards onto shared InsightCard chrome"
```

---

### Task 4: CalendarCard (month heatmap)

**Files:**
- Create: `lib/widgets/charts/calendar_card.dart`
- Test: `test/data/calendar_card_test.dart` (new)

**Interfaces:**
- Consumes: `AppState.dailyTotals`, `AppState.dayEntryCount`, `AppState.monthName`, `AppState.fmt`, `kMon`; `InsightCard`, `EmptyHint`.
- Produces: `CalendarCard` (StatefulWidget).

- [ ] **Step 1: Write the failing test**

Create `test/data/calendar_card_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';
import 'package:spendwise/theme.dart';
import 'package:spendwise/widgets/charts/calendar_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(AppState app) => ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: buildTheme(false),
          home: const Scaffold(
              body: SingleChildScrollView(child: CalendarCard())),
        ),
      );

  testWidgets('renders the calendar with data', (tester) async {
    final app = AppState()..loadSampleData();
    await tester.pumpWidget(host(app));
    await tester.pump();
    expect(find.text('Spending calendar'), findsOneWidget);
  });

  testWidgets('shows the empty hint with no data', (tester) async {
    final app = AppState();
    await tester.pumpWidget(host(app));
    await tester.pump();
    expect(find.text('No spending recorded this month.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/calendar_card_test.dart`
Expected: FAIL — `calendar_card.dart` not found.

- [ ] **Step 3: Create the calendar card**

Create `lib/widgets/charts/calendar_card.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';
import 'insight_card.dart';

/// Month heatmap of daily spending. Each day is shaded by how much was spent;
/// tap a day to see its total.
class CalendarCard extends StatefulWidget {
  const CalendarCard({super.key});

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  int? _selectedDay; // 1-based, or null

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final daily = app.dailyTotals(app.viewMonth); // index 0 == day 1
    final hasData = daily.any((v) => v > 0);
    final maxVal = hasData ? daily.reduce((a, b) => a > b ? a : b) : 1;

    final parts = app.viewMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // Sun=0..Sat=6
    final daysInMonth = daily.length;

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final amt = daily[day - 1];
      final selected = _selectedDay == day;
      cells.add(_dayCell(c, day, amt, maxVal, selected,
          () => setState(() => _selectedDay = selected ? null : day)));
    }

    return InsightCard(
      title: 'Spending calendar',
      caption: app.monthName(app.viewMonth),
      child: !hasData
          ? const EmptyHint(
              icon: Icons.calendar_today_outlined,
              text: 'No spending recorded this month.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _weekHeader(c),
                const SizedBox(height: 6),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  children: cells,
                ),
                const SizedBox(height: 12),
                _selectionLine(app, c, month),
                const SizedBox(height: 10),
                _legend(c),
              ],
            ),
    );
  }

  Widget _weekHeader(AppColors c) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: labels
          .map((l) => Expanded(
                child: Center(
                  child: Text(l,
                      style: manrope(
                          size: 11, weight: FontWeight.w700, color: c.ink2)),
                ),
              ))
          .toList(),
    );
  }

  Widget _dayCell(AppColors c, int day, int amt, int maxVal, bool selected,
      VoidCallback onTap) {
    final t = maxVal > 0 ? amt / maxVal : 0.0;
    final bg = amt <= 0
        ? c.key
        : Brand.accent.withValues(alpha: 0.30 + 0.70 * t.clamp(0.0, 1.0));
    final fg = amt > 0 && t > 0.45 ? Colors.white : c.ink2;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border:
                selected ? Border.all(color: Brand.accent, width: 1.5) : null,
          ),
          child: Text('$day',
              style: manrope(size: 11.5, weight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }

  Widget _selectionLine(AppState app, AppColors c, int month) {
    final day = _selectedDay;
    if (day == null) {
      return Text('Tap a day to see its spending.',
          style: manrope(size: 12.5, weight: FontWeight.w600, color: c.ink2));
    }
    final iso = '${app.viewMonth}-${day.toString().padLeft(2, '0')}';
    final amt = app.dailyTotals(app.viewMonth)[day - 1];
    final count = app.dayEntryCount(iso);
    final dateLabel = '$day ${kMon[month - 1]}';
    return Text(
      amt > 0
          ? '$dateLabel · ${app.fmt(amt)} · $count ${count == 1 ? 'entry' : 'entries'}'
          : '$dateLabel · No spending',
      style: manrope(size: 13, weight: FontWeight.w700, color: c.ink),
    );
  }

  Widget _legend(AppColors c) {
    const steps = [0.0, 0.33, 0.66, 1.0];
    return Row(
      children: [
        Text('Less',
            style: manrope(size: 11, weight: FontWeight.w600, color: c.ink2)),
        const SizedBox(width: 6),
        ...steps.map((s) => Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: s == 0
                    ? c.key
                    : Brand.accent.withValues(alpha: 0.30 + 0.70 * s),
                borderRadius: BorderRadius.circular(4),
              ),
            )),
        const SizedBox(width: 6),
        Text('More',
            style: manrope(size: 11, weight: FontWeight.w600, color: c.ink2)),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/calendar_card_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze` (No issues).
```bash
git add lib/widgets/charts/calendar_card.dart test/data/calendar_card_test.dart
git commit -m "feat: add CalendarCard month-heatmap of daily spending"
```

---

### Task 5: Settings → Insights section

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `AppState.insightOn`, `AppState.toggleInsight`.

- [ ] **Step 1: Insert the Insights section**

In `lib/screens/settings_screen.dart`, find the Appearance block's end — the line `const SizedBox(height: 24),` immediately followed by `// ---- currency (collapsed to the selected one; tap to change)`. Insert this block BETWEEN them (after that `SizedBox`, before the currency comment):
```dart
        // ---- insights visibility
        const SectionLabel('Insights'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: const [
              _InsightToggle(label: 'Summary stats', k: 'summary'),
              _InsightToggle(label: 'Category donut', k: 'category'),
              _InsightToggle(label: 'Monthly trend', k: 'trend'),
              _InsightToggle(label: 'Daily spending', k: 'daily'),
              _InsightToggle(label: 'Calendar', k: 'calendar', last: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
```

- [ ] **Step 2: Add the `_InsightToggle` widget**

At the end of `lib/screens/settings_screen.dart` (after the last existing private class), add:
```dart
class _InsightToggle extends StatelessWidget {
  final String label;
  final String k;
  final bool last;
  const _InsightToggle(
      {required this.label, required this.k, this.last = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    return Container(
      decoration: last
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: c.line2))),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    manrope(size: 14.5, weight: FontWeight.w700, color: c.ink)),
          ),
          Switch(
            value: app.insightOn(k),
            onChanged: (_) => app.toggleInsight(k),
            activeTrackColor: Brand.accent,
          ),
        ],
      ),
    );
  }
}
```
(`context.watch`/`provider`, `AppState`, `AppColors`, `manrope`, `Brand`, `SectionLabel` are already imported in this file.)

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add Insights show/hide toggles to Settings"
```

---

### Task 6: Insights screen assembly (conditional cards + calendar + empty state)

**Files:**
- Modify: `lib/screens/insights_screen.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `AppState.insightOn`; `CalendarCard`; existing card widgets.

- [ ] **Step 1: Update the existing empty-state assertion**

In `test/widget_test.dart`, the test `'shows empty states with no data'` currently asserts `find.text('No spending recorded this month.')` is `findsNWidgets(2)`. The calendar (default on) adds a third occurrence with no data. Change that one assertion to:
```dart
      expect(find.text('No spending recorded this month.'), findsNWidgets(3));
```

- [ ] **Step 2: Add the visibility + all-hidden smoke tests**

In `test/widget_test.dart`, inside the `'InsightsScreen smoke'` group (before its closing `});`), add:
```dart
    testWidgets('honors per-card visibility toggles', (tester) async {
      tester.view.physicalSize = const Size(440, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = AppState()..loadSampleData();
      app.set(() => app.screen = 'insights');
      await tester.pumpWidget(buildApp(app));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Spending by category'), findsOneWidget);

      app.toggleInsight('category');
      await tester.pump();
      expect(find.text('Spending by category'), findsNothing);
    });

    testWidgets('shows the all-hidden message when every card is off',
        (tester) async {
      tester.view.physicalSize = const Size(440, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = AppState()..loadSampleData();
      for (final k in ['summary', 'category', 'trend', 'daily', 'calendar']) {
        app.toggleInsight(k);
      }
      app.set(() => app.screen = 'insights');
      await tester.pumpWidget(buildApp(app));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('All insights are hidden.'), findsOneWidget);
    });
```
(`buildApp` is the helper already defined in the `'InsightsScreen smoke'` group.)

- [ ] **Step 3: Run tests to verify the new ones fail**

Run: `flutter test --plain-name "honors per-card visibility"`
Expected: FAIL — Insights screen does not yet read `insightOn`.

- [ ] **Step 4: Rewrite the Insights screen**

Replace the entire contents of `lib/screens/insights_screen.dart` with:
```dart
import 'package:flutter/material.dart';
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
        Text('Insights',
            style: manrope(
                size: 24,
                weight: FontWeight.w800,
                color: c.ink,
                letterSpacing: -0.5)),
        const SizedBox(height: 10),
        const MonthSwitch(),
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
```

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS — including the updated `findsNWidgets(3)` and the two new visibility tests.

- [ ] **Step 6: Analyze + build + commit**

Run: `flutter analyze` (No issues) and `flutter build web` (compiles).
```bash
git add lib/screens/insights_screen.dart test/widget_test.dart
git commit -m "feat: Insights screen honors per-card visibility + adds calendar"
```

---

## Verification (whole feature)

- `flutter analyze` clean.
- `flutter test` green: existing 33 (one assertion updated) + Task 1 (3) + Task 2 (1) + Task 4 (2) + Task 6 (2) new tests.
- `flutter build web` compiles.
- Manual: open Insights → see all five cards incl. the calendar; tap calendar days → caption updates. Settings → Insights → toggle each card off and confirm it disappears from the Insights tab; turn all off → "All insights are hidden." Restart app → toggles persist.
