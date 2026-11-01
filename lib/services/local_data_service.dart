import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart' show Color;
import '../models/daily_challenge.dart';
import '../models/garden_flower.dart';
import '../models/memory_entry.dart';
import '../models/mood_entry.dart';
import '../models/garden_progress.dart';
import 'supabase_data_service.dart';

enum ChallengeOperationType { complete, undo }

class PendingSyncOperation {
  const PendingSyncOperation({
    required this.id,
    required this.userId,
    required this.entity,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String entity;
  final String operation;
  final Map<String, dynamic> payload;
  final String createdAt;
}

class PendingChallengeOperation {
  const PendingChallengeOperation({
    required this.id,
    required this.userId,
    required this.type,
    required this.localDate,
    required this.challengeId,
  });

  final int id;
  final String userId;
  final ChallengeOperationType type;
  final String localDate;
  final String challengeId;
}

class LocalDataService {
  LocalDataService({
    this._preferences,
    this._databaseFactory,
    this._databasePath,
  });

  SharedPreferencesAsync? _preferences;
  final DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  Database? _dailyContentDatabase;
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

  Future<DailyContent?> loadDailyContentCache() async {
    final database = await _getDailyContentDatabase();
    final rows = await database.query(
      'daily_content_cache',
      columns: ['content_json'],
      orderBy: 'local_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final data = rows.single['content_json'] as String;
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic> ||
        decoded['date'] is! String ||
        decoded['quote'] is! String ||
        decoded['challenges'] is! List) {
      throw const FormatException('Cached daily content is invalid.');
    }
    return DailyContent(
      date: decoded['date'] as String,
      quote: decoded['quote'] as String,
      challenges: (decoded['challenges'] as List)
          .map((challenge) {
            if (challenge is! Map<String, dynamic> ||
                challenge['id'] is! String ||
                challenge['title'] is! String ||
                challenge['description'] is! String ||
                challenge['emoji'] is! String) {
              throw const FormatException('Cached daily challenge is invalid.');
            }
            return DailyChallenge(
              id: challenge['id'] as String,
              title: challenge['title'] as String,
              description: challenge['description'] as String,
              emoji: challenge['emoji'] as String,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> saveDailyContentCache(DailyContent content) async {
    final database = await _getDailyContentDatabase();
    await database.insert('daily_content_cache', {
      'local_date': content.date,
      'content_json': jsonEncode({
        'date': content.date,
        'quote': content.quote,
        'challenges': [
          for (final challenge in content.challenges)
            {
              'id': challenge.id,
              'title': challenge.title,
              'description': challenge.description,
              'emoji': challenge.emoji,
            },
        ],
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> enqueueChallengeOperation({
    required String userId,
    required ChallengeOperationType type,
    required String localDate,
    required String challengeId,
  }) async {
    final database = await _getDailyContentDatabase();
    return database.insert('pending_challenge_operations', {
      'user_id': userId,
      'operation': type.name,
      'local_date': localDate,
      'challenge_id': challengeId,
    });
  }

  Future<List<PendingChallengeOperation>> loadPendingChallengeOperations(
    String userId,
  ) async {
    final database = await _getDailyContentDatabase();
    final rows = await database.query(
      'pending_challenge_operations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id',
    );
    return rows
        .map((row) {
          final operation = row['operation'] as String;
          return PendingChallengeOperation(
            id: row['id'] as int,
            userId: row['user_id'] as String,
            type: ChallengeOperationType.values.byName(operation),
            localDate: row['local_date'] as String,
            challengeId: row['challenge_id'] as String,
          );
        })
        .toList(growable: false);
  }

  Future<void> enqueuePendingSyncOperation(
    PendingSyncOperation operation,
  ) async {
    final db = await _getDailyContentDatabase();

    await db.insert('pending_sync_operations', {
      'id': operation.id,
      'user_id': operation.userId,
      'entity': operation.entity,
      'operation': operation.operation,
      'payload_json': jsonEncode(operation.payload),
      'created_at': operation.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PendingSyncOperation>> loadPendingSyncOperations(
    String userId,
  ) async {
    final db = await _getDailyContentDatabase();

    final rows = await db.query(
      'pending_sync_operations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );

    return rows.map((row) {
      return PendingSyncOperation(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        entity: row['entity'] as String,
        operation: row['operation'] as String,
        payload:
            jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
        createdAt: row['created_at'] as String,
      );
    }).toList();
  }

  Future<void> deletePendingSyncOperation(String id) async {
    final db = await _getDailyContentDatabase();

    await db.delete(
      'pending_sync_operations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removePendingChallengeOperation(int id) async {
    final database = await _getDailyContentDatabase();
    await database.delete(
      'pending_challenge_operations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Database> _getDailyContentDatabase() async {
    final existing = _dailyContentDatabase;
    if (existing != null) return existing;

    final factory = _databaseFactory ?? databaseFactory;
    final databasePath =
        _databasePath ??
        path.join(await factory.getDatabasesPath(), 'petalpop_offline.db');

    final database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await _createDailyContentCacheTable(db);
          await _createPendingChallengeOperationsTable(db);
          await _createPendingSyncOperationsTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await _createDailyContentCacheTable(db);
          }

          if (oldVersion < 2) {
            await _createPendingChallengeOperationsTable(db);
          }

          if (oldVersion < 3) {
            await _createPendingSyncOperationsTable(db);
          }
        },
      ),
    );

    _dailyContentDatabase = database;
    return database;
  }

  Future<void> _createDailyContentCacheTable(DatabaseExecutor db) => db.execute(
    'CREATE TABLE IF NOT EXISTS daily_content_cache ('
    'local_date TEXT PRIMARY KEY, content_json TEXT NOT NULL)',
  );

  Future<void> _createPendingChallengeOperationsTable(
    DatabaseExecutor db,
  ) => db.execute(
    'CREATE TABLE IF NOT EXISTS pending_challenge_operations ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'user_id TEXT NOT NULL, '
    'operation TEXT NOT NULL CHECK (operation IN (\'complete\', \'undo\')), '
    'local_date TEXT NOT NULL, '
    'challenge_id TEXT NOT NULL)',
  );

  Future<void> _createPendingSyncOperationsTable(
    DatabaseExecutor db,
  ) => db.execute(
    'CREATE TABLE IF NOT EXISTS pending_sync_operations ('
    'id TEXT PRIMARY KEY, '
    'user_id TEXT NOT NULL, '
    'entity TEXT NOT NULL CHECK (entity IN (\'mood\', \'memory\')), '
    'operation TEXT NOT NULL CHECK (operation IN (\'create\', \'update\', \'delete\')), '
    'payload_json TEXT NOT NULL, '
    'created_at TEXT NOT NULL)',
  );

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
      final rawCatalog = decoded['flowerCatalog'];
      final flowerCatalog = rawCatalog is List
          ? rawCatalog
                .map((flower) {
                  if (flower is! Map<String, dynamic> ||
                      flower['id'] is! String ||
                      flower['name'] is! String ||
                      flower['emoji'] is! String ||
                      flower['color'] is! int ||
                      flower['sortOrder'] is! int) {
                    throw const FormatException(
                      'Cached flower catalog is invalid.',
                    );
                  }
                  return GardenFlower(
                    id: flower['id'] as String,
                    name: flower['name'] as String,
                    emoji: flower['emoji'] as String,
                    color: Color(flower['color'] as int),
                    sortOrder: flower['sortOrder'] as int,
                  );
                })
                .toList(growable: false)
          : const <GardenFlower>[];
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
        flowerCatalog: flowerCatalog,
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
          'flowerCatalog': [
            for (final flower in progress.flowerCatalog)
              {
                'id': flower.id,
                'name': flower.name,
                'emoji': flower.emoji,
                'color': flower.color.toARGB32(),
                'sortOrder': flower.sortOrder,
              },
          ],
          'activeFlowerId': progress.activeFlowerId,
          'growthPoints': progress.growthPoints,
          'lifetimeGrowthPoints': progress.lifetimeGrowthPoints,
        }),
      );

  Future<List<MoodEntry>> loadMoods() async {
    final data = await preferences.getString('moods');
    if (data == null) return [];

    final entries = (jsonDecode(data) as List<dynamic>)
        .map((entry) => _moodFromJson(entry as Map<String, dynamic>))
        .toList();

    // Save migrated entries so their IDs remain stable.
    await saveMoods(entries);

    return entries;
  }

  Future<void> saveMoods(List<MoodEntry> entries) => preferences.setString(
    'moods',
    jsonEncode(entries.map((entry) => entry.toJson()).toList()),
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

    final memoryId = const Uuid().v4();
    final fileId =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';

    final normalizedExtension = extension.startsWith('.')
        ? extension
        : '.$extension';

    final file = await File(sourcePath).copy(
      '${directory.path}${Platform.pathSeparator}$fileId$normalizedExtension',
    );

    return MemoryEntry(
      id: memoryId,
      type: type,
      title: type == MemoryType.photo
          ? 'A little photo memory'
          : 'Voice memory',
      description: '',
      createdAt: DateTime.now(),
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
    id: json['id'] as String? ?? const Uuid().v4(),
    mood: json['mood'] as String,
    emoji: json['emoji'] as String,
    note: json['note'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
