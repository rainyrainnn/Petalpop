import 'dart:math' as math;

import 'package:flutter/material.dart';

class MoodFaceIllustration extends StatelessWidget {
  const MoodFaceIllustration({required this.mood, this.size = 48, super.key});

  final String mood;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MoodFacePainter(mood)),
  );
}

class _MoodFacePainter extends CustomPainter {
  const _MoodFacePainter(this.mood);

  final String mood;

  static const _colors = <String, Color>{
    'Happy': Color(0xFFFFE59A),
    'Calm': Color(0xFFE5D9FA),
    'Loved': Color(0xFFFFD6E4),
    'Excited': Color(0xFFFFD9B3),
    'Tired': Color(0xFFDCDCF3),
    'Sad': Color(0xFFD5E6FA),
    'Anxious': Color(0xFFD1EEE2),
    'Angry': Color(0xFFFFD3CC),
    'Other': Color(0xFFFFECDD),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final color = _colors[mood] ?? _colors['Other']!;
    final fill = Paint()..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(50, 50), 48, fill..color = color);
    canvas.drawCircle(
      const Offset(50, 50),
      42,
      fill..color = const Color(0xFFFFFBF7).withValues(alpha: .72),
    );
    canvas.drawOval(const Rect.fromLTWH(20, 16, 60, 67), fill..color = color);
    canvas.drawOval(
      const Rect.fromLTWH(28, 22, 38, 11),
      fill..color = Colors.white.withValues(alpha: .28),
    );
    _drawCheeks(canvas);

    switch (mood) {
      case 'Happy':
        _drawEyes(canvas, eyeY: 43);
        _drawSmile(canvas);
        break;
      case 'Calm':
        _drawClosedEyes(canvas, downturned: false);
        _drawSmile(canvas, subtle: true);
        break;
      case 'Loved':
        _drawHeartEye(canvas, const Offset(38, 43));
        _drawHeartEye(canvas, const Offset(62, 43));
        _drawSmile(canvas, width: 18);
        break;
      case 'Excited':
        canvas.drawCircle(const Offset(38, 42), 4.5, _inkFill());
        canvas.drawCircle(const Offset(62, 42), 4.5, _inkFill());
        canvas.drawOval(
          const Rect.fromLTWH(43, 53, 14, 17),
          Paint()..color = const Color(0xFF9A5860),
        );
        canvas.drawOval(
          const Rect.fromLTWH(46, 55, 8, 6),
          Paint()..color = const Color(0xFFFFA7AA),
        );
        break;
      case 'Tired':
        _drawClosedEyes(canvas, downturned: true);
        _drawMouth(canvas, const Offset(50, 62), const Offset(8, 0));
        canvas.drawArc(
          const Rect.fromLTWH(33, 37, 12, 12),
          math.pi,
          math.pi / 2,
          false,
          _inkStroke(),
        );
        canvas.drawArc(
          const Rect.fromLTWH(57, 37, 12, 12),
          math.pi,
          math.pi / 2,
          false,
          _inkStroke(),
        );
        break;
      case 'Sad':
        _drawEyes(canvas, eyeY: 44, radius: 3.2);
        _drawBrow(canvas, const Offset(32, 35), const Offset(43, 38));
        _drawBrow(canvas, const Offset(57, 38), const Offset(68, 35));
        _drawFrown(canvas);
        _drawTear(canvas, const Offset(69, 53));
        break;
      case 'Anxious':
        _drawEyes(canvas, eyeY: 43, radius: 4.4, pupilsOffset: -1.5);
        _drawBrow(canvas, const Offset(31, 34), const Offset(44, 32));
        _drawBrow(canvas, const Offset(56, 32), const Offset(69, 34));
        _drawWorriedMouth(canvas);
        _drawTear(canvas, const Offset(76, 43));
        break;
      case 'Angry':
        _drawEyes(canvas, eyeY: 45, radius: 3.5);
        _drawBrow(canvas, const Offset(31, 34), const Offset(44, 39));
        _drawBrow(canvas, const Offset(56, 39), const Offset(69, 34));
        _drawMouth(canvas, const Offset(50, 62), const Offset(14, 2));
        break;
      default:
        _drawEyes(canvas, eyeY: 44, radius: 3);
        _drawMouth(canvas, const Offset(50, 62), const Offset(11, 0));
        break;
    }

