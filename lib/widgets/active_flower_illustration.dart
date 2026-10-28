import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ActiveFlowerIllustration extends StatelessWidget {
  const ActiveFlowerIllustration({
    required this.stage,
    super.key,
    this.locked = false,
  });

  final int stage;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ActiveFlowerPainter(stage.clamp(0, 7), locked: locked),
      child: const SizedBox.expand(),
    );
  }
}

class _ActiveFlowerPainter extends CustomPainter {
  const _ActiveFlowerPainter(this.stage, {required this.locked});

  final int stage;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height * .96);

    final colors = locked
        ? (stem: const Color(0xFF849582), leaf: const Color(0xFF9BAA91))
        : (stem: PetalPopColors.leafGreen, leaf: const Color(0xFF91C97F));
    final stemHeight = size.height * (.22 + stage * .075);
    final stemTop = -stemHeight;

    final stem = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        size.width * .04,
        -stemHeight * .35,
        -size.width * .05,
        -stemHeight * .72,
        0,
        stemTop,
      );
    canvas.drawPath(
      stem,
      Paint()
        ..color = colors.stem
        ..strokeWidth = (size.width * .035).clamp(2, 5)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    if (stage >= 1) {
      _drawLeaf(
        canvas,
        Offset(-size.width * .14, -stemHeight * .42),
        -.7,
        colors.leaf,
      );
    }
    if (stage >= 3) {
      _drawLeaf(
        canvas,
        Offset(size.width * .14, -stemHeight * .64),
        .68,
        colors.leaf,
      );
    }
    if (stage >= 5) {
      _drawLeaf(
        canvas,
        Offset(-size.width * .12, -stemHeight * .78),
        -.85,
        colors.leaf,
      );
    }

    if (stage == 0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, stemTop - size.height * .025),
          width: size.width * .1,
          height: size.height * .12,
        ),
        Paint()
          ..color = locked ? const Color(0xFF9E8A91) : const Color(0xFFB98762),
      );
    } else {
      final bloomSize = size.width * (.12 + stage * .045);
      final petalCount = stage < 3 ? stage + 1 : 5 + stage;
      final bloomCenter = Offset(0, stemTop - bloomSize * .13);
      final bloomColor = locked
          ? const Color(0xFFB6A3AB)
          : Color.lerp(
              const Color(0xFFFFC1D8),
              const Color(0xFFE89ADF),
              (stage - 1) / 6,
            )!;
      for (var i = 0; i < petalCount; i++) {
        final angle = 2 * 3.141592653589793 * i / petalCount;
        canvas.save();
        canvas.translate(bloomCenter.dx, bloomCenter.dy);
        canvas.rotate(angle);
        final petalRect = Rect.fromCenter(
          center: Offset(0, -bloomSize * .37),
          width: bloomSize * .43,
          height: bloomSize * .72,
        );
        canvas.drawOval(petalRect, Paint()..color = bloomColor);
        canvas.restore();
      }
      canvas.drawCircle(
        bloomCenter,
        bloomSize * (stage == 7 ? .22 : .16),
        Paint()
          ..color = locked ? const Color(0xFF8F7B84) : const Color(0xFFFFE18B),
      );
      if (!locked && stage >= 6) {
        final face = Paint()..color = const Color(0xFF704451);
        canvas.drawCircle(bloomCenter + Offset(-bloomSize * .07, 0), 1.5, face);
        canvas.drawCircle(bloomCenter + Offset(bloomSize * .07, 0), 1.5, face);
        final smile = Path()
          ..moveTo(bloomCenter.dx - bloomSize * .045, bloomCenter.dy + 3)
          ..quadraticBezierTo(
            bloomCenter.dx,
            bloomCenter.dy + 7,
            bloomCenter.dx + bloomSize * .045,
            bloomCenter.dy + 3,
          );
        canvas.drawPath(
          smile,
          Paint()
            ..color = const Color(0xFF704451)
            ..strokeWidth = 1.3
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
  }

  void _drawLeaf(Canvas canvas, Offset center, double angle, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 20, height: 10),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ActiveFlowerPainter oldDelegate) =>
      oldDelegate.stage != stage || oldDelegate.locked != locked;
}
