import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../csv_io.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final cur = app.currency;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      children: [
        Text('Settings',
            style: manrope(
                size: 24,
                weight: FontWeight.w800,
                color: c.ink,
                letterSpacing: -0.5)),
        const SizedBox(height: 18),

        // ---- profile
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.hero, shape: BoxShape.circle),
                child: Text(app.nameInitial,
                    style: manrope(
                        size: 19,
                        weight: FontWeight.w800,
                        color: Colors.white)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _BareField(
                            value: app.name,
                            hint: 'Your name',
                            style: manrope(
                                size: 17,
                                weight: FontWeight.w800,
                                color: c.ink),
                            onChanged: (v) => app.set(() => app.name = v),
                          ),
                        ),
                        Icon(Icons.edit_outlined, size: 17, color: c.ink2),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text('Tap your name to edit · ${cur.symbol} ${cur.code}',
                        style: manrope(
                            size: 13,
                            weight: FontWeight.w600,
                            color: c.ink2)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- appearance
        const SectionLabel('Appearance'),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: c.key, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              _Segment(
                  label: '☀ Light',
                  selected: app.themeMode == 'light',
                  onTap: () => app.set(() => app.themeMode = 'light')),
              const SizedBox(width: 6),
              _Segment(
                  label: '☾ Dark',
                  selected: app.themeMode == 'dark',
                  onTap: () => app.set(() => app.themeMode = 'dark')),
              const SizedBox(width: 6),
              _Segment(
                  label: '◐ System',
                  selected: app.themeMode == 'system',
                  onTap: () => app.set(() => app.themeMode = 'system')),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- currency (collapsed to the selected one; tap to change)
        const SectionLabel('Currency'),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showCurrencyPicker(context, app),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                _MiniBox(text: cur.symbol, bg: c.key, fg: c.ink),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cur.label,
                          style: manrope(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: c.ink)),
                      Text('Converts all amounts at indicative rates',
                          style: manrope(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: c.ink2)),
                    ],
                  ),
                ),
                Text(cur.code,
                    style: manrope(
                        size: 13, weight: FontWeight.w700, color: c.ink2)),
                Icon(Icons.expand_more, size: 22, color: c.ink2),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ---- categories
        const SectionLabel('Expense categories'),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...app.cats.map((cc) => Container(
                    decoration: BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: c.line2))),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        _MiniBox(
                            text: cc.label.isNotEmpty
                                ? cc.label[0].toUpperCase()
                                : '?',
                            bg: cc.color,
                            fg: Colors.white,
                            size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(cc.label,
                              style: manrope(
                                  size: 14.5,
                                  weight: FontWeight.w700,
                                  color: c.ink)),
                        ),
                        _DeleteX(onTap: () => app.delCat(cc.key)),
                      ],
                    ),
                  )),
              const SizedBox(height: 14),
              // palette
              Wrap(
                spacing: 7,
                children: kPalette.map<Widget>((col) {
                  final sel = app.newCatColor == col;
                  return GestureDetector(
                    onTap: () => app.set(() => app.newCatColor = col),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: sel ? c.ink : Colors.transparent,
                            width: 2.5),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: SoftField(
                      value: app.newCatName,
                      hint: 'New category name',
                      onChanged: (v) => app.set(() => app.newCatName = v),
                    ),
                  ),
                  const SizedBox(width: 9),
                  _AddButton(
                      label: 'Add', color: Brand.accent, onTap: app.addCat),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- income sources
        const SectionLabel('Income sources'),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...app.sources.map((s) => Container(
                    decoration: BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: c.line2))),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        _MiniBox(
                            text: '+',
                            bg: Brand.greenTintBg,
                            fg: Brand.green,
                            size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s,
                              style: manrope(
                                  size: 14.5,
                                  weight: FontWeight.w700,
                                  color: c.ink)),
                        ),
                        _DeleteX(onTap: () => app.delSource(s)),
                      ],
                    ),
                  )),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: SoftField(
                      value: app.newSourceName,
                      hint: 'New income source',
                      onChanged: (v) => app.set(() => app.newSourceName = v),
                    ),
                  ),
                  const SizedBox(width: 9),
                  _AddButton(
                      label: 'Add', color: Brand.green, onTap: app.addSource),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- recurring
        const SectionLabel('Recurring (monthly)'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: app.recurring.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                      'Turn on "Repeat monthly" when adding an entry to keep it here for one-tap logging.',
                      style: manrope(
                          size: 13,
                          weight: FontWeight.w600,
                          color: c.ink2,
                          height: 1.45)),
                )
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
                          _MiniBox(
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
                          _DeleteX(onTap: () => app.delRecurring(r.id)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 24),

        // ---- backup
        const SectionLabel('Backup & restore'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              _BackupRow(
                iconBg: Brand.greenTintBg,
                iconColor: Brand.green,
                glyph: '↓',
                title: 'Export to CSV',
                sub: 'download a backup file',
                divider: true,
                onTap: () => exportCsv(app),
              ),
              _BackupRow(
                iconBg: Brand.tintBg,
                iconColor: Brand.accent,
                glyph: '↑',
                title: 'Import from CSV',
                sub: 'restore from a backup',
                divider: false,
                onTap: () async {
                  final go = await confirmDialog(
                    context,
                    title: 'Import backup?',
                    message:
                        'Importing a CSV replaces all of your current transactions and income. This cannot be undone.',
                    confirmLabel: 'Import',
                  );
                  if (!go || !context.mounted) return;
                  final ok = await importCsv(app);
                  if (ok != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Backup imported.'
                            : 'Could not read that file.')));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Text('SpendWise · v1.0',
              style:
                  manrope(size: 12, weight: FontWeight.w600, color: c.ink2)),
        ),
      ],
    );
  }
}

