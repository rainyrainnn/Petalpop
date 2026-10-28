import 'package:flutter/material.dart';

class GardenFlower {
  const GardenFlower({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String emoji;
  final Color color;
  final int sortOrder;
}
