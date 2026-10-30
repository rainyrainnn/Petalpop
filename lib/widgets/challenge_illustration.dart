import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/daily_challenge.dart';

class ChallengeIllustration extends StatelessWidget {
  const ChallengeIllustration({
    required this.challenge,
    super.key,
    this.size = 64,
  });

  final DailyChallenge challenge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      image: true,
      label: 'Illustration for ${challenge.title}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF604253), Color(0xFF3D2B3A)]
                : const [Color(0xFFFFF1F6), Color(0xFFEDE4FF)],
          ),
          borderRadius: BorderRadius.circular(size * .31),
          border: Border.all(
            color: isDark ? const Color(0xFF8F5A78) : const Color(0xFFFFD1E2),
          ),
        ),
        child: CustomPaint(
          painter: _ChallengeIllustrationPainter(
            _challengeKind(challenge),
            isDark,
          ),
        ),
      ),
    );
  }

  static _ChallengeKind _challengeKind(DailyChallenge challenge) {
    final id = challenge.id.toLowerCase().replaceAll('_', '-');
    final title = challenge.title.toLowerCase();
    final text = '$id $title ${challenge.description}'.toLowerCase();
    if (id.contains('kind-yourself') ||
        id.contains('self-kind') ||
        id.contains('self-love') ||
        title.contains('kind to yourself') ||
        title.contains('self-kindness') ||
        title.contains('self-love')) {
      return _ChallengeKind.selfKindness;
    }
    if (id.contains('happy-thought') ||
        title.contains('happy thought') ||
        title.contains('happy thoughts')) {
      return _ChallengeKind.happyThought;
    }
    if (id.contains('favorite-song') ||
        id.contains('favourite-song') ||
        title.contains('favorite song') ||
        title.contains('favourite song')) {
      return _ChallengeKind.favoriteSong;
    }
    if (text.contains('water') || text.contains('drink')) {
      return _ChallengeKind.water;
    }
    if (text.contains('photo') || text.contains('camera')) {
      return _ChallengeKind.camera;
    }
    if (text.contains('write') ||
        text.contains('journal') ||
        text.contains('gratitude') ||
        text.contains('list') ||
        text.contains('note') ||
        text.contains('memory') ||
        text.contains('three words') ||
        text.contains('postcard')) {
      return _ChallengeKind.journal;
    }
    if (text.contains('song') ||
        text.contains('music') ||
        text.contains('listen')) {
      return _ChallengeKind.music;
    }
    if (text.contains('stretch') ||
        text.contains('exercise') ||
        text.contains('dance') ||
        text.contains('walk') ||
        text.contains('move')) {
      return _ChallengeKind.movement;
    }
    if (text.contains('rest') ||
        text.contains('break') ||
        text.contains('pause') ||
        text.contains('breathe') ||
        text.contains('breath') ||
        text.contains('cozy') ||
        text.contains('comfort')) {
      return _ChallengeKind.rest;
    }
    if (text.contains('fruit') ||
        text.contains('snack') ||
        text.contains('food')) {
      return _ChallengeKind.fruit;
    }
    if (text.contains('kind') ||
        text.contains('thank') ||
        text.contains('appreciat') ||
        text.contains('compliment') ||
        text.contains('smile')) {
      return _ChallengeKind.kindness;
    }
    if (text.contains('sky') ||
        text.contains('air') ||
        text.contains('nature') ||
        text.contains('sunlight') ||
        text.contains('green') ||
        text.contains('smell')) {
      return _ChallengeKind.nature;
    }
    return _ChallengeKind.bloom;
  }
}

enum _ChallengeKind {
  water,
  camera,
  journal,
  happyThought,
  music,
  favoriteSong,
  movement,
  rest,
  fruit,
  kindness,
  selfKindness,
  nature,
  bloom,
}

class _ChallengeIllustrationPainter extends CustomPainter {
  const _ChallengeIllustrationPainter(this.kind, this.isDark);

  final _ChallengeKind kind;
  final bool isDark;

