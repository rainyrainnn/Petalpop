import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FlowerIllustration extends StatelessWidget {
  const FlowerIllustration({
    super.key,
    this.petalCount = 8,
    this.color = const Color(0xFFFFB1CB),
    this.growthPoints = 10,
    this.variety = 1,
  });

  final int petalCount;
  final Color color;
  final int growthPoints;
  final int variety;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FlowerPainter(
        petalCount: petalCount,
        color: color,
        growthPoints: growthPoints,
        variety: variety,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter({
    required this.petalCount,
    required this.color,
    required this.growthPoints,
    required this.variety,
  });

  final int petalCount;
  final Color color;
  final int growthPoints;
  final int variety;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.save();
    canvas.scale(size.width / 300, size.height / 320);
    canvas.translate(150, 302);
    canvas.scale(.72 + growthPoints.clamp(0, 10) * .028);
    canvas.translate(-150, -302);

    final stemPaint = Paint()
      ..color = PetalPopColors.leafGreen
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final stem = Path()
      ..moveTo(150, 172)
      ..cubicTo(145, 218, 157, 263, 150, 302);
    canvas.drawPath(stem, stemPaint);

    _drawLeaf(
      canvas,
      const Rect.fromLTWH(83, 224, 70, 34),
      variety.isEven ? -.45 : -.7,
    );
    _drawLeaf(
      canvas,
      const Rect.fromLTWH(149, 258, 73, 35),
      variety.isEven ? .48 : .7,
    );
    if (variety % 3 == 0) {
      _drawLeaf(canvas, const Rect.fromLTWH(105, 278, 55, 28), .38);
    }

    const center = Offset(150, 125);
    if (growthPoints <= 0) {
      final budRect = Rect.fromCenter(
        center: const Offset(150, 152),
        width: 43,
        height: 57,
      );
      canvas.drawOval(budRect, Paint()..color = color);
      canvas.drawOval(
        budRect,
        Paint()
          ..color = const Color(0xFFE95D91).withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _drawSparkle(canvas, const Offset(204, 112), 8);
      _drawPot(canvas);
      canvas.restore();
      return;
    }

    final totalPetals = (5 + variety.abs() % 4)
        .clamp(1, petalCount.clamp(1, 10))
        .toInt();
    final visiblePetals = (totalPetals * growthPoints.clamp(0, 10) / 10)
        .ceil()
        .clamp(1, totalPetals);
    final bloomColor = Color.lerp(color, const Color(0xFFDFA8F5), .18)!;
    final petalHighlight = Color.lerp(color, const Color(0xFFFFD7F4), .48)!;
    for (var i = 0; i < visiblePetals; i++) {
      final angle = i * 2 * 3.141592653589793 / visiblePetals;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final petal = _petalPath(variety % 4);
      final bounds = petal.getBounds();
      canvas.drawPath(
        petal,
        Paint()
          ..shader = LinearGradient(
            colors: [bloomColor, petalHighlight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
      );
      canvas.drawPath(
        petal,
        Paint()
          ..color = const Color(0xFFE95D91).withValues(alpha: .42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      canvas.restore();
    }

    final centerColor = variety.isEven
        ? PetalPopColors.paleYellow
        : const Color(0xFFFFD58D);
    canvas.drawCircle(center, 39, Paint()..color = centerColor);
    canvas.drawCircle(
      center,
      39,
      Paint()
        ..color = const Color(0xFFF2B84B).withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (growthPoints >= 8) {
      final facePaint = Paint()..color = const Color(0xFF66414A);
      canvas.drawCircle(const Offset(137, 121), 2.6, facePaint);
      canvas.drawCircle(const Offset(163, 121), 2.6, facePaint);
      final smile = Path()
        ..moveTo(140, 135)
        ..quadraticBezierTo(150, 145, 160, 135);
      canvas.drawPath(
        smile,
        Paint()
          ..color = const Color(0xFF66414A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      final cheekPaint = Paint()
        ..color = const Color(0xFFFF9DBA).withValues(alpha: .8);
      canvas.drawCircle(const Offset(127, 133), 5, cheekPaint);
      canvas.drawCircle(const Offset(173, 133), 5, cheekPaint);
    }

    _drawSparkle(canvas, const Offset(65, 87), 10);
    if (growthPoints >= 5) {
      _drawSparkle(canvas, const Offset(231, 74), 8);
    }
    if (growthPoints == 10) {
      _drawSparkle(canvas, const Offset(219, 174), 6);
    }
    _drawPot(canvas);
    canvas.restore();
  }

  void _drawPot(Canvas canvas) {
    final pot = Path()
      ..moveTo(111, 267)
      ..lineTo(189, 267)
      ..lineTo(178, 307)
      ..quadraticBezierTo(150, 319, 122, 307)
      ..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFFE88B76));
    canvas.drawPath(
      pot,
      Paint()
        ..color = const Color(0xFFC96C62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(105, 258, 90, 14),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFFF4AE91),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(105, 258, 90, 14),
        const Radius.circular(7),
      ),
      Paint()
        ..color = const Color(0xFFC96C62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final decoration = Paint()
      ..color = const Color(0xFFFFE6A7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(137, 283), const Offset(137, 296), decoration);
    canvas.drawLine(const Offset(150, 283), const Offset(150, 296), decoration);
    canvas.drawLine(const Offset(163, 283), const Offset(163, 296), decoration);
  }

  Path _petalPath(int shape) {
    switch (shape) {
      case 1:
        return Path()
          ..moveTo(0, -12)
          ..cubicTo(27, -35, 29, -70, 0, -91)
          ..cubicTo(-29, -70, -27, -35, 0, -12)
          ..close();
      case 2:
        return Path()
          ..moveTo(0, -12)
          ..cubicTo(28, -29, 34, -60, 0, -87)
          ..cubicTo(-34, -60, -28, -29, 0, -12)
          ..close();
      case 3:
        return Path()
          ..moveTo(0, -12)
          ..quadraticBezierTo(28, -40, 14, -86)
          ..quadraticBezierTo(0, -76, -14, -86)
          ..quadraticBezierTo(-28, -40, 0, -12)
          ..close();
      default:
        return Path()..addOval(
          Rect.fromCenter(center: const Offset(0, -48), width: 48, height: 78),
        );
    }
  }

  void _drawLeaf(Canvas canvas, Rect rect, double angle) {
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(angle);
    final leafRect = Rect.fromCenter(
      center: Offset.zero,
      width: rect.width,
      height: rect.height,
    );
    canvas.drawOval(
      leafRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9BD28A), PetalPopColors.leafGreen],
        ).createShader(leafRect),
    );
    canvas.drawOval(
      leafRect,
      Paint()
        ..color = const Color(0xFF4E9D5C).withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * .22,
        center.dy - radius * .22,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * .22,
        center.dy + radius * .22,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * .22,
        center.dy + radius * .22,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * .22,
        center.dy - radius * .22,
        center.dx,
        center.dy - radius,
      );
    canvas.drawPath(path, Paint()..color = PetalPopColors.paleYellow);
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter oldDelegate) =>
      oldDelegate.petalCount != petalCount ||
      oldDelegate.color != color ||
      oldDelegate.growthPoints != growthPoints ||
      oldDelegate.variety != variety;
}
