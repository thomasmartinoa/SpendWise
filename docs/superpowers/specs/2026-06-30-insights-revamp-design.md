# Insights Revamp — Design

**Date:** 2026-06-30
**Status:** Approved (design)
**Scope:** The Insights screen + a new Settings "Insights" section. No change to persistence architecture or other screens.

## Context

The Insights screen ([lib/screens/insights_screen.dart](../../../lib/screens/insights_screen.dart))
currently stacks four cards built in an earlier feature: a summary-stats card,
a category donut, a 6-month income-vs-spending trend, and a daily-spending bar
chart. It works but the card chrome is duplicated and slightly inconsistent,
there are no real empty states, and the user wants (a) a polished UI, (b) a new
**calendar heatmap** of daily spending, and (c) the ability to **show/hide each
insight** from Settings.

Decisions confirmed with the user:
- Calendar = **heatmap month grid** (coloured squares, tap a day for its total).
- Visibility = **per-card toggles** (one switch per card), not a master switch.
- Polish = a **refinement** of the current layout, not a from-scratch redesign.
- Daily-bars and Calendar are **both kept** as separate, individually toggleable
  cards (they overlap, so the toggles let the user choose).

## Goals

- A cleaner, more consistent Insights screen with real empty states.
- A new tappable calendar heatmap card.
- Per-card visibility, persisted, controlled from Settings.
- No regressions to the existing charts or the 33 passing tests.

## Architecture

All cards read derived data from `AppState` (unchanged aggregation helpers).
New work is additive UI plus a small visibility model.

### Shared card chrome — `InsightCard`

A new `lib/widgets/charts/insight_card.dart` exposes:
```dart
class InsightCard extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget child;
}
```
It renders the `c.card` container (radius 20, border `c.line`, padding 18) with a
consistent title (`manrope` size 15 w700) + optional caption (size 11.5 w600
`c.ink2`) above the body. The four existing cards (`SummaryStatsCard`,
`CategoryDonutCard`, `MonthlyTrendCard`, `DailySpendingCard`) are refactored to
use it, removing their duplicated `Container`/title boilerplate. Their charts and
logic are unchanged.

### Per-card empty states

Each chart card shows a centered icon + one-line message when its period has no
data (e.g. donut: "No spending recorded this month."; trend: "Not enough history
yet."). Most already have partial empty states; this standardizes them via a tiny
`_EmptyHint(icon, text)` helper inside each card file.

### Visibility model (`AppState`)

- New field: `Map<String, bool> insightCards` with keys
  `['summary','category','trend','daily','calendar']`, all default `true`.
- `void toggleInsight(String key)` flips the value, persists, notifies.
- Persistence: stored in `shared_preferences` as a JSON string under the key
  `insight_cards` (read in `load()`, written in `_savePrefs()` — both already
  exist post-Drift). Unknown/missing keys default to `true`.
- `bool insightOn(String key) => insightCards[key] ?? true;`

## Calendar heatmap card

New `lib/widgets/charts/calendar_card.dart` — a `StatefulWidget` (tracks the
selected day):

- Title "Spending calendar", caption = month name.
- A 7-column grid (Sun→Sat header row) for `app.viewMonth`, with leading blank
  cells before day 1. Each day is a rounded square (`AspectRatio` 1:1) shaded by
  that day's spend from `app.dailyTotals(viewMonth)`:
  - 0 spend → `c.key` (neutral).
  - else → `Brand.accent` at opacity scaled `0.30 → 1.0` by
    `amount / maxDayInMonth`.
  - the selected day gets a ring (`Brand.accent`, 1.5).
- Tapping a day sets the selection and shows a caption line below the grid:
  `"12 Jun · ₹240 · 3 entries"` (entry count computed from
  `app.transactions.where(date == that day)`), or "No spending" for empty days.
- A small legend row: "Less ▢▨▩◼ More".
- Empty state (no spend all month): the standard `_EmptyHint`.

Reuses existing `AppState` helpers (`dailyTotals`, `monthName`, `fmt`,
`parse`/`iso`); no new aggregation. A `dayEntryCount(String isoDate)` helper is
added to `AppState` for the caption (pure, derived).

## Settings → Insights section

New section in [lib/screens/settings_screen.dart](../../../lib/screens/settings_screen.dart),
placed after "Appearance": a card with five switch rows — Summary stats,
Category donut, Monthly trend, Daily spending, Calendar — each bound to
`app.insightOn(key)` / `app.toggleInsight(key)`. A small caption: "Choose which
cards appear on the Insights tab." Each row uses a Material `Switch` tinted with
`Brand.accent` (active track/thumb), label in `manrope` size 14.5 w700.
`toggleInsight` flips the map, calls `_savePrefs()`, and notifies.

## Insights screen assembly

`InsightsScreen` becomes: title + month switcher, then each card wrapped in
`if (app.insightOn('<key>')) ...`. If **no** cards are enabled, show a centered
empty state: "All insights are hidden." + "Turn them on in Settings." The
month-switcher and header always render.

## Testing

- Unit: `toggleInsight` flips + `insightOn` reflects it; visibility map
  round-trips through `_savePrefs`/`load` (via `SharedPreferences` mock).
- Unit: `dayEntryCount` counts entries on a given date.
- Widget smoke: Insights with sample data renders all five cards; after
  disabling 'trend' and 'daily', those titles are absent; with all disabled,
  the "All insights are hidden." message shows.
- Calendar widget renders with sample data and shows the empty hint with none.

## Verification

`flutter analyze` clean · `flutter test` green (existing 33 + new) ·
`flutter build web` compiles · manual: toggle each card off/on in Settings and
confirm the Insights tab reflects it; tap calendar days.

## Out of scope

- Changing the aggregation helpers or other screens.
- Income on the calendar (spending only).
- Reordering cards or custom date ranges.
