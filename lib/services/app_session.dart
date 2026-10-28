import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../models/daily_challenge.dart';
import '../models/garden_flower.dart';
import '../models/garden_progress.dart';
import '../models/memory_entry.dart';
import '../models/mood_entry.dart';
import 'local_data_service.dart';
import 'supabase_data_service.dart';

class ChallengeProgressRefreshException implements Exception {
  const ChallengeProgressRefreshException({
    required this.challengeId,
    required this.localDate,
    required this.wasAlreadyCompleted,
    required this.cause,
  });

  final String challengeId;
  final String localDate;
  final bool wasAlreadyCompleted;
  final Object cause;

  @override
  String toString() =>
      'Challenge "$challengeId" for $localDate was '
      '${wasAlreadyCompleted ? 'already completed' : 'saved successfully'}, '
      'but the latest flower progress could not be refreshed. The completion '
      'status is preserved. Original Supabase error: $cause';
}

class AppSession extends ChangeNotifier {
  AppSession(this.storage, {DateTime Function()? clock, this.backend})
    : _clock = clock ?? DateTime.now;

  final LocalDataService storage;
  final SupabaseDataService? backend;
  final DateTime Function() _clock;
  final List<MoodEntry> _moodEntries = [];
  final List<MemoryEntry> _memories = [];
  final Set<String> _completedChallengeIds = {};
  final Map<String, List<String>> _dailyCompletions = {};
  final Map<String, String?> _flowerUnlockDates = {};
  final Set<String> _pendingDailyChallengeIds = {};
  List<GardenFlower> _flowerCatalog = flowers;
  String? _activeFlowerId;
  int _growthPoints = 0;
  int _lifetimeGrowthPoints = 0;
  List<DailyChallenge>? _backendChallenges;
  String? _backendQuote;
  String? _backendDate;
  Timer? _dateRefreshTimer;
  String? _lastObservedDateKey;
  DateTime? _lastBackendDateCheck;
  bool _isDisposed = false;
  bool isLoading = true;
  Object? loadError;

