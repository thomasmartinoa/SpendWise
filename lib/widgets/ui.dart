import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Themed yes/no confirmation dialog. Returns true only if confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) async {
  final c = AppColors.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: manrope(size: 17, weight: FontWeight.w800, color: c.ink)),
      content: Text(message,
          style: manrope(
              size: 14, weight: FontWeight.w600, color: c.ink2, height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel,
              style:
                  manrope(size: 14, weight: FontWeight.w700, color: c.ink2)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel,
              style: manrope(
                  size: 14,
                  weight: FontWeight.w800,
                  color: danger ? Brand.accent : Brand.green)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Small circular ‹ / › nav button used by the month switcher.
class ArrowButton extends StatelessWidget {
  final String glyph;
  final VoidCallback onTap;
  const ArrowButton(this.glyph, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.line),
        ),
        child: Text(glyph,
            style: manrope(size: 15, weight: FontWeight.w600, color: c.ink2)),
      ),
    );
  }
}

/// ‹ Month YYYY › control. [big] uses the large Home heading size.
class MonthSwitch extends StatelessWidget {
  final bool big;
  const MonthSwitch({super.key, this.big = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ArrowButton('‹', () => app.shiftMonth(-1)),
        const SizedBox(width: 10),
        SizedBox(
          width: big ? 138 : 130,
          child: Text(
            app.monthName(app.viewMonth),
            textAlign: TextAlign.center,
            style: big
                ? manrope(
                    size: 22,
                    weight: FontWeight.w800,
                    color: c.ink,
                    letterSpacing: -0.4)
                : manrope(size: 14, weight: FontWeight.w700, color: c.ink),
          ),
        ),
        const SizedBox(width: 10),
        ArrowButton('›', () => app.shiftMonth(1)),
      ],
    );
  }
}

/// Uppercase muted section label.
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text,
      {super.key, this.padding = const EdgeInsets.only(bottom: 8)});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: manrope(
            size: 12,
            weight: FontWeight.w700,
            color: c.ink2,
            letterSpacing: 0.5),
      ),
    );
  }
}

/// A bordered surface card.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}

/// Rounded "field" styled text input. Keeps its own controller and only
/// re-syncs when the external [value] diverges (e.g. cleared after "Add").
class SoftField extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  const SoftField({
    super.key,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<SoftField> createState() => _SoftFieldState();
}

class _SoftFieldState extends State<SoftField> {
  late final TextEditingController controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SoftField old) {
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
      style: manrope(size: 14, weight: FontWeight.w600, color: c.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: manrope(size: 14, weight: FontWeight.w600, color: c.ink2),
        filled: true,
        fillColor: c.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.line, width: 1.5),
        ),
      ),
    );
  }
}
