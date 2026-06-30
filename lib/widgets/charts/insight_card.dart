import 'package:flutter/material.dart';

import '../../theme.dart';

/// Shared chrome for an Insights card: rounded card with an optional title +
/// caption above the body. Keeps every card visually consistent.
class InsightCard extends StatelessWidget {
  final String? title;
  final String? caption;
  final EdgeInsets padding;
  final Widget child;
  const InsightCard({
    super.key,
    this.title,
    this.caption,
    this.padding = const EdgeInsets.all(18),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(title!,
                style: manrope(size: 15, weight: FontWeight.w700, color: c.ink)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                style:
                    manrope(size: 11.5, weight: FontWeight.w600, color: c.ink2)),
          ],
          if (title != null) const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Centered icon + message used for a card's empty state.
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyHint({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 26, color: c.ink2),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style:
                    manrope(size: 13.5, weight: FontWeight.w600, color: c.ink2)),
          ],
        ),
      ),
    );
  }
}
