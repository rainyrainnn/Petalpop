import 'package:flutter/material.dart';

import 'flower_artwork.dart';

class FlowerIllustration extends StatelessWidget {
  const FlowerIllustration({
    super.key,
    this.petalCount = 8,
    this.color = const Color(0xFFFFB1CB),
    this.growthPoints = 10,
    this.variety = 1,
    this.locked = false,
    this.showPot = true,
  });

  final int petalCount;
  final Color color;
  final int growthPoints;
  final int variety;
  final bool locked;
  final bool showPot;

  @override
  Widget build(BuildContext context) => FlowerArtwork(
    color: color,
    growthPoints: growthPoints,
    variety: variety,
    petalCount: petalCount,
    locked: locked,
    showPot: showPot,
  );
}
