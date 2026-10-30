import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FlowerArtwork extends StatelessWidget {
  const FlowerArtwork({
    required this.color,
    required this.growthPoints,
    required this.variety,
    super.key,
    this.petalCount = 10,
    this.locked = false,
    this.showPot = true,
  });

  final Color color;
  final int growthPoints;
  final int variety;
  final int petalCount;
  final bool locked;
  final bool showPot;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: PetalFlowerPainter(
      color: color,
      growthPoints: growthPoints,
      variety: variety,
      petalCount: petalCount,
      locked: locked,
      showPot: showPot,
    ),
    child: const SizedBox.expand(),
  );
}

class PetalFlowerPainter extends CustomPainter {
  const PetalFlowerPainter({
    required this.color,
    required this.growthPoints,
    required this.variety,
    required this.petalCount,
    required this.locked,
    required this.showPot,
  });

  final Color color;
  final int growthPoints;
  final int variety;
  final int petalCount;
  final bool locked;
  final bool showPot;

  static const _outline = Color(0xFF9E526F);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final style = ((variety.abs() - 1) % 20) + 1;
    final growth = locked ? 10 : growthPoints.clamp(0, 10);
    final flowerColor = locked ? const Color(0xFFB5B5B8) : color;
    final leafColor = locked
        ? const Color(0xFFB1B3B4)
        : const Color(0xFF63A46A);
    final stemColor = locked
        ? const Color(0xFF9A9D9F)
        : PetalPopColors.leafGreen;

    canvas.save();
    canvas.scale(size.width / 300, size.height / 320);

    final base = Offset(150, showPot ? 265 : 302);
    final flowerCenter = Offset(150, growth == 0 ? 161 : 119);
    final bloomScale = .74 + growth * .026;

    _drawStem(canvas, style, flowerCenter, base, stemColor, locked);
    _drawFoliage(canvas, style, leafColor, locked, showPot);

    canvas.save();
    canvas.translate(flowerCenter.dx, flowerCenter.dy);
    canvas.scale(bloomScale);
    canvas.translate(-flowerCenter.dx, -flowerCenter.dy);
    if (growth == 0) {
      _drawBud(canvas, style, flowerCenter, flowerColor, locked);
    } else {
      _drawFlowerHead(
        canvas,
        style,
        flowerCenter,
        flowerColor,
        growth,
        math.max(1, petalCount.clamp(1, 16)),
        locked,
      );
    }
    if (!locked && growth >= 7) _drawFace(canvas, flowerCenter, style);
    if (!locked && growth >= 4) {
      _drawSparkle(canvas, const Offset(70, 81), 8, const Color(0xFFFFF5C4));
      _drawSparkle(canvas, const Offset(232, 103), 6, const Color(0xFFFFF5C4));
    }
    if (!locked && growth == 10) {
      _drawSparkle(canvas, const Offset(219, 171), 5, const Color(0xFFFFF5C4));
    }
    canvas.restore();

