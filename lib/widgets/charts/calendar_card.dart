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
  String _lastMonth = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    // Clear the selection when the month changes so a day index from the old
    // month can't run past the new month's length (avoids a RangeError).
    if (app.viewMonth != _lastMonth) {
      _lastMonth = app.viewMonth;
      _selectedDay = null;
    }
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
