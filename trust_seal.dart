import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// The copper trust seal — WorkLink's signature verification mark.
/// The arc fills 20% per verification level (L1–L5).
class TrustSeal extends StatelessWidget {
  final int level;
  final double size;
  const TrustSeal({super.key, required this.level, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SealPainter(level),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            'L$level',
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w600,
              color: WL.copper,
            ),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  final int level;
  _SealPainter(this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    ring.color = WL.copperLight;
    canvas.drawCircle(c, r - ring.strokeWidth / 2, ring);

    ring.color = WL.copper;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - ring.strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi * (level / 5),
      false,
      ring,
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.level != level;
}
