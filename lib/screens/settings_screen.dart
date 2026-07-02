import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'settings/backup_screen.dart';
import 'settings/categories_screen.dart';
import 'settings/insights_screen.dart';
import 'settings/recurring_screen.dart';
import 'settings/settings_widgets.dart';
import 'settings/sources_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final cur = app.currency;

    return Material(
      type: MaterialType.transparency,
      child: ListView(
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
                MiniBox(text: cur.symbol, bg: c.key, fg: c.ink),
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
                      Text('Sets the currency symbol used across the app.',
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
        const SectionLabel('Manage'),
        _NavRow(
            icon: Icons.bar_chart_rounded,
            label: 'Insights',
            subtitle:
                '${app.insightCards.values.where((v) => v).length} of ${app.insightCards.length} cards shown',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const InsightsSettingsScreen()))),
        _NavRow(
            icon: Icons.category_outlined,
            label: 'Categories',
            subtitle: '${app.cats.length} categories',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CategoriesScreen()))),
        _NavRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Income sources',
            subtitle: '${app.sources.length} sources',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SourcesScreen()))),
        _NavRow(
            icon: Icons.repeat,
            label: 'Recurring',
            subtitle: '${app.recurring.length} items',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const RecurringScreen()))),
        _NavRow(
            icon: Icons.backup_outlined,
            label: 'Backup & restore',
            subtitle:
                app.lastBackup == null ? 'never backed up' : 'backed up',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const BackupScreen()))),
        const SizedBox(height: 22),
        Center(
          child: Text('SpendWise · v1.0',
              style:
                  manrope(size: 12, weight: FontWeight.w600, color: c.ink2)),
        ),
      ],
      ),
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
                    MiniBox(text: cu.symbol, bg: c.key, fg: c.ink),
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

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _NavRow(
      {required this.icon,
      required this.label,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.ink2),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: manrope(
                            size: 14.5, weight: FontWeight.w700, color: c.ink)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: manrope(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: c.ink2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: c.ink2),
            ],
          ),
        ),
      ),
    );
  }
}
