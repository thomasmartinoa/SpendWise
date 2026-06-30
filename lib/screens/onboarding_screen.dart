import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../csv_io.dart';
import '../theme.dart';
import '../widgets/logo_mark.dart';
import '../widgets/ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // setup-form state
  String _name = '';
  String _currency = 'INR';
  String _theme = 'system';

  static const _last = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _last) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      context.read<AppState>().completeOnboarding(
            name: _name,
            currencyCode: _currency,
            themeMode: _theme,
          );
    }
  }

  void _skipToSetup() => _controller.animateToPage(_last,
      duration: const Duration(milliseconds: 320), curve: Curves.easeOut);

  /// Restore from a CSV backup during first-run, then enter the app.
  Future<void> _importBackup() async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await importCsv(app);
    if (ok == null || !mounted) return; // cancelled
    if (ok) {
      app.completeOnboarding(
          name: _name, currencyCode: _currency, themeMode: _theme);
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not read that file.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SafeArea(
            child: Column(
              children: [
                // top bar: Skip on the value slides
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      opacity: _page < _last ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: _page < _last ? _skipToSetup : null,
                        child: Text('Skip',
                            style: manrope(
                                size: 14,
                                weight: FontWeight.w700,
                                color: c.ink2)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      const _WelcomePage(),
                      const _FeaturePage(
                        glyph: '÷',
                        accent: Brand.accent,
                        tintBg: Brand.tintBg,
                        title: 'Split bills in a tap',
                        body:
                            'Log a shared bill and SpendWise auto-calculates just your share — no mental math.',
                      ),
                      const _FeaturePage(
                        icon: Icons.insights_rounded,
                        accent: Brand.green,
                        tintBg: Brand.greenTintBg,
                        title: 'See where it goes',
                        body:
                            'Monthly insights break your spending down by category, with income vs. spent at a glance.',
                      ),
                      _SetupPage(
                        name: _name,
                        currency: _currency,
                        theme: _theme,
                        onName: (v) => _name = v,
                        onCurrency: (v) => setState(() => _currency = v),
                        onTheme: (v) => setState(() => _theme = v),
                        onImport: _importBackup,
                      ),
                    ],
                  ),
                ),
                // dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_last + 1, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? Brand.accent : c.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                // primary button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                  child: GestureDetector(
                    onTap: _next,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Brand.accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_page < _last ? 'Next' : 'Start tracking',
                          style: manrope(
                              size: 16,
                              weight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LogoMark(size: 116),
          const SizedBox(height: 28),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: 'Spend',
                  style: manrope(
                      size: 34, weight: FontWeight.w800, color: c.ink)),
              TextSpan(
                  text: 'Wise',
                  style: manrope(
                      size: 34,
                      weight: FontWeight.w800,
                      color: Brand.accent)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            'Track every rupee, split bills fairly, and spend a little wiser.',
            textAlign: TextAlign.center,
            style: manrope(
                size: 15, weight: FontWeight.w600, color: c.ink2, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FeaturePage extends StatelessWidget {
  final String? glyph;
  final IconData? icon;
  final String title, body;
  final Color accent, tintBg;
  const _FeaturePage({
    this.glyph,
    this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.tintBg,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: tintBg, borderRadius: BorderRadius.circular(28)),
            child: icon != null
                ? Icon(icon, size: 44, color: accent)
                : Text(glyph ?? '',
                    style: manrope(
                        size: 46, weight: FontWeight.w800, color: accent)),
          ),
          const SizedBox(height: 28),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  manrope(size: 24, weight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 10),
          Text(body,
              textAlign: TextAlign.center,
              style: manrope(
                  size: 15,
                  weight: FontWeight.w600,
                  color: c.ink2,
                  height: 1.5)),
        ],
      ),
    );
  }
}

class _SetupPage extends StatelessWidget {
  final String name, currency, theme;
  final ValueChanged<String> onName, onCurrency, onTheme;
  final VoidCallback onImport;
  const _SetupPage({
    required this.name,
    required this.currency,
    required this.theme,
    required this.onName,
    required this.onCurrency,
    required this.onTheme,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Let's set you up",
              style:
                  manrope(size: 24, weight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 6),
          Text('You can change any of this later in Settings.',
              style:
                  manrope(size: 14, weight: FontWeight.w600, color: c.ink2)),
          const SizedBox(height: 22),

          const SectionLabel('Your name'),
          SoftField(
            value: name,
            hint: 'e.g. Alex',
            onChanged: onName,
          ),
          const SizedBox(height: 22),

          const SectionLabel('Currency'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCurrencies.map((cu) {
              final sel = currency == cu.code;
              return GestureDetector(
                onTap: () => onCurrency(cu.code),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? Brand.tintBg : c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? Brand.accent : c.line, width: 1.5),
                  ),
                  child: Text('${cu.symbol}  ${cu.code}',
                      style: manrope(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: sel ? Brand.tintInk : c.ink)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          const SectionLabel('Appearance'),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: c.key, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                _ThemeSeg(label: '☀ Light', value: 'light', selected: theme, onTap: onTheme),
                const SizedBox(width: 6),
                _ThemeSeg(label: '☾ Dark', value: 'dark', selected: theme, onTap: onTheme),
                const SizedBox(width: 6),
                _ThemeSeg(label: '◐ System', value: 'system', selected: theme, onTap: onTheme),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // restore from a previous backup
          Center(
            child: GestureDetector(
              onTap: onImport,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: c.line, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file_outlined, size: 18, color: c.ink2),
                    const SizedBox(width: 8),
                    Text('Import from CSV backup',
                        style: manrope(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: c.ink)),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Already use SpendWise? Restore your data.',
                  style: manrope(
                      size: 12, weight: FontWeight.w600, color: c.ink2)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSeg extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  const _ThemeSeg(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sel = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: sel
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
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: sel ? c.ink : c.ink2)),
        ),
      ),
    );
  }
}