  static const challenges = <DailyChallenge>[
    DailyChallenge(
      id: 'drink-water',
      title: 'Drink a glass of water',
      description: 'Take a little pause and give your body a refreshing sip.',
      emoji: '💧',
    ),
    DailyChallenge(
      id: 'short-walk',
      title: 'Spend five minutes outdoors',
      description: 'Step outside and notice the world around you.',
      emoji: '🚶',
    ),
    DailyChallenge(
      id: 'express-gratitude',
      title: 'Write down one thing you are grateful for',
      description: 'Capture one little thing that makes today brighter.',
      emoji: '💌',
    ),
    DailyChallenge(
      id: 'favorite-song',
      title: 'Listen to a favorite song',
      description: 'Play a song you love and enjoy a little music break.',
      emoji: '🎵',
    ),
    DailyChallenge(
      id: 'share-a-smile',
      title: 'Compliment someone',
      description: 'Share a sincere kind word with someone today.',
      emoji: '😊',
    ),
    DailyChallenge(
      id: 'step-into-sunshine',
      title: 'Take a photo of something that made you smile',
      description: 'Save a cheerful little detail from your day.',
      emoji: '☀️',
    ),
    DailyChallenge(
      id: 'stretch-break',
      title: 'Take a gentle stretch break',
      description: 'Give your shoulders, hands, or legs a little stretch.',
      emoji: '🧘',
    ),
    DailyChallenge(
      id: 'notice-something-lovely',
      title: 'Notice something lovely',
      description: 'Pause and notice one small beautiful thing around you.',
      emoji: '🌷',
    ),
    DailyChallenge(
      id: 'kind-note',
      title: 'Write a kind little note',
      description: 'Send yourself or someone else a few encouraging words.',
      emoji: '💖',
    ),
    DailyChallenge(
      id: 'make-your-bed',
      title: 'Make your bed',
      description: 'Freshen up one small corner of your space.',
      emoji: '🛏️',
    ),
    DailyChallenge(
      id: 'drink-something-cozy',
      title: 'Enjoy a cozy drink',
      description: 'Take a mindful pause with water, tea, or another favorite.',
      emoji: '🍵',
    ),
    DailyChallenge(
      id: 'tidy-one-thing',
      title: 'Tidy one little thing',
      description: 'Choose one small spot to make a bit more peaceful.',
      emoji: '🧺',
    ),
    DailyChallenge(
      id: 'read-a-page',
      title: 'Read one page',
      description: 'Spend a quiet moment with something you enjoy reading.',
      emoji: '📖',
    ),
    DailyChallenge(
      id: 'water-a-plant',
      title: 'Water a plant',
      description: 'Give a leafy friend a little care.',
      emoji: '🪴',
    ),
    DailyChallenge(
      id: 'take-a-deep-breath',
      title: 'Take three slow breaths',
      description: 'Pause, breathe gently, and give yourself a moment.',
      emoji: '🌬️',
    ),
    DailyChallenge(
      id: 'send-a-kind-message',
      title: 'Send a kind message',
      description: 'Let someone know you are thinking of them.',
      emoji: '💌',
    ),
    DailyChallenge(
      id: 'enjoy-a-fruit',
      title: 'Enjoy a piece of fruit',
      description: 'Pick a fruit you like and savor a refreshing snack.',
      emoji: '🍓',
    ),
    DailyChallenge(
      id: 'take-a-screen-break',
      title: 'Take a screen break',
      description: 'Look away from your screen and rest your eyes.',
      emoji: '🌿',
    ),
    DailyChallenge(
      id: 'write-a-happy-memory',
      title: 'Write a happy memory',
      description: 'Jot down a moment you would like to remember.',
      emoji: '📔',
    ),
    DailyChallenge(
      id: 'listen-to-nature',
      title: 'Listen to the sounds around you',
      description: 'Pause and notice one sound you might usually miss.',
      emoji: '🐦',
    ),
    DailyChallenge(
      id: 'choose-a-kind-thought',
      title: 'Choose a kind thought about yourself',
      description: 'Offer yourself the same understanding you give a friend.',
      emoji: '🩷',
    ),
    DailyChallenge(
      id: 'organize-a-small-space',
      title: 'Organize one small space',
      description: 'Spend a few minutes making a drawer or shelf feel nicer.',
      emoji: '🧸',
    ),
    DailyChallenge(
      id: 'watch-the-sky',
      title: 'Look at the sky',
      description: 'Take a moment to notice the clouds, colors, or sunshine.',
      emoji: '☁️',
    ),
    DailyChallenge(
      id: 'dance-to-a-song',
      title: 'Dance to one song',
      description: 'Move however feels fun while a favorite song plays.',
      emoji: '💃',
    ),
    DailyChallenge(
      id: 'thank-someone',
      title: 'Thank someone',
      description: 'Tell someone you appreciate something they did.',
      emoji: '🙏',
    ),
    DailyChallenge(
      id: 'draw-a-doodle',
      title: 'Draw a tiny doodle',
      description: 'Make a little sketch, no artistic skills needed.',
      emoji: '✏️',
    ),
    DailyChallenge(
      id: 'fresh-air-break',
      title: 'Get a breath of fresh air',
      description: 'Open a window or step outside for a refreshing pause.',
      emoji: '🌤️',
    ),
    DailyChallenge(
      id: 'prepare-for-tomorrow',
      title: 'Make tomorrow a little easier',
      description: 'Set out one thing that will help your future self.',
      emoji: '🎒',
    ),
    DailyChallenge(
      id: 'smile-at-yourself',
      title: 'Give yourself a smile',
      description: 'Look in the mirror and offer yourself a friendly smile.',
      emoji: '😊',
    ),
    DailyChallenge(
      id: 'pause-for-sunlight',
      title: 'Enjoy a little sunlight',
      description: 'Find a comfortable sunny spot for a few peaceful minutes.',
      emoji: '🌞',
    ),
    DailyChallenge(
      id: 'write-three-words',
      title: 'Describe today in three kind words',
      description: 'Find a gentle way to describe how your day is going.',
      emoji: '📝',
    ),
    DailyChallenge(
      id: 'stretch-your-hands',
      title: 'Give your hands a gentle stretch',
      description: 'Pause and loosen your fingers after a busy day.',
      emoji: '🤲',
    ),
    DailyChallenge(
      id: 'open-a-window',
      title: 'Let a little fresh air in',
      description: 'Open a window for a moment if it feels comfortable.',
      emoji: '🪟',
    ),
    DailyChallenge(
      id: 'make-a-colorful-snack',
      title: 'Make a colorful snack',
      description: 'Choose something tasty with a bright color.',
      emoji: '🍊',
    ),
    DailyChallenge(
      id: 'write-a-thank-you',
      title: 'Write a thank-you note',
      description: 'Thank someone for a small thing you appreciated.',
      emoji: '💌',
    ),
    DailyChallenge(
      id: 'watch-a-favorite-scene',
      title: 'Enjoy a favorite little moment',
      description: 'Watch or remember a scene that makes you feel good.',
      emoji: '🎬',
    ),
    DailyChallenge(
      id: 'sort-a-few-things',
      title: 'Put a few things back in place',
      description: 'Tidy just a handful of things; small is enough.',
      emoji: '🧸',
    ),
    DailyChallenge(
      id: 'make-a-cozy-corner',
      title: 'Make a cozy corner',
      description: 'Arrange a comfy spot for a little rest.',
      emoji: '🛋️',
    ),
    DailyChallenge(
      id: 'write-a-kind-list',
      title: 'List three things you like about yourself',
      description: 'They can be tiny qualities or things you have done.',
      emoji: '📝',
    ),
    DailyChallenge(
      id: 'notice-your-breath',
      title: 'Notice one slow breath',
      description: 'Feel one gentle breath in and out without rushing.',
      emoji: '🌬️',
    ),
    DailyChallenge(
      id: 'share-a-laugh',
      title: 'Find something that makes you laugh',
      description: 'Enjoy a funny memory, joke, or cheerful clip.',
      emoji: '😄',
    ),
    DailyChallenge(
      id: 'care-for-a-pet',
      title: 'Spend a kind moment with an animal',
      description: 'Give a pet some affection or admire an animal nearby.',
      emoji: '🐾',
    ),
    DailyChallenge(
      id: 'choose-a-comfort-song',
      title: 'Play a song that comforts you',
      description: 'Let a familiar favorite keep you company.',
      emoji: '🎶',
    ),
    DailyChallenge(
      id: 'pause-before-a-task',
      title: 'Take a pause before your next task',
      description: 'Give yourself a moment to reset before moving on.',
      emoji: '⏸️',
    ),
    DailyChallenge(
      id: 'add-color-to-a-page',
      title: 'Add a little color to a page',
      description: 'Color, sketch, or decorate something just for fun.',
      emoji: '🎨',
    ),
    DailyChallenge(
      id: 'try-a-new-fruit',
      title: 'Try a fruit you enjoy',
      description: 'Pick a fresh snack and enjoy it without multitasking.',
      emoji: '🍇',
    ),
    DailyChallenge(
      id: 'say-something-kind',
      title: 'Say something kind out loud',
      description: 'Offer an encouraging word to yourself or someone else.',
      emoji: '💬',
    ),
    DailyChallenge(
      id: 'step-away-and-rest',
      title: 'Rest your eyes for a minute',
      description: 'Look away from close-up screens and soften your gaze.',
      emoji: '🌷',
    ),
    DailyChallenge(
      id: 'celebrate-a-small-win',
      title: 'Celebrate one small win',
      description: 'Notice something you finished, tried, or kept going with.',
      emoji: '🎉',
    ),
    DailyChallenge(
      id: 'leave-a-kind-review',
      title: 'Send appreciation to someone who helped you',
      description: 'A quick thank-you can brighten someone’s day.',
      emoji: '💛',
    ),
    DailyChallenge(
      id: 'take-a-leisurely-stroll',
      title: 'Take a gentle stroll',
      description: 'Walk at a comfortable pace, even if it is just nearby.',
      emoji: '🚶',
    ),
    DailyChallenge(
      id: 'make-a-wish',
      title: 'Make a little wish for yourself',
      description: 'Imagine one kind thing you hope for in the days ahead.',
      emoji: '⭐',
    ),
    DailyChallenge(
      id: 'notice-a-nice-smell',
      title: 'Notice a pleasant scent',
      description: 'Pause for a moment with a favorite flower, tea, or soap.',
      emoji: '🌼',
    ),
    DailyChallenge(
      id: 'write-a-postcard',
      title: 'Write a few words to someone you miss',
      description: 'Send a note or simply write down what you would say.',
      emoji: '✉️',
    ),
    DailyChallenge(
      id: 'put-on-a-favorite-outfit',
      title: 'Wear something that feels like you',
      description: 'Choose a comfortable favorite if it suits your day.',
      emoji: '👗',
    ),
    DailyChallenge(
      id: 'listen-without-distraction',
      title: 'Listen closely to one song',
      description: 'Notice a sound, lyric, or instrument you enjoy.',
      emoji: '🎧',
    ),
    DailyChallenge(
      id: 'give-yourself-permission',
      title: 'Give yourself permission to pause',
      description: 'A short break is a kind thing to offer yourself.',
      emoji: '🩷',
    ),
    DailyChallenge(
      id: 'make-a-mini-plan',
      title: 'Make one tiny plan for something fun',
      description: 'Think of a simple thing you would enjoy doing soon.',
      emoji: '🗓️',
    ),
    DailyChallenge(
      id: 'compliment-yourself',
      title: 'Give yourself a sincere compliment',
      description: 'Notice a quality or effort you are proud of.',
      emoji: '🌟',
    ),
    DailyChallenge(
      id: 'look-at-something-green',
      title: 'Look at something green',
      description: 'Find a plant, tree, or other bit of green to admire.',
      emoji: '🍃',
    ),
  ];

