import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/garden_flower.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/flower_illustration.dart';

class FlowerGardenScreen extends StatelessWidget {
  const FlowerGardenScreen({required this.session, super.key});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final activeFlower = session.activeFlower;
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6EF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_florist_rounded,
                    color: PetalPopColors.hotPink,
                    size: 29,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My happy garden',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: PetalPopColors.deepPink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          '${session.unlockedFlowerCount} of '
                          '${session.flowerCatalog.length} flowers unlocked',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: activeFlower == null
                  ? _FullBloomProgress(session: session)
                  : _ActiveFlowerProgress(session: session),
            ),
            Expanded(
              child: _GardenScene(
                session: session,
                onSelect: (flower, isUnlocked) =>
                    _showFlowerDetails(context, flower, isUnlocked),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFlowerDetails(
    BuildContext context,
    GardenFlower flower,
    bool unlocked,
  ) {
    final catalogIndex = session.flowerCatalog.indexWhere(
      (candidate) => candidate.id == flower.id,
    );
    final activeFlower = session.activeFlower;
    final isActiveFlower = activeFlower?.id == flower.id;
    final activeIndex = activeFlower == null
        ? session.flowerCatalog.length
        : session.flowerCatalog.indexOf(activeFlower);
    final isFullyBloomed = catalogIndex < activeIndex;
    final previousFlower = catalogIndex > 0
        ? session.flowerCatalog[catalogIndex - 1]
        : null;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: unlocked
            ? const Color(0xFFFFFBF7)
            : const Color(0xFFF7F5F5),
        title: Text(unlocked ? flower.name : 'A flower waiting to bloom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 104,
              height: 118,
              child: _CatalogFlowerIllustration(
                flower: flower,
                unlocked: unlocked,
                growthPoints: isActiveFlower
                    ? session.growthPoints
                    : isFullyBloomed
                    ? AppSession.growthStagesPerFlower
                    : 0,
                size: 98,
                variety: catalogIndex + 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              unlocked
                  ? 'A bloom from the PetalPop flower garden.'
                  : previousFlower == null
                  ? 'This flower is waiting to grow. Complete unique daily '
                        'challenges to help the first flower bloom.'
                  : 'This flower unlocks when ${previousFlower.name} is fully '
                        'bloomed (${AppSession.growthStagesPerFlower}/'
                        '${AppSession.growthStagesPerFlower}). Only unique '
                        'completed daily challenges add growth.',
              textAlign: TextAlign.center,
            ),
            if (unlocked) ...[
              const SizedBox(height: 10),
              Text(
                isActiveFlower
                    ? '${flower.name} · ${session.growthPoints}/'
                          '${AppSession.growthStagesPerFlower} · Growing'
                    : isFullyBloomed
                    ? '${flower.name} · '
                          '${AppSession.growthStagesPerFlower}/'
                          '${AppSession.growthStagesPerFlower} · Fully bloomed'
                    : '${flower.name} · 0/'
                          '${AppSession.growthStagesPerFlower} · Ready to grow',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: PetalPopColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ActiveFlowerProgress extends StatelessWidget {
  const _ActiveFlowerProgress({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final flower = session.activeFlower!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      flower.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: PetalPopColors.deepPink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${session.growthPoints}/'
                    '${AppSession.growthStagesPerFlower} petals',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: session.activeFlowerProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white,
                  color: PetalPopColors.hotPink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullBloomProgress extends StatelessWidget {
  const _FullBloomProgress({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF4),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      session.flowerCatalog.isEmpty
          ? 'Your garden is waiting for its first seeds.'
          : 'Your garden is in full bloom! '
                '${session.lifetimeGrowthPoints} lifetime petals earned.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: PetalPopColors.deepPink,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _GardenScene extends StatelessWidget {
  const _GardenScene({required this.session, required this.onSelect});

  final AppSession session;
  final void Function(GardenFlower flower, bool unlocked) onSelect;

  @override
  Widget build(BuildContext context) {
    final flowers = session.flowerCatalog;
    final unlockedIds = session.flowerUnlockDates.keys.toSet();
    final activeFlower = session.activeFlower;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final columns = width < 360
            ? 3
            : width < 520
            ? 4
            : 5;
        final rows = flowers.isEmpty ? 1 : (flowers.length / columns).ceil();
        final itemSize = math
            .min(96.0, math.min(width / columns * .92, height / rows * .86))
            .clamp(48.0, 96.0)
            .toDouble();

        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _GardenLandscapePainter()),
              ),
              if (flowers.isEmpty)
                const Center(
                  child: Text(
                    'Your garden is ready for its first flowers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF476B4B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                for (var index = 0; index < flowers.length; index++)
                  _positionedFlower(
                    flowers[index],
                    index,
                    columns,
                    rows,
                    width,
                    height,
                    itemSize,
                    unlockedIds.contains(flowers[index].id),
                    flowers[index].id == activeFlower?.id
                        ? session.growthPoints
                        : unlockedIds.contains(flowers[index].id)
                        ? AppSession.growthStagesPerFlower
                        : 0,
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _positionedFlower(
    GardenFlower flower,
    int index,
    int columns,
    int rows,
    double width,
    double height,
    double itemSize,
    bool unlocked,
    int growthPoints,
  ) {
    final column = index % columns;
    final row = index ~/ columns;
    final left = width * (column + .5) / columns - itemSize / 2;
    final rowHeight = height / rows;
    final stagger = row.isEven ? 0.0 : rowHeight * .11;
    final top = row * rowHeight + rowHeight / 2 - itemSize / 2 + stagger;
    return Positioned(
      key: ValueKey('garden-flower-${flower.id}'),
      left: left.clamp(0, math.max(0.0, width - itemSize)).toDouble(),
      top: top.clamp(0, math.max(0.0, height - itemSize)).toDouble(),
      width: itemSize,
      height: itemSize,
      child: Semantics(
        button: true,
        label: unlocked ? flower.name : 'Locked flower',
        child: Tooltip(
          message: unlocked ? flower.name : 'Locked flower',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSelect(flower, unlocked),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _CatalogFlowerIllustration(
                    flower: flower,
                    unlocked: unlocked,
                    growthPoints: growthPoints,
                    size: itemSize * .9,
                    variety: flower.sortOrder > 0
                        ? flower.sortOrder
                        : index + 1,
                  ),
                  if (!unlocked)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F7F7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: Color(0xFF777778),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GardenLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFE8F0),
          Color(0xFFFFF2E8),
          Color(0xFFCBE9B9),
          Color(0xFF8FBD78),
        ],
        stops: [0, .23, .36, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFF9D9).withValues(alpha: .95),
              const Color(0xFFFFE6B9).withValues(alpha: .15),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .84, size.height * .13),
              radius: size.width * .18,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * .84, size.height * .13),
      size.width * .18,
      glow,
    );
    _drawSparkle(canvas, Offset(size.width * .12, size.height * .12), 7);
    _drawSparkle(canvas, Offset(size.width * .68, size.height * .08), 5);
    _drawSparkle(canvas, Offset(size.width * .92, size.height * .25), 6);

    final hill = Path()
      ..moveTo(0, size.height * .34)
      ..quadraticBezierTo(
        size.width * .25,
        size.height * .27,
        size.width * .48,
        size.height * .36,
      )
      ..quadraticBezierTo(
        size.width * .74,
        size.height * .44,
        size.width,
        size.height * .31,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB7D990), Color(0xFF78AD68)],
        ).createShader(Offset.zero & size),
    );

    final farBed = Paint()..color = const Color(0xFF9BC77E);
    final nearBed = Paint()..color = const Color(0xFF78AA68);
    for (var row = 0; row < 5; row++) {
      final y = size.height * (.36 + row * .13);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .5, y),
          width: size.width * .92,
          height: size.height * .11,
        ),
        row.isEven ? farBed : nearBed,
      );
      final bedHighlight = Paint()
        ..color = const Color(0xFFD4E6A8).withValues(alpha: .42);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .5, y - size.height * .014),
          width: size.width * .88,
          height: size.height * .075,
        ),
        bedHighlight,
      );
    }

    final path = Path()
      ..moveTo(size.width * .43, size.height)
      ..cubicTo(
        size.width * .64,
        size.height * .78,
        size.width * .31,
        size.height * .62,
        size.width * .52,
        size.height * .43,
      )
      ..cubicTo(
        size.width * .65,
        size.height * .31,
        size.width * .44,
        size.height * .23,
        size.width * .52,
        size.height * .12,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB89C87)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(35.0, size.width * .13)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF2DFC5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(27.0, size.width * .098)
        ..strokeCap = StrokeCap.round,
    );

    for (var index = 0; index < 13; index++) {
      final x = size.width * (.03 + index * .078);
      final y = size.height * (.39 + (index.isEven ? .01 : .045));
      _drawLeaf(
        canvas,
        Offset(x, y),
        size.width * (index.isEven ? .038 : .03),
        index.isEven ? -.5 : .55,
      );
    }
    _drawButterfly(
      canvas,
      Offset(size.width * .19, size.height * .3),
      math.max(5.0, size.width * .018),
    );
    _drawButterfly(
      canvas,
      Offset(size.width * .76, size.height * .24),
      math.max(6.0, size.width * .022),
    );
    _drawFlowerSprinkle(canvas, size.width * .08, size.height * .56);
    _drawFlowerSprinkle(canvas, size.width * .91, size.height * .67);
    _drawGrass(canvas, size);
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius) {
    final sparkle = Path()
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
    canvas.drawPath(sparkle, Paint()..color = const Color(0xFFFFFEF5));
  }

  void _drawButterfly(Canvas canvas, Offset center, double size) {
    final wing = Paint()..color = const Color(0xFFFFD1E2);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(-size * .55, -size * .35),
        width: size,
        height: size * 1.15,
      ),
      wing,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(size * .55, -size * .35),
        width: size,
        height: size * 1.15,
      ),
      Paint()..color = const Color(0xFFE6D5FF),
    );
    canvas.drawLine(
      center + Offset(0, -size * .8),
      center + Offset(0, size * .8),
      Paint()
        ..color = const Color(0xFF8A685F)
        ..strokeWidth = math.max(1.0, size * .12)
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawFlowerSprinkle(Canvas canvas, double x, double y) {
    final center = Offset(x, y);
    for (var index = 0; index < 5; index++) {
      final angle = math.pi * 2 * index / 5;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * 4, math.sin(angle) * 4),
        2.5,
        Paint()..color = const Color(0xFFFFD5E4),
      );
    }
    canvas.drawCircle(center, 2.2, Paint()..color = const Color(0xFFFFE091));
  }

  void _drawLeaf(Canvas canvas, Offset center, double radius, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final leaf = Paint()..color = const Color(0xFF4E895A);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 2.2, height: radius),
      leaf,
    );
    canvas.drawLine(
      Offset(-radius, 0),
      Offset(radius, 0),
      Paint()
        ..color = const Color(0xFF39734B)
        ..strokeWidth = 1.4,
    );
    canvas.restore();
  }

  void _drawGrass(Canvas canvas, Size size) {
    final grass = Paint()
      ..color = const Color(0xFF4E8750)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 70; i++) {
      final x = size.width * ((i * 37 % 97) / 100);
      final y = size.height * (.38 + (i * 19 % 56) / 100);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + (i.isEven ? 3 : -3), y - 6 - (i % 4)),
        grass,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GardenLandscapePainter oldDelegate) => false;
}

