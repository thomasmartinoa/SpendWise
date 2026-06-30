import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A brief GPay-style success overlay: a green circle springs in and a white
/// checkmark draws, then it auto-dismisses via [onDone]. Non-interactive.
class SuccessTick extends StatefulWidget {
  final VoidCallback onDone;
  const SuccessTick({super.key, required this.onDone});

  @override
  State<SuccessTick> createState() => _SuccessTickState();
}

class _SuccessTickState extends State<SuccessTick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1150))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final pop = Curves.easeOutBack.transform(_seg(t, 0.0, 0.42));
          final check = Curves.easeInOut.transform(_seg(t, 0.34, 0.72));
          final fade = 1 - _seg(t, 0.86, 1.0);
          final labelIn = _seg(t, 0.45, 0.7);
          return Opacity(
            opacity: fade,
            child: Container(
              color: Color.fromRGBO(20, 20, 18, 0.22 * _seg(t, 0, 0.3)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: pop,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: Brand.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Brand.green.withValues(alpha: 0.4),
                                blurRadius: 28,
                                offset: const Offset(0, 10)),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _CheckPainter(check),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: labelIn,
                      child: Text('Saved',
                          style: manrope(
                              size: 16,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.30, w * 0.52)
      ..lineTo(w * 0.44, w * 0.66)
      ..lineTo(w * 0.71, w * 0.37);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
