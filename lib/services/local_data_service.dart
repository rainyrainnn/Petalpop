import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_entry.dart';
import '../models/mood_entry.dart';
import '../models/garden_progress.dart';

class LocalDataService {
  LocalDataService({this._preferences});

  SharedPreferencesAsync? _preferences;
  Future<Directory>? _mediaDirectory;

  SharedPreferencesAsync get preferences =>
      _preferences ??= SharedPreferencesAsync();

  Future<Map<String, String>> loadProfile() async => {
    'name': await preferences.getString('profile.name') ?? 'Sunshine',
    'avatar': await preferences.getString('profile.avatar') ?? 'girl',
    'theme': await preferences.getString('profile.theme') ?? 'light',
  };

  Future<void> saveProfile({
    required String name,
    required String avatar,
    required String theme,
  }) async {
    await preferences.setString('profile.name', name);
    await preferences.setString('profile.avatar', avatar);
    await preferences.setString('profile.theme', theme);
  }

  Future<List<String>> loadCompletedChallenges() async =>
      await preferences.getStringList('garden.completed') ?? [];

  Future<void> saveCompletedChallenges(List<String> ids) =>
      preferences.setStringList('garden.completed', ids);

  Future<GardenProgressData> loadGardenProgress() async {
    final data = await preferences.getString('garden.daily_progress');
    if (data == null) return const GardenProgressData();
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        return const GardenProgressData();
      }
      final completions = <String, String>{};
      final dailyCompletions = <String, List<String>>{};
      final rawCompletions = decoded['completions'];
      if (rawCompletions is Map) {
        for (final entry in rawCompletions.entries) {
          if (entry.key is! String) continue;
          if (entry.value is String) {
            completions[entry.key as String] = entry.value as String;
          } else if (entry.value is List) {
            dailyCompletions[entry.key as String] = entry.value
                .whereType<String>()
                .toList();
          }
        }
      }
      final flowers = <String, String?>{};
      final rawFlowers = decoded['flowers'];
      if (rawFlowers is Map) {
        for (final entry in rawFlowers.entries) {
          if (entry.key is String &&
              (entry.value == null || entry.value is String)) {
            flowers[entry.key as String] = entry.value as String?;
          }
        }
      }
      final activeFlowerId = decoded['activeFlowerId'];
      final growthPoints = decoded['growthPoints'];
      final lifetimeGrowthPoints = decoded['lifetimeGrowthPoints'];
      return GardenProgressData(
        dailyCompletions: {
          ...dailyCompletions,
          for (final entry in completions.entries) entry.key: [entry.value],
        },
        flowerUnlockDates: flowers,
        activeFlowerId: activeFlowerId is String ? activeFlowerId : null,
        growthPoints: growthPoints is int ? growthPoints : 0,
        lifetimeGrowthPoints: lifetimeGrowthPoints is int
            ? lifetimeGrowthPoints
            : 0,
      );
    } on FormatException {
      return const GardenProgressData();
    } on TypeError {
      return const GardenProgressData();
    }
  }

  Future<void> saveGardenProgress(GardenProgressData progress) =>
      preferences.setString(
        'garden.daily_progress',
        jsonEncode({
          'completions': progress.dailyCompletions,
          'flowers': progress.flowerUnlockDates,
          'activeFlowerId': progress.activeFlowerId,
          'growthPoints': progress.growthPoints,
          'lifetimeGrowthPoints': progress.lifetimeGrowthPoints,
        }),
      );

  Future<List<MoodEntry>> loadMoods() async {
    final data = await preferences.getString('moods');
    if (data == null) return [];
    return (jsonDecode(data) as List<dynamic>)
        .map((entry) => _moodFromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMoods(List<MoodEntry> entries) => preferences.setString(
    'moods',
    jsonEncode(
      entries
          .map(
            (entry) => {
              'mood': entry.mood,
              'emoji': entry.emoji,
              'note': entry.note,
              'createdAt': entry.createdAt.toIso8601String(),
            },
          )
          .toList(),
    ),
  );

  Future<List<MemoryEntry>> loadMemories() async {
    final data = await preferences.getString('memories');
    if (data == null) return [];
    return (jsonDecode(data) as List<dynamic>)
        .map((entry) => MemoryEntry.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMemories(List<MemoryEntry> entries) => preferences.setString(
    'memories',
    jsonEncode(entries.map((entry) => entry.toJson()).toList()),
  );

  Future<MemoryEntry> copyMediaIntoApp({
    required String sourcePath,
    required MemoryType type,
    required String extension,
  }) async {
    final directory = await _getMediaDirectory(type);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final normalizedExtension = extension.startsWith('.')
        ? extension
        : '.$extension';
    final file = await File(
      sourcePath,
    ).copy('${directory.path}${Platform.pathSeparator}$id$normalizedExtension');
    final now = DateTime.now();
    return MemoryEntry(
      id: id,
      type: type,
      title: type == MemoryType.photo
          ? 'A little photo memory'
          : 'Voice memory',
      description: '',
      createdAt: now,
      filePath: file.path,
    );
  }

  Future<String> createMediaPath({
    required MemoryType type,
    required String extension,
  }) async {
    final directory = await _getMediaDirectory(type);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final normalizedExtension = extension.startsWith('.')
        ? extension
        : '.$extension';
    return '${directory.path}${Platform.pathSeparator}$id$normalizedExtension';
  }

  Future<void> deleteMediaFile(MemoryEntry entry) async {
    final path = entry.filePath;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<Directory> _getMediaDirectory(MemoryType type) async {
    final root = await (_mediaDirectory ??= getApplicationDocumentsDirectory()
        .then((directory) async {
          final media = Directory(
            '${directory.path}${Platform.pathSeparator}petalpop_memories',
          );
          await media.create(recursive: true);
          return media;
        }));
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}${type.name}',
    );
    await directory.create(recursive: true);
    return directory;
  }

  MoodEntry _moodFromJson(Map<String, dynamic> json) => MoodEntry(
    mood: json['mood'] as String,
    emoji: json['emoji'] as String,
    note: json['note'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
