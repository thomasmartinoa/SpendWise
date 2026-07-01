import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/charts/insight_card.dart';
import 'settings_widgets.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Recurring (monthly)',
            style: manrope(
                size: 18, weight: FontWeight.w700, color: AppColors.of(context).ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: app.recurring.isEmpty
                ? const EmptyHint(
                    icon: Icons.repeat, text: 'No recurring items yet.')
                : Column(
                    children: app.recurring.map((r) {
                      final cc = app.catOf(r.category);
                      final isInc = r.type == 'income';
                      return Container(
                        decoration: BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: c.line2))),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            MiniBox(
                                text: isInc
                                    ? '+'
                                    : (cc.label.isNotEmpty
                                        ? cc.label[0].toUpperCase()
                                        : '?'),
                                bg: isInc ? Brand.green : cc.color,
                                fg: Colors.white,
                                size: 34),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(r.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: manrope(
                                          size: 14,
                                          weight: FontWeight.w700,
                                          color: c.ink)),
                                  Text(
                                      '${isInc ? 'Income' : cc.label} · ${app.fmt(r.amount)}${kFreqShort[r.freq] ?? '/mo'}',
                                      style: manrope(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: c.ink2)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => app.logRecurring(r),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                    color: c.key,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('Log now',
                                    style: manrope(
                                        size: 12.5,
                                        weight: FontWeight.w700,
                                        color: c.ink)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DeleteX(onTap: () => app.delRecurring(r.id)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
