import 'garden_flower.dart';

class GardenProgressData {
  const GardenProgressData({
    this.dailyCompletions = const {},
    this.flowerUnlockDates = const {},
    this.flowerCatalog = const [],
    this.activeFlowerId,
    this.growthPoints = 0,
    this.lifetimeGrowthPoints = 0,
  });

  final Map<String, List<String>> dailyCompletions;
  final Map<String, String?> flowerUnlockDates;
  final List<GardenFlower> flowerCatalog;
  final String? activeFlowerId;
  final int growthPoints;
  final int lifetimeGrowthPoints;
}
