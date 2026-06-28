import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// A single income/expense list row, matching the prototype's `row()` output.
class TxnRow extends StatelessWidget {
  final Txn txn;
  final double avatar;
  final bool divider;
  const TxnRow(this.txn, {super.key, this.avatar = 43, this.divider = true});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final c = AppColors.of(context);
    final cat = app.catOf(txn.category);

    var sub = txn.isIncome ? txn.category : cat.label;
    if (txn.split != null) sub = '${cat.label} · split ${txn.split!.count} ways';
    if (txn.recurring) sub += ' · ↻ monthly';

    final initial = txn.isIncome
        ? '+'
        : (cat.label.isNotEmpty ? cat.label[0].toUpperCase() : '?');
    final avColor = txn.isIncome ? Brand.green : cat.color;
    final amountText = (txn.isIncome ? '+' : '−') + app.fmt(txn.amount);
    final amtColor = txn.isIncome ? Brand.green : c.ink;

    return InkWell(
      onTap: () => app.openDetail(txn),
      child: Container(
        decoration: divider
            ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line2)))
            : null,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: avatar,
              height: avatar,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avColor,
                borderRadius: BorderRadius.circular(avatar * 0.3),
              ),
              child: Text(
                initial,
                style: manrope(
                    size: avatar * 0.32,
                    weight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    txn.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: manrope(
                        size: 14.5, weight: FontWeight.w700, color: c.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: manrope(
                        size: 12.5, weight: FontWeight.w500, color: c.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountText,
              style:
                  manrope(size: 15, weight: FontWeight.w700, color: amtColor),
            ),
          ],
        ),
      ),
    );
  }
}
