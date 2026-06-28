import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/txn_row.dart';
import '../widgets/ui.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    final q = app.histQuery.trim().toLowerCase();
    final filtered = [...app.transactions, ...app.income].where((t) {
      if (app.histCat != 'All' && t.category != app.histCat) return false;
      if (q.isNotEmpty &&
          !(t.title.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q))) {
        return false;
      }
      return true;
    }).toList();

    // group consecutive rows (already date-sorted desc) by their date label
    final sorted = app.sortDesc(filtered);
    final groups = <({String label, List<Txn> rows})>[];
    for (final t in sorted) {
      final label = app.dateLabel(t.date);
      if (groups.isNotEmpty && groups.last.label == label) {
        groups.last.rows.add(t);
      } else {
        groups.add((label: label, rows: [t]));
      }
    }

    final chips = ['All', ...app.cats.map((e) => e.key)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      children: [
        Text('History',
            style: manrope(
                size: 24,
                weight: FontWeight.w800,
                color: c.ink,
                letterSpacing: -0.5)),
        const SizedBox(height: 14),
        SoftField(
          value: app.histQuery,
          hint: 'Search transactions',
          onChanged: (v) => app.set(() => app.histQuery = v),
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final key = chips[i];
              final sel = app.histCat == key;
              final label = key == 'All' ? 'All' : app.catOf(key).label;
              return GestureDetector(
                onTap: () => app.set(() => app.histCat = key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? Brand.tintBg : c.card,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: sel ? Brand.accent : c.line, width: 1.5),
                  ),
                  child: Text(label,
                      style: manrope(
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: sel ? Brand.tintInk : c.ink)),
                ),
              );
            },
          ),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 46),
            child: Column(
              children: [
                Text('⌕', style: TextStyle(fontSize: 30, color: c.ink2)),
                const SizedBox(height: 6),
                Text('No transactions found.',
                    style: manrope(
                        size: 13.5, weight: FontWeight.w600, color: c.ink2)),
              ],
            ),
          )
        else
          ...groups.map((g) => Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(g.label),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.line),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < g.rows.length; i++)
                            TxnRow(g.rows[i],
                                avatar: 40, divider: i != g.rows.length - 1),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}