/// Bottom-sheet currency picker (replaces the always-expanded list).
void _showCurrencyPicker(BuildContext context, AppState app) {
  final c = AppColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: c.line, borderRadius: BorderRadius.circular(3)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Currency',
                  style:
                      manrope(size: 17, weight: FontWeight.w800, color: c.ink)),
            ),
          ),
          ...kCurrencies.map((cu) {
            final sel = app.currencyCode == cu.code;
            return InkWell(
              onTap: () {
                app.setCurrency(cu.code);
                Navigator.of(ctx).pop();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    _MiniBox(text: cu.symbol, bg: c.key, fg: c.ink),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(cu.label,
                          style: manrope(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: c.ink)),
                    ),
                    if (sel)
                      const Icon(Icons.check, color: Brand.accent, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: c.dark ? 0.25 : 0.1),
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

class _MiniBox extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final double size;
  const _MiniBox(
      {required this.text, required this.bg, required this.fg, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(text,
          style: manrope(
              size: size * 0.45, weight: FontWeight.w800, color: fg)),
    );
  }
}

class _DeleteX extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteX({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.key, shape: BoxShape.circle),
        child: Text('×',
            style: manrope(size: 15, weight: FontWeight.w700, color: c.ink2)),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AddButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style:
                manrope(size: 14, weight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  final Color iconBg, iconColor;
  final String glyph, title, sub;
  final bool divider;
  final VoidCallback onTap;
  const _BackupRow({
    required this.iconBg,
    required this.iconColor,
    required this.glyph,
    required this.title,
    required this.sub,
    required this.divider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: divider
            ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line2)))
            : null,
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            _MiniBox(text: glyph, bg: iconBg, fg: iconColor),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: manrope(
                          size: 14.5, weight: FontWeight.w700, color: c.ink)),
                  Text(sub,
                      style: manrope(
                          size: 11.5, weight: FontWeight.w600, color: c.ink2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A borderless inline text field (used for the profile name).
class _BareField extends StatefulWidget {
  final String value;
  final String hint;
  final TextStyle style;
  final ValueChanged<String> onChanged;
  const _BareField(
      {required this.value,
      required this.hint,
      required this.style,
      required this.onChanged});

  @override
  State<_BareField> createState() => _BareFieldState();
}

class _BareFieldState extends State<_BareField> {
  late final TextEditingController controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_BareField old) {
    super.didUpdateWidget(old);
    if (widget.value != controller.text) {
      controller.text = widget.value;
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      onChanged: widget.onChanged,
      style: widget.style,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: widget.style.copyWith(color: c.ink2),
      ),
    );
  }
}
