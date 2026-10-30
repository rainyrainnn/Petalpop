import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_challenge.dart';
import '../models/garden_flower.dart';
import '../models/garden_progress.dart';
import '../models/app_notification.dart';
import '../models/memory_entry.dart';
import '../models/mood_entry.dart';

class SupabaseDataService {
  SupabaseDataService(this.client);

  static const privateBucket = 'petalpop-private';
  final SupabaseClient client;

  String get userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in is required.');
    return id;
  }

  Future<Map<String, dynamic>> loadProfile() async {
    final row = await client
        .from('profiles')
        .select('display_name, avatar_id, theme, time_zone')
        .eq('id', userId)
        .single();
    return row;
  }

  Future<void> saveProfile({
    required String displayName,
    required String avatarId,
    required String theme,
    required String timeZone,
  }) async {
    await client
        .from('profiles')
        .update({
          'display_name': displayName,
          'avatar_id': avatarId,
          'theme': theme,
          'time_zone': timeZone,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<DailyContent> loadDailyContent() async {
    final rows = await client.rpc('get_daily_content') as List<dynamic>;
    if (rows.length != 10) {
      throw StateError(
        'The backend returned ${rows.length} challenges; expected exactly 10.',
      );
    }
    final mapRows = rows.cast<Map<String, dynamic>>();
    final challenges = mapRows
        .map(
          (row) => DailyChallenge(
            id: row['challenge_id'] as String,
            title: row['title'] as String,
            description: row['description'] as String,
            emoji: row['emoji'] as String,
          ),
        )
        .toList(growable: false);
    if (challenges.map((challenge) => challenge.id).toSet().length !=
        challenges.length) {
      throw StateError('Daily content contains duplicate challenge IDs.');
    }
    final dates = mapRows.map((row) => row['local_date'] as String).toSet();
    final quotes = mapRows.map((row) => row['quote'] as String).toSet();
    if (dates.length != 1 || quotes.length != 1) {
      throw StateError('Daily content returned inconsistent dates or quotes.');
    }
    return DailyContent(
      date: dates.single,
      challenges: challenges,
      quote: quotes.single,
    );
  }

  Future<bool> completeChallenge(String localDate, String challengeId) async {
    final result =
        await client.rpc(
              'complete_daily_challenge',
              params: {
                'p_local_date': localDate,
                'p_challenge_id': challengeId,
              },
            )
            as List<dynamic>;
    if (result.length != 1 || result.single is! Map<String, dynamic>) {
      throw StateError('Challenge completion returned an invalid response.');
    }
    return (result.single as Map<String, dynamic>)['newly_completed'] as bool;
  }

  Future<bool> undoChallenge(String localDate, String challengeId) async {
    try {
      final result =
          await client.rpc(
                'undo_daily_challenge',
                params: {
                  'p_local_date': localDate,
                  'p_challenge_id': challengeId,
                },
              )
              as List<dynamic>;
      if (result.length != 1 || result.single is! Map<String, dynamic>) {
        _logUndoDiagnostic(
          'RPC response shape invalid: rowCount=${result.length}.',
        );
        throw StateError('Challenge undo returned an invalid response.');
      }
      final wasUndone =
          (result.single as Map<String, dynamic>)['was_undone'] as bool;
      _logUndoDiagnostic(
        'RPC success: date=$localDate challenge=$challengeId '
        'wasUndone=$wasUndone.',
      );
      return wasUndone;
    } catch (error) {
      _logUndoDiagnostic(
        'RPC error: date=$localDate challenge=$challengeId '
        'type=${error.runtimeType} error=${_redactDiagnostic(error.toString())}',
      );
      rethrow;
    }
  }

  Future<List<String>> loadDailyChallengeCompletions(String localDate) async {
    final id = userId;
    try {
      final rows = await client
          .from('challenge_completions')
          .select('local_date, challenge_id')
          .eq('user_id', id)
          .eq('local_date', localDate);
      final challengeIds = rows
          .where((row) => row['local_date'] == localDate)
          .map((row) => row['challenge_id'] as String)
          .toList(growable: false);
      _logUndoDiagnostic(
        'Completion query: authenticatedUserFilter=present '
        'date=$localDate records=$challengeIds count=${challengeIds.length}.',
      );
      return challengeIds;
    } catch (error) {
      _logUndoDiagnostic(
        'Completion query error: date=$localDate type=${error.runtimeType} '
        'error=${_redactDiagnostic(error.toString())}',
      );
      rethrow;
    }
  }

  void _logUndoDiagnostic(String message) {
    if (kDebugMode) debugPrint('[PetalPop undo] $message');
  }

  String _redactDiagnostic(String message) => message
      .replaceAll(
        RegExp(r'Bearer\s+\S+', caseSensitive: false),
        'Bearer [REDACTED]',
      )
      .replaceAllMapped(
        RegExp(r'sb_(publishable|secret)_[A-Za-z0-9_-]+'),
        (match) => 'sb_${match[1]}_[REDACTED]',
      )
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[REDACTED_JWT]',
      )
      .replaceAllMapped(
        RegExp(
          r'(password|access_token|refresh_token)\s*[:=]\s*\S+',
          caseSensitive: false,
        ),
        (match) => '${match[1]}=[REDACTED]',
      );

  Future<GardenProgressData> loadGardenProgress() async {
    final completionRows = await _loadChallengeCompletionRows();
    final flowerRows = await client
        .from('flower_catalog')
        .select('id, sort_order, display_name, emoji')
        .order('sort_order');
    if (flowerRows.length != 20) {
      throw StateError(
        'The backend returned ${flowerRows.length} flowers; expected exactly 20.',
      );
    }
    if (flowerRows.map((row) => row['id']).toSet().length !=
        flowerRows.length) {
      throw StateError('The flower catalog contains duplicate IDs.');
    }
    final state = await client
        .from('garden_state')
        .select('active_flower_id, growth_points, lifetime_growth_points')
        .eq('user_id', userId)
        .single();
    final unlockRows = await client
        .from('flower_unlocks')
        .select('flower_id, unlocked_at')
        .eq('user_id', userId);
    final dailyCompletions = <String, List<String>>{};
    for (final row in completionRows) {
      final completion = row;
      dailyCompletions
          .putIfAbsent(completion['local_date'] as String, () => [])
          .add(completion['challenge_id'] as String);
    }
    final unlocked = <String, String?>{};
    for (final row in unlockRows) {
      final unlock = row;
      final timestamp = DateTime.parse(unlock['unlocked_at'] as String);
      unlocked[unlock['flower_id'] as String] = timestamp
          .toLocal()
          .toIso8601String()
          .split('T')
          .first;
    }
    return GardenProgressData(
      dailyCompletions: dailyCompletions,
      flowerUnlockDates: unlocked,
      flowerCatalog: [
        for (final row in flowerRows)
          GardenFlower(
            id: row['id'] as String,
            name: row['display_name'] as String,
            emoji: row['emoji'] as String,
            color:
                _flowerColors[((row['sort_order'] as int) - 1) %
                    _flowerColors.length],
            sortOrder: row['sort_order'] as int,
          ),
      ],
      activeFlowerId: state['active_flower_id'] as String?,
      growthPoints: state['growth_points'] as int,
      lifetimeGrowthPoints: state['lifetime_growth_points'] as int,
    );
  }

  static const _flowerColors = <Color>[
    Color(0xFFFFE1EC),
    Color(0xFFFFF2C7),
    Color(0xFFFFE3E8),
    Color(0xFFFFDCE5),
    Color(0xFFEDE3FF),
    Color(0xFFFFE8CC),
    Color(0xFFFFEAF2),
    Color(0xFFFFE0F0),
    Color(0xFFFFF0B8),
    Color(0xFFFFDCE1),
    Color(0xFFDDF3E9),
    Color(0xFFFFE5EF),
    Color(0xFFECE2FF),
    Color(0xFFFFE1D6),
    Color(0xFFFFF1C2),
    Color(0xFFFFDDE7),
    Color(0xFFE9E0FF),
    Color(0xFFFFF4D0),
    Color(0xFFFFDFE5),
    Color(0xFFEDE7FF),
  ];

  Future<List<Map<String, dynamic>>> _loadChallengeCompletionRows() async {
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    final id = userId;
    for (var offset = 0; ; offset += pageSize) {
      final page = await client
          .from('challenge_completions')
          .select('local_date, challenge_id')
          .eq('user_id', id)
          .order('local_date')
          .order('challenge_id')
          .range(offset, offset + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
    }
  }

  Future<List<MoodEntry>> loadMoods() async {
    final rows = await client
        .from('mood_entries')
        .select('mood, emoji, note, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => MoodEntry(
            mood: row['mood'] as String,
            emoji: row['emoji'] as String,
            note: row['note'] as String,
            createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          ),
        )
        .toList();
  }

  Future<List<AppNotification>> loadNotifications() async {
    final rows = await client
        .from('app_notifications')
        .select(
          'id, kind, source_key, title, body, created_at, read_at, retracted_at',
        )
        .eq('user_id', userId)
        .isFilter('retracted_at', null)
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map(
          (row) => AppNotification(
            id: row['id'] as String,
            kind: row['kind'] as String,
            sourceKey: row['source_key'] as String,
            title: row['title'] as String,
            body: row['body'] as String,
            createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
            isRead: row['read_at'] != null,
            isRetracted: row['retracted_at'] != null,
          ),
        )
        .toList(growable: false);
  }

  Future<void> markNotificationRead(String id) async {
    await client
        .from('app_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> saveMood(MoodEntry entry) async {
    await client.from('mood_entries').insert({
      'user_id': userId,
      'mood': entry.mood,
      'emoji': entry.emoji,
      'note': entry.note,
      'created_at': entry.createdAt.toUtc().toIso8601String(),
    });
  }

  Future<List<MemoryEntry>> loadMemories() async {
    final rows = await client
        .from('memories')
        .select(
          'id, type, title, description, created_at, storage_path, duration_seconds',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final memories = <MemoryEntry>[];
    for (final row in rows) {
      final path = row['storage_path'] as String?;
      final signedUrl = path == null
          ? null
          : await client.storage
                .from(privateBucket)
                .createSignedUrl(path, 15 * 60);
      memories.add(
        MemoryEntry(
          id: row['id'] as String,
          type: MemoryType.values.byName(row['type'] as String),
          title: row['title'] as String,
          description: row['description'] as String,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          storagePath: path,
          signedUrl: signedUrl,
          durationSeconds: row['duration_seconds'] as int? ?? 0,
        ),
      );
    }
    return memories;
  }

  Future<MemoryEntry> addMemory(MemoryEntry entry) async {
    final id = _uuidV4();
    final extension = entry.filePath == null
        ? (entry.type == MemoryType.photo ? 'jpg' : 'm4a')
        : entry.filePath!.split('.').last.toLowerCase();
    final path = entry.filePath == null ? null : '$userId/$id/$id.$extension';
    if (path != null) {
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        _ => entry.type == MemoryType.photo ? 'image/jpeg' : 'audio/mp4',
      };
      await client.storage
          .from(privateBucket)
          .upload(
            path,
            File(entry.filePath!),
            fileOptions: FileOptions(upsert: false, contentType: contentType),
          );
    }
    try {
      await client.from('memories').insert({
        'id': id,
        'user_id': userId,
        'type': entry.type.name,
        'title': entry.title,
        'description': entry.description,
        'created_at': entry.createdAt.toUtc().toIso8601String(),
        'storage_path': path,
        'duration_seconds': entry.type == MemoryType.voice
            ? entry.durationSeconds
            : null,
      });
    } catch (_) {
      if (path != null) {
        await client.storage.from(privateBucket).remove([path]);
      }
      rethrow;
    }
    final signedUrl = path == null
        ? null
        : await client.storage
              .from(privateBucket)
              .createSignedUrl(path, 15 * 60);
    return MemoryEntry(
      id: id,
      type: entry.type,
      title: entry.title,
      description: entry.description,
      createdAt: entry.createdAt,
      filePath: entry.filePath,
      storagePath: path,
      signedUrl: signedUrl,
      durationSeconds: entry.durationSeconds,
    );
  }

  Future<void> updateMemory(MemoryEntry entry) async {
    await client
        .from('memories')
        .update({'title': entry.title, 'description': entry.description})
        .eq('id', entry.id)
        .eq('user_id', userId);
  }

  Future<void> deleteMemory(MemoryEntry entry) async {
    await client
        .from('memories')
        .delete()
        .eq('id', entry.id)
        .eq('user_id', userId);
    final path = entry.storagePath;
    if (path != null) {
      await client.storage.from(privateBucket).remove([path]);
    }
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

class DailyContent {
  const DailyContent({
    required this.date,
    required this.challenges,
    required this.quote,
  });

  final String date;
  final List<DailyChallenge> challenges;
  final String quote;
}
