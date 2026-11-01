import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petalpop/main.dart';
import 'package:petalpop/models/garden_progress.dart';
import 'package:petalpop/models/memory_entry.dart';
import 'package:petalpop/models/mood_entry.dart';
import 'package:petalpop/screens/auth_screen.dart';
import 'package:petalpop/screens/flower_garden_screen.dart';
import 'package:petalpop/screens/daily_challenges_screen.dart';
import 'package:petalpop/screens/memory_journal_screen.dart';
import 'package:petalpop/screens/home_screen.dart';
import 'package:petalpop/screens/mood_checkin_screen.dart';
import 'package:petalpop/screens/profile_screen.dart';
import 'package:petalpop/screens/settings_screen.dart';
import 'package:petalpop/services/app_session.dart';
import 'package:petalpop/services/local_data_service.dart';
import 'package:petalpop/theme/app_theme.dart';
import 'package:petalpop/widgets/flower_illustration.dart';
import 'package:petalpop/widgets/mood_face_illustration.dart';
import 'package:petalpop/widgets/app_widgets.dart';
import 'package:petalpop/widgets/profile_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late MemoryLocalDataService _storage;

void main() {
  setUp(() {
    _storage = MemoryLocalDataService();
  });

  testWidgets('welcome screen shows branding and future account actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('PetalPop'), findsOneWidget);
    expect(find.text('Your Daily Happy Space'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);

    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue in demo mode'), findsOneWidget);
    expect(
      find.textContaining('authentication is not connected'),
      findsOneWidget,
    );
  });

  testWidgets('sign up validates inputs and continues in demo mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Sign Up'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Create a happy space'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue in demo mode'));
    await tester.tap(find.text('Continue in demo mode'));
    await tester.pump();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Daisy Bloom');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(2), 'flower123');
    await tester.enterText(find.byType(TextFormField).at(3), 'different123');
    await tester.ensureVisible(find.text('Continue in demo mode'));
    await tester.tap(find.text('Continue in demo mode'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'daisy@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(3), 'flower123');
    await tester.ensureVisible(find.text('Continue in demo mode'));
    await tester.tap(find.text('Continue in demo mode'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Daisy Bloom!'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('My Mood'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('My Mood'), findsOneWidget);
  });

  testWidgets('demo login validates fields and opens Home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Continue in demo mode'));
    await tester.tap(find.text('Continue in demo mode'));
    await tester.pump();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'daisy@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'flower123');
    await tester.ensureVisible(find.text('Continue in demo mode'));
    await tester.tap(find.text('Continue in demo mode'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.text('My Mood'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('My Mood'), findsOneWidget);
  });

  testWidgets('configured sign-up submits account details to auth handler', (
    WidgetTester tester,
  ) async {
    AuthMode? submittedMode;
    String? submittedEmail;
    String? submittedName;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          mode: AuthMode.signUp,
          onBack: () {},
          onContinueAsDemo: (_) {},
          onAuthenticate:
              ({
                required AuthMode mode,
                required String email,
                required String password,
                required String? displayName,
              }) async {
                submittedMode = mode;
                submittedEmail = email;
                submittedName = displayName;
                return null;
              },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Daisy Bloom');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'daisy@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'flower123');
    await tester.enterText(find.byType(TextFormField).at(3), 'flower123');
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(submittedMode, AuthMode.signUp);
    expect(submittedEmail, 'daisy@example.com');
    expect(submittedName, 'Daisy Bloom');
  });

  testWidgets('configured login submits credentials to auth handler', (
    WidgetTester tester,
  ) async {
    AuthMode? submittedMode;
    String? submittedEmail;
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          mode: AuthMode.logIn,
          onBack: () {},
          onContinueAsDemo: (_) {},
          onAuthenticate:
              ({
                required AuthMode mode,
                required String email,
                required String password,
                required String? displayName,
              }) async {
                submittedMode = mode;
                submittedEmail = email;
                submittedPassword = password;
                return null;
              },
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'daisy@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'flower123');
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(submittedMode, AuthMode.logIn);
    expect(submittedEmail, 'daisy@example.com');
    expect(submittedPassword, 'flower123');
  });

  testWidgets('login shows friendly guidance for an offline auth request', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          mode: AuthMode.logIn,
          onBack: () {},
          onContinueAsDemo: (_) {},
          onAuthenticate:
              ({
                required AuthMode mode,
                required String email,
                required String password,
                required String? displayName,
              }) async {
                throw AuthRetryableFetchException(
                  message: 'SocketException: Failed host lookup',
                );
              },
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'daisy@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'flower123');
    await tester.tap(find.text('Log In'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Could not connect to PetalPop. Check your internet connection and '
        'try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('SocketException'), findsNothing);
  });

  testWidgets(
    'restored session opens Home offline and logout returns to welcome',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = SupabaseClient(
        'http://127.0.0.1:1',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                'sub': 'offline-user',
                'role': 'authenticated',
              }),
            ),
          )
          .replaceAll('=', '');
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': 'eyJhbGciOiJub25lIn0.$payload.signature',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'offline-refresh-token',
          'user': {
            'id': 'offline-user',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'daisy@example.com',
            'app_metadata': {
              'provider': 'email',
              'providers': ['email'],
            },
            'user_metadata': {'display_name': 'Daisy'},
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        }),
      );

      await tester.pumpWidget(PetalPopApp(storage: _storage, client: client));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);

      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final settingsList = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Log Out'),
        240,
        scrollable: settingsList,
      );
      await tester.tap(find.text('Log Out'));
      await tester.pump();
      expect(find.text('Log out of PetalPop?'), findsOneWidget);
      await tester.tap(find.text('Log Out').last);
      await tester.pump();

      expect(find.text('Your Daily Happy Space'), findsOneWidget);
      expect(client.auth.currentUser, isNull);
      client.dispose();
    },
  );

  testWidgets('four bottom tabs navigate and Home opens Mood and Memories', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);

    expect(find.textContaining('Sunshine!'), findsOneWidget);
    expect(find.byTooltip('My Profile'), findsNothing);
    expect(find.byType(FlowerIllustration), findsOneWidget);
    final homeAvatar = find.descendant(
      of: find.byType(HomeScreen),
      matching: find.byType(ProfileAvatar),
    );
    expect(homeAvatar, findsOneWidget);
    await tester.tap(homeAvatar, warnIfMissed: false);
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar.destinations.whereType<NavigationDestination>().map(
        (destination) => destination.label,
      ),
      ['Home', 'Challenges', 'Garden', 'Profile'],
    );
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('All quiet in the garden'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await tester.tap(find.byTooltip('Back to Home'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("Today's Challenge"), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('My Mood'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('My Mood'), findsOneWidget);
    expect(find.text("Today's Challenge"), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('“Bloom your day, one petal at a time.”'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('“Bloom your day, one petal at a time.”'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('0 of 10 completed today'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('0 of 10 completed today'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('My Garden'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('My Garden'), findsOneWidget);
    expect(find.text('View Garden'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-view-garden')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('My happy garden'), findsOneWidget);

    for (final (tab, heading) in [
      ('Challenges', 'Today’s happy challenges'),
      ('Garden', 'My happy garden'),
      ('Profile', 'Edit name'),
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text(heading),
        findsOneWidget,
        reason: '$tab tab did not open',
      );
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.text('Home').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const ValueKey('home-mood-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-mood-card')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('How are you feeling today?'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(
      find.byKey(const ValueKey('home-memories-card')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-memories-card')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Little memory journal'), findsOneWidget);
  });

  testWidgets('Home shortcut cards activate their direct navigation actions', (
    WidgetTester tester,
  ) async {
    final session = AppSession(_storage);
    await session.initialize();
    var challengeOpens = 0;
    var moodOpens = 0;
    var memoryOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            session: session,
            onOpenMood: () => moodOpens++,
            onOpenMemories: () => memoryOpens++,
            onOpenChallenges: () => challengeOpens++,
            onOpenGarden: () {},
            displayName: 'Daisy',
            avatarId: 'daisy',
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('home-mood-card'))),
      tester.getSize(find.byKey(const ValueKey('home-memories-card'))),
    );

    final challengeCard = find.byKey(
      const ValueKey('home-today-challenge-card'),
    );
    await tester.ensureVisible(challengeCard);
    await tester.pumpAndSettle();
    await tester.tap(challengeCard);
    await tester.tap(
      find.descendant(
        of: challengeCard,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
    );
    expect(challengeOpens, 2);

    final moodCard = find.byKey(const ValueKey('home-mood-card'));
    await tester.ensureVisible(moodCard);
    await tester.pumpAndSettle();
    final moodSize = tester.getSize(moodCard);
    await tester.tapAt(
      tester.getTopLeft(moodCard) + Offset(moodSize.width - 12, 60),
    );
    expect(moodOpens, 1);

    final memoryCard = find.byKey(const ValueKey('home-memories-card'));
    await tester.ensureVisible(memoryCard);
    await tester.pumpAndSettle();
    final memorySize = tester.getSize(memoryCard);
    await tester.tapAt(
      tester.getTopLeft(memoryCard) + Offset(memorySize.width - 12, 60),
    );
    expect(memoryOpens, 1);
    expect(find.text('View Garden'), findsOneWidget);
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  testWidgets('Profile statistics reflect saved application state', (
    WidgetTester tester,
  ) async {
    _storage.challenges.add('drink-water');
    _storage.memories.add(
      MemoryEntry(
        id: 'memory-1',
        type: MemoryType.note,
        title: 'A little moment',
        description: 'A saved note',
        createdAt: DateTime(2026, 10, 26),
      ),
    );
    _storage.gardenProgress = const GardenProgressData(
      flowerUnlockDates: {'flower-01': '2026-10-20'},
      activeFlowerId: 'flower-02',
      growthPoints: 2,
      lifetimeGrowthPoints: 12,
    );

    await _openHome(tester);
    await tester.tap(find.text('Profile').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(
        of: find.widgetWithText(PetalCard, 'Challenges'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(PetalCard, 'Petals'),
        matching: find.text('12'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(PetalCard, 'Memories'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    for (final (key, label, value) in [
      ('profile-challenges-stat', 'Challenges', '1'),
      ('profile-petals-stat', 'Petals', '12'),
      ('profile-memories-stat', 'Memories', '1'),
      ('profile-garden-stat', 'Garden', '2/20'),
    ]) {
      final statCard = find.byKey(ValueKey(key));
      expect(
        find.descendant(of: statCard, matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: statCard, matching: find.text(value)),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('Garden').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sunny daisy'), findsWidgets);
    expect(find.text('2/10 petals'), findsOneWidget);
  });

  testWidgets('Help and Support shows a tappable support email', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    final profileScrollable = find.descendant(
      of: find.byType(ProfileScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Help & Support'),
      240,
      scrollable: profileScrollable.first,
    );
    await tester.ensureVisible(find.text('Help & Support'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();

    final email = find.text('reynaannjoybausin@gmail.com');
    expect(email, findsOneWidget);
    final link = find.ancestor(of: email, matching: find.byType(InkWell));
    expect(link, findsOneWidget);
    expect(tester.widget<InkWell>(link).onTap, isNotNull);
  });

  testWidgets('Home greeting uses the saved name and updates on resume', (
    WidgetTester tester,
  ) async {
    var time = DateTime(2026, 10, 26, 9);
    _storage.profile['name'] = 'Daisy';
    await _openHome(tester, clock: () => time);

    expect(find.text('Good morning, Daisy!'), findsOneWidget);
    time = DateTime(2026, 10, 26, 14);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Good afternoon, Daisy!'), findsOneWidget);

    time = DateTime(2026, 10, 26, 19);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Good evening, Daisy!'), findsOneWidget);
  });

  testWidgets('empty profile name gets a friendly greeting fallback', (
    WidgetTester tester,
  ) async {
    _storage.profile['name'] = '  ';
    await _openHome(tester, clock: () => DateTime(2026, 10, 26, 9));

    expect(find.text('Good morning, flower friend!'), findsOneWidget);
  });

  testWidgets('changing the profile name updates the Home greeting', (
    WidgetTester tester,
  ) async {
    await _openHome(tester, clock: () => DateTime(2026, 10, 26, 9));
    await tester.tap(find.text('Profile').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Edit name'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Clover');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_storage.profile['name'], 'Clover');
    await tester.tap(find.text('Home').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Good morning, Clover!'), findsOneWidget);
  });

  test('daily challenge and quote are deterministic per local date', () async {
    var time = DateTime(2026, 10, 26, 9);
    final session = AppSession(_storage, clock: () => time);
    await session.initialize();
    final challenges = session.dailyChallenges;
    final quote = session.dailyQuote;

    session.refreshForResume();
    expect(
      session.dailyChallenges.map((challenge) => challenge.id),
      challenges.map((challenge) => challenge.id),
    );
    expect(session.dailyQuote, quote);
    expect(AppSession.challenges.length, greaterThanOrEqualTo(30));
    expect(session.dailyChallenges, hasLength(10));
    expect(
      AppSession.challenges.map((challenge) => challenge.id).toSet().length,
      AppSession.challenges.length,
    );
    expect(AppSession.quotes.length, 30);
    expect(AppSession.flowers, hasLength(20));
    expect(
      AppSession.flowers.map((flower) => flower.emoji).toSet(),
      hasLength(20),
    );

    time = time.add(const Duration(days: 1));
    session.refreshForResume();
    expect(
      session.dailyChallenges.map((challenge) => challenge.id).toSet(),
      isNot(equals(challenges.map((challenge) => challenge.id).toSet())),
    );
    expect(session.dailyChallenges, hasLength(10));
    expect(session.dailyQuote, isNot(quote));

    final seenChallengeIds = <String>{};
    for (var day = 0; day < 6; day++) {
      final date = DateTime(2026, 10, 26 + day, 9);
      final dailyIds = AppSession.challengesFor(
        date,
      ).map((challenge) => challenge.id).toSet();
      expect(dailyIds.intersection(seenChallengeIds), isEmpty);
      seenChallengeIds.addAll(dailyIds);
    }
    expect(seenChallengeIds, hasLength(60));
    session.dispose();
  });

  testWidgets('flower illustration repaints as petal progress changes', (
    WidgetTester tester,
  ) async {
    Widget flower(int petalCount) => MaterialApp(
      home: Scaffold(body: FlowerIllustration(petalCount: petalCount)),
    );

    await tester.pumpWidget(flower(1));
    final flowerPainter = find.descendant(
      of: find.byType(FlowerIllustration),
      matching: find.byType(CustomPaint),
    );
    final initialPainter = tester.widget<CustomPaint>(flowerPainter).painter!;

    await tester.pumpWidget(flower(2));
    final updatedPainter = tester.widget<CustomPaint>(flowerPainter).painter!;

    expect(initialPainter.shouldRepaint(updatedPainter), isTrue);
  });

  testWidgets('mood check-in requires a mood and saves a note', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-mood-card')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-mood-card')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MoodFaceIllustration), findsNWidgets(9));
    await tester.tap(find.text('Happy'));
    await tester.pump();
    final selectedMood = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Happy',
      ),
    );
    expect(selectedMood.properties.selected, isTrue);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'Had a sunny walk.');
    await tester.scrollUntilVisible(
      find.text('Save'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Happy'), findsWidgets);
    expect(find.text('Had a sunny walk.'), findsOneWidget);
    expect(
      find.text('Your mood check-in is saved on this device 💗'),
      findsOneWidget,
    );
  });

  testWidgets('mood screen remains scrollable on a small phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = AppSession(_storage);
    await session.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MoodCheckinScreen(session: session)),
      ),
    );

    for (final mood in [
      'Happy',
      'Excited',
      'Calm',
      'Tired',
      'Sad',
      'Angry',
      'Anxious',
      'Loved',
      'Other',
    ]) {
      expect(find.text(mood), findsOneWidget);
    }

    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.showKeyboard(find.byType(TextField));
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  testWidgets('memory journal validates fields and displays saved entry', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-memories-card')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-memories-card')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add a memory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save note'));
    await tester.pump();
    expect(find.text('Please add a title.'), findsOneWidget);
    expect(find.text('Write a few words about your memory.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Picnic day');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'We shared strawberries in the park.',
    );
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();

    expect(find.text('Picnic day'), findsOneWidget);
    expect(find.text('We shared strawberries in the park.'), findsOneWidget);
    expect(find.text('Note saved 🌷'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('memory save shows progress while persistence is pending', (
    WidgetTester tester,
  ) async {
    final saveGate = Completer<void>();
    _storage.memorySaveGate = saveGate;
    await _openHome(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-memories-card')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-memories-card')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add a memory'));
    await tester.pumpAndSettle();
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'Picnic day');
    await tester.enterText(find.byType(TextFormField).at(1), 'A sunny walk.');
    await tester.tap(find.text('Save note'));
    await tester.pump();

    expect(find.text('Saving memory…'), findsOneWidget);
    saveGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Picnic day'), findsOneWidget);
    expect(find.text('Note saved 🌷'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completing a challenge updates garden progress', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await tester.tap(find.text('Challenges').last);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Got it').first);
    await tester.pump();
    expect(
      find.text('Lovely work! Your flower grew a little 🌱'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Undo'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Garden').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1/10 petals'), findsOneWidget);
  });

  testWidgets('settings edit profile and switch the app theme', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await tester.tap(find.text('Profile').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Edit Profile'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Daisy');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Daisy'), findsOneWidget);

    final settingsList = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(ListView),
    );
    await tester.drag(settingsList, const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.drag(settingsList, const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('About PetalPop'));
    await tester.tap(find.text('About PetalPop'));
    await tester.pump();
    expect(
      find.textContaining('push notifications are not configured.'),
      findsOneWidget,
    );
  });

  testWidgets('logout asks for confirmation and returns to welcome', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openHome(tester);
    await tester.tap(find.text('Challenges').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Got it').first);
    await tester.pump();

    await tester.tap(find.text('Home').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Profile').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(const Duration(milliseconds: 300));
    final settingsList = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    );
    await tester.drag(settingsList, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pump();

    expect(find.text('Log out of PetalPop?'), findsOneWidget);
    await tester.tap(find.text('Stay here'));
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);

    await tester.drag(settingsList, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pump();
    await tester.tap(find.text('Log Out').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('PetalPop'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Challenges').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1 of 10 completed today'), findsOneWidget);
    expect(find.textContaining('1 of 20 flowers unlocked'), findsOneWidget);
  });

  testWidgets('notification preference toggle is clearly session-only', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await tester.tap(find.text('Profile').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(const Duration(milliseconds: 300));

    final notificationSwitch = find.byType(SwitchListTile);
    expect(notificationSwitch, findsOneWidget);
    await tester.tap(notificationSwitch);
    await tester.pump();

    expect(
      find.textContaining('Phone notifications are not connected yet.'),
      findsOneWidget,
    );
    expect(tester.widget<SwitchListTile>(notificationSwitch).value, isTrue);
  });

  testWidgets(
    'profile lets users choose an avatar and keeps it after relaunch',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openHome(tester);
      await tester.tap(find.text('Profile').last);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(
        find
            .descendant(
              of: find.byType(ProfileScreen),
              matching: find.byType(ProfileAvatar),
            )
            .first,
      );
      await tester.pump();
      expect(find.text('Choose your avatar'), findsOneWidget);
      expect(find.byType(ProfileAvatar), findsNWidgets(13));
      for (final avatar in PetalAvatarChoice.choices) {
        expect(find.text(avatar.label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Bunny'));
      await tester.pump();
      expect(_storage.profile['avatar'], isNot('bunny'));
      await tester.tap(find.text('Save avatar'));
      await tester.pump();
      expect(_storage.profile['avatar'], 'bunny');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Get Started'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('My Mood'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('My Mood'), findsOneWidget);
      await tester.tap(find.text('Profile').last);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(
        find
            .descendant(
              of: find.byType(ProfileScreen),
              matching: find.byType(ProfileAvatar),
            )
            .first,
      );
      await tester.pump();
      expect(find.text('Choose your avatar'), findsOneWidget);
      expect(
        tester
            .widget<ProfileAvatar>(
              find
                  .descendant(
                    of: find.byType(ProfileScreen),
                    matching: find.byType(ProfileAvatar),
                  )
                  .first,
            )
            .avatarId,
        'bunny',
      );
    },
  );

  testWidgets('Memories shows compact filters and add-memory options', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-memories-card')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-memories-card')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Little memory journal'), findsOneWidget);
    expect(find.text('Keep the moments you want to remember.'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Add a photo from gallery'), findsNothing);
    expect(find.text('Your memories will bloom here'), findsOneWidget);
    expect(find.byTooltip('Add a memory'), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.text('Voice').first,
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No voice memories yet'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add a memory'));
    await tester.pumpAndSettle();
    expect(find.text('Add a Memory'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Voice'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add a memory'));
    await tester.pumpAndSettle();
    expect(find.text('Write a memory'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add a memory'));
    await tester.pumpAndSettle();
    expect(find.text('Add a Memory'), findsNothing);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add a memory'));
    await tester.pumpAndSettle();
    expect(find.text('Add a Memory'), findsNothing);
  });

  testWidgets('Memories grid filters types and toggles favorites', (
    WidgetTester tester,
  ) async {
    final session = AppSession(_storage);
    await session.initialize();
    for (final (id, type, title) in [
      ('photo', MemoryType.photo, 'Sunny afternoon'),
      ('note', MemoryType.note, 'A lovely day'),
      ('voice', MemoryType.voice, 'Voice memory'),
    ]) {
      await session.addMemory(
        MemoryEntry(
          id: id,
          type: type,
          title: title,
          description: type == MemoryType.note ? 'A lovely day outside.' : '',
          createdAt: DateTime(2026, 10, 27),
          durationSeconds: type == MemoryType.voice ? 32 : 0,
        ),
      );
    }

    expect(
      session.memories.map((memory) => memory.title),
      containsAll(['Sunny afternoon', 'A lovely day', 'Voice memory']),
    );
    expect(session.isLoading, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MemoryJournalScreen(session: session)),
      ),
    );
    expect(find.byKey(const ValueKey('note')), findsOneWidget);
    expect(find.byKey(const ValueKey('voice')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sunny afternoon'),
      240,
      scrollable: find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const ValueKey('photo')), findsOneWidget);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    expect(find.text('Sunny afternoon'), findsOneWidget);
    expect(find.text('A lovely day'), findsNothing);
    expect(find.text('Voice memory'), findsNothing);
    expect(find.byType(AspectRatio), findsOneWidget);

    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('♥ Added to favorites'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove favorite'));
    await tester.pump();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('Removed from favorites'), findsOneWidget);

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('A lovely day'), findsOneWidget);
    expect(find.text('Sunny afternoon'), findsNothing);

    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('voice')), findsOneWidget);
    expect(find.text('A lovely day'), findsNothing);
    expect(find.text('Sunny afternoon'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: PetalPopTheme.dark,
        home: Scaffold(body: MemoryJournalScreen(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    final noteCard = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('note')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (noteCard.decoration! as BoxDecoration).color,
      PetalPopTheme.dark.colorScheme.surface,
    );
    final noteTitle = tester.widget<Text>(find.text('A lovely day'));
    expect(
      noteTitle.style?.color,
      PetalPopTheme.dark.textTheme.labelLarge?.color,
    );
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  test(
    'unique challenge completions grow, persist, and unlock flowers',
    () async {
      var time = DateTime(2026, 10, 26, 9);
      final session = AppSession(_storage, clock: () => time);
      await session.initialize();

      expect(session.unlockedFlowerCount, 1);
      expect(session.completedTodayCount, 0);
      final activeFlowerId = session.activeFlowerId;
      final challengesToday = session.dailyChallenges;
      for (final challenge in challengesToday.take(6)) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }

      expect(session.growthPoints, 6);
      expect(session.growthStage, 4);
      expect(session.unlockedFlowerCount, 1);
      expect(session.activeFlowerId, activeFlowerId);
      expect(
        await session.completeDailyChallenge(challengesToday.first.id),
        isFalse,
      );
      expect(session.growthPoints, 6);
      expect(session.completedTodayCount, 6);

      final restoredSession = AppSession(_storage, clock: () => time);
      await restoredSession.initialize();
      expect(restoredSession.growthPoints, 6);
      expect(restoredSession.lifetimeGrowthPoints, 6);
      expect(restoredSession.completedTodayCount, 6);
      expect(restoredSession.activeFlowerId, activeFlowerId);

      time = time.add(const Duration(days: 2));
      restoredSession.refreshForResume();
      expect(restoredSession.completedTodayCount, 0);
      expect(restoredSession.unlockedFlowerCount, 1);
      expect(restoredSession.growthPoints, 6);
      expect(restoredSession.lifetimeGrowthPoints, 6);

      final challengeAfterMissedDays = restoredSession.dailyChallenges.first;
      expect(
        await restoredSession.completeDailyChallenge(
          challengeAfterMissedDays.id,
        ),
        isTrue,
      );
      expect(restoredSession.unlockedFlowerCount, 1);
      expect(restoredSession.growthPoints, 7);
      expect(restoredSession.lifetimeGrowthPoints, 7);
      expect(restoredSession.activeFlowerId, activeFlowerId);
      for (final challenge in restoredSession.dailyChallenges.skip(1).take(2)) {
        expect(
          await restoredSession.completeDailyChallenge(challenge.id),
          isTrue,
        );
      }
      expect(restoredSession.unlockedFlowerCount, 1);
      expect(restoredSession.growthPoints, 9);
      expect(restoredSession.lifetimeGrowthPoints, 9);
      expect(
        await restoredSession.completeDailyChallenge(
          restoredSession.dailyChallenges[3].id,
        ),
        isTrue,
      );
      expect(restoredSession.unlockedFlowerCount, 2);
      expect(restoredSession.growthPoints, 0);
      expect(restoredSession.lifetimeGrowthPoints, 10);
      expect(restoredSession.activeFlowerId, isNot(activeFlowerId));
      expect(
        await restoredSession.completeDailyChallenge(
          challengeAfterMissedDays.id,
        ),
        isFalse,
      );

      final afterRestart = AppSession(_storage, clock: () => time);
      await afterRestart.initialize();
      expect(afterRestart.unlockedFlowerCount, 2);
      expect(afterRestart.growthPoints, 0);
      expect(afterRestart.lifetimeGrowthPoints, 10);
      expect(afterRestart.activeFlowerId, restoredSession.activeFlowerId);
      expect(afterRestart.completedTodayCount, 4);
      session.dispose();
      restoredSession.dispose();
      afterRestart.dispose();
    },
  );

  test(
    'legacy saved challenge progress migrates without being reset',
    () async {
      _storage.challenges
        ..add(AppSession.challenges[0].id)
        ..add(AppSession.challenges[1].id)
        ..add(AppSession.challenges[2].id);
      final session = AppSession(_storage);
      await session.initialize();

      expect(session.unlockedFlowerCount, 1);
      expect(session.growthPoints, 3);
      expect(session.lifetimeGrowthPoints, 3);
      expect(_storage.challenges.length, 3);
      session.dispose();
    },
  );

  test(
    'legacy flower progress rebases to lifetime ten-point progression',
    () async {
      _storage.gardenProgress = const GardenProgressData(
        flowerUnlockDates: {
          'flower-01': null,
          'flower-02': null,
          'flower-03': null,
        },
        activeFlowerId: 'flower-04',
        growthPoints: 9,
        lifetimeGrowthPoints: 17,
      );
      final session = AppSession(_storage);
      await session.initialize();

      expect(session.lifetimeGrowthPoints, 17);
      expect(session.growthPoints, 7);
      expect(session.activeFlowerId, 'flower-02');
      expect(
        session.flowerUnlockDates.keys,
        containsAll(['flower-01', 'flower-02', 'flower-03']),
      );
      session.dispose();
    },
  );

  testWidgets('full collection displays the full-bloom state', (
    WidgetTester tester,
  ) async {
    var time = DateTime(2026, 10, 26, 9);
    final session = AppSession(_storage, clock: () => time);
    await session.initialize();
    var rewards = 0;
    final pointsBeforeLastFlower =
        (AppSession.flowers.length - 1) * AppSession.growthStagesPerFlower;
    while (rewards < pointsBeforeLastFlower) {
      final challenge = session.dailyChallenges.first;
      expect(await session.completeDailyChallenge(challenge.id), isTrue);
      rewards++;
      if (rewards <
          AppSession.flowers.length * AppSession.growthStagesPerFlower) {
        time = time.add(const Duration(days: 1));
        session.refreshForResume();
      }
    }

    expect(session.unlockedFlowerCount, 20);
    expect(session.activeFlowerId, 'flower-20');
    expect(session.growthPoints, 0);
    expect(session.isFullBloom, isFalse);
    while (rewards <
        AppSession.flowers.length * AppSession.growthStagesPerFlower) {
      final challenge = session.dailyChallenges.first;
      expect(await session.completeDailyChallenge(challenge.id), isTrue);
      rewards++;
      if (rewards <
          AppSession.flowers.length * AppSession.growthStagesPerFlower) {
        time = time.add(const Duration(days: 1));
        session.refreshForResume();
      }
    }

    expect(session.activeFlowerId, isNull);
    expect(session.growthPoints, 0);
    expect(session.isFullBloom, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FlowerGardenScreen(session: session)),
      ),
    );
    expect(
      find.textContaining('Your garden is in full bloom!'),
      findsOneWidget,
    );
    expect(find.textContaining('20 of 20 flowers unlocked'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.byKey(const ValueKey('garden-flower-flower-01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('garden-flower-flower-20')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('garden-flower-flower-01')));
    await tester.pumpAndSettle();
    expect(find.text(AppSession.flowers.first.name), findsWidgets);
    expect(find.textContaining('Fully bloomed'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(
      session.unlockedFlowers.map((flower) => flower.id).toSet(),
      hasLength(20),
    );
    session.dispose();
  });

  testWidgets('locked garden flowers show real progression and stay locked', (
    WidgetTester tester,
  ) async {
    final session = AppSession(
      _storage,
      clock: () => DateTime(2026, 10, 26, 9),
    );
    await session.initialize();
    final mysteryName = session.activeFlower!.name;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FlowerGardenScreen(session: session)),
      ),
    );

    expect(find.textContaining('0/10 petals'), findsOneWidget);
    expect(find.textContaining(mysteryName), findsWidgets);
    final lockedFlower = session.flowerCatalog[2];
    expect(
      find.byKey(ValueKey('garden-flower-${lockedFlower.id}')),
      findsOneWidget,
    );
    expect(find.text(lockedFlower.name), findsNothing);
    final unlockedBeforeTap = session.unlockedFlowerCount;
    await tester.tap(find.byKey(ValueKey('garden-flower-${lockedFlower.id}')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('unique completed daily challenges'),
      findsOneWidget,
    );
    expect(find.text(lockedFlower.name), findsNothing);
    expect(session.unlockedFlowerCount, unlockedBeforeTap);
    session.dispose();
  });

  testWidgets('garden illustration fits a small phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = AppSession(_storage);
    await session.initialize();
    await tester.pumpWidget(
      MaterialApp(home: FlowerGardenScreen(session: session)),
    );

    expect(
      find.byKey(const ValueKey('garden-flower-flower-20')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  test(
    'daily task progress is distinct from challenge-earned flower growth',
    () async {
      var time = DateTime(2026, 10, 26, 9);
      final session = AppSession(_storage, clock: () => time);
      await session.initialize();

      for (final challenge in session.dailyChallenges) {
        expect(await session.completeDailyChallenge(challenge.id), isTrue);
      }
      expect(session.completedTodayCount, AppSession.dailyChallengeCount);
      expect(session.isDailyChallengeComplete, isTrue);
      expect(session.unlockedFlowerCount, 2);
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 10);

      time = time.add(const Duration(days: 1));
      session.refreshForResume();
      expect(session.completedTodayCount, 0);
      expect(session.unlockedFlowerCount, 2);
      expect(session.growthPoints, 0);
      expect(session.lifetimeGrowthPoints, 10);
      session.dispose();
    },
  );

  testWidgets('daily challenges page displays exactly ten tasks and progress', (
    WidgetTester tester,
  ) async {
    final session = AppSession(
      _storage,
      clock: () => DateTime(2026, 10, 26, 9),
    );
    await session.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DailyChallengesScreen(session: session)),
      ),
    );

    expect(session.dailyChallenges, hasLength(10));
    expect(find.textContaining('0 of 10 completed today'), findsOneWidget);
    for (final challenge in session.dailyChallenges) {
      await tester.scrollUntilVisible(
        find.text(challenge.title),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(challenge.title), findsOneWidget);
    }
    expect(find.text('Got it'), findsWidgets);
    session.dispose();
  });
}

PetalPopApp _app({DateTime Function()? clock}) =>
    PetalPopApp(storage: _storage, clock: clock);

Future<void> _openHome(
  WidgetTester tester, {
  DateTime Function()? clock,
}) async {
  await tester.pumpWidget(_app(clock: clock));
  await tester.tap(find.text('Get Started'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

class MemoryLocalDataService extends LocalDataService {
  MemoryLocalDataService() : super();

  final Map<String, String> profile = {};
  final List<String> challenges = [];
  final List<MoodEntry> moods = [];
  final List<MemoryEntry> memories = [];
  Completer<void>? memorySaveGate;
  GardenProgressData gardenProgress = const GardenProgressData();

  @override
  Future<Map<String, String>> loadProfile() async => {
    'name': profile['name'] ?? 'Sunshine',
    'avatar': profile['avatar'] ?? 'girl',
    'theme': profile['theme'] ?? 'light',
  };

  @override
  Future<void> saveProfile({
    required String name,
    required String avatar,
    required String theme,
  }) async {
    profile
      ..['name'] = name
      ..['avatar'] = avatar
      ..['theme'] = theme;
  }

  @override
  Future<List<String>> loadCompletedChallenges() async => List.of(challenges);

  @override
  Future<void> saveCompletedChallenges(List<String> ids) async {
    challenges
      ..clear()
      ..addAll(ids);
  }

  @override
  Future<GardenProgressData> loadGardenProgress() async => GardenProgressData(
    dailyCompletions: Map.of(gardenProgress.dailyCompletions),
    flowerUnlockDates: Map.of(gardenProgress.flowerUnlockDates),
    activeFlowerId: gardenProgress.activeFlowerId,
    growthPoints: gardenProgress.growthPoints,
    lifetimeGrowthPoints: gardenProgress.lifetimeGrowthPoints,
  );

  @override
  Future<void> saveGardenProgress(GardenProgressData progress) async {
    gardenProgress = GardenProgressData(
      dailyCompletions: Map.of(progress.dailyCompletions),
      flowerUnlockDates: Map.of(progress.flowerUnlockDates),
      activeFlowerId: progress.activeFlowerId,
      growthPoints: progress.growthPoints,
      lifetimeGrowthPoints: progress.lifetimeGrowthPoints,
    );
  }

  @override
  Future<List<MoodEntry>> loadMoods() async => List.of(moods);

  @override
  Future<void> saveMoods(List<MoodEntry> entries) async {
    moods
      ..clear()
      ..addAll(entries);
  }

  @override
  Future<List<MemoryEntry>> loadMemories() async => List.of(memories);

  @override
  Future<void> saveMemories(List<MemoryEntry> entries) async {
    final gate = memorySaveGate;
    if (gate != null) await gate.future;
    memories
      ..clear()
      ..addAll(entries);
  }

  @override
  Future<void> deleteMediaFile(MemoryEntry entry) async {}
}
