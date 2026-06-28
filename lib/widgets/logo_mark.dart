import 'package:flutter/material.dart';

/// The SpendWise app mark, drawn with a [CustomPainter] so it needs no SVG
/// dependency or asset. Geometry matches branding/spendwise_icon.svg exactly.
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1024.0);
    final full = Rect.fromLTWH(0, 0, 1024, 1024);
    final tile = RRect.fromRectAndRadius(full, const Radius.circular(232));

    // gradient tile
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEE6A4E), Color(0xFFE0533D), Color(0xFFC53F29)],
          stops: [0, 0.5, 1],
        ).createShader(full),
    );

    // top sheen
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.68),
          radius: 0.9,
          colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.55],
        ).createShader(full),
    );

    // simple bold "S" monogram
    final s = Path()
      ..moveTo(648, 360)
      ..cubicTo(648, 312, 596, 286, 524, 286)
      ..cubicTo(442, 286, 392, 330, 392, 388)
      ..cubicTo(392, 446, 438, 474, 524, 496)
      ..cubicTo(610, 518, 656, 546, 656, 606)
      ..cubicTo(656, 666, 600, 712, 520, 712)
      ..cubicTo(446, 712, 392, 684, 388, 628);
    canvas.drawPath(
      s,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 96
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
