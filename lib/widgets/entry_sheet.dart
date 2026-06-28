import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'ui.dart';

class EntrySheet extends StatelessWidget {
  const EntrySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    final val = double.tryParse(app.amount) ?? 0;
    final count = app.splitCount < 1 ? 1 : app.splitCount;
    final share = (val / count).round();
    final isExp = app.entryMode == 'expense';
    final showSplitShare = isExp && app.splitOn && val > 0;
    final cur = app.currency;
    final editing = app.editingId != null;

    String saveLabel;
    if (editing) {
      saveLabel = 'Save changes';
    } else if (!isExp) {
      saveLabel = val > 0 ? 'Add income ${cur.symbol}${app.fmtType(app.amount)}' : 'Add income';
    } else if (app.splitOn) {
      saveLabel = val > 0 ? 'Save your share ${app.fmt(share)}' : 'Save expense';
    } else {
      saveLabel = val > 0 ? 'Add expense ${cur.symbol}${app.fmtType(app.amount)}' : 'Add expense';
    }

    return Stack(
      children: [
        // scrim
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 200),
            builder: (_, t, _) => Opacity(
              opacity: t,
              child: GestureDetector(
                onTap: app.close,
                child: Container(color: const Color(0x66141412)),
              ),
            ),
          ),
        ),
        // sheet
        Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 280),
            curve: const Cubic(.22, 1, .36, 1),
            builder: (_, t, child) =>
                Transform.translate(offset: Offset(0, t * 600), child: child),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.95),
              child: Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(
                    22,
                    10,
                    22,
                    26 +
                        MediaQuery.of(context).viewInsets.bottom +
                        MediaQuery.of(context).padding.bottom),
                child: SingleChildScrollView(
                  child: _SheetBody(
                    isExp: isExp,
                    val: val,
                    count: count,
                    share: share,
                    showSplitShare: showSplitShare,
                    saveLabel: saveLabel,
                    editing: editing,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetBody extends StatelessWidget {
  final bool isExp;
  final double val;
  final int count;
  final int share;
  final bool showSplitShare;
  final String saveLabel;
  final bool editing;
  const _SheetBody({
    required this.isExp,
    required this.val,
    required this.count,
    required this.share,
    required this.showSplitShare,
    required this.saveLabel,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final cur = app.currency;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // grab handle
        Center(
          child: Container(
            width: 38,
            height: 5,
            margin: const EdgeInsets.only(top: 2, bottom: 14),
            decoration: BoxDecoration(
                color: c.line, borderRadius: BorderRadius.circular(3)),
          ),
        ),

        // mode tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: c.key, borderRadius: BorderRadius.circular(13)),
          child: Row(
            children: [
              _Tab(
                  label: 'Expense',
                  selected: isExp,
                  onTap: () => app.set(() => app.entryMode = 'expense')),
              const SizedBox(width: 8),
              _Tab(
                  label: 'Income',
                  selected: !isExp,
                  onTap: () => app.set(() => app.entryMode = 'income')),
            ],
          ),
        ),

        // amount
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Center(
            child: Column(
              children: [
                Text('${cur.symbol}${app.fmtType(app.amount)}',
                    style: manrope(
                        size: 44,
                        weight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: -1.3)),
                if (showSplitShare)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                        color: Brand.tintBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        'Your share ${app.fmt(share)}  ·  split $count ways',
                        style: manrope(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: Brand.tintInk)),
                  ),
              ],
            ),
          ),
        ),

        if (isExp) ...[
          const SectionLabel('Category',
              padding: EdgeInsets.only(top: 4, bottom: 9)),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: app.cats.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cc = app.cats[i];
                final sel = app.cat == cc.key;
                return GestureDetector(
                  onTap: () => app.set(() => app.cat = cc.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? Brand.tintBg : c.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? Brand.accent : c.line, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: cc.color,
                                borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 7),
                        Text(cc.label,
                            style: manrope(
                                size: 13,
                                weight: FontWeight.w700,
                                color: sel ? Brand.tintInk : c.ink)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _SplitToggle(),
          if (app.splitOn) ...[
            const SizedBox(height: 10),
            _PeopleStepper(count: count),
          ],
        ] else ...[
          const SectionLabel('Source',
              padding: EdgeInsets.only(top: 4, bottom: 9)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: app.sources.map((s) {
              final sel = app.source == s;
              return GestureDetector(
                onTap: () => app.set(() => app.source = s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? Brand.greenTintBg : c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? Brand.green : c.line, width: 1.5),
                  ),
                  child: Text(s,
                      style: manrope(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: sel ? Brand.greenInk : c.ink)),
                ),
              );
            }).toList(),
          ),
        ],

        // date
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: app.parse(app.entryDate),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              app.set(() => app.entryDate = app.iso(picked));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: c.field,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date',
                    style: manrope(
                        size: 14, weight: FontWeight.w700, color: c.ink)),
                Text(_prettyDate(app),
                    style: manrope(
                        size: 14, weight: FontWeight.w700, color: c.ink)),
              ],
            ),
          ),
        ),

        // recurring
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => app.set(() => app.recurringOn = !app.recurringOn),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: app.recurringOn ? Brand.tintBg : c.field,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: app.recurringOn ? Brand.accent : c.line, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Repeat monthly',
                          style: manrope(
                              size: 14,
                              weight: FontWeight.w700,
                              color: app.recurringOn ? Brand.tintInk : c.ink)),
                      Text('save as a recurring item',
                          style: manrope(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: c.ink2)),
                    ],
                  ),
                ),
                _Toggle(on: app.recurringOn),
              ],
            ),
          ),
        ),

        // note
        const SizedBox(height: 10),
        SoftField(
          value: app.note,
          hint: 'Add a note (optional)',
          onChanged: (v) => app.set(() => app.note = v),
        ),

        // keypad
        const SizedBox(height: 12),
        _Keypad(),

        // actions
        const SizedBox(height: 13),
        Row(
          children: [
            if (editing) ...[
              GestureDetector(
                onTap: () {
                  final removed = app.editingTxn;
                  app.remove();
                  if (removed != null) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(SnackBar(
                        content: const Text('Entry deleted'),
                        action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => app.restore(removed)),
                      ));
                  }
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
            ],
            Expanded(
              child: GestureDetector(
                onTap: app.save,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: val > 0 ? Brand.accent : const Color(0xFFD9B6AE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(saveLabel,
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
    );
  }

  String _prettyDate(AppState app) {
    final d = app.parse(app.entryDate);
    final base = '${d.day} ${kMon[d.month - 1]}';
    return d.year != app.today.year ? '$base ${d.year}' : base;
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: c.dark ? 0.25 : 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Text(label,
              style: manrope(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: selected ? c.ink : c.ink2)),
        ),
      ),
    );
  }
}

