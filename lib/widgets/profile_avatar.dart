import 'dart:math' as math;

import 'package:flutter/material.dart';

class PetalAvatarChoice {
  const PetalAvatarChoice({
    required this.id,
    required this.label,
    required this.background,
    required this.skin,
    required this.hair,
    required this.outfit,
    required this.flower,
    required this.hairStyle,
    this.accessory = 0,
  });

  final String id;
  final String label;
  final Color background;
  final Color skin;
  final Color hair;
  final Color outfit;
  final Color flower;
  final int hairStyle;
  final int accessory;

  static const choices = [
    PetalAvatarChoice(
      id: 'girl',
      label: 'Daisy',
      background: Color(0xFFFFDFEA),
      skin: Color(0xFFF2C6A8),
      hair: Color(0xFF704334),
      outfit: Color(0xFFF07CA6),
      flower: Color(0xFFFFD35C),
      hairStyle: 0,
      accessory: 1,
    ),
    PetalAvatarChoice(
      id: 'boy',
      label: 'Sunny',
      background: Color(0xFFFFE8C2),
      skin: Color(0xFFD89A72),
      hair: Color(0xFF3D302F),
      outfit: Color(0xFF63B8A0),
      flower: Color(0xFFFFF0A0),
      hairStyle: 1,
      accessory: 2,
    ),
    PetalAvatarChoice(
      id: 'curly',
      label: 'Clover',
      background: Color(0xFFE8DFFC),
      skin: Color(0xFF8F573D),
      hair: Color(0xFF2E2427),
      outfit: Color(0xFF9C81D2),
      flower: Color(0xFFFFB8D0),
      hairStyle: 2,
      accessory: 3,
    ),
    PetalAvatarChoice(
      id: 'bunny',
      label: 'Bunny',
      background: Color(0xFFF9E3F2),
      skin: Color(0xFFFFD8C8),
      hair: Color(0xFFD7A27E),
      outfit: Color(0xFFFF91B2),
      flower: Color(0xFFB8E3A5),
      hairStyle: 3,
      accessory: 4,
    ),
    PetalAvatarChoice(
      id: 'cat',
      label: 'Kitty',
      background: Color(0xFFFFE8CF),
      skin: Color(0xFFD49A74),
      hair: Color(0xFF633A30),
      outfit: Color(0xFF7BB9DF),
      flower: Color(0xFFFFC45C),
      hairStyle: 4,
      accessory: 5,
    ),
    PetalAvatarChoice(
      id: 'bear',
      label: 'Bear',
      background: Color(0xFFDDF1DF),
      skin: Color(0xFF9B624A),
      hair: Color(0xFF302421),
      outfit: Color(0xFFE48878),
      flower: Color(0xFFFFD9E7),
      hairStyle: 5,
      accessory: 1,
    ),
    PetalAvatarChoice(
      id: 'fox',
      label: 'Fox',
      background: Color(0xFFFFE0D0),
      skin: Color(0xFFFFD7B5),
      hair: Color(0xFFB65033),
      outfit: Color(0xFF88B96D),
      flower: Color(0xFFFFE681),
      hairStyle: 6,
      accessory: 2,
    ),
    PetalAvatarChoice(
      id: 'frog',
      label: 'Froggy',
      background: Color(0xFFD8F0D5),
      skin: Color(0xFFB97955),
      hair: Color(0xFF4A342B),
      outfit: Color(0xFF71B9A1),
      flower: Color(0xFFFFB2C9),
      hairStyle: 7,
      accessory: 3,
    ),
  ];

