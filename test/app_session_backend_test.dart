import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petalpop/models/daily_challenge.dart';
import 'package:petalpop/models/garden_flower.dart';
import 'package:petalpop/models/garden_progress.dart';
import 'package:petalpop/models/memory_entry.dart';
import 'package:petalpop/models/mood_entry.dart';
import 'package:petalpop/screens/home_screen.dart';
import 'package:petalpop/services/app_session.dart';
import 'package:petalpop/services/local_data_service.dart';
import 'package:petalpop/services/supabase_data_service.dart';
import 'package:petalpop/screens/daily_challenges_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'Home shows an unavailable state when backend daily content fails',
    (tester) async {
      final loadFailure = StateError('daily content is unavailable');
      final backend = _FakeSupabaseDataService([])
        ..dailyContentError = loadFailure;
      final session = AppSession(LocalDataService(), backend: backend);
      await session.initialize();

      expect(session.loadError, same(loadFailure));
      expect(session.dailyChallenges, isEmpty);
      expect(session.dailyChallenge, isNull);

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

      expect(find.text('Today’s challenge is unavailable'), findsOneWidget);
      expect(find.text('Drink a glass of water'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

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

      expect(session.activeFlowerId, 'flower-01');
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
      await session.initialize();

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
    await session.initialize();
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
    await session.initialize();
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
    await session.initialize();
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
    await session.initialize();
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
  Completer<void>? completionGate;
  Object? dailyContentError;
  Object? completionError;
  Object? dailyCompletionQueryError;
  Object? gardenProgressError;
  Completer<void>? nextProgressGate;
  DailyContent? dailyContentOverride;
  var _dailyContentIndex = 0;
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
    return true;
  }

  @override
  Future<bool> undoChallenge(String localDate, String challengeId) async {
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
    final lifetime = _progress.lifetimeGrowthPoints - 1;
    final activeIndex = lifetime ~/ AppSession.growthStagesPerFlower;
    final unlockedCount = (activeIndex + 1).clamp(
      0,
      _progress.flowerCatalog.length,
    );
    final unlocks = {
      for (var index = 0; index < unlockedCount; index++)
        _progress.flowerCatalog[index].id:
            _progress.flowerUnlockDates[_progress.flowerCatalog[index].id],
    };
    _progress = GardenProgressData(
      dailyCompletions: completions,
      flowerUnlockDates: unlocks,
      flowerCatalog: _progress.flowerCatalog,
      activeFlowerId: activeIndex < _progress.flowerCatalog.length
          ? _progress.flowerCatalog[activeIndex].id
          : null,
      growthPoints: lifetime % AppSession.growthStagesPerFlower,
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
    return snapshot;
  }

  @override
  Future<List<MoodEntry>> loadMoods() async => [];

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