class _SplitToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final on = app.splitOn;
    return GestureDetector(
      onTap: () => app.set(() => app.splitOn = !app.splitOn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: on ? Brand.tintBg : c.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? Brand.accent : c.line, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: on ? Brand.accent : c.key,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('÷',
                  style: manrope(
                      size: 17,
                      weight: FontWeight.w800,
                      color: on ? Colors.white : c.ink2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Split this bill',
                      style: manrope(
                          size: 14,
                          weight: FontWeight.w700,
                          color: on ? Brand.tintInk : c.ink)),
                  Text(
                      on
                          ? 'records only your share'
                          : 'auto-calc your share of the total',
                      style: manrope(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: c.ink2)),
                ],
              ),
            ),
            _Toggle(on: on),
          ],
        ),
      ),
    );
  }
}

class _PeopleStepper extends StatelessWidget {
  final int count;
  const _PeopleStepper({required this.count});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Number of people',
                  style: manrope(
                      size: 14, weight: FontWeight.w700, color: c.ink)),
              Text('including you',
                  style: manrope(
                      size: 11.5, weight: FontWeight.w600, color: c.ink2)),
            ],
          ),
          Row(
            children: [
              _RoundBtn(
                  glyph: '−',
                  filled: false,
                  onTap: () => app.set(() => app.splitCount =
                      (app.splitCount - 1) < 1 ? 1 : app.splitCount - 1)),
              const SizedBox(width: 14),
              SizedBox(
                width: 26,
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: manrope(
                        size: 20, weight: FontWeight.w800, color: c.ink)),
              ),
              const SizedBox(width: 14),
              _RoundBtn(
                  glyph: '+',
                  filled: true,
                  onTap: () => app.set(() {
                        final next =
                            (app.splitCount < 1 ? 1 : app.splitCount) + 1;
                        app.splitCount = next > 30 ? 30 : next;
                      })),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final String glyph;
  final bool filled;
  final VoidCallback onTap;
  const _RoundBtn(
      {required this.glyph, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? Brand.accent : c.card,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: c.line, width: 1.5),
        ),
        child: Text(glyph,
            style: manrope(
                size: 22,
                weight: FontWeight.w700,
                color: filled ? Colors.white : c.ink)),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool on;
  const _Toggle({required this.on});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        color: on ? Brand.accent : const Color(0xFFC8C8C0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1))
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final c = AppColors.of(context);
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'back'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 2.25,
      children: keys.map((k) {
        return GestureDetector(
          onTap: () => app.press(k),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: c.key, borderRadius: BorderRadius.circular(14)),
            child: Text(k == 'back' ? '⌫' : k,
                style:
                    manrope(size: 22, weight: FontWeight.w700, color: c.ink)),
          ),
        );
      }).toList(),
    );
  }
}