  static const quotes = <String>[
    'Small steps every day lead to beautiful things.',
    'You deserve the same kindness you give others.',
    'A little progress is still progress.',
    'You are allowed to grow at your own pace.',
    'There is something lovely about simply beginning again.',
    'Your presence makes the world a little brighter.',
    'Rest is part of growing, too.',
    'You can do hard things one gentle step at a time.',
    'A kind thought can make room for a brighter day.',
    'You are blooming right where you are.',
    'Small joys make lovely days.',
    'Take today one happy little moment at a time.',
    'You do not have to be perfect to be wonderful.',
    'Give yourself credit for how far you have come.',
    'A soft start can still lead to a strong finish.',
    'Your best is enough for today.',
    'Let your little joys take up space.',
    'You make a difference in ways you may not see.',
    'Every day is a new page in your story.',
    'You are worthy of patience and care.',
    'A moment of calm can change the shape of a day.',
    'Keep choosing what helps your heart feel lighter.',
    'Your small acts of courage count.',
    'There is no rush to become who you are becoming.',
    'You bring your own kind of sunshine.',
    'Notice how much good you carry with you.',
    'You can be a work in progress and still be proud.',
    'Make space for one tiny thing that feels good.',
    'You deserve to celebrate the little wins.',
    'Hope can begin with one small breath.',
  ];