class _CatalogFlowerIllustration extends StatelessWidget {
  const _CatalogFlowerIllustration({
    required this.flower,
    required this.unlocked,
    required this.growthPoints,
    required this.size,
    required this.variety,
  });

  final GardenFlower flower;
  final bool unlocked;
  final int growthPoints;
  final double size;
  final int variety;

  @override
  Widget build(BuildContext context) => FlowerIllustration(
    color: flower.color,
    growthPoints: growthPoints,
    variety: variety,
    petalCount: 12,
    locked: !unlocked,
    showPot: false,
  );
}

class LegacyCatalogFlowerPainter extends CustomPainter {
  const LegacyCatalogFlowerPainter({
    required this.color,
    required this.sortOrder,
    required this.unlocked,
    required this.growthPoints,
  });

  final Color color;
  final int sortOrder;
  final bool unlocked;
  final int growthPoints;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final stemColor = unlocked
        ? const Color(0xFF397E50)
        : const Color(0xFF96999A);
    final leafColor = unlocked
        ? const Color(0xFF67A967)
        : const Color(0xFFB4B6B7);
    final flowerColor = unlocked ? color : const Color(0xFFB7B8B9);
    final stem = Path()
      ..moveTo(50, 93)
      ..cubicTo(44, 75, 58, 61, 50, 39);
    canvas.drawPath(
      stem,
      Paint()
        ..color = stemColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      stem,
      Paint()
        ..color = unlocked ? const Color(0xFF9CCB78) : const Color(0xFFC5C7C8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    _drawGardenLeaf(canvas, const Offset(46, 74), -0.5, leafColor);
    _drawGardenLeaf(canvas, const Offset(54, 63), 0.45, leafColor);
    _drawGardenLeaf(canvas, const Offset(50, 91), 0, leafColor);
    if (unlocked) {
      final vein = Paint()
        ..color = const Color(0xFFB3D88E)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(35, 75), const Offset(46, 73), vein);
      canvas.drawLine(const Offset(54, 64), const Offset(64, 59), vein);
    }

    final totalPetals = 5 + sortOrder.abs() % 4;
    final visiblePetals = unlocked
        ? (totalPetals * growthPoints.clamp(0, 10) / 10).ceil()
        : totalPetals;
    if (visiblePetals == 0) {
      final budColor = unlocked ? flowerColor : const Color(0xFFB7B8B9);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 31), width: 18, height: 25),
        Paint()..color = budColor,
      );
    } else {
      for (var i = 0; i < visiblePetals; i++) {
        final angle = math.pi * 2 * i / visiblePetals;
        canvas.save();
        canvas.translate(50, 31);
        canvas.rotate(angle);
        final petal = _petalPath(sortOrder.abs() % 8);
        canvas.drawPath(
          petal,
          Paint()
            ..color = unlocked
                ? Color.lerp(flowerColor, const Color(0xFF9D6878), .15)!
                : const Color(0xFF96999A),
        );
        canvas.save();
        canvas.translate(0, -1.2);
        canvas.drawPath(
          petal,
          Paint()
            ..shader = LinearGradient(
              colors: [
                unlocked
                    ? Color.lerp(flowerColor, Colors.white, .48)!
                    : const Color(0xFFD0D1D1),
                flowerColor,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(petal.getBounds()),
        );
        canvas.restore();
        if (unlocked) {
          canvas.drawPath(
            petal,
            Paint()
              ..color = Colors.white.withValues(alpha: .36)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .65,
          );
        }
        canvas.restore();
      }
    }
    if (visiblePetals > 0) {
      if (unlocked && sortOrder % 4 == 0) {
        final star = Path();
        for (var point = 0; point < 10; point++) {
          final radius = point.isEven ? 9.5 : 6.5;
          final angle = math.pi * 2 * point / 10 - math.pi / 2;
          final offset = Offset(
            50 + math.cos(angle) * radius,
            31 + math.sin(angle) * radius,
          );
          if (point == 0) {
            star.moveTo(offset.dx, offset.dy);
          } else {
            star.lineTo(offset.dx, offset.dy);
          }
        }
        star.close();
        canvas.drawPath(star, Paint()..color = const Color(0xFFFFCF61));
      } else {
        canvas.drawCircle(
          const Offset(50, 31),
          9.5,
          Paint()
            ..color = unlocked
                ? const Color(0xFFFFE6A2)
                : const Color(0xFFB8BABB),
        );
      }
      canvas.drawCircle(
        const Offset(50, 31),
        7.5,
        Paint()
          ..color = unlocked
              ? const Color(0xFFFFD66B)
              : const Color(0xFF8F9293),
      );
      if (unlocked) {
        for (var dot = 0; dot < 5; dot++) {
          final angle = math.pi * 2 * dot / 5;
          canvas.drawCircle(
            Offset(50 + math.cos(angle) * 5, 31 + math.sin(angle) * 5),
            .8,
            Paint()..color = const Color(0xFFFFF8D8),
          );
        }
      }
    }
    if (unlocked && growthPoints >= 8) {
      canvas.drawCircle(
        const Offset(47.5, 29),
        1,
        Paint()..color = const Color(0xFF9C7046),
      );
      canvas.drawCircle(
        const Offset(52.5, 29),
        1,
        Paint()..color = const Color(0xFF9C7046),
      );
      canvas.drawArc(
        const Rect.fromLTWH(47, 30, 6, 5),
        .2,
        2.7,
        false,
        Paint()
          ..color = const Color(0xFF9C7046)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9,
      );
    }
    canvas.restore();
  }

  Path _petalPath(int shape) {
    switch (shape) {
      case 1:
        return Path()
          ..moveTo(0, -4)
          ..cubicTo(10, -14, 8, -24, 0, -29)
          ..cubicTo(-8, -24, -10, -14, 0, -4)
          ..close();
      case 2:
        return Path()
          ..moveTo(0, -4)
          ..quadraticBezierTo(12, -14, 7, -27)
          ..quadraticBezierTo(0, -23, -7, -27)
          ..quadraticBezierTo(-12, -14, 0, -4)
          ..close();
      case 3:
        return Path()
          ..moveTo(0, -4)
          ..cubicTo(14, -12, 12, -21, 0, -30)
          ..cubicTo(-12, -21, -14, -12, 0, -4)
          ..close();
      case 4:
        return Path()
          ..moveTo(0, -4)
          ..cubicTo(5, -12, 13, -17, 7, -29)
          ..cubicTo(1, -27, -2, -24, -4, -20)
          ..cubicTo(-11, -16, -9, -8, 0, -4)
          ..close();
      case 5:
        return Path()
          ..moveTo(0, -4)
          ..quadraticBezierTo(4, -10, 13, -17)
          ..quadraticBezierTo(12, -27, 0, -30)
          ..quadraticBezierTo(-12, -27, -13, -17)
          ..quadraticBezierTo(-4, -10, 0, -4)
          ..close();
      case 6:
        return Path()
          ..moveTo(0, -4)
          ..cubicTo(6, -12, 15, -17, 8, -27)
          ..quadraticBezierTo(0, -23, -8, -27)
          ..cubicTo(-15, -17, -6, -12, 0, -4)
          ..close();
      case 7:
        return Path()
          ..moveTo(0, -4)
          ..cubicTo(3, -13, 9, -18, 5, -28)
          ..cubicTo(1, -26, -1, -23, -3, -19)
          ..cubicTo(-12, -16, -10, -8, 0, -4)
          ..close();
      default:
        return Path()..addOval(
          Rect.fromCenter(center: const Offset(0, -17), width: 13, height: 24),
        );
    }
  }

  void _drawGardenLeaf(Canvas canvas, Offset point, double angle, Color color) {
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-7, 0), width: 20, height: 9),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LegacyCatalogFlowerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.sortOrder != sortOrder ||
      oldDelegate.unlocked != unlocked ||
      oldDelegate.growthPoints != growthPoints;
}
