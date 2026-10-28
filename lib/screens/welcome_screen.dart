import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/flower_illustration.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    this.onGetStarted,
    this.onLogIn,
    this.onSignUp,
  });

  final VoidCallback? onGetStarted;
  final VoidCallback? onLogIn;
  final VoidCallback? onSignUp;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowerController;
  late final Animation<double> _flowerBob;

  @override
  void initState() {
    super.initState();
    _flowerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _flowerBob = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _flowerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flowerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _PetalBackdrop())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = math.min(constraints.maxWidth, 480.0);
                final flowerExtent = math.min(
                  contentWidth * .82,
                  math.min(320.0, math.max(150.0, constraints.maxHeight * .39)),
                );
                final isShortScreen = constraints.maxHeight < 620;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const _PetalPopWordmark(),
                              SizedBox(height: isShortScreen ? 4 : 14),
                              AnimatedBuilder(
                                animation: _flowerBob,
                                builder: (context, child) =>
                                    Transform.translate(
                                      offset: Offset(0, _flowerBob.value),
                                      child: child,
                                    ),
                                child: SizedBox(
                                  width: flowerExtent,
                                  height: flowerExtent,
                                  child: Semantics(
                                    label: 'A smiling pink flower',
                                    child: ExcludeSemantics(
                                      child: FlowerIllustration(),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: isShortScreen ? 2 : 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed:
                                      widget.onGetStarted ??
                                      () => _showMessage(
                                        'Your happy space is getting ready.',
                                      ),
                                  child: const Text('Get Started'),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(
                                    'Already have an account?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontSize: 13),
                                  ),
                                  TextButton(
                                    onPressed:
                                        widget.onLogIn ??
                                        () => _showMessage(
                                          'Log in will be available in a '
                                          'later PetalPop milestone.',
                                        ),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Log In',
                                      style: TextStyle(
                                        color: PetalPopColors.deepPink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    '·',
                                    style: TextStyle(
                                      color: PetalPopColors.mutedInk,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        widget.onSignUp ??
                                        () => _showMessage(
                                          'Sign up will be available in a '
                                          'later PetalPop milestone.',
                                        ),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: PetalPopColors.deepPink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.local_florist, color: PetalPopColors.hotPink),
        title: const Text('Coming up in PetalPop'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _PetalPopWordmark extends StatelessWidget {
  const _PetalPopWordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_florist_rounded,
          color: PetalPopColors.petalPink,
          size: 42,
        ),
        Text(
          'PetalPop',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 46, height: 1),
        ),
        const SizedBox(height: 7),
        Text(
          'Your Daily Happy Space',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: PetalPopColors.deepPink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }
}

class _PetalBackdrop extends CustomPainter {
  const _PetalBackdrop();

  static const _petals = <(double, double, double, double)>[
    (.08, .16, 13, -.7),
    (.91, .12, 10, .4),
    (.04, .48, 9, .5),
    (.96, .55, 14, -.6),
    (.13, .82, 11, .3),
    (.88, .89, 12, -.2),
    (.23, .31, 6, -.4),
    (.79, .37, 7, .8),
    (.72, .73, 7, .2),
    (.05, .92, 8, -.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final blushPaint = Paint()
      ..color = const Color(0xFFFFD7E6).withValues(alpha: .44);
    canvas.drawCircle(
      Offset(size.width * .02, size.height * .03),
      95,
      blushPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .98, size.height * .95),
      115,
      blushPaint,
    );

    for (final (x, y, radius, angle) in _petals) {
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * .75,
          height: radius * 1.5,
        ),
        Paint()..color = const Color(0xFFF58AB1).withValues(alpha: .28),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