  static const flowers = <GardenFlower>[
    GardenFlower(
      id: 'flower-01',
      name: 'Happy starter bloom',
      emoji: '🌸',
      color: Color(0xFFFFE1EC),
    ),
    GardenFlower(
      id: 'flower-02',
      name: 'Sunny daisy',
      emoji: '🌼',
      color: Color(0xFFFFF2C7),
    ),
    GardenFlower(
      id: 'flower-03',
      name: 'Lovely tulip',
      emoji: '🌷',
      color: Color(0xFFFFE3E8),
    ),
    GardenFlower(
      id: 'flower-04',
      name: 'Blushing hibiscus',
      emoji: '🌺',
      color: Color(0xFFFFDCE5),
    ),
    GardenFlower(
      id: 'flower-05',
      name: 'Lavender bell',
      emoji: '🪻',
      color: Color(0xFFEDE3FF),
    ),
    GardenFlower(
      id: 'flower-06',
      name: 'Golden rosette',
      emoji: '🏵️',
      color: Color(0xFFFFE8CC),
    ),
    GardenFlower(
      id: 'flower-07',
      name: 'Sweet white bloom',
      emoji: '💮',
      color: Color(0xFFFFEAF2),
    ),
    GardenFlower(
      id: 'flower-08',
      name: 'Dreamy lotus',
      emoji: '🪷',
      color: Color(0xFFFFE0F0),
    ),
    GardenFlower(
      id: 'flower-09',
      name: 'Sunshine flower',
      emoji: '🌻',
      color: Color(0xFFFFF0B8),
    ),
    GardenFlower(
      id: 'flower-10',
      name: 'Forever rose',
      emoji: '🌹',
      color: Color(0xFFFFDCE1),
    ),
    GardenFlower(
      id: 'flower-11',
      name: 'Mint garden star',
      emoji: '✿',
      color: Color(0xFFDDF3E9),
    ),
    GardenFlower(
      id: 'flower-12',
      name: 'Pink bouquet',
      emoji: '💐',
      color: Color(0xFFFFE5EF),
    ),
    GardenFlower(
      id: 'flower-13',
      name: 'Lilac petal star',
      emoji: '❀',
      color: Color(0xFFECE2FF),
    ),
    GardenFlower(
      id: 'flower-14',
      name: 'Peach bell bloom',
      emoji: '❁',
      color: Color(0xFFFFE1D6),
    ),
    GardenFlower(
      id: 'flower-15',
      name: 'Buttercup rosette',
      emoji: '✾',
      color: Color(0xFFFFF1C2),
    ),
    GardenFlower(
      id: 'flower-16',
      name: 'Blush petal charm',
      emoji: '✽',
      color: Color(0xFFFFDDE7),
    ),
    GardenFlower(
      id: 'flower-17',
      name: 'Lavender little star',
      emoji: '✻',
      color: Color(0xFFE9E0FF),
    ),
    GardenFlower(
      id: 'flower-18',
      name: 'Sweet snow blossom',
      emoji: '✼',
      color: Color(0xFFFFF4D0),
    ),
    GardenFlower(
      id: 'flower-19',
      name: 'Happy coral flower',
      emoji: '✺',
      color: Color(0xFFFFDFE5),
    ),
    GardenFlower(
      id: 'flower-20',
      name: 'Moonlight sparkle bloom',
      emoji: '❃',
      color: Color(0xFFEDE7FF),
    ),
  ];

  static const _quoteSeedYear = 2000;
  static const dailyChallengeCount = 10;
  static const growthStagesPerFlower = 10;
  static const activeFlowerVisualStages = 8;

  DateTime get now => _clock().toLocal();
  String get todayKey => dateKey(now);
  String get dailyContentDate =>
      backend == null ? todayKey : _backendDate ?? todayKey;
  List<DailyChallenge> get dailyChallenges => backend != null
      ? _backendChallenges ?? const <DailyChallenge>[]
      : challengesFor(now);
  DailyChallenge? get dailyChallenge => dailyChallenges.firstOrNull;
  String get dailyQuote =>
      backend != null ? _backendQuote ?? quoteFor(now) : quoteFor(now);
  Set<String> get completedToday =>
      Set.unmodifiable(_dailyCompletions[dailyContentDate] ?? const <String>[]);
  int get completedTodayCount => completedToday.length;
  bool get isDailyChallengeComplete =>
      dailyChallenges.isNotEmpty &&
      completedToday.length == dailyChallenges.length;
  bool isChallengeSaving(String challengeId) =>
      _pendingDailyChallengeIds.contains(challengeId);
  bool isChallengeUndoing(String challengeId) =>
      _pendingDailyChallengeIds.contains(challengeId);

  List<MoodEntry> get moodEntries => List.unmodifiable(_moodEntries);
  List<MemoryEntry> get memories => List.unmodifiable(_memories);
  int get completedChallengeCount =>
      _completedChallengeIds.length +
      _dailyCompletions.values.fold<int>(0, (sum, ids) => sum + ids.length);
  int get unlockedFlowerCount => unlockedFlowers.length;
  int get growthPoints => _growthPoints;
  int get growthStage =>
      (_growthPoints *
              (activeFlowerVisualStages - 1) ~/
              (growthStagesPerFlower - 1))
          .clamp(0, activeFlowerVisualStages - 1);
  int get lifetimeGrowthPoints => _lifetimeGrowthPoints;
  String? get activeFlowerId => _activeFlowerId;
  GardenFlower? get activeFlower {
    final id = _activeFlowerId;
    if (id == null) return null;
    return _flowerCatalog.where((flower) => flower.id == id).firstOrNull;
  }

  List<GardenFlower> get flowerCatalog => List.unmodifiable(_flowerCatalog);
  double get activeFlowerProgress => _growthPoints / growthStagesPerFlower;
  int get petalCount => unlockedFlowerCount;
  bool get isFullBloom =>
      _flowerCatalog.isNotEmpty &&
      _activeFlowerId == null &&
      unlockedFlowerCount == _flowerCatalog.length;
  double get gardenProgressValue =>
      _flowerCatalog.isEmpty ? 0 : unlockedFlowerCount / _flowerCatalog.length;
  List<GardenFlower> get unlockedFlowers => List.unmodifiable(
    _flowerCatalog.where((flower) => _flowerUnlockDates.containsKey(flower.id)),
  );
  Map<String, String?> get flowerUnlockDates =>
      Map.unmodifiable(_flowerUnlockDates);

