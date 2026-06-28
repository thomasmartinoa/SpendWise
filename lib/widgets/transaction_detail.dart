import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Read-only view of a single transaction. Tapping a row opens this; the
/// "Edit" button hands off to the editor sheet.
class TransactionDetail extends StatelessWidget {
  const TransactionDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.detailTxn;
    if (t == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final cat = app.catOf(t.category);
    final isInc = t.isIncome;
    final accent = isInc ? Brand.green : cat.color;

    return Stack(
      children: [
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (_, v, _) => Opacity(
              opacity: v,
              child: GestureDetector(
                onTap: app.closeDetail,
                child: Container(color: const Color(0x66141412)),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 260),
            curve: const Cubic(.22, 1, .36, 1),
            builder: (_, v, child) =>
                Transform.translate(offset: Offset(0, v * 520), child: child),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                  22, 10, 22, 26 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      margin: const EdgeInsets.only(top: 2, bottom: 18),
                      decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(3)),
                    ),
                  ),

                  // header: avatar + title
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(14)),
                        child: Text(
                            isInc
                                ? '+'
                                : (cat.label.isNotEmpty
                                    ? cat.label[0].toUpperCase()
                                    : '?'),
                            style: manrope(
                                size: 18,
                                weight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: manrope(
                                    size: 18,
                                    weight: FontWeight.w800,
                                    color: c.ink)),
                            Text(isInc ? 'Income' : 'Expense',
                                style: manrope(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: c.ink2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // amount
                  Text(
                    (isInc ? '+' : '−') + app.fmt(t.amount),
                    style: manrope(
                        size: 38,
                        weight: FontWeight.w800,
                        color: isInc ? Brand.green : c.ink,
                        letterSpacing: -1),
                  ),
                  const SizedBox(height: 18),

                  // details
                  Container(
                    decoration: BoxDecoration(
                      color: c.field,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _Row(
                          label: isInc ? 'Source' : 'Category',
                          valueWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 7),
                              Text(isInc ? t.category : cat.label,
                                  style: manrope(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: c.ink)),
                            ],
                          ),
                        ),
                        _Row(label: 'Date', value: _fullDate(app, t.date)),
                        if (t.split != null)
                          _Row(
                              label: 'Split',
                              value:
                                  '${t.split!.count} ways · total ${app.fmt(t.split!.total)}'),
                        if (t.recurring)
                          _Row(label: 'Repeats', value: 'Monthly'),
                        _Row(label: 'Note', value: t.title, last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // actions
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final removed = t;
                          app.removeTxn(removed);
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                              content: const Text('Entry deleted'),
                              action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () => app.restore(removed)),
                            ));
                        },
                        child: Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Brand.accent, width: 1.5),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Brand.accent, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: app.editFromDetail,
                          child: Container(
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Brand.accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('Edit',
                                style: manrope(
                                    size: 15.5,
                                    weight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fullDate(AppState app, String iso) {
    final d = app.parse(iso);
    return '${d.day} ${kMonths[d.month - 1]} ${d.year}';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool last;
  const _Row(
      {required this.label, this.value, this.valueWidget, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: last
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: c.line2))),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  manrope(size: 14, weight: FontWeight.w600, color: c.ink2)),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget ??
                  Text(value ?? '',
                      textAlign: TextAlign.right,
                      style: manrope(
                          size: 14, weight: FontWeight.w700, color: c.ink)),
            ),
          ),
        ],
      ),
    );
  }
}