  static PetalAvatarChoice fromId(String id) => choices.firstWhere(
    (choice) => choice.id == id,
    orElse: () => choices.first,
  );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.avatarId, super.key, this.radius = 28});

  final String avatarId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = PetalAvatarChoice.fromId(avatarId);
    return SizedBox.square(
      dimension: radius * 2,
      child: ClipOval(
        child: CustomPaint(
          painter: _PetalAvatarPainter(avatar),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PetalAvatarPainter extends CustomPainter {
  const _PetalAvatarPainter(this.avatar);

  final PetalAvatarChoice avatar;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final background = Paint()..color = avatar.background;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), background);

    final hair = Paint()..color = avatar.hair;
    final skin = Paint()..color = avatar.skin;
    final outfit = Paint()..color = avatar.outfit;

    canvas.drawOval(const Rect.fromLTWH(18, 68, 64, 46), outfit);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 59, 16, 20),
        const Radius.circular(6),
      ),
      skin,
    );

    if (avatar.hairStyle == 0 ||
        avatar.hairStyle == 3 ||
        avatar.hairStyle == 6) {
      canvas.drawOval(const Rect.fromLTWH(21, 21, 18, 55), hair);
      canvas.drawOval(const Rect.fromLTWH(61, 21, 18, 55), hair);
    } else if (avatar.hairStyle == 5 || avatar.hairStyle == 7) {
      canvas.drawCircle(const Offset(32, 25), 13, hair);
      canvas.drawCircle(const Offset(68, 25), 13, hair);
    }

    canvas.drawOval(const Rect.fromLTWH(27, 17, 46, 57), skin);
    _drawHair(canvas, hair);
    _drawFace(canvas);
    _drawAccessory(canvas, Paint()..color = avatar.flower);

    canvas.restore();
  }

  void _drawHair(Canvas canvas, Paint paint) {
    switch (avatar.hairStyle) {
      case 0:
        final path = Path()
          ..moveTo(25, 45)
          ..quadraticBezierTo(20, 7, 51, 11)
          ..quadraticBezierTo(80, 12, 75, 45)
          ..quadraticBezierTo(64, 32, 56, 27)
          ..quadraticBezierTo(43, 42, 25, 45)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case 1:
        canvas.drawOval(const Rect.fromLTWH(26, 13, 48, 34), paint);
        final sidePart = Path()
          ..moveTo(48, 15)
          ..quadraticBezierTo(68, 14, 74, 34)
          ..quadraticBezierTo(61, 28, 48, 31)
          ..close();
        canvas.drawPath(
          sidePart,
          Paint()..color = avatar.hair.withValues(alpha: .82),
        );
        break;
      case 2:
        for (var row = 0; row < 2; row++) {
          for (var column = 0; column < 5; column++) {
            canvas.drawCircle(
              Offset(29 + column * 10.5, 18 + row * 10),
              row == 0 ? 9 : 8,
              paint,
            );
          }
        }
        break;
      case 3:
        canvas.drawOval(const Rect.fromLTWH(24, 13, 52, 48), paint);
        final fringe = Path()
          ..moveTo(28, 34)
          ..quadraticBezierTo(43, 19, 53, 34)
          ..quadraticBezierTo(65, 24, 73, 36)
          ..lineTo(72, 43)
          ..lineTo(28, 43)
          ..close();
        canvas.drawPath(fringe, Paint()..color = avatar.hair);
        break;
      case 4:
        canvas.drawOval(const Rect.fromLTWH(25, 14, 50, 42), paint);
        canvas.drawOval(const Rect.fromLTWH(23, 35, 18, 42), paint);
        final fringe = Path()
          ..moveTo(28, 37)
          ..quadraticBezierTo(47, 21, 72, 38)
          ..lineTo(69, 45)
          ..quadraticBezierTo(51, 37, 31, 47)
          ..close();
        canvas.drawPath(fringe, paint);
        break;
      case 5:
        canvas.drawOval(const Rect.fromLTWH(24, 13, 52, 42), paint);
        for (final x in [32.0, 44.0, 56.0, 68.0]) {
          canvas.drawCircle(Offset(x, 23), 8, paint);
        }
        break;
      case 6:
        canvas.drawOval(const Rect.fromLTWH(24, 13, 52, 53), paint);
        final fringe = Path()
          ..moveTo(27, 39)
          ..quadraticBezierTo(49, 17, 74, 38)
          ..lineTo(68, 48)
          ..quadraticBezierTo(52, 39, 31, 47)
          ..close();
        canvas.drawPath(fringe, paint);
        break;
      case 7:
        canvas.drawCircle(const Offset(31, 22), 13, paint);
        canvas.drawCircle(const Offset(69, 22), 13, paint);
        canvas.drawOval(const Rect.fromLTWH(27, 15, 46, 38), paint);
        canvas.drawOval(const Rect.fromLTWH(21, 32, 13, 37), paint);
        canvas.drawOval(const Rect.fromLTWH(66, 32, 13, 37), paint);
        break;
    }
  }

  void _drawFace(Canvas canvas) {
    final ink = Paint()
      ..color = const Color(0xFF533B3A)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final eye = Paint()..color = const Color(0xFF533B3A);
    final eyeY = avatar.hairStyle == 1 ? 46.0 : 47.0;
    canvas.drawCircle(Offset(40, eyeY), 1.8, eye);
    canvas.drawCircle(Offset(60, eyeY), 1.8, eye);
    final smile = Path()
      ..moveTo(43, 57)
      ..quadraticBezierTo(50, 64, 57, 57);
    canvas.drawPath(smile, ink..strokeWidth = 2.2);
    final cheek = Paint()
      ..color = const Color(0xFFE98994).withValues(alpha: .55);
    canvas.drawOval(const Rect.fromLTWH(31, 54, 7, 3.5), cheek);
    canvas.drawOval(const Rect.fromLTWH(62, 54, 7, 3.5), cheek);
  }

  void _drawAccessory(Canvas canvas, Paint paint) {
    switch (avatar.accessory) {
      case 1:
        _drawFlower(canvas, const Offset(70, 24), 6, avatar.flower);
        break;
      case 2:
        canvas.drawArc(
          const Rect.fromLTWH(33, 38, 34, 18),
          3.5,
          2.2,
          false,
          Paint()
            ..color = const Color(0xFF7F5D46)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _drawFlower(canvas, const Offset(72, 22), 5, avatar.flower);
        break;
      case 3:
        _drawFlower(canvas, const Offset(29, 28), 5, avatar.flower);
        _drawFlower(canvas, const Offset(70, 29), 4, const Color(0xFFFFF1B3));
        break;
      case 4:
        _drawFlower(canvas, const Offset(50, 17), 6, avatar.flower);
        break;
      case 5:
        canvas.drawCircle(
          const Offset(29, 62),
          2.2,
          paint..color = avatar.flower,
        );
        canvas.drawCircle(const Offset(71, 62), 2.2, paint);
        break;
    }
  }

  void _drawFlower(Canvas canvas, Offset center, double radius, Color color) {
    final petal = Paint()..color = color;
    for (var i = 0; i < 5; i++) {
      final angle = i * 1.2566370614;
      final point =
          center +
          Offset(
            radius * .72 * math.cos(angle),
            radius * .72 * math.sin(angle),
          );
      canvas.drawCircle(point, radius * .43, petal);
    }
    canvas.drawCircle(
      center,
      radius * .32,
      Paint()..color = const Color(0xFFFFF0A1),
    );
  }

  @override
  bool shouldRepaint(covariant _PetalAvatarPainter oldDelegate) =>
      oldDelegate.avatar.id != avatar.id;
}