  bool isChallengeComplete(String id) =>
      _completedChallengeIds.contains(id) || completedToday.contains(id);

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DailyChallenge challengeFor(DateTime date) =>
      challengesFor(date).first;

  static List<DailyChallenge> challengesFor(DateTime date) {
    final start =
        (_dayIndex(date) * dailyChallengeCount % challenges.length +
            challenges.length) %
        challenges.length;
    return List.unmodifiable([
      for (var offset = 0; offset < dailyChallengeCount; offset++)
        challenges[(start + offset) % challenges.length],
    ]);
  }

  static String quoteFor(DateTime date) =>
      quotes[(_dayIndex(date) % quotes.length + quotes.length) % quotes.length];

  static String greetingFor(DateTime date, String displayName) {
    final period = switch (date.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    final name = displayName.trim().isEmpty
        ? 'flower friend'
        : displayName.trim();
    return '$period, $name!';
  }

  static int _dayIndex(DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(_quoteSeedYear)).inDays;

  void refreshForResume() {
    _lastObservedDateKey = todayKey;
    _lastBackendDateCheck = DateTime.now();
    unawaited(_refreshBackendDailyContent());
  }

  Future<void> refreshDailyChallenges() async {
    if (backend == null) return;
    final dailyContent = await backend!.loadDailyContent();
    final progress = await backend!.loadGardenProgress();
    if (_isDisposed) return;
    _setBackendDailyContent(dailyContent);
    _replaceGardenProgress(progress);
    loadError = null;
    _notifyListenersIfAlive();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dateRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    isLoading = true;
    loadError = null;
    _notifyListenersIfAlive();
    try {
      _lastObservedDateKey = todayKey;
      _lastBackendDateCheck = DateTime.now();
      _dateRefreshTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
        final currentDate = todayKey;
        if (currentDate != _lastObservedDateKey) {
          _lastObservedDateKey = currentDate;
          _lastBackendDateCheck = DateTime.now();
          unawaited(_refreshBackendDailyContent());
          return;
        }
        final lastCheck = _lastBackendDateCheck;
        if (backend != null &&
            (lastCheck == null ||
                DateTime.now().difference(lastCheck) >=
                    const Duration(minutes: 15))) {
          _lastBackendDateCheck = DateTime.now();
          unawaited(_checkBackendDailyContentDate());
        }
      });
      if (backend != null) {
        await _loadBackendState();
        return;
      }
      final results = await Future.wait([
        storage.loadCompletedChallenges(),
        storage.loadMoods(),
        storage.loadMemories(),
        storage.loadGardenProgress(),
      ]);
      _completedChallengeIds
        ..clear()
        ..addAll(
          (results[0] as List<String>).where(
            (id) => challenges.any((challenge) => challenge.id == id),
          ),
        );
      _moodEntries
        ..clear()
        ..addAll(results[1] as List<MoodEntry>);
      _memories
        ..clear()
        ..addAll(results[2] as List<MemoryEntry>);
      final savedProgress = results[3] as GardenProgressData;
      _dailyCompletions
        ..clear()
        ..addAll(_validCompletions(savedProgress.dailyCompletions));
      _flowerUnlockDates
        ..clear()
        ..addAll(_validFlowerUnlocks(savedProgress.flowerUnlockDates));
      _growthPoints = savedProgress.growthPoints.clamp(
        0,
        growthStagesPerFlower - 1,
      );
      _lifetimeGrowthPoints = savedProgress.lifetimeGrowthPoints < 0
          ? 0
          : savedProgress.lifetimeGrowthPoints;
      _activeFlowerId = savedProgress.activeFlowerId;
      _migrateFlowerProgress();
      await _saveGardenProgress();
    } catch (error) {
      loadError = error;
    } finally {
      isLoading = false;
      _notifyListenersIfAlive();
    }
  }

  Future<bool> completeDailyChallenge(String challengeId) async {
    if (!_pendingDailyChallengeIds.add(challengeId)) return false;
    _notifyListenersIfAlive();
    try {
      return await _completeDailyChallenge(challengeId);
    } finally {
      _pendingDailyChallengeIds.remove(challengeId);
      _notifyListenersIfAlive();
    }
  }

  Future<bool> undoDailyChallenge(String challengeId) async {
    if (!_pendingDailyChallengeIds.add(challengeId)) return false;
    _notifyListenersIfAlive();
    try {
      return await _undoDailyChallenge(challengeId);
    } finally {
      _pendingDailyChallengeIds.remove(challengeId);
      _notifyListenersIfAlive();
    }
  }

  Future<bool> _undoDailyChallenge(String challengeId) async {
    if (backend != null) {
      final content = await backend!.loadDailyContent();
      _setBackendDailyContent(content);
      if (!content.challenges.any((challenge) => challenge.id == challengeId)) {
        throw StateError(
          'This challenge is no longer assigned for ${content.date}; its '
          'completion cannot be undone from today.',
        );
      }
      if (!(_dailyCompletions[content.date]?.contains(challengeId) ?? false)) {
        return false;
      }
      final wasUndone = await backend!.undoChallenge(content.date, challengeId);
      if (!wasUndone) {
        _replaceDailyCompletions(
          content.date,
          await backend!.loadDailyChallengeCompletions(content.date),
        );
        await _loadBackendGardenProgress();
        _notifyListenersIfAlive();
        return false;
      }
      _removeDailyCompletion(content.date, challengeId);
      _notifyListenersIfAlive();
      await _loadBackendGardenProgress(allowGrowthRollback: true);
      loadError = null;
      _notifyListenersIfAlive();
      return true;
    }

    final date = todayKey;
    final completions = _dailyCompletions[date];
    if (completions == null || !completions.contains(challengeId)) {
      return false;
    }
    final previousActiveFlowerId = _activeFlowerId;
    final previousGrowthPoints = _growthPoints;
    final previousLifetimeGrowthPoints = _lifetimeGrowthPoints;
    final previousUnlockDates = Map<String, String?>.of(_flowerUnlockDates);
    _removeDailyCompletion(date, challengeId);
    if (_lifetimeGrowthPoints > 0) _lifetimeGrowthPoints--;
    _reconcileLocalFlowerUnlocks();
    try {
      await _saveGardenProgress();
    } catch (_) {
      _addDailyCompletion(date, challengeId);
      _flowerUnlockDates
        ..clear()
        ..addAll(previousUnlockDates);
      _activeFlowerId = previousActiveFlowerId;
      _growthPoints = previousGrowthPoints;
      _lifetimeGrowthPoints = previousLifetimeGrowthPoints;
      rethrow;
    }
    _notifyListenersIfAlive();
    return true;
  }

  void _reconcileLocalFlowerUnlocks() {
    final activeFlowerIndex = _lifetimeGrowthPoints ~/ growthStagesPerFlower;
    final unlockedFlowerCount = (activeFlowerIndex + 1).clamp(
      0,
      _flowerCatalog.length,
    );
    for (final flower in _flowerCatalog.skip(unlockedFlowerCount)) {
      _flowerUnlockDates.remove(flower.id);
    }
    for (var index = 0; index < unlockedFlowerCount; index++) {
      _flowerUnlockDates.putIfAbsent(_flowerCatalog[index].id, () => null);
    }
    _activeFlowerId = activeFlowerIndex < _flowerCatalog.length
        ? _flowerCatalog[activeFlowerIndex].id
        : null;
    _growthPoints = _activeFlowerId == null
        ? 0
        : _lifetimeGrowthPoints % growthStagesPerFlower;
  }

  Future<bool> _completeDailyChallenge(String challengeId) async {
    if (backend != null) {
      final content = await backend!.loadDailyContent();
      final assignmentsChanged =
          _backendDate != content.date ||
          !_sameChallengeIds(_backendChallenges, content.challenges);
      _setBackendDailyContent(content);
      if (assignmentsChanged) _notifyListenersIfAlive();
      if (!content.challenges.any((challenge) => challenge.id == challengeId)) {
        throw StateError(
          'This challenge is no longer assigned for ${content.date}. '
          'Refresh the daily challenges and try again.',
        );
      }

      final completedToday = _dailyCompletions[content.date] ?? const [];
      if (completedToday.contains(challengeId)) return false;

      final completed = await backend!.completeChallenge(
        content.date,
        challengeId,
      );
      if (!completed) {
        late final List<String> dailyCompletions;
        try {
          dailyCompletions = await backend!.loadDailyChallengeCompletions(
            content.date,
          );
        } catch (error) {
          throw StateError(
            'The backend reported challenge "$challengeId" as already completed '
            'for ${content.date}, but the completion record could not be '
            'loaded for the authenticated user. Original Supabase error: '
            '$error',
          );
        }
        if (!dailyCompletions.contains(challengeId)) {
          throw StateError(
            'The backend reported challenge "$challengeId" as already '
            'completed for ${content.date}, but no matching row was returned '
            'for the authenticated user and backend-assigned date. Refresh '
            'daily challenges; if this persists, investigate the backend '
            'completion record.',
          );
        }
        _addDailyCompletion(content.date, challengeId);
        _notifyListenersIfAlive();
        try {
          await _loadBackendGardenProgress();
          loadError = null;
        } catch (error) {
          loadError = error;
          _notifyListenersIfAlive();
          throw ChallengeProgressRefreshException(
            challengeId: challengeId,
            localDate: content.date,
            wasAlreadyCompleted: true,
            cause: error,
          );
        }
        _notifyListenersIfAlive();
        return false;
      }
      _addDailyCompletion(content.date, challengeId);
      _notifyListenersIfAlive();
      try {
        await _loadBackendGardenProgress();
        loadError = null;
      } catch (error) {
        loadError = error;
        _notifyListenersIfAlive();
        throw ChallengeProgressRefreshException(
          challengeId: challengeId,
          localDate: content.date,
          wasAlreadyCompleted: false,
          cause: error,
        );
      }
      return true;
    }

    final date = todayKey;
    if (!dailyChallenges.any((challenge) => challenge.id == challengeId)) {
      return false;
    }
    final completedToday = _dailyCompletions.putIfAbsent(date, () => []);
    if (completedToday.contains(challengeId)) return false;

    completedToday.add(challengeId);
    final previousActiveFlowerId = _activeFlowerId;
    final previousGrowthPoints = _growthPoints;
    final previousLifetimeGrowthPoints = _lifetimeGrowthPoints;
    final previousUnlockDates = Map<String, String?>.of(_flowerUnlockDates);
    _lifetimeGrowthPoints++;
    final activeFlowerIndex = _lifetimeGrowthPoints ~/ growthStagesPerFlower;
    final unlockedFlowerCount = (activeFlowerIndex + 1).clamp(
      0,
      _flowerCatalog.length,
    );
    for (var index = 0; index < unlockedFlowerCount; index++) {
      _flowerUnlockDates.putIfAbsent(
        _flowerCatalog[index].id,
        () => index == 0 ? null : date,
      );
    }
    _activeFlowerId = activeFlowerIndex < _flowerCatalog.length
        ? _flowerCatalog[activeFlowerIndex].id
        : null;
    _growthPoints = _activeFlowerId == null
        ? 0
        : _lifetimeGrowthPoints % growthStagesPerFlower;
    try {
      await _saveGardenProgress();
    } catch (_) {
      completedToday.remove(challengeId);
      if (completedToday.isEmpty) _dailyCompletions.remove(date);
      _flowerUnlockDates
        ..clear()
        ..addAll(previousUnlockDates);
      _activeFlowerId = previousActiveFlowerId;
      _growthPoints = previousGrowthPoints;
      _lifetimeGrowthPoints = previousLifetimeGrowthPoints;
      rethrow;
    }
    _notifyListenersIfAlive();
    return true;
  }

  Future<void> _saveGardenProgress() => storage.saveGardenProgress(
    GardenProgressData(
      dailyCompletions: Map.of(_dailyCompletions),
      flowerUnlockDates: Map.of(_flowerUnlockDates),
      activeFlowerId: _activeFlowerId,
      growthPoints: _growthPoints,
      lifetimeGrowthPoints: _lifetimeGrowthPoints,
    ),
  );

  Map<String, List<String>> _validCompletions(Map<String, List<String>> saved) {
    final valid = <String, List<String>>{};
    for (final entry in saved.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null || dateKey(date) != entry.key) continue;
      final completedIds = entry.value
          .where((id) => challenges.any((challenge) => challenge.id == id))
          .toSet()
          .toList();
      if (completedIds.isNotEmpty) {
        valid[entry.key] = completedIds;
      }
    }
    return valid;
  }

  Map<String, String?> _validFlowerUnlocks(Map<String, String?> saved) {
    final knownIds = _flowerCatalog.map((flower) => flower.id).toSet();
    final valid = <String, String?>{};
    for (final entry in saved.entries) {
      if (!knownIds.contains(entry.key)) continue;
      final date = entry.value;
      if (date == null || DateTime.tryParse(date) != null) {
        valid[entry.key] = date;
      }
    }
    return valid;
  }

  void _migrateFlowerProgress() {
    if (_flowerCatalog.isEmpty) {
      _activeFlowerId = null;
      _growthPoints = 0;
      return;
    }

    if (backend == null) {
      _flowerUnlockDates.putIfAbsent(_flowerCatalog.first.id, () => null);
      final dailyCompletionCount = _dailyCompletions.values.fold<int>(
        0,
        (sum, ids) => sum + ids.length,
      );
      final legacyCompletionCount =
          _completedChallengeIds.length > dailyCompletionCount
          ? _completedChallengeIds.length
          : dailyCompletionCount;
      if (_lifetimeGrowthPoints == 0) {
        _lifetimeGrowthPoints = legacyCompletionCount > _growthPoints
            ? legacyCompletionCount
            : _growthPoints;
      }
      _growthPoints = _lifetimeGrowthPoints % growthStagesPerFlower;
    }
    final activeFlowerIndex = _lifetimeGrowthPoints ~/ growthStagesPerFlower;
    final unlockedFlowerCount = (activeFlowerIndex + 1).clamp(
      0,
      _flowerCatalog.length,
    );
    if (backend == null) {
      for (var index = 0; index < unlockedFlowerCount; index++) {
        _flowerUnlockDates.putIfAbsent(_flowerCatalog[index].id, () => null);
      }
    }
    if (activeFlowerIndex >= _flowerCatalog.length) {
      _activeFlowerId = null;
      _growthPoints = 0;
      return;
    }
    _activeFlowerId = _flowerCatalog[activeFlowerIndex].id;
    _growthPoints = _lifetimeGrowthPoints % growthStagesPerFlower;
  }

  Future<void> addMoodEntry(MoodEntry entry) async {
    if (backend != null) await backend!.saveMood(entry);
    final updated = [entry, ..._moodEntries];
    await storage.saveMoods(updated);
    if (_isDisposed) return;
    _moodEntries
      ..clear()
      ..addAll(updated);
    _notifyListenersIfAlive();
  }

  Future<void> addMemory(MemoryEntry memory) async {
    final savedMemory = backend == null
        ? memory
        : await backend!.addMemory(memory);
    final updated = [savedMemory, ..._memories];
    await storage.saveMemories(updated);
    if (_isDisposed) return;
    _memories
      ..clear()
      ..addAll(updated);
    _notifyListenersIfAlive();
  }

  Future<void> updateMemory(MemoryEntry memory) async {
    if (backend != null) await backend!.updateMemory(memory);
    final updated = [
      for (final current in _memories)
        if (current.id == memory.id) memory else current,
    ];
    await storage.saveMemories(updated);
    if (_isDisposed) return;
    _memories
      ..clear()
      ..addAll(updated);
    _notifyListenersIfAlive();
  }

  Future<void> deleteMemory(String id) async {
    MemoryEntry? entry;
    for (final memory in _memories) {
      if (memory.id == id) {
        entry = memory;
        break;
      }
    }
    if (entry == null) return;
    if (backend != null) await backend!.deleteMemory(entry);
    await storage.deleteMediaFile(entry);
    final updated = _memories.where((memory) => memory.id != id).toList();
    await storage.saveMemories(updated);
    if (_isDisposed) return;
    _memories
      ..clear()
      ..addAll(updated);
    _notifyListenersIfAlive();
  }

  Future<void> _loadBackendState() async {
    final dailyContent = await backend!.loadDailyContent();
    _setBackendDailyContent(dailyContent);
    final results = await Future.wait([
      backend!.loadGardenProgress(),
      backend!.loadMoods(),
      backend!.loadMemories(),
    ]);
    _replaceGardenProgress(results[0] as GardenProgressData);
    _moodEntries
      ..clear()
      ..addAll(results[1] as List<MoodEntry>);
    _memories
      ..clear()
      ..addAll(results[2] as List<MemoryEntry>);
  }

  Future<void> _refreshBackendDailyContent() async {
    if (backend == null) {
      _notifyListenersIfAlive();
      return;
    }
    try {
      await refreshDailyChallenges();
    } catch (error) {
      loadError = error;
      _notifyListenersIfAlive();
    }
  }

  Future<void> _checkBackendDailyContentDate() async {
    try {
      final content = await backend!.loadDailyContent();
      final changed =
          _backendDate != content.date ||
          !_sameChallengeIds(_backendChallenges, content.challenges) ||
          _backendQuote != content.quote;
      if (!changed) return;
      final progress = await backend!.loadGardenProgress();
      if (_isDisposed) return;
      _setBackendDailyContent(content);
      _replaceGardenProgress(progress);
      loadError = null;
      _notifyListenersIfAlive();
    } catch (error) {
      loadError = error;
      _notifyListenersIfAlive();
    }
  }

  Future<void> _loadBackendGardenProgress({
    bool allowGrowthRollback = false,
  }) async {
    _replaceGardenProgress(
      await backend!.loadGardenProgress(),
      allowGrowthRollback: allowGrowthRollback,
    );
  }

  void _setBackendDailyContent(DailyContent content) {
    _backendDate = content.date;
    _backendChallenges = content.challenges;
    _backendQuote = content.quote;
  }

  bool _sameChallengeIds(
    List<DailyChallenge>? first,
    List<DailyChallenge> second,
  ) {
    if (first == null || first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].id != second[index].id) return false;
    }
    return true;
  }

  void _notifyListenersIfAlive() {
    if (!_isDisposed) notifyListeners();
  }

  void _addDailyCompletion(String date, String challengeId) {
    final completions = _dailyCompletions.putIfAbsent(date, () => []);
    if (!completions.contains(challengeId)) completions.add(challengeId);
  }

  void _removeDailyCompletion(String date, String challengeId) {
    final completions = _dailyCompletions[date];
    completions?.remove(challengeId);
    if (completions?.isEmpty ?? false) _dailyCompletions.remove(date);
    if (dailyContentDate == date) _completedChallengeIds.remove(challengeId);
  }

  void _replaceDailyCompletions(String date, List<String> challengeIds) {
    if (challengeIds.isEmpty) {
      _dailyCompletions.remove(date);
    } else {
      _dailyCompletions[date] = List.of(challengeIds);
    }
    if (dailyContentDate == date) {
      _completedChallengeIds
        ..removeWhere(
          (id) => _backendChallenges?.any(
            (challenge) => challenge.id == id,
          ) ?? false,
        )
        ..addAll(challengeIds);
    }
  }

  void _replaceGardenProgress(
    GardenProgressData progress, {
    bool allowGrowthRollback = false,
  }) {
    if (backend != null || progress.flowerCatalog.isNotEmpty) {
      final defaultFlowers = {for (final flower in flowers) flower.id: flower};
      final uniqueFlowers = <String, GardenFlower>{};
      for (final flower in progress.flowerCatalog) {
        uniqueFlowers.putIfAbsent(
          flower.id,
          () => GardenFlower(
            id: flower.id,
            name: flower.name,
            emoji: flower.emoji,
            color: defaultFlowers[flower.id]?.color ?? flower.color,
            sortOrder: flower.sortOrder,
          ),
        );
      }
      _flowerCatalog = List.unmodifiable(
        uniqueFlowers.values.toList()..sort((first, second) {
          final byOrder = first.sortOrder.compareTo(second.sortOrder);
          return byOrder != 0 ? byOrder : first.id.compareTo(second.id);
        }),
      );
    }
    final validCompletions = _validCompletions(progress.dailyCompletions);
    if (allowGrowthRollback) _dailyCompletions.clear();
    for (final entry in validCompletions.entries) {
      final completions = _dailyCompletions.putIfAbsent(entry.key, () => []);
      for (final challengeId in entry.value) {
        if (!completions.contains(challengeId)) {
          completions.add(challengeId);
        }
      }
    }
    final validUnlocks = _validFlowerUnlocks(progress.flowerUnlockDates);
    if (allowGrowthRollback) {
      _flowerUnlockDates
        ..clear()
        ..addAll(validUnlocks);
    } else {
      _flowerUnlockDates.addAll(validUnlocks);
    }
    if (allowGrowthRollback ||
        progress.lifetimeGrowthPoints >= _lifetimeGrowthPoints) {
      _growthPoints = progress.growthPoints.clamp(0, growthStagesPerFlower - 1);
      _lifetimeGrowthPoints = progress.lifetimeGrowthPoints;
      _activeFlowerId = progress.activeFlowerId;
    }
    _migrateFlowerProgress();
  }
}