    if (showPot) _drawPot(canvas, locked);
    canvas.restore();
  }

  void _drawStem(
    Canvas canvas,
    int style,
    Offset head,
    Offset base,
    Color color,
    bool monochrome,
  ) {
    final sway = style.isEven ? 13.0 : -13.0;
    final stem = Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo(
        base.dx + sway,
        base.dy - 46,
        head.dx - sway,
        head.dy + 78,
        head.dx,
        head.dy + 34,
      );
    canvas.drawPath(
      stem,
      Paint()
        ..color = color
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    if (!monochrome) {
      canvas.drawPath(
        stem,
        Paint()
          ..color = const Color(0xFFB7D987)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawFoliage(
    Canvas canvas,
    int style,
    Color color,
    bool monochrome,
    bool showPot,
  ) {
    final lower = showPot ? 232.0 : 272.0;
    final leafShape = style % 4;
    _drawLeaf(
      canvas,
      Offset(118 - (style % 3) * 4, lower - 18),
      64,
      29,
      -.48,
      color,
      leafShape,
      monochrome,
    );
    _drawLeaf(
      canvas,
      Offset(181 + (style % 4) * 3, lower + 4),
      68,
      30,
      .52,
      color,
      (leafShape + 1) % 4,
      monochrome,
    );
    if (style % 3 == 0 || style == 1 || style == 10) {
      _drawLeaf(
        canvas,
        Offset(143, lower + 13),
        48,
        24,
        -.08,
        color,
        2,
        monochrome,
      );
    }
  }

  void _drawFlowerHead(
    Canvas canvas,
    int style,
    Offset center,
    Color base,
    int growth,
    int maxPetals,
    bool monochrome,
  ) {
    if (style == 2 || style == 14) {
      _drawBellCluster(canvas, style, center, base, growth, monochrome);
      return;
    }
    if (style == 19) {
      _drawLavenderSprig(canvas, center, base, growth, monochrome);
      return;
    }

    final count = _petalCount(style, maxPetals);
    final visible = math.max(1, (count * growth / 10).ceil());
    final layers = _layerCount(style);
    for (var layer = layers - 1; layer >= 0; layer--) {
      if (layer > 0 && growth < (layer == 1 ? 4 : 7)) continue;
      final layerScale = 1 - layer * .22;
      final layerCount = layer == 0 ? visible : math.max(5, count - layer * 2);
      final rotationOffset = layer.isEven ? 0.0 : math.pi / layerCount;
      for (var index = 0; index < layerCount; index++) {
        final angle = math.pi * 2 * index / layerCount + rotationOffset;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.scale(layerScale, layerScale);
        _drawPetal(canvas, style, base, layer, monochrome);
        canvas.restore();
      }
    }

    _drawCenter(canvas, style, center, base, monochrome);
    if (!monochrome && growth >= 3) {
      _drawPetalDetails(canvas, style, center, count, base);
    }
  }

  int _petalCount(int style, int maxPetals) {
    final designCount = switch (style) {
      1 || 4 || 10 || 15 => 12,
      2 || 14 => 6,
      3 || 7 || 13 || 17 => 6,
      5 || 8 || 11 || 16 => 8,
      6 || 9 || 12 || 18 => 5,
      19 => 8,
      _ => 7,
    };
    return math.min(designCount, maxPetals);
  }

  int _layerCount(int style) => switch (style) {
    1 || 4 || 10 || 15 => 3,
    5 || 7 || 8 || 13 || 17 || 18 || 20 => 2,
    _ => 1,
  };

  void _drawPetal(
    Canvas canvas,
    int style,
    Color base,
    int layer,
    bool monochrome,
  ) {
    final petal = _petalPath(style, layer);
    final bounds = petal.getBounds();
    final shadow = monochrome
        ? const Color(0xFF9FA1A3)
        : Color.lerp(base, _outline, .2)!;
    final highlight = monochrome
        ? const Color(0xFFD0D1D2)
        : Color.lerp(base, Colors.white, .63)!;
    final shade = monochrome
        ? const Color(0xFFB4B5B7)
        : Color.lerp(base, const Color(0xFFD35F92), .18)!;
    canvas.drawPath(
      petal,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawPath(
      petal,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [highlight, shade],
        ).createShader(bounds),
    );
    canvas.drawPath(
      petal,
      Paint()
        ..color = monochrome
            ? const Color(0xFF929597)
            : _outline.withValues(alpha: .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    if (!monochrome && style == 7) _drawCrystalFacet(canvas, petal, base);
  }

  Path _petalPath(int style, int layer) {
    final length = layer == 0 ? 91.0 : 76.0;
    switch (style) {
      case 3:
      case 7:
      case 13:
      case 17:
        return Path()
          ..moveTo(0, -11)
          ..cubicTo(18, -38, 19, -71, 0, -length)
          ..cubicTo(-18, -71, -18, -38, 0, -11)
          ..close();
      case 4:
      case 10:
      case 15:
        return Path()
          ..moveTo(0, -10)
          ..cubicTo(23, -25, 28, -45, 17, -58)
          ..cubicTo(31, -76, 15, -89, 0, -length)
          ..cubicTo(-15, -89, -31, -76, -17, -58)
          ..cubicTo(-28, -45, -23, -25, 0, -10)
          ..close();
      case 5:
        return _starPetal(length);
      case 6:
        return Path()
          ..moveTo(-5, -8)
          ..cubicTo(-25, -39, -25, -69, -12, -length)
          ..quadraticBezierTo(0, -length + 14, 12, -length)
          ..cubicTo(25, -69, 25, -39, 5, -8)
          ..quadraticBezierTo(0, -2, -5, -8)
          ..close();
      case 8:
      case 11:
      case 16:
        return Path()
          ..moveTo(0, -8)
          ..cubicTo(19, -31, 14, -67, 0, -length)
          ..cubicTo(-14, -67, -19, -31, 0, -8)
          ..close();
      case 9:
      case 12:
      case 18:
        return Path()
          ..moveTo(0, -10)
          ..cubicTo(18, -24, 35, -51, 26, -73)
          ..cubicTo(18, -92, 3, -86, 0, -length)
          ..cubicTo(-3, -86, -18, -92, -26, -73)
          ..cubicTo(-35, -51, -18, -24, 0, -10)
          ..close();
      case 20:
        return Path()
          ..moveTo(0, -10)
          ..cubicTo(12, -27, 35, -28, 29, -55)
          ..cubicTo(24, -77, 11, -89, 0, -length)
          ..cubicTo(-11, -89, -24, -77, -29, -55)
          ..cubicTo(-35, -28, -12, -27, 0, -10)
          ..close();
      default:
        return Path()
          ..moveTo(0, -10)
          ..cubicTo(30, -35, 29, -68, 0, -length)
          ..cubicTo(-29, -68, -30, -35, 0, -10)
          ..close();
    }
  }

  Path _starPetal(double length) {
    return Path()
      ..moveTo(0, -10)
      ..quadraticBezierTo(7, -39, 0, -length)
      ..quadraticBezierTo(-9, -73, -22, -72)
      ..quadraticBezierTo(-14, -51, 0, -10)
      ..close();
  }

  void _drawCenter(
    Canvas canvas,
    int style,
    Offset center,
    Color base,
    bool monochrome,
  ) {
    final radius = switch (style) {
      9 || 12 => 19.0,
      2 || 14 || 19 => 13.0,
      _ => 24.0,
    };
    final centerColor = monochrome
        ? const Color(0xFF97999A)
        : switch (style) {
            3 || 7 || 17 => const Color(0xFFBCEBF3),
            8 || 11 || 15 => const Color(0xFFFFC54D),
            9 || 12 => const Color(0xFFFFD16C),
            _ => const Color(0xFFFFE6A2),
          };
    final centerRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius + 3,
      Paint()
        ..color = monochrome
            ? const Color(0xFFA8AAAC)
            : Colors.white.withValues(alpha: .7),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            monochrome ? const Color(0xFFD0D1D2) : Colors.white,
            centerColor,
          ],
        ).createShader(centerRect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = monochrome
            ? const Color(0xFF888B8D)
            : const Color(0xFFD89A43).withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    if (!monochrome) {
      for (var index = 0; index < 9; index++) {
        final angle = math.pi * 2 * index / 9;
        final dot =
            center + Offset(math.cos(angle), math.sin(angle)) * (radius * .67);
        canvas.drawCircle(
          dot,
          style == 9 ? 2 : 1.6,
          Paint()..color = const Color(0xFFFFF9D8),
        );
      }
    } else {
      canvas.drawCircle(
        center,
        radius * .55,
        Paint()..color = const Color(0xFFB8BABC),
      );
    }
  }

  void _drawPetalDetails(
    Canvas canvas,
    int style,
    Offset center,
    int count,
    Color base,
  ) {
    if (style == 9) {
      final lip = Path()
        ..moveTo(center.dx - 18, center.dy + 5)
        ..quadraticBezierTo(
          center.dx,
          center.dy + 36,
          center.dx + 20,
          center.dy + 4,
        )
        ..quadraticBezierTo(
          center.dx,
          center.dy + 14,
          center.dx - 18,
          center.dy + 5,
        )
        ..close();
      canvas.drawPath(
        lip,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFE68E), Color(0xFFFF8EC1)],
          ).createShader(lip.getBounds()),
      );
      for (var dot = 0; dot < 5; dot++) {
        canvas.drawCircle(
          Offset(
            center.dx - 12 + dot * 6,
            center.dy + 12 + (dot.isEven ? 0 : 4),
          ),
          1.5,
          Paint()..color = const Color(0xFFB94E82),
        );
      }
    } else if (style == 12) {
      final filament = Paint()
        ..color = const Color(0xFFFFD46A)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, center + const Offset(2, 39), filament);
      for (var dot = 0; dot < 5; dot++) {
        canvas.drawCircle(
          Offset(center.dx - 6 + dot * 4, center.dy + 34),
          2.2,
          Paint()..color = const Color(0xFFFFE18A),
        );
      }
    } else if (style == 20) {
      _drawCrescent(canvas, center + const Offset(0, -5), 13, base);
    } else if (style == 3 || style == 13) {
      final vein = Paint()
        ..color = Color.lerp(base, Colors.white, .68)!
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var index = 0; index < math.min(count, 7); index++) {
        final angle = math.pi * 2 * index / count;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.drawLine(const Offset(0, -19), const Offset(0, -68), vein);
        canvas.restore();
      }
    }
  }

  void _drawBellCluster(
    Canvas canvas,
    int style,
    Offset center,
    Color base,
    int growth,
    bool monochrome,
  ) {
    final positions = [Offset(-28, -5), Offset(0, -25), Offset(28, -3)];
    for (var index = 0; index < positions.length; index++) {
      if (growth <
          (index == 0
              ? 1
              : index == 1
              ? 4
              : 7)) {
        continue;
      }
      final point = center + positions[index];
      final bell = Path()
        ..moveTo(point.dx, point.dy - 47)
        ..cubicTo(
          point.dx - 19,
          point.dy - 34,
          point.dx - 22,
          point.dy - 11,
          point.dx - 18,
          point.dy,
        )
        ..quadraticBezierTo(point.dx, point.dy + 12, point.dx + 18, point.dy)
        ..cubicTo(
          point.dx + 22,
          point.dy - 11,
          point.dx + 19,
          point.dy - 34,
          point.dx,
          point.dy - 47,
        )
        ..close();
      final paintColor = monochrome
          ? const Color(0xFFB6B8B9)
          : Color.lerp(
              base,
              index == 1 ? const Color(0xFFB7A7FF) : const Color(0xFF8FB6FF),
              .38,
            )!;
      canvas.drawPath(
        bell,
        Paint()
          ..shader = LinearGradient(
            colors: [
              monochrome
                  ? const Color(0xFFD2D3D4)
                  : Color.lerp(paintColor, Colors.white, .55)!,
              paintColor,
            ],
          ).createShader(bell.getBounds()),
      );
      canvas.drawPath(
        bell,
        Paint()
          ..color = monochrome
              ? const Color(0xFF909294)
              : _outline.withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
      if (!monochrome) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(point.dx, point.dy),
            width: 35,
            height: 12,
          ),
          0,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xFFF9E8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        if (style == 14) {
          _drawCrescent(canvas, point + const Offset(0, -24), 6, paintColor);
        }
        canvas.drawCircle(
          point + const Offset(0, 5),
          2,
          Paint()..color = const Color(0xFFFFE9A0),
        );
      }
    }
  }

  void _drawLavenderSprig(
    Canvas canvas,
    Offset center,
    Color base,
    int growth,
    bool monochrome,
  ) {
    for (var stem = 0; stem < 3; stem++) {
      final x = center.dx - 26 + stem * 26;
      final height = 50 + stem % 2 * 12;
      final branch = Path()
        ..moveTo(x, center.dy + 62)
        ..quadraticBezierTo(
          x + (stem - 1) * 8,
          center.dy + 10,
          x,
          center.dy - height,
        );
      canvas.drawPath(
        branch,
        Paint()
          ..color = monochrome
              ? const Color(0xFF9FA1A2)
              : PetalPopColors.leafGreen
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      for (var bud = 0; bud < 4; bud++) {
        if (growth < (bud == 0 ? 1 : bud * 2)) continue;
        final y = center.dy + 7 - bud * 16;
        final side = bud.isEven ? -1.0 : 1.0;
        final petalColor = monochrome
            ? const Color(0xFFB9BBBC)
            : Color.lerp(base, const Color(0xFFB39BEB), .36)!;
        canvas.save();
        canvas.translate(x + side * 8, y);
        canvas.rotate(side * .32);
        canvas.drawOval(
          const Rect.fromLTWH(-8.5, -12, 17, 24),
          Paint()
            ..shader = LinearGradient(
              colors: [
                monochrome
                    ? const Color(0xFFD4D5D6)
                    : Colors.white.withValues(alpha: .8),
                petalColor,
              ],
            ).createShader(const Rect.fromLTWH(-8, -12, 16, 24)),
        );
        canvas.restore();
      }
    }
  }

  void _drawCrystalFacet(Canvas canvas, Path petal, Color base) {
    final bounds = petal.getBounds();
    final facet = Path()
      ..moveTo(bounds.center.dx, bounds.top + 10)
      ..lineTo(bounds.right - 5, bounds.center.dy)
      ..lineTo(bounds.center.dx, bounds.bottom - 9);
    canvas.drawPath(
      facet,
      Paint()
        ..color = Color.lerp(base, Colors.white, .7)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawBud(
    Canvas canvas,
    int style,
    Offset center,
    Color base,
    bool monochrome,
  ) {
    final budColor = monochrome ? const Color(0xFFB7B8B9) : base;
    final bud = Path()
      ..moveTo(center.dx, center.dy + 35)
      ..cubicTo(
        center.dx - 31,
        center.dy + 8,
        center.dx - 23,
        center.dy - 36,
        center.dx,
        center.dy - 45,
      )
      ..cubicTo(
        center.dx + 26,
        center.dy - 35,
        center.dx + 32,
        center.dy + 8,
        center.dx,
        center.dy + 35,
      )
      ..close();
    canvas.drawPath(
      bud,
      Paint()
        ..shader = LinearGradient(
          colors: [
            monochrome
                ? const Color(0xFFD2D3D4)
                : Color.lerp(budColor, Colors.white, .55)!,
            budColor,
          ],
        ).createShader(bud.getBounds()),
    );
    final seam = Path()
      ..moveTo(center.dx, center.dy + 27)
      ..quadraticBezierTo(
        center.dx - (style.isEven ? 13 : -13),
        center.dy - 3,
        center.dx,
        center.dy - 37,
      );
    canvas.drawPath(
      seam,
      Paint()
        ..color = monochrome
            ? const Color(0xFF8E9092)
            : Color.lerp(base, _outline, .3)!
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLeaf(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    double angle,
    Color color,
    int shape,
    bool monochrome,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final leaf = switch (shape) {
      0 =>
        Path()
          ..moveTo(-width / 2, 0)
          ..quadraticBezierTo(0, -height * 1.25, width / 2, 0)
          ..quadraticBezierTo(0, height * .8, -width / 2, 0)
          ..close(),
      1 =>
        Path()
          ..moveTo(-width / 2, 0)
          ..cubicTo(
            -width * .2,
            -height * 1.5,
            width * .35,
            -height,
            width / 2,
            0,
          )
          ..cubicTo(
            width * .2,
            height * .55,
            -width * .35,
            height * .5,
            -width / 2,
            0,
          )
          ..close(),
      2 =>
        Path()
          ..moveTo(-width / 2, 0)
          ..quadraticBezierTo(0, -height, width / 2, 0)
          ..quadraticBezierTo(0, height, -width / 2, 0)
          ..close(),
      _ =>
        Path()
          ..moveTo(-width / 2, 0)
          ..cubicTo(
            -width * .2,
            -height,
            width * .15,
            -height * 1.3,
            width / 2,
            0,
          )
          ..cubicTo(
            width * .1,
            height,
            -width * .25,
            height * .8,
            -width / 2,
            0,
          )
          ..close(),
    };
    canvas.drawPath(
      leaf,
      Paint()
        ..shader = LinearGradient(
          colors: [
            monochrome
                ? const Color(0xFFD2D3D4)
                : Color.lerp(color, const Color(0xFFB8DF91), .52)!,
            color,
          ],
        ).createShader(leaf.getBounds()),
    );
    canvas.drawPath(
      leaf,
      Paint()
        ..color = monochrome
            ? const Color(0xFF929496)
            : const Color(0xFF438354).withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    if (!monochrome) {
      canvas.drawLine(
        Offset(-width * .38, 0),
        Offset(width * .38, 0),
        Paint()
          ..color = const Color(0xFFD0E4A5)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  void _drawFace(Canvas canvas, Offset center, int style) {
    final eyeColor = const Color(0xFF724252);
    final eyeY = center.dy + (style == 12 ? 2 : 3);
    canvas.drawCircle(
      Offset(center.dx - 10, eyeY),
      2.2,
      Paint()..color = eyeColor,
    );
    canvas.drawCircle(
      Offset(center.dx + 10, eyeY),
      2.2,
      Paint()..color = eyeColor,
    );
    canvas.drawCircle(
      Offset(center.dx - 19, eyeY + 9),
      4,
      Paint()..color = const Color(0xFFFF97B3).withValues(alpha: .75),
    );
    canvas.drawCircle(
      Offset(center.dx + 19, eyeY + 9),
      4,
      Paint()..color = const Color(0xFFFF97B3).withValues(alpha: .75),
    );
    final smile = Path()
      ..moveTo(center.dx - 5, eyeY + 14)
      ..quadraticBezierTo(center.dx, eyeY + 20, center.dx + 5, eyeY + 14);
    canvas.drawPath(
      smile,
      Paint()
        ..color = eyeColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCrescent(Canvas canvas, Offset center, double radius, Color base) {
    final crescent = Path()
      ..moveTo(center.dx + radius * .25, center.dy - radius)
      ..arcToPoint(
        Offset(center.dx + radius * .25, center.dy + radius),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..arcToPoint(
        Offset(center.dx - radius * .1, center.dy - radius),
        radius: Radius.elliptical(radius * .58, radius),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFFFF0A6));
    canvas.drawPath(
      crescent,
      Paint()
        ..color = Color.lerp(base, Colors.white, .6)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * .2,
        center.dy - radius * .2,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * .2,
        center.dy + radius * .2,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * .2,
        center.dy + radius * .2,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * .2,
        center.dy - radius * .2,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawPot(Canvas canvas, bool monochrome) {
    final pot = Path()
      ..moveTo(111, 267)
      ..lineTo(189, 267)
      ..lineTo(178, 307)
      ..quadraticBezierTo(150, 319, 122, 307)
      ..close();
    final potColor = monochrome
        ? const Color(0xFFB6B7B8)
        : const Color(0xFFE88B76);
    canvas.drawPath(
      pot,
      Paint()
        ..shader = LinearGradient(
          colors: [
            monochrome ? const Color(0xFFD4D5D6) : const Color(0xFFFFB69B),
            potColor,
          ],
        ).createShader(pot.getBounds()),
    );
    canvas.drawPath(
      pot,
      Paint()
        ..color = monochrome ? const Color(0xFF929496) : const Color(0xFFC96C62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final rim = RRect.fromRectAndRadius(
      const Rect.fromLTWH(105, 258, 90, 14),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..color = monochrome
            ? const Color(0xFFD2D3D4)
            : const Color(0xFFF4AE91),
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..color = monochrome ? const Color(0xFF929496) : const Color(0xFFC96C62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final detail = Paint()
      ..color = monochrome ? const Color(0xFFE1E2E3) : const Color(0xFFFFE6A7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(137, 283), const Offset(137, 296), detail);
    canvas.drawLine(const Offset(150, 283), const Offset(150, 296), detail);
    canvas.drawLine(const Offset(163, 283), const Offset(163, 296), detail);
  }

  @override
  bool shouldRepaint(covariant PetalFlowerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.growthPoints != growthPoints ||
      oldDelegate.variety != variety ||
      oldDelegate.petalCount != petalCount ||
      oldDelegate.locked != locked ||
      oldDelegate.showPot != showPot;
}
