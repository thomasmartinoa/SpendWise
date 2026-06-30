import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/txn_row.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final recent = app.sortDesc([...app.transactions, ...app.income]).take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
      children: [
        // header + hero — horizontal swipe changes the viewed month
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
              Text(app.greeting,
                  style:
                      manrope(size: 14, weight: FontWeight.w600, color: c.ink2)),
              const SizedBox(height: 8),
              const MonthSwitch(big: true),
              const SizedBox(height: 20),
              // hero
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: c.hero,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEFT TO SPEND',
                        style: manrope(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: const Color(0xFF9A9A90),
                            letterSpacing: 0.3)),
                    const SizedBox(height: 7),
                    Text(app.fmt(app.monthIncome - app.monthSpent),
                        style: manrope(
                            size: 40,
                            weight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                              dot: Brand.greenDot,
                              label: 'Income',
                              value: app.fmt(app.monthIncome)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeroStat(
                              dot: Brand.accent,
                              label: 'Spent',
                              value: app.fmt(app.monthSpent)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // shortcuts
        Row(
          children: [
            Expanded(
              child: _Shortcut(
                onTap: () => app.openEntry('expense', true),
                bg: Brand.tintBg,
                border: Brand.tintBorder,
                iconBg: Brand.accent,
                iconColor: Colors.white,
                glyph: '÷',
                title: 'Split a bill',
                titleColor: Brand.tintInk,
                sub: 'auto-calc your share',
                subColor: Brand.tintSub,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Shortcut(
                onTap: () => app.openEntry('income', false),
                bg: c.card,
                border: c.line,
                iconBg: Brand.greenTintBg,
                iconColor: Brand.green,
                glyph: '+',
                title: 'Add income',
                titleColor: c.ink,
                sub: 'salary, pocket money',
                subColor: c.ink2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // recent
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent activity',
                style:
                    manrope(size: 16, weight: FontWeight.w800, color: c.ink)),
            GestureDetector(
              onTap: () => app.go('history'),
              child: Text('See all',
                  style: manrope(
                      size: 13, weight: FontWeight.w700, color: Brand.accent)),
            ),
          ],
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Column(
              children: [
                Text('◔', style: TextStyle(fontSize: 30, color: c.ink2)),
                const SizedBox(height: 6),
                Text('No activity yet — tap + to add one.',
                    style: manrope(
                        size: 13.5, weight: FontWeight.w600, color: c.ink2)),
              ],
            ),
          )
        else
          ...recent.map((t) => TxnRow(t)),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  final Color dot;
  final String label;
  final String value;
  const _HeroStat(
      {required this.dot, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: c.heroSub,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(label,
                  style: manrope(
                      size: 12,
                      weight: FontWeight.w600,
                      color: const Color(0xFFA8A8A0))),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: manrope(
                  size: 18, weight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final VoidCallback onTap;
  final Color bg, border, iconBg, iconColor, titleColor, subColor;
  final String glyph, title, sub;
  const _Shortcut({
    required this.onTap,
    required this.bg,
    required this.border,
    required this.iconBg,
    required this.iconColor,
    required this.glyph,
    required this.title,
    required this.titleColor,
    required this.sub,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(glyph,
                  style: manrope(
                      size: 18, weight: FontWeight.w800, color: iconColor)),
            ),
            const SizedBox(height: 11),
            Text(title,
                style: manrope(
                    size: 14.5, weight: FontWeight.w700, color: titleColor)),
            const SizedBox(height: 1),
            Text(sub,
                style: manrope(
                    size: 11.5, weight: FontWeight.w600, color: subColor)),
          ],
        ),
      ),
    );
  }
}
