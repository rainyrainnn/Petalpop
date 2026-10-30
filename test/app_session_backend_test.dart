import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:petalpop/models/daily_challenge.dart';
import 'package:petalpop/models/app_notification.dart';
import 'package:petalpop/models/garden_flower.dart';
import 'package:petalpop/models/garden_progress.dart';
import 'package:petalpop/models/memory_entry.dart';
import 'package:petalpop/models/mood_entry.dart';
import 'package:petalpop/screens/home_screen.dart';
import 'package:petalpop/services/app_session.dart';
import 'package:petalpop/services/local_data_service.dart';
import 'package:petalpop/services/supabase_data_service.dart';
import 'package:petalpop/screens/daily_challenges_screen.dart';
import 'package:petalpop/screens/notification_screen.dart';
import 'package:petalpop/theme/app_theme.dart';
import 'package:petalpop/widgets/challenge_illustration.dart';
import 'package:petalpop/widgets/profile_avatar.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late Directory _testDatabaseDirectory;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _testDatabaseDirectory = await Directory.systemTemp.createTemp(
      'petalpop-test-',
    );
    await databaseFactory.setDatabasesPath(_testDatabaseDirectory.path);
  });

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final database = await databaseFactory.openDatabase(
      path.join(_testDatabaseDirectory.path, 'petalpop_offline.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE daily_content_cache ('
            'local_date TEXT PRIMARY KEY, content_json TEXT NOT NULL)',
          );
        },
      ),
    );
    await database.delete('daily_content_cache');
    await database.close();
  });

  tearDownAll(() async {
    await databaseFactory.deleteDatabase(
      path.join(_testDatabaseDirectory.path, 'petalpop_offline.db'),
    );
    await _testDatabaseDirectory.delete(recursive: true);
  });

  test('avatar IDs and labels use the requested stable picker order', () {
    expect(
      PetalAvatarChoice.choices
          .map((avatar) => (avatar.id, avatar.label))
          .toList(),
      [
        ('girl', 'Daisy'),
        ('boy', 'Sunny'),
        ('curly', 'Clover'),
        ('bunny', 'Bunny'),
        ('cat', 'Kitty'),
        ('bear', 'Bear'),
        ('fox', 'Fox'),
        ('frog', 'Froggy'),
        ('owl', 'Pip'),
        ('deer', 'Fawn'),
        ('bee', 'Bumble'),
        ('unicorn', 'Lumi'),
      ],
    );
  });

  testWidgets('View Garden action invokes the existing navigation callback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ]);
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    await tester.runAsync(session.initialize);
    var gardenOpenCount = 0;
    var notificationOpenCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            session: session,
            onOpenMood: () {},
            onOpenMemories: () {},
            onOpenChallenges: () {},
            onOpenGarden: () => gardenOpenCount++,
            displayName: 'Sunshine',
            avatarId: 'girl',
            onOpenNotifications: () => notificationOpenCount++,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('home-view-garden')), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications'));
    expect(notificationOpenCount, 1);
    await tester.tap(find.byKey(const ValueKey('home-view-garden')));
    expect(gardenOpenCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'notifications load, mark read, and stay read after a new session',
    (tester) async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      backend.notifications.add(
        AppNotification(
          id: 'notice-1',
          kind: 'challenge_completed',
          sourceKey: 'challenge:2026-10-27:drink-water:notice-1',
          title: 'Challenge completed',
          body: 'A real completion event.',
          createdAt: DateTime(2026, 10, 27),
          isRead: false,
        ),
      );
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      await tester.runAsync(session.initialize);
      expect(session.unreadNotificationCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: session,
              builder: (context, _) =>
                  NotificationScreen(session: session, onBack: () {}),
            ),
          ),
        ),
      );
      expect(find.text('Challenge completed'), findsOneWidget);
      expect(find.text('Mark as read'), findsOneWidget);
      await tester.tap(find.text('Mark as read'));
      await tester.pumpAndSettle();
      expect(session.unreadNotificationCount, 0);
      expect(find.text('Mark as read'), findsNothing);
      session.dispose();
      await tester.pumpWidget(const SizedBox());

      final restartedSession = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      await tester.runAsync(restartedSession.initialize);
      expect(restartedSession.notifications.single.isRead, isTrue);
      restartedSession.dispose();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('notifications show an honest empty state', (tester) async {
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ]);
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    await tester.runAsync(session.initialize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationScreen(session: session, onBack: () {}),
        ),
      ),
    );

    expect(find.text('All quiet in the garden'), findsOneWidget);
    expect(find.text('Challenge completed'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  test(
    'signed-in session restores cached data when Supabase is offline',
    () async {
      final seedStorage = LocalDataService();
      final content = _dailyContent('2026-10-27', 'cached');
      final completed = _challengeId('cached', 1);
      await seedStorage.saveDailyContentCache(content);
      await seedStorage.saveGardenProgress(
        GardenProgressData(
          dailyCompletions: {
            '2026-10-27': [completed],
          },
          flowerUnlockDates: {'flower-01': null, 'flower-02': '2026-10-20'},
          flowerCatalog: AppSession.flowers,
          activeFlowerId: 'flower-02',
          growthPoints: 2,
          lifetimeGrowthPoints: 12,
        ),
      );
      await seedStorage.saveMoods([
        MoodEntry(
          mood: 'Calm',
          emoji: '🌿',
          note: 'Taking it slowly.',
          createdAt: DateTime(2026, 10, 27, 9),
        ),
      ]);
      await seedStorage.saveMemories([
        MemoryEntry(
          id: 'offline-note',
          type: MemoryType.note,
          title: 'A saved note',
          description: 'Still available offline.',
          createdAt: DateTime(2026, 10, 27, 10),
        ),
      ]);

      final offlineError = StateError('Supabase is unreachable.');
      final backend = _FakeSupabaseDataService([content])
        ..dailyContentError = offlineError;
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);

      await session.initialize();

      expect(session.isLoading, isFalse);
      expect(session.loadError, same(offlineError));
      expect(session.dailyChallenges.map((challenge) => challenge.id), [
        for (var index = 0; index < AppSession.dailyChallengeCount; index++)
          _challengeId('cached', index),
      ]);
      expect(session.completedToday, {completed});
      expect(session.growthPoints, 2);
      expect(session.lifetimeGrowthPoints, 12);
      expect(session.moodEntries, hasLength(1));
      expect(session.memories.single.title, 'A saved note');
    },
  );

  test(
    'offline cache without a saved flower catalog keeps garden progress',
    () async {
      final storage = LocalDataService();
      await storage.saveGardenProgress(
        GardenProgressData(
          flowerUnlockDates: {'flower-01': null, 'flower-02': '2026-10-20'},
          activeFlowerId: 'flower-02',
          growthPoints: 2,
          lifetimeGrowthPoints: 12,
        ),
      );
      final backend = _FakeSupabaseDataService([])
        ..dailyContentError = StateError('Supabase is unreachable.');
      final session = AppSession(
        storage,
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);

      await session.initialize();

      expect(session.flowerCatalog, AppSession.flowers);
      expect(session.activeFlowerId, 'flower-02');
      expect(session.growthPoints, 2);
      expect(session.lifetimeGrowthPoints, 12);
    },
  );

  test(
    'undoing one of three completions preserves others through reload',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      final selected = _challengeId('day', 0);
      final preserved = _challengeId('day', 1);
      final alsoPreserved = _challengeId('day', 2);
      await session.completeDailyChallenge(selected);
      await session.completeDailyChallenge(preserved);
      await session.completeDailyChallenge(alsoPreserved);
      expect(session.growthPoints, 3);

      expect(await session.undoDailyChallenge(selected), isTrue);
      expect(session.completedToday, contains(preserved));
      expect(session.completedToday, contains(alsoPreserved));
      expect(session.completedToday, isNot(contains(selected)));
      expect(session.growthPoints, 2);
      expect(session.lifetimeGrowthPoints, 2);
      expect(backend.progress.dailyCompletions['2026-10-27'], [
        preserved,
        alsoPreserved,
      ]);
      expect(backend.undoneChallenges, [('2026-10-27', selected)]);

      final reloadedSession = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(reloadedSession.dispose);
      await reloadedSession.initialize();
      expect(reloadedSession.completedToday, {preserved, alsoPreserved});
      expect(reloadedSession.growthPoints, 2);
      expect(reloadedSession.lifetimeGrowthPoints, 2);
    },
  );

  test(
    'garden refresh cannot restore undone completion or replace another date',
    () async {
      final previousDateChallenge = _challengeId('day', 2);
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      backend.setProgress(
        GardenProgressData(
          dailyCompletions: {
            '2026-10-26': [previousDateChallenge],
          },
          flowerUnlockDates: {'flower-01': null},
          flowerCatalog: AppSession.flowers,
          activeFlowerId: 'flower-01',
        ),
      );
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      final selected = _challengeId('day', 0);
      final preserved = _challengeId('day', 1);
      await session.completeDailyChallenge(selected);
      await session.completeDailyChallenge(preserved);
      expect(await session.undoDailyChallenge(selected), isTrue);

      backend.gardenCompletionOverride = {
        '2026-10-27': [selected, preserved],
        '2026-10-26': [previousDateChallenge],
      };
      await session.refreshDailyChallenges();

      expect(session.completedToday, {preserved});
      expect(session.completedChallengeCount, 2);
      expect(session.lifetimeGrowthPoints, 1);

      backend.setDailyContent(_dailyContent('2026-10-26', 'day'));
      await session.refreshDailyChallenges();
      expect(session.completedToday, {previousDateChallenge});
    },
  );

  test(
    'undo refreshes authoritative completion rows before calling the RPC',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final selected = _challengeId('day', 0);
      final preserved = _challengeId('day', 1);
      final alsoPreserved = _challengeId('day', 2);
      backend.setProgress(
        GardenProgressData(
          dailyCompletions: {
            '2026-10-27': [selected, preserved, alsoPreserved],
          },
          flowerUnlockDates: {'flower-01': null},
          flowerCatalog: AppSession.flowers,
          activeFlowerId: 'flower-01',
          growthPoints: 3,
          lifetimeGrowthPoints: 3,
        ),
      );
      backend.gardenCompletionOverride = {
        '2026-10-27': [selected],
      };
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();
      expect(session.completedToday, {selected});

      expect(await session.undoDailyChallenge(selected), isTrue);
      expect(backend.undoneChallenges, [('2026-10-27', selected)]);
      expect(session.completedToday, {preserved, alsoPreserved});
      expect(session.growthPoints, 2);
      expect(session.lifetimeGrowthPoints, 2);

      backend.gardenCompletionOverride = null;
      final reloadedSession = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(reloadedSession.dispose);
      await reloadedSession.initialize();
      expect(reloadedSession.completedToday, {preserved, alsoPreserved});
      expect(reloadedSession.growthPoints, 2);
    },
  );

  test(
    'undo refresh preserves other dates and previously unlocked flowers',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final previousDayChallenge = _challengeId('day', 2);
      backend.setProgress(
        GardenProgressData(
          dailyCompletions: {
            '2026-10-26': [previousDayChallenge],
          },
          flowerUnlockDates: {'flower-01': null, 'flower-02': '2026-10-20'},
          flowerCatalog: AppSession.flowers,
          activeFlowerId: 'flower-02',
          growthPoints: 2,
          lifetimeGrowthPoints: 12,
        ),
      );
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      final selected = _challengeId('day', 0);
      final preserved = _challengeId('day', 1);
      await session.completeDailyChallenge(selected);
      await session.completeDailyChallenge(preserved);
      backend.omitGardenCompletionDates.add('2026-10-26');

      expect(await session.undoDailyChallenge(selected), isTrue);
      expect(session.completedToday, contains(preserved));
      expect(session.completedToday, isNot(contains(selected)));
      expect(session.completedChallengeCount, 2);
      expect(session.lifetimeGrowthPoints, 13);
      expect(session.growthPoints, 3);
      expect(session.unlockedFlowerCount, 2);
      expect(session.flowerUnlockDates['flower-02'], '2026-10-20');
    },
  );

  test(
    'failed undo refreshes state and keeps the selected task unchanged',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();
      final selected = _challengeId('day', 0);
      await session.completeDailyChallenge(selected);

      backend.undoError = StateError('The undo RPC is unavailable.');
      await expectLater(
        session.undoDailyChallenge(selected),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('undo RPC is unavailable'),
          ),
        ),
      );

      expect(session.completedToday, contains(selected));
      expect(session.growthPoints, 1);
      expect(session.lifetimeGrowthPoints, 1);
    },
  );

  test(
    'undo retracts its notice and same-day re-completion creates a fresh unread notice',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();
      final challengeId = _challengeId('day', 0);

      expect(await session.completeDailyChallenge(challengeId), isTrue);
      expect(session.notifications, hasLength(1));
      final originalNotificationId = session.notifications.single.id;
      await session.markNotificationRead(originalNotificationId);
      expect(session.unreadNotificationCount, 0);

      expect(await session.undoDailyChallenge(challengeId), isTrue);
      expect(session.notifications, isEmpty);
      expect(session.unreadNotificationCount, 0);
      expect(backend.notifications.single.isRetracted, isTrue);
      expect(backend.notifications.single.isRead, isTrue);

      expect(await session.completeDailyChallenge(challengeId), isTrue);
      expect(session.notifications, hasLength(1));
      expect(session.notifications.single.id, isNot(originalNotificationId));
      expect(session.notifications.single.isRead, isFalse);
      expect(session.unreadNotificationCount, 1);
      expect(backend.notifications, hasLength(2));
    },
  );

  testWidgets(
    'self-kindness, happy-thought, and favorite-song art are distinct',
    (tester) async {
      final challenges = [
        const DailyChallenge(
          id: 'be-kind-to-yourself',
          title: 'Be Kind to Yourself',
          description: 'Offer yourself a little kindness.',
          emoji: '',
        ),
        const DailyChallenge(
          id: 'write-happy-thought',
          title: 'Write a Happy Thought',
          description: 'Write down something cheerful.',
          emoji: '',
        ),
        const DailyChallenge(
          id: 'enjoy-favorite-song',
          title: 'Enjoy Your Favorite Song',
          description: 'Listen to music you love.',
          emoji: '',
        ),
        AppSession.challenges[2],
        const DailyChallenge(
          id: 'water-a',
          title: 'Drink a glass of water',
          description: 'Take a refreshing sip.',
          emoji: '',
        ),
        const DailyChallenge(
          id: 'water-b',
          title: 'Drink a glass of water',
          description: 'Enjoy a cool drink.',
          emoji: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final challenge in challenges)
                  ChallengeIllustration(challenge: challenge),
              ],
            ),
          ),
        ),
      );

      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((paint) => paint.painter != null)
          .map((paint) => paint.painter!)
          .toList();
      expect(painters, hasLength(challenges.length));
      for (var first = 0; first < 3; first++) {
        for (var second = first + 1; second < 3; second++) {
          expect(painters[first].shouldRepaint(painters[second]), isTrue);
        }
      }
      expect(painters[1].shouldRepaint(painters[3]), isTrue);
      expect(painters[4].shouldRepaint(painters[5]), isFalse);
    },
  );

  testWidgets('Home uses bundled challenges when backend daily content fails', (
    tester,
  ) async {
    final loadFailure = StateError('daily content is unavailable');
    final backend = _FakeSupabaseDataService([])
      ..dailyContentError = loadFailure;
    final session = AppSession(LocalDataService(), backend: backend);
    await tester.runAsync(session.initialize);

    expect(session.loadError, same(loadFailure));
    expect(session.dailyChallenges, hasLength(AppSession.dailyChallengeCount));
    expect(session.dailyChallenge, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            session: session,
            onOpenMood: () {},
            onOpenMemories: () {},
            onOpenChallenges: () {},
            onOpenGarden: () {},
            displayName: 'Sunshine',
            avatarId: 'girl',
          ),
        ),
      ),
    );

    expect(find.text('Today’s challenge is unavailable'), findsNothing);
    expect(find.text(session.dailyChallenge!.title), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  test(
    'confirmed backend completion updates task and garden progress',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);

      await session.initialize();
      final challengeId = _challengeId('day', 0);
      expect(await session.completeDailyChallenge(challengeId), isTrue);

      expect(session.completedToday, contains(challengeId));
      expect(session.completedTodayCount, 1);
      expect(session.growthPoints, 1);
      expect(backend.completedChallenges, [('2026-10-27', challengeId)]);
    },
  );

  test(
    'undo removes only today completion and returns its growth point',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();
      final challengeId = _challengeId('day', 0);
      await session.completeDailyChallenge(challengeId);

      expect(await session.undoDailyChallenge(challengeId), isTrue);
      expect(session.completedToday, isNot(contains(challengeId)));
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 0);
      expect(backend.undoneChallenges, [('2026-10-27', challengeId)]);
    },
  );

  test(
    'undo at a bloom boundary relocks only the newly earned flower',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      backend.setProgress(
        GardenProgressData(
          flowerCatalog: AppSession.flowers,
          flowerUnlockDates: {'flower-01': null},
          activeFlowerId: 'flower-01',
          growthPoints: 9,
          lifetimeGrowthPoints: 9,
        ),
      );
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();
      final challengeId = _challengeId('day', 0);
      await session.completeDailyChallenge(challengeId);

      expect(session.activeFlowerId, 'flower-02');
      expect(session.unlockedFlowerCount, 2);
      expect(await session.undoDailyChallenge(challengeId), isTrue);

      expect(session.activeFlowerId, 'flower-02');
      expect(session.growthPoints, 9);
      expect(session.lifetimeGrowthPoints, 9);
      expect(session.unlockedFlowerCount, 1);
      expect(session.flowerUnlockDates, isNot(contains('flower-02')));
    },
  );

  test('new backend user starts with zero flower growth', () async {
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ]);
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    addTearDown(session.dispose);

    await session.initialize();

    expect(session.growthPoints, 0);
    expect(session.lifetimeGrowthPoints, 0);
    expect(session.completedToday, isEmpty);
    expect(session.unlockedFlowerCount, 1);
    expect(session.activeFlowerId, 'flower-01');
    expect(session.growthPoints, 0);
  });

  test(
    'partial flower progress carries across backend dates and duplicates do not grow it',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day-one'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      for (final challenge in session.dailyChallenges.take(5)) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }

      expect(session.activeFlowerId, 'flower-01');
      expect(session.growthPoints, 5);
      expect(session.lifetimeGrowthPoints, 5);

      backend.setDailyContent(_dailyContent('2026-10-28', 'day-two'));
      await session.refreshDailyChallenges();
      expect(session.completedToday, isEmpty);
      expect(session.activeFlowerId, 'flower-01');
      expect(session.growthPoints, 5);

      final nextDayChallenges = session.dailyChallenges.take(5).toList();
      for (final challenge in nextDayChallenges) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }
      expect(session.activeFlowerId, 'flower-02');
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 10);
      expect(session.unlockedFlowerCount, 2);

      expect(
        await session.completeDailyChallenge(nextDayChallenges.first.id),
        isFalse,
      );
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 10);
    },
  );

  test(
    'nine points do not unlock; the tenth unlocks the next flower',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      for (final challenge in session.dailyChallenges.take(9)) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }

      expect(session.growthPoints, 9);
      expect(session.lifetimeGrowthPoints, 9);
      expect(session.unlockedFlowerCount, 1);
      expect(
        await session.completeDailyChallenge(session.dailyChallenges[9].id),
        isTrue,
      );

      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 10);
      expect(session.unlockedFlowerCount, 2);
      expect(session.flowerUnlockDates.keys, contains('flower-02'));
      expect(session.activeFlowerId, 'flower-02');
    },
  );

  test(
    'twenty unique completions across dates preserve growth and unlocks',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      for (final challenge in session.dailyChallenges) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 10);
      expect(session.unlockedFlowerCount, 2);

      backend.setDailyContent(_dailyContent('2026-10-28', 'today'));
      await session.refreshDailyChallenges();
      expect(session.completedToday, isEmpty);
      expect(session.growthPoints, 0);

      for (final challenge in session.dailyChallenges) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }

      expect(session.completedTodayCount, 10);
      expect(session.completedChallengeCount, 20);
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 20);
      expect(session.unlockedFlowerCount, 3);
      expect(
        session.flowerUnlockDates.keys,
        containsAll(['flower-01', 'flower-02', 'flower-03']),
      );
      expect(session.activeFlowerId, 'flower-03');
    },
  );

  test(
    'legacy 17-point garden is rebased without removing saved unlocks',
    () async {
      final backend =
          _FakeSupabaseDataService([_dailyContent('2026-10-27', 'day')])
            ..setProgress(
              GardenProgressData(
                flowerCatalog: AppSession.flowers,
                flowerUnlockDates: const {
                  'flower-01': null,
                  'flower-02': null,
                  'flower-03': null,
                },
                activeFlowerId: 'flower-04',
                growthPoints: 9,
                lifetimeGrowthPoints: 17,
              ),
            );
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);

      await session.initialize();
      expect(session.growthPoints, 7);
      expect(session.lifetimeGrowthPoints, 17);
      expect(session.activeFlowerId, 'flower-02');
      expect(
        session.flowerUnlockDates.keys,
        containsAll(['flower-01', 'flower-02', 'flower-03']),
      );

      for (final challenge in session.dailyChallenges.take(3)) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }

      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 20);
      expect(session.unlockedFlowerCount, 3);
      expect(
        session.flowerUnlockDates.keys,
        containsAll(['flower-01', 'flower-02', 'flower-03']),
      );
      expect(session.activeFlowerId, 'flower-03');
    },
  );

  test(
    'catalog expansion derives progress from lifetime, not stale growth',
    () async {
      final allInitialFlowers = {
        for (final flower in AppSession.flowers) flower.id: null,
      };
      final backend =
          _FakeSupabaseDataService([_dailyContent('2026-10-27', 'day')])
            ..setProgress(
              GardenProgressData(
                flowerCatalog: AppSession.flowers,
                flowerUnlockDates: allInitialFlowers,
                activeFlowerId: null,
                growthPoints: 9,
                lifetimeGrowthPoints: 205,
              ),
            );
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      expect(session.activeFlowerId, isNull);
      expect(session.growthPoints, 0);
      expect(
        await session.completeDailyChallenge(session.dailyChallenges[0].id),
        isTrue,
      );
      expect(session.activeFlowerId, isNull);
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 206);

      final extendedCatalog = [
        ...AppSession.flowers,
        const GardenFlower(
          id: 'flower-21',
          name: 'New catalog flower',
          emoji: '🌺',
          color: Color(0xFFFFDFE5),
          sortOrder: 21,
        ),
      ];
      backend.setProgress(
        GardenProgressData(
          dailyCompletions: backend.progress.dailyCompletions,
          flowerUnlockDates: backend.progress.flowerUnlockDates,
          flowerCatalog: extendedCatalog,
          activeFlowerId: backend.progress.activeFlowerId,
          growthPoints: 9,
          lifetimeGrowthPoints: backend.progress.lifetimeGrowthPoints,
        ),
      );
      await session.refreshDailyChallenges();

      expect(session.activeFlowerId, 'flower-21');
      expect(session.growthPoints, 6);
      for (final challenge in session.dailyChallenges.skip(1).take(4)) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }

      expect(session.flowerUnlockDates.keys, contains('flower-21'));
      expect(session.unlockedFlowerCount, 21);
      expect(session.activeFlowerId, isNull);
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 210);
    },
  );

  test('legitimate saved flower growth is preserved on session load', () async {
    final backend =
        _FakeSupabaseDataService([_dailyContent('2026-10-27', 'day')])
          ..setProgress(
            const GardenProgressData(
              flowerUnlockDates: {'flower-01': null, 'flower-02': null},
              activeFlowerId: 'flower-02',
              growthPoints: 3,
              lifetimeGrowthPoints: 13,
            ),
          );
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    addTearDown(session.dispose);

    await session.initialize();

    expect(session.growthPoints, 3);
    expect(session.lifetimeGrowthPoints, 13);
    expect(session.completedToday, isEmpty);
  });

  test(
    'previous-day completions do not affect today status or saved growth',
    () async {
      final previousChallenge = _challengeId('day', 0);
      final backend =
          _FakeSupabaseDataService([_dailyContent('2026-10-27', 'day')])
            ..setProgress(
              GardenProgressData(
                dailyCompletions: {
                  '2026-10-26': [previousChallenge],
                },
                flowerUnlockDates: const {
                  'flower-01': null,
                  'flower-02': null,
                  'flower-03': null,
                },
                activeFlowerId: 'flower-03',
                growthPoints: 3,
                lifetimeGrowthPoints: 13,
              ),
            );
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);

      await session.initialize();

      expect(session.dailyContentDate, '2026-10-27');
      expect(session.completedToday, isEmpty);
      expect(session.completedChallengeCount, 1);
      expect(session.growthPoints, 3);
      expect(session.lifetimeGrowthPoints, 13);
    },
  );

  test('repeat completion does not submit a second reward request', () async {
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ]);
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    addTearDown(session.dispose);
    await session.initialize();

    final challengeId = _challengeId('day', 0);
    expect(await session.completeDailyChallenge(challengeId), isTrue);
    expect(await session.completeDailyChallenge(challengeId), isFalse);

    expect(backend.completedChallenges, [('2026-10-27', challengeId)]);
    expect(session.growthPoints, 1);
  });

  test(
    'already-completed backend task refreshes status without a reward',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      final challengeId = _challengeId('day', 0);
      backend.recordExistingCompletion('2026-10-27', challengeId);

      expect(session.completedToday, isEmpty);
      expect(await session.completeDailyChallenge(challengeId), isFalse);
      expect(session.completedToday, contains(challengeId));
      expect(session.growthPoints, 1);
      expect(session.lifetimeGrowthPoints, 1);
      expect(backend.completedChallenges, isEmpty);
    },
  );

  test(
    'backend duplicate-completion verification surfaces query errors',
    () async {
      final backend =
          _FakeSupabaseDataService([_dailyContent('2026-10-27', 'day')])
            ..dailyCompletionQueryError = StateError(
              'challenge completion query failed',
            );
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      final challengeId = _challengeId('day', 0);
      backend.recordExistingCompletion('2026-10-27', challengeId);

      await expectLater(
        session.completeDailyChallenge(challengeId),
        throwsStateError,
      );
      expect(session.completedToday, isEmpty);
      expect(backend.completedChallenges, isEmpty);
    },
  );

  test(
    'completion status restores from backend after session reload',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final firstSession = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      await firstSession.initialize();
      final challengeId = _challengeId('day', 0);
      expect(await firstSession.completeDailyChallenge(challengeId), isTrue);
      firstSession.dispose();

      final restoredSession = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(restoredSession.dispose);
      await restoredSession.initialize();

      expect(restoredSession.completedToday, contains(challengeId));
      expect(restoredSession.completedTodayCount, 1);
      expect(
        await restoredSession.completeDailyChallenge(challengeId),
        isFalse,
      );
      expect(backend.completedChallenges, [('2026-10-27', challengeId)]);
    },
  );

  test(
    'new day loads assignments without showing yesterday completions',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'yesterday'),
        _dailyContent('2026-10-27', 'yesterday'),
        _dailyContent('2026-10-28', 'today'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 23, 59),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();
      final yesterdayChallenge = _challengeId('yesterday', 0);
      expect(await session.completeDailyChallenge(yesterdayChallenge), isTrue);

      await session.refreshDailyChallenges();

      expect(session.dailyContentDate, '2026-10-28');
      expect(session.dailyChallenges.first.id, _challengeId('today', 0));
      expect(session.completedToday, isEmpty);
      expect(session.completedChallengeCount, 1);
      expect(backend.progress.dailyCompletions['2026-10-27'], [
        yesterdayChallenge,
      ]);
    },
  );

  test('failed completion clears only its own saving state', () async {
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ]);
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    addTearDown(session.dispose);
    await session.initialize();

    final firstChallenge = _challengeId('day', 0);
    final failedChallenge = _challengeId('day', 1);
    expect(await session.completeDailyChallenge(firstChallenge), isTrue);
    backend.completionError = StateError('request failed');

    await expectLater(
      session.completeDailyChallenge(failedChallenge),
      throwsStateError,
    );

    expect(session.completedToday, contains(firstChallenge));
    expect(session.completedToday, isNot(contains(failedChallenge)));
    expect(session.isChallengeSaving(firstChallenge), isFalse);
    expect(session.isChallengeSaving(failedChallenge), isFalse);
    expect(backend.progress.growthPoints, 1);
  });

  test(
    'confirmed completion remains DONE and surfaces garden refresh failure',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      final challengeId = _challengeId('day', 0);
      backend.gardenProgressError = StateError('garden query failed');

      await expectLater(
        session.completeDailyChallenge(challengeId),
        throwsA(isA<ChallengeProgressRefreshException>()),
      );

      expect(session.completedToday, contains(challengeId));
      expect(session.growthPoints, 0);
      expect(backend.progress.growthPoints, 1);
      expect(backend.completedChallenges, [('2026-10-27', challengeId)]);
      expect(session.isChallengeSaving(challengeId), isFalse);
    },
  );

  test(
    'out-of-order garden refreshes preserve each challenge completion',
    () async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      addTearDown(session.dispose);
      await session.initialize();

      final firstChallenge = _challengeId('day', 0);
      final secondChallenge = _challengeId('day', 1);
      final firstProgressGate = Completer<void>();
      backend.nextProgressGate = firstProgressGate;

      final firstCompletion = session.completeDailyChallenge(firstChallenge);
      await Future<void>.delayed(Duration.zero);
      expect(session.isChallengeSaving(firstChallenge), isTrue);

      expect(await session.completeDailyChallenge(secondChallenge), isTrue);
      expect(
        session.completedToday,
        containsAll([firstChallenge, secondChallenge]),
      );
      expect(session.growthPoints, 2);

      firstProgressGate.complete();
      expect(await firstCompletion, isTrue);
      expect(
        session.completedToday,
        containsAll([firstChallenge, secondChallenge]),
      );
      expect(session.completedTodayCount, 2);
      expect(session.growthPoints, 2);
      expect(backend.progress.lifetimeGrowthPoints, 2);
    },
  );

  testWidgets(
    'completed challenge stays at bottom while another challenge is saving',
    (tester) async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      await tester.runAsync(session.initialize);

      final firstChallenge = _challengeId('day', 0);
      final secondChallenge = _challengeId('day', 1);
      expect(await session.completeDailyChallenge(firstChallenge), isTrue);

      final requestGate = Completer<void>();
      backend.completionGate = requestGate;
      final secondCompletion = session.completeDailyChallenge(secondChallenge);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: session,
              builder: (context, _) => DailyChallengesScreen(session: session),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Saving…'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Saving…'), findsOneWidget);
      expect(session.isChallengeSaving(secondChallenge), isTrue);
      await tester.scrollUntilVisible(
        find.text('Completed'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('day challenge 0'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('day challenge 0'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(session.isChallengeSaving(secondChallenge), isTrue);
      expect(session.completedToday, contains(firstChallenge));

      requestGate.complete();
      expect(await secondCompletion, isTrue);
      await tester.pumpAndSettle();
      expect(
        session.completedToday,
        containsAll([firstChallenge, secondChallenge]),
      );
      expect(find.text('DONE'), findsNWidgets(2));
      expect(find.text('Undo'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('reopening the challenges screen restores undo state', (
    tester,
  ) async {
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ]);
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    await tester.runAsync(session.initialize);
    final challengeId = _challengeId('day', 0);
    expect(await session.completeDailyChallenge(challengeId), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DailyChallengesScreen(session: session)),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Undo'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(find.byTooltip('Refresh daily challenges'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DailyChallengesScreen(session: session)),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Undo'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('Undo returns today challenge and removes the refresh control', (
    tester,
  ) async {
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ]);
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    await tester.runAsync(session.initialize);
    final challengeId = _challengeId('day', 0);
    await session.completeDailyChallenge(challengeId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: session,
            builder: (context, _) => DailyChallengesScreen(session: session),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Refresh daily challenges'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Undo'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(session.completedToday, isNot(contains(challengeId)));
    expect(session.lifetimeGrowthPoints, 0);
    expect(find.text('Undo'), findsNothing);
    expect(find.byTooltip('Refresh daily challenges'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'challenge cards use PetalPop illustrations and dark theme styles',
    (tester) async {
      final backend = _FakeSupabaseDataService([
        _dailyContent('2026-10-27', 'day'),
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 12),
        backend: backend,
      );
      await tester.runAsync(session.initialize);

      await tester.pumpWidget(
        MaterialApp(
          theme: PetalPopTheme.dark,
          home: Scaffold(
            body: AnimatedBuilder(
              animation: session,
              builder: (context, _) => DailyChallengesScreen(session: session),
            ),
          ),
        ),
      );

      expect(find.byType(ChallengeIllustration), findsAtLeastNWidgets(2));
      expect(find.byTooltip('Refresh daily challenges'), findsNothing);
      expect(find.text('Still to do'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('challenge card shows loading until backend confirms', (
    tester,
  ) async {
    final requestGate = Completer<void>();
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ])..completionGate = requestGate;
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    await tester.runAsync(session.initialize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: session,
            builder: (context, _) => DailyChallengesScreen(session: session),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Got it').first);
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(session.isChallengeSaving(_challengeId('day', 0)), isTrue);

    requestGate.complete();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Undo'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(session.completedToday, contains(_challengeId('day', 0)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('already-completed backend task can be undone', (tester) async {
    final backend = _FakeSupabaseDataService([
      _dailyContent('2026-10-27', 'day'),
    ]);
    final session = AppSession(
      LocalDataService(),
      clock: () => DateTime(2026, 10, 27, 12),
      backend: backend,
    );
    await tester.runAsync(session.initialize);
    final challengeId = _challengeId('day', 0);
    backend.recordExistingCompletion('2026-10-27', challengeId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: session,
            builder: (context, _) => DailyChallengesScreen(session: session),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Got it').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Undo'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(
      find.text(
        'This challenge was already complete. It is now marked DONE. 🌸',
      ),
      findsOneWidget,
    );
    expect(session.completedToday, contains(challengeId));
    expect(session.growthPoints, 1);
    expect(backend.completedChallenges, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  test(
    'backend assignments and date remain authoritative during completion',
    () async {
      final previousAssignment = _dailyContent('2026-10-27', 'old');
      final currentAssignment = _dailyContent('2026-10-28', 'current');
      final backend = _FakeSupabaseDataService([
        previousAssignment,
        currentAssignment,
        currentAssignment,
        currentAssignment,
      ]);
      final session = AppSession(
        LocalDataService(),
        clock: () => DateTime(2026, 10, 27, 23, 30),
        backend: backend,
      );
      addTearDown(session.dispose);

      await session.initialize();
      expect(session.dailyContentDate, '2026-10-27');
      expect(session.dailyChallenges.first.id, _challengeId('old', 0));

      await expectLater(
        session.completeDailyChallenge(_challengeId('old', 0)),
        throwsStateError,
      );
      expect(session.dailyContentDate, '2026-10-28');
      expect(session.dailyChallenges.first.id, _challengeId('current', 0));
      expect(backend.completedChallenges, isEmpty);

      final currentChallenge = _challengeId('current', 0);
      expect(await session.completeDailyChallenge(currentChallenge), isTrue);
      expect(backend.completedChallenges, [('2026-10-28', currentChallenge)]);
    },
  );

  test('memory save does not notify a disposed session', () async {
    final saveGate = Completer<void>();
    final storage = _DelayedMemoryStorage(saveGate);
    final session = AppSession(storage);

    final save = session.addMemory(
      MemoryEntry(
        id: 'memory-1',
        type: MemoryType.note,
        title: 'A saved note',
        description: 'A few words',
        createdAt: DateTime(2026, 10, 27),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    session.dispose();
    saveGate.complete();

    await expectLater(save, completes);
    expect(storage.savedMemories, hasLength(1));
  });
}

DailyContent _dailyContent(String date, String prefix) => DailyContent(
  date: date,
  challenges: [
    for (var index = 0; index < AppSession.dailyChallengeCount; index++)
      DailyChallenge(
        id: _challengeId(prefix, index),
        title: '$prefix challenge $index',
        description: 'A daily challenge.',
        emoji: '🌸',
      ),
  ],
  quote: '$prefix quote',
);

String _challengeId(String prefix, int index) {
  final start = switch (prefix) {
    'current' || 'today' => AppSession.dailyChallengeCount,
    _ => 0,
  };
  return AppSession.challenges[start + index].id;
}

class _FakeSupabaseDataService extends SupabaseDataService {
  _FakeSupabaseDataService(this._dailyContentResults)
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<DailyContent> _dailyContentResults;
  final List<(String, String)> completedChallenges = [];
  final List<(String, String)> undoneChallenges = [];
  final List<AppNotification> notifications = [];
  final Set<String> omitGardenCompletionDates = {};
  Map<String, List<String>>? gardenCompletionOverride;
  Completer<void>? completionGate;
  Object? dailyContentError;
  Object? completionError;
  Object? undoError;
  Object? dailyCompletionQueryError;
  Object? gardenProgressError;
  Completer<void>? nextProgressGate;
  DailyContent? dailyContentOverride;
  var _dailyContentIndex = 0;
  var _notificationSequence = 0;
  GardenProgressData _progress = GardenProgressData(
    flowerCatalog: AppSession.flowers,
    flowerUnlockDates: {'flower-01': null},
    activeFlowerId: 'flower-01',
  );
  GardenProgressData get progress => _progress;

  void setDailyContent(DailyContent content) {
    dailyContentOverride = content;
  }

  void setProgress(GardenProgressData progress) {
    _progress = GardenProgressData(
      dailyCompletions: progress.dailyCompletions,
      flowerUnlockDates: progress.flowerUnlockDates,
      flowerCatalog: progress.flowerCatalog.isEmpty
          ? AppSession.flowers
          : progress.flowerCatalog,
      activeFlowerId: progress.activeFlowerId,
      growthPoints: progress.growthPoints,
      lifetimeGrowthPoints: progress.lifetimeGrowthPoints,
    );
  }

  void recordExistingCompletion(String localDate, String challengeId) {
    final completions = {
      for (final entry in _progress.dailyCompletions.entries)
        entry.key: List<String>.of(entry.value),
    };
    completions.putIfAbsent(localDate, () => []).add(challengeId);
    _progress = GardenProgressData(
      dailyCompletions: completions,
      flowerUnlockDates: _progress.flowerUnlockDates,
      flowerCatalog: _progress.flowerCatalog,
      activeFlowerId: _progress.activeFlowerId,
      growthPoints: 1,
      lifetimeGrowthPoints: 1,
    );
  }

  @override
  Future<DailyContent> loadDailyContent() async {
    if (dailyContentError != null) throw dailyContentError!;
    if (dailyContentOverride != null) return dailyContentOverride!;
    final index = _dailyContentIndex.clamp(0, _dailyContentResults.length - 1);
    if (_dailyContentIndex < _dailyContentResults.length - 1) {
      _dailyContentIndex++;
    }
    return _dailyContentResults[index];
  }

  @override
  Future<bool> completeChallenge(String localDate, String challengeId) async {
    if (completionError != null) throw completionError!;
    final gate = completionGate;
    if (gate != null) await gate.future;
    if (_progress.dailyCompletions[localDate]?.contains(challengeId) ?? false) {
      return false;
    }
    completedChallenges.add((localDate, challengeId));
    final completions = {
      for (final entry in _progress.dailyCompletions.entries)
        entry.key: List<String>.of(entry.value),
    };
    completions.putIfAbsent(localDate, () => []).add(challengeId);
    final unlockedFlowers = Map<String, String?>.of(
      _progress.flowerUnlockDates,
    );
    final newLifetimeGrowthPoints = _progress.lifetimeGrowthPoints + 1;
    final activeFlowerIndex =
        newLifetimeGrowthPoints ~/ AppSession.growthStagesPerFlower;
    final unlockedCount = (activeFlowerIndex + 1).clamp(
      0,
      _progress.flowerCatalog.length,
    );
    for (var index = 0; index < unlockedCount; index++) {
      unlockedFlowers.putIfAbsent(
        _progress.flowerCatalog[index].id,
        () => index == 0 ? null : localDate,
      );
    }
    final activeFlowerId = activeFlowerIndex < _progress.flowerCatalog.length
        ? _progress.flowerCatalog[activeFlowerIndex].id
        : null;
    final growthPoints = activeFlowerId == null
        ? 0
        : newLifetimeGrowthPoints % AppSession.growthStagesPerFlower;
    _progress = GardenProgressData(
      dailyCompletions: completions,
      flowerUnlockDates: unlockedFlowers,
      flowerCatalog: _progress.flowerCatalog,
      activeFlowerId: activeFlowerId,
      growthPoints: growthPoints,
      lifetimeGrowthPoints: newLifetimeGrowthPoints,
    );
    _notificationSequence++;
    notifications.add(
      AppNotification(
        id: 'notice-$_notificationSequence',
        kind: 'challenge_completed',
        sourceKey: 'challenge:$localDate:$challengeId:$_notificationSequence',
        title: 'Challenge completed',
        body: 'A completed challenge event.',
        createdAt: DateTime(2026, 10, 27),
        isRead: false,
      ),
    );
    return true;
  }

  @override
  Future<bool> undoChallenge(String localDate, String challengeId) async {
    if (undoError != null) throw undoError!;
    if (!(_progress.dailyCompletions[localDate]?.contains(challengeId) ??
        false)) {
      return false;
    }
    undoneChallenges.add((localDate, challengeId));
    final completions = {
      for (final entry in _progress.dailyCompletions.entries)
        entry.key: List<String>.of(entry.value),
    };
    completions[localDate]!.remove(challengeId);
    if (completions[localDate]!.isEmpty) completions.remove(localDate);
    final notificationPrefix = 'challenge:$localDate:$challengeId:';
    for (var index = 0; index < notifications.length; index++) {
      final notification = notifications[index];
      if (!notification.isRetracted &&
          notification.sourceKey.startsWith(notificationPrefix)) {
        notifications[index] = notification.retract();
      }
    }
    final lifetime = _progress.lifetimeGrowthPoints - 1;
    final unlocks = Map<String, String?>.of(_progress.flowerUnlockDates);
    if (_progress.lifetimeGrowthPoints % AppSession.growthStagesPerFlower ==
        0) {
      final completionUnlock = _progress.flowerCatalog
          .where(
            (flower) =>
                unlocks.containsKey(flower.id) &&
                unlocks[flower.id] == localDate,
          )
          .lastOrNull;
      if (completionUnlock != null) unlocks.remove(completionUnlock.id);
    }
    final activeFlowerId = _progress.flowerCatalog
        .where((flower) => !unlocks.containsKey(flower.id))
        .firstOrNull
        ?.id;
    _progress = GardenProgressData(
      dailyCompletions: completions,
      flowerUnlockDates: unlocks,
      flowerCatalog: _progress.flowerCatalog,
      activeFlowerId: activeFlowerId,
      growthPoints: activeFlowerId == null
          ? 0
          : lifetime % AppSession.growthStagesPerFlower,
      lifetimeGrowthPoints: lifetime,
    );
    return true;
  }

  @override
  Future<List<String>> loadDailyChallengeCompletions(String localDate) async {
    if (dailyCompletionQueryError != null) {
      throw dailyCompletionQueryError!;
    }
    return (_progress.dailyCompletions[localDate] ?? const <String>[]).toList(
      growable: false,
    );
  }

  @override
  Future<GardenProgressData> loadGardenProgress() async {
    if (gardenProgressError != null) throw gardenProgressError!;
    final snapshot = _progress;
    final gate = nextProgressGate;
    if (gate != null) {
      nextProgressGate = null;
      await gate.future;
    }
    if (omitGardenCompletionDates.isNotEmpty) {
      return GardenProgressData(
        dailyCompletions: {
          for (final entry in snapshot.dailyCompletions.entries)
            if (!omitGardenCompletionDates.contains(entry.key))
              entry.key: entry.value,
        },
        flowerUnlockDates: snapshot.flowerUnlockDates,
        flowerCatalog: snapshot.flowerCatalog,
        activeFlowerId: snapshot.activeFlowerId,
        growthPoints: snapshot.growthPoints,
        lifetimeGrowthPoints: snapshot.lifetimeGrowthPoints,
      );
    }
    final completionOverride = gardenCompletionOverride;
    if (completionOverride != null) {
      return GardenProgressData(
        dailyCompletions: completionOverride,
        flowerUnlockDates: snapshot.flowerUnlockDates,
        flowerCatalog: snapshot.flowerCatalog,
        activeFlowerId: snapshot.activeFlowerId,
        growthPoints: snapshot.growthPoints,
        lifetimeGrowthPoints: snapshot.lifetimeGrowthPoints,
      );
    }
    return snapshot;
  }

  @override
  Future<List<MoodEntry>> loadMoods() async => [];

  @override
  Future<List<AppNotification>> loadNotifications() async =>
      List<AppNotification>.of(notifications);

  @override
  Future<void> markNotificationRead(String id) async {
    final index = notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index >= 0) notifications[index] = notifications[index].markRead();
  }

  @override
  Future<List<MemoryEntry>> loadMemories() async => [];
}

class _DelayedMemoryStorage extends LocalDataService {
  _DelayedMemoryStorage(this._saveGate);

  final Completer<void> _saveGate;
  List<MemoryEntry> savedMemories = [];

  @override
  Future<void> saveMemories(List<MemoryEntry> entries) async {
    await _saveGate.future;
    savedMemories = List.of(entries);
  }
}