  static const _ink = Color(0xFF6D4A5E);
  static const _pink = Color(0xFFF17FA7);
  static const _blue = Color(0xFF80C8E5);
  static const _green = Color(0xFF79B982);
  static const _yellow = Color(0xFFFFD676);
  static const _purple = Color(0xFFB49AE2);
  static const _cream = Color(0xFFFFF7E7);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    _drawSparkle(canvas, const Offset(19, 20), 4.5);
    _drawSparkle(canvas, const Offset(82, 27), 3);
    switch (kind) {
      case _ChallengeKind.water:
        _drawWater(canvas);
      case _ChallengeKind.camera:
        _drawCamera(canvas);
      case _ChallengeKind.journal:
        _drawJournal(canvas);
      case _ChallengeKind.happyThought:
        _drawHappyThought(canvas);
      case _ChallengeKind.music:
        _drawMusic(canvas);
      case _ChallengeKind.favoriteSong:
        _drawFavoriteSong(canvas);
      case _ChallengeKind.movement:
        _drawMovement(canvas);
      case _ChallengeKind.rest:
        _drawRest(canvas);
      case _ChallengeKind.fruit:
        _drawFruit(canvas);
      case _ChallengeKind.kindness:
        _drawKindness(canvas);
      case _ChallengeKind.selfKindness:
        _drawSelfKindness(canvas);
      case _ChallengeKind.nature:
        _drawNature(canvas);
      case _ChallengeKind.bloom:
        _drawBloom(canvas);
    }
    canvas.restore();
  }

  void _drawWater(Canvas canvas) {
    final glass = Path()
      ..moveTo(30, 26)
      ..lineTo(69, 26)
      ..lineTo(64, 78)
      ..quadraticBezierTo(50, 86, 36, 78)
      ..close();
    canvas.drawPath(glass, Paint()..color = const Color(0xFFFAFFFF));
    final water = Path()
      ..moveTo(34, 54)
      ..quadraticBezierTo(49, 49, 66, 54)
      ..lineTo(64, 77)
      ..quadraticBezierTo(50, 83, 37, 77)
      ..close();
    canvas.drawPath(water, Paint()..color = _blue);
    canvas.drawPath(
      glass,
      Paint()
        ..color = _blue.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      const Offset(59, 20),
      const Offset(62, 53),
      Paint()
        ..color = _pink
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      const Rect.fromLTWH(40, 35, 7, 14),
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
    canvas.drawCircle(const Offset(73, 62), 3, Paint()..color = _yellow);
  }

  void _drawCamera(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 33, 64, 46),
      const Radius.circular(11),
    );
    canvas.drawRRect(body, Paint()..color = _pink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, 27, 21, 12),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE66B98),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(62, 39, 12, 8),
        const Radius.circular(3),
      ),
      Paint()..color = _yellow,
    );
    canvas.drawCircle(const Offset(49, 56), 17, Paint()..color = _cream);
    canvas.drawCircle(const Offset(49, 56), 11, Paint()..color = _blue);
    canvas.drawCircle(
      const Offset(46, 52),
      3,
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
    _drawSparkle(canvas, const Offset(71, 23), 5);
  }

  void _drawJournal(Canvas canvas) {
    canvas.save();
    canvas.translate(50, 55);
    canvas.rotate(-.12);
    final cover = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-26, -32, 52, 65),
      const Radius.circular(7),
    );
    canvas.drawRRect(cover, Paint()..color = _purple);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-19, -25, 39, 51),
        const Radius.circular(3),
      ),
      Paint()..color = _cream,
    );
    canvas.drawLine(
      const Offset(-16, -17),
      const Offset(-16, 20),
      Paint()
        ..color = _pink
        ..strokeWidth = 2,
    );
    for (var y = -14.0; y <= 16; y += 9) {
      canvas.drawLine(
        Offset(-10, y),
        Offset(14, y),
        Paint()
          ..color = const Color(0xFFCCB7C7)
          ..strokeWidth = 1.4,
      );
    }
    _drawFlower(canvas, const Offset(4, -1), 5, _pink);
    canvas.restore();
    canvas.drawLine(
      const Offset(73, 67),
      const Offset(82, 32),
      Paint()
        ..color = _green
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    _drawFlower(canvas, const Offset(74, 26), 5, _yellow);
  }

  void _drawHappyThought(Canvas canvas) {
    canvas.save();
    canvas.translate(47, 49);
    canvas.rotate(-.1);
    final cover = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-26, -32, 52, 65),
      const Radius.circular(8),
    );
    canvas.drawRRect(cover, Paint()..color = const Color(0xFFEE91B5));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -26, 40, 53),
        const Radius.circular(4),
      ),
      Paint()..color = _cream,
    );
    canvas.drawLine(
      const Offset(-15, -20),
      const Offset(-15, 20),
      Paint()
        ..color = const Color(0xFFDDA6C2)
        ..strokeWidth = 2,
    );
    for (var y = -17.0; y <= 13; y += 9) {
      canvas.drawLine(
        Offset(-10, y),
        Offset(14, y),
        Paint()
          ..color = const Color(0xFFD6C5D2)
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawCircle(const Offset(2, 5), 10, Paint()..color = _yellow);
    canvas.drawCircle(const Offset(-1, 3), 1.3, Paint()..color = _ink);
    canvas.drawCircle(const Offset(5, 3), 1.3, Paint()..color = _ink);
    canvas.drawArc(
      const Rect.fromLTWH(-2, 4, 8, 6),
      0,
      math.pi,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(69, 61);
    canvas.rotate(.72);
    final pencil = Path()
      ..moveTo(-4, 13)
      ..lineTo(-4, -11)
      ..quadraticBezierTo(0, -17, 4, -11)
      ..lineTo(4, 13)
      ..lineTo(0, 20)
      ..close();
    canvas.drawPath(pencil, Paint()..color = _purple);
    canvas.drawPath(
      pencil,
      Paint()
        ..color = const Color(0xFF8872B5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      const Offset(-3, 8),
      const Offset(3, 8),
      Paint()
        ..color = _yellow
        ..strokeWidth = 2,
    );
    canvas.restore();
    _drawSparkle(canvas, const Offset(27, 24), 4);
    _drawFlower(canvas, const Offset(77, 29), 4.5, _pink);
  }

  void _drawMusic(Canvas canvas) {
    canvas.drawArc(
      const Rect.fromLTWH(25, 20, 50, 53),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 46, 16, 25),
        const Radius.circular(7),
      ),
      Paint()..color = _pink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(64, 46, 16, 25),
        const Radius.circular(7),
      ),
      Paint()..color = _pink,
    );
    _drawMusicNote(canvas, const Offset(48, 42), _yellow);
    _drawMusicNote(canvas, const Offset(58, 60), _blue);
    canvas.drawCircle(const Offset(47, 74), 2.5, Paint()..color = _green);
  }

  void _drawFavoriteSong(Canvas canvas) {
    canvas.drawArc(
      const Rect.fromLTWH(22, 18, 56, 57),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFE86F9E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      const Rect.fromLTWH(28, 23, 44, 44),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFFFB3CD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (final x in [20.0, 68.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 47, 15, 25),
          const Radius.circular(7),
        ),
        Paint()..color = const Color(0xFFE86F9E),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 3, 51, 9, 15),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFFFD8E6),
      );
    }
    _drawMusicNote(canvas, const Offset(39, 68), _purple);
    _drawMusicNote(canvas, const Offset(61, 38), _yellow);
    _drawSparkle(canvas, const Offset(79, 24), 5);
    canvas.drawCircle(
      const Offset(40, 48),
      2,
      Paint()..color = Colors.white.withValues(alpha: .85),
    );
  }

  void _drawMusicNote(Canvas canvas, Offset center, Color color) {
    canvas.drawLine(
      center,
      center + const Offset(0, -13),
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 4, Paint()..color = color);
    canvas.drawCircle(center + const Offset(0, -13), 2, Paint()..color = color);
  }

  void _drawMovement(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 33), 11, Paint()..color = _cream);
    canvas.drawCircle(const Offset(46, 32), 1.6, Paint()..color = _ink);
    canvas.drawCircle(const Offset(54, 32), 1.6, Paint()..color = _ink);
    final body = Paint()
      ..color = _pink
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 45), const Offset(50, 66), body);
    canvas.drawLine(const Offset(50, 50), const Offset(31, 40), body);
    canvas.drawLine(const Offset(31, 40), const Offset(24, 28), body);
    canvas.drawLine(const Offset(50, 50), const Offset(68, 42), body);
    canvas.drawLine(const Offset(68, 42), const Offset(78, 28), body);
    canvas.drawLine(const Offset(50, 65), const Offset(35, 80), body);
    canvas.drawLine(const Offset(50, 65), const Offset(67, 78), body);
    _drawFlower(canvas, const Offset(23, 24), 4, _yellow);
    _drawSparkle(canvas, const Offset(80, 20), 4);
  }

  void _drawRest(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 49, 60, 28),
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFFB7A1E2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 43, 46, 25),
        const Radius.circular(11),
      ),
      Paint()..color = _cream,
    );
    canvas.drawOval(
      const Rect.fromLTWH(34, 48, 29, 15),
      Paint()..color = const Color(0xFFFFD7E5),
    );
    canvas.drawArc(
      const Rect.fromLTWH(42, 18, 20, 22),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _pink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      const Offset(42, 29),
      const Offset(42, 43),
      Paint()
        ..color = _pink
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      const Offset(62, 29),
      const Offset(62, 43),
      Paint()
        ..color = _pink
        ..strokeWidth = 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 33, 20, 10),
        const Radius.circular(3),
      ),
      Paint()..color = _cream,
    );
    _drawFlower(canvas, const Offset(76, 35), 4, _yellow);
  }

  void _drawFruit(Canvas canvas) {
    final fruit = Path()
      ..moveTo(50, 37)
      ..cubicTo(32, 26, 22, 43, 29, 63)
      ..cubicTo(35, 83, 45, 80, 50, 75)
      ..cubicTo(57, 82, 67, 82, 73, 62)
      ..cubicTo(80, 42, 67, 28, 50, 37)
      ..close();
    canvas.drawPath(fruit, Paint()..color = const Color(0xFFEF7185));
    canvas.drawLine(
      const Offset(50, 37),
      const Offset(51, 26),
      Paint()
        ..color = const Color(0xFF80604D)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final leaf = Path()
      ..moveTo(51, 31)
      ..quadraticBezierTo(60, 20, 69, 28)
      ..quadraticBezierTo(61, 35, 51, 31)
      ..close();
    canvas.drawPath(leaf, Paint()..color = _green);
    canvas.drawOval(
      const Rect.fromLTWH(35, 46, 7, 15),
      Paint()..color = Colors.white.withValues(alpha: .45),
    );
  }

  void _drawKindness(Canvas canvas) {
    final heart = Path()
      ..moveTo(50, 76)
      ..cubicTo(44, 69, 25, 56, 25, 43)
      ..cubicTo(25, 28, 43, 25, 50, 38)
      ..cubicTo(58, 25, 76, 28, 76, 43)
      ..cubicTo(76, 56, 57, 69, 50, 76)
      ..close();
    canvas.drawPath(heart, Paint()..color = _pink);
    canvas.drawPath(
      heart,
      Paint()
        ..color = const Color(0xFFD85D89)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      const Offset(40, 39),
      4,
      Paint()..color = Colors.white.withValues(alpha: .55),
    );
    _drawFlower(canvas, const Offset(73, 25), 5, _yellow);
    _drawSparkle(canvas, const Offset(24, 72), 4);
  }

  void _drawSelfKindness(Canvas canvas) {
    final heart = Path()
      ..moveTo(50, 79)
      ..cubicTo(44, 71, 23, 56, 23, 42)
      ..cubicTo(23, 27, 42, 23, 50, 38)
      ..cubicTo(58, 23, 77, 27, 77, 42)
      ..cubicTo(77, 56, 56, 71, 50, 79)
      ..close();
    canvas.drawShadow(heart, const Color(0xFFB94C79), 5, true);
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB4CF), Color(0xFFEC6D9A)],
        ).createShader(const Rect.fromLTWH(20, 22, 60, 60)),
    );
    canvas.drawPath(
      heart,
      Paint()
        ..color = const Color(0xFFD85D89)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawOval(
      const Rect.fromLTWH(32, 35, 7, 13),
      Paint()..color = Colors.white.withValues(alpha: .62),
    );
    canvas.drawCircle(const Offset(42, 45), 2, Paint()..color = _ink);
    canvas.drawCircle(const Offset(58, 45), 2, Paint()..color = _ink);
    canvas.drawOval(
      const Rect.fromLTWH(33, 50, 8, 4),
      Paint()..color = const Color(0xFFDA628D).withValues(alpha: .65),
    );
    canvas.drawOval(
      const Rect.fromLTWH(59, 50, 8, 4),
      Paint()..color = const Color(0xFFDA628D).withValues(alpha: .65),
    );
    canvas.drawArc(
      const Rect.fromLTWH(44, 48, 12, 9),
      0,
      math.pi,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawSparkle(canvas, const Offset(22, 30), 5);
    _drawSparkle(canvas, const Offset(79, 62), 4);
    _drawFlower(canvas, const Offset(77, 25), 4, _yellow);
  }

  void _drawNature(Canvas canvas) {
    final leaf = Path()
      ..moveTo(28, 72)
      ..cubicTo(27, 40, 47, 22, 76, 25)
      ..cubicTo(77, 55, 59, 76, 28, 72)
      ..close();
    canvas.drawPath(leaf, Paint()..color = _green);
    canvas.drawPath(
      leaf,
      Paint()
        ..color = const Color(0xFF4F9660)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(30, 72),
      const Offset(69, 34),
      Paint()
        ..color = const Color(0xFFDDF2D2)
        ..strokeWidth = 3,
    );
    for (var index = 0; index < 3; index++) {
      canvas.drawLine(
        Offset(43 + index * 8, 59 - index * 8),
        Offset(40 + index * 7, 48 - index * 7),
        Paint()
          ..color = const Color(0xFFDDF2D2)
          ..strokeWidth = 2,
      );
    }
    _drawButterfly(canvas, const Offset(72, 73));
  }

  void _drawButterfly(Canvas canvas, Offset center) {
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(-5, -2),
        width: 9,
        height: 12,
      ),
      Paint()..color = _purple,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(5, -2),
        width: 9,
        height: 12,
      ),
      Paint()..color = const Color(0xFFFFC4D8),
    );
    canvas.drawLine(
      center + const Offset(0, -6),
      center + const Offset(0, 6),
      Paint()
        ..color = _ink
        ..strokeWidth = 2,
    );
  }

  void _drawBloom(Canvas canvas) {
    canvas.drawLine(
      const Offset(50, 73),
      const Offset(50, 45),
      Paint()
        ..color = _green
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    _drawLeaf(canvas, const Offset(39, 62), _green, -.55);
    _drawLeaf(canvas, const Offset(60, 56), const Color(0xFF91C98B), .55);
    _drawFlower(canvas, const Offset(50, 37), 11, _pink);
    canvas.drawOval(
      const Rect.fromLTWH(43, 72, 14, 7),
      Paint()..color = _yellow,
    );
  }

  void _drawLeaf(Canvas canvas, Offset center, Color color, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      const Rect.fromLTWH(-11, -5, 22, 10),
      Paint()..color = color,
    );
    canvas.restore();
  }

  void _drawFlower(Canvas canvas, Offset center, double radius, Color color) {
    for (var index = 0; index < 6; index++) {
      final angle = math.pi * 2 * index / 6;
      final petalCenter =
          center +
          Offset(
            math.cos(angle) * radius * .78,
            math.sin(angle) * radius * .78,
          );
      canvas.drawOval(
        Rect.fromCenter(
          center: petalCenter,
          width: radius * .95,
          height: radius * .72,
        ),
        Paint()..color = color,
      );
    }
    canvas.drawCircle(center, radius * .43, Paint()..color = _yellow);
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius) {
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
    canvas.drawPath(
      path,
      Paint()..color = isDark ? const Color(0xFFFFD8E9) : Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _ChallengeIllustrationPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.isDark != isDark;
}
