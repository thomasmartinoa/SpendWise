import 'package:flutter/material.dart';

import '../../theme.dart';

class MiniBox extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final double size;
  const MiniBox(
      {super.key, required this.text, required this.bg, required this.fg, this.size = 34});

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

class DeleteX extends StatelessWidget {
  final VoidCallback onTap;
  const DeleteX({super.key, required this.onTap});

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

class AddButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const AddButton(
      {super.key, required this.label, required this.color, required this.onTap});

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

class BackupRow extends StatelessWidget {
  final Color iconBg, iconColor;
  final String glyph, title, sub;
  final bool divider;
  final VoidCallback onTap;
  const BackupRow({
    super.key,
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
            MiniBox(text: glyph, bg: iconBg, fg: iconColor),
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