    canvas.restore();
  }

  void _drawCheeks(Canvas canvas) {
    final cheek = Paint()
      ..color = const Color(0xFFE88E9A).withValues(alpha: .38);
    canvas.drawOval(const Rect.fromLTWH(24, 52, 13, 6), cheek);
    canvas.drawOval(const Rect.fromLTWH(63, 52, 13, 6), cheek);
  }

  void _drawEyes(
    Canvas canvas, {
    required double eyeY,
    double radius = 3.5,
    double pupilsOffset = 0,
  }) {
    final eye = _inkFill();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(38 + pupilsOffset, eyeY),
        width: radius * 2,
        height: radius * 2.4,
      ),
      eye,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(62 + pupilsOffset, eyeY),
        width: radius * 2,
        height: radius * 2.4,
      ),
      eye,
    );
    final shine = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(39 + pupilsOffset, eyeY - 1), 1, shine);
    canvas.drawCircle(Offset(63 + pupilsOffset, eyeY - 1), 1, shine);
  }

  void _drawClosedEyes(Canvas canvas, {required bool downturned}) {
    final eye = _inkStroke();
    final left = Path()
      ..moveTo(31, 43)
      ..quadraticBezierTo(38, downturned ? 50 : 36, 45, 43);
    final right = Path()
      ..moveTo(55, 43)
      ..quadraticBezierTo(62, downturned ? 50 : 36, 69, 43);
    canvas.drawPath(left, eye);
    canvas.drawPath(right, eye);
  }

  void _drawSmile(Canvas canvas, {double width = 17, bool subtle = false}) {
    final path = Path()
      ..moveTo(50 - width / 2, 57)
      ..quadraticBezierTo(50, subtle ? 63 : 70, 50 + width / 2, 57);
    canvas.drawPath(path, _inkStroke()..strokeWidth = subtle ? 2 : 3);
  }

  void _drawFrown(Canvas canvas) {
    final path = Path()
      ..moveTo(40, 66)
      ..quadraticBezierTo(50, 54, 60, 66);
    canvas.drawPath(path, _inkStroke()..strokeWidth = 3);
  }

  void _drawMouth(Canvas canvas, Offset center, Offset size) {
    canvas.drawLine(
      Offset(center.dx - size.dx / 2, center.dy - size.dy / 2),
      Offset(center.dx + size.dx / 2, center.dy + size.dy / 2),
      _inkStroke()..strokeWidth = 2.8,
    );
  }

  void _drawWorriedMouth(Canvas canvas) {
    final path = Path()
      ..moveTo(42, 63)
      ..quadraticBezierTo(50, 55, 58, 63);
    canvas.drawPath(path, _inkStroke()..strokeWidth = 2.8);
  }

  void _drawBrow(Canvas canvas, Offset start, Offset end) =>
      canvas.drawLine(start, end, _inkStroke()..strokeWidth = 3);

  void _drawTear(Canvas canvas, Offset center) {
    final path = Path()
      ..moveTo(center.dx, center.dy - 5)
      ..cubicTo(
        center.dx - 5,
        center.dy + 1,
        center.dx - 3,
        center.dy + 6,
        center.dx,
        center.dy + 6,
      )
      ..cubicTo(
        center.dx + 4,
        center.dy + 6,
        center.dx + 5,
        center.dy + 1,
        center.dx,
        center.dy - 5,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF8DC9E9));
  }

  void _drawHeartEye(Canvas canvas, Offset center) {
    final path = Path()
      ..moveTo(center.dx, center.dy + 5)
      ..cubicTo(
        center.dx - 2,
        center.dy + 3,
        center.dx - 7,
        center.dy,
        center.dx - 6,
        center.dy - 4,
      )
      ..cubicTo(
        center.dx - 5,
        center.dy - 8,
        center.dx - 1,
        center.dy - 7,
        center.dx,
        center.dy - 4,
      )
      ..cubicTo(
        center.dx + 2,
        center.dy - 8,
        center.dx + 6,
        center.dy - 7,
        center.dx + 6,
        center.dy - 3,
      )
      ..cubicTo(
        center.dx + 6,
        center.dy,
        center.dx + 2,
        center.dy + 3,
        center.dx,
        center.dy + 5,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE86C94));
  }

  Paint _inkFill() => Paint()..color = const Color(0xFF59434A);

  Paint _inkStroke() => Paint()
    ..color = const Color(0xFF59434A)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  @override
  bool shouldRepaint(covariant _MoodFacePainter oldDelegate) =>
      oldDelegate.mood != mood;
}
