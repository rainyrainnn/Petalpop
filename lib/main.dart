import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'navigation/main_navigation_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'services/local_data_service.dart';
import 'config/supabase_config.dart';
import 'services/supabase_data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.cleanUrl.isNotEmpty !=
    SupabaseConfig.cleanPublishableKey.isNotEmpty) {
    throw StateError(
      'Configure both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, or neither.',
    );
  }
  SupabaseClient? client;

if (SupabaseConfig.isConfigured) {
  debugPrint('Supabase configured: ${SupabaseConfig.isConfigured}');
  debugPrint('Supabase URL: ${SupabaseConfig.cleanUrl}');
  debugPrint(
    'Publishable key loaded: ${SupabaseConfig.cleanPublishableKey.isNotEmpty}',
  );

 await Supabase.initialize(
  url: SupabaseConfig.cleanUrl,
  publishableKey: SupabaseConfig.cleanPublishableKey,
);

  client = Supabase.instance.client;
}

runApp(PetalPopApp(client: client));
}

class PetalPopApp extends StatefulWidget {
  const PetalPopApp({super.key, this.storage, this.clock, this.client});

  final LocalDataService? storage;
  final DateTime Function()? clock;
  final SupabaseClient? client;

  @override
  State<PetalPopApp> createState() => _PetalPopAppState();
}

class _PetalPopAppState extends State<PetalPopApp> {
  bool _hasStarted = false;
  String _displayName = 'Sunshine';
  String _avatarId = 'girl';
  ThemeMode _themeMode = ThemeMode.light;
  AuthMode? _authMode;
  late final LocalDataService _storage;
  late final SupabaseDataService? _backend;
  String? _profileLoadError;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? LocalDataService();
    final client = widget.client;
    _backend = client == null ? null : SupabaseDataService(client);
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetalPop',
      debugShowCheckedModeBanner: false,
      theme: PetalPopTheme.light,
      darkTheme: PetalPopTheme.dark,
      themeMode: _themeMode,
      home: _hasStarted
          ? MainNavigationScreen(
              storage: _storage,
              backend: _backend,
              clock: widget.clock,
              displayName: _displayName,
              avatarId: _avatarId,
              themeMode: _themeMode,
              profileLoadError: _profileLoadError,
              onDisplayNameChanged: _onDisplayNameChanged,
              onAvatarChanged: _onAvatarChanged,
              onThemeModeChanged: _onThemeModeChanged,
              onLogout: _logout,
            )
          : _authMode == null
          ? WelcomeScreen(
              onGetStarted: () => setState(() {
                if (_backend == null) {
                  _hasStarted = true;
                } else {
                  _authMode = AuthMode.signUp;
                }
              }),
              onLogIn: () => setState(() => _authMode = AuthMode.logIn),
              onSignUp: () => setState(() => _authMode = AuthMode.signUp),
            )
          : AuthScreen(
              mode: _authMode!,
              onBack: () => setState(() => _authMode = null),
              onAuthenticate: _backend == null ? null : _authenticate,
              onContinueAsDemo: (name) {
                setState(() {
                  if (name != null && name.isNotEmpty) _displayName = name;
                  _authMode = null;
                  _hasStarted = true;
                });
                if (name != null && name.isNotEmpty) {
                  _saveProfile(name: name);
                }
              },
            ),
    );
  }

  Future<void> _loadProfile() async {
    final cloudUser = widget.client?.auth.currentUser;
    late final Map<String, String> cachedProfile;
    try {
      cachedProfile = await _storage.loadProfile();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileLoadError = 'Could not load saved profile preferences: $error';
        if (cloudUser != null) _hasStarted = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _displayName = cachedProfile['name'] ?? _displayName;
      _avatarId = cachedProfile['avatar'] ?? _avatarId;
      _themeMode = cachedProfile['theme'] == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
      if (cloudUser != null) _hasStarted = true;
    });

    if (cloudUser == null || _backend == null) return;
    try {
      final profile = await _backend.loadProfile();
      final displayName = profile['display_name'] as String;
      final avatarId = profile['avatar_id'] as String;
      final theme = profile['theme'] as String;
      await _storage.saveProfile(
        name: displayName,
        avatar: avatarId,
        theme: theme,
      );
      if (!mounted) return;
      setState(() {
        _displayName = displayName;
        _avatarId = avatarId;
        _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        _profileLoadError = null;
      });
      final timeZone = await FlutterTimezone.getLocalTimezone();
      await _backend.saveProfile(
        displayName: displayName,
        avatarId: avatarId,
        theme: theme,
        timeZone: timeZone.identifier,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileLoadError = 'Could not load saved profile preferences: $error';
      });
    }
  }

  void _onDisplayNameChanged(String name) {
    setState(() => _displayName = name);
    _saveProfile();
  }

  void _onAvatarChanged(String avatar) {
    setState(() => _avatarId = avatar);
    _saveProfile();
  }

  void _onThemeModeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveProfile();
  }

  Future<void> _saveProfile({String? name}) async {
    try {
      final displayName = name ?? _displayName;
      final theme = _themeMode == ThemeMode.dark ? 'dark' : 'light';
      await _storage.saveProfile(
        name: displayName,
        avatar: _avatarId,
        theme: theme,
      );
      if (_backend != null && widget.client?.auth.currentUser != null) {
        final timeZone = await FlutterTimezone.getLocalTimezone();
        await _backend.saveProfile(
          displayName: displayName,
          avatarId: _avatarId,
          theme: theme,
          timeZone: timeZone.identifier,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your profile settings: $error')),
      );
    }
  }

  Future<String?> _authenticate({
    required AuthMode mode,
    required String email,
    required String password,
    required String? displayName,
  }) async {
    final client = widget.client;
    final backend = _backend;
    if (client == null || backend == null) {
      throw StateError('Supabase is not configured.');
    }

    if (mode == AuthMode.signUp) {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      if (response.session == null) {
        return 'Account created. Check your email to confirm it, then log in.';
      }
    } else {
      await client.auth.signInWithPassword(email: email, password: password);
    }

    final profile = await backend.loadProfile();
    final profileName = profile['display_name'] as String;
    final profileAvatarId = profile['avatar_id'] as String;
    final profileTheme = profile['theme'] as String;
    await _storage.saveProfile(
      name: profileName,
      avatar: profileAvatarId,
      theme: profileTheme,
    );
    final timeZone = await FlutterTimezone.getLocalTimezone();
    await backend.saveProfile(
      displayName: profileName,
      avatarId: profileAvatarId,
      theme: profileTheme,
      timeZone: timeZone.identifier,
    );
    if (!mounted) return null;
    setState(() {
      _displayName = profileName;
      _avatarId = profileAvatarId;
      _themeMode = profileTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _authMode = null;
      _hasStarted = true;
    });
    return null;
  }

  Future<void> _logout() async {
    if (_backend != null) {
      try {
        await widget.client!.auth.signOut();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
        return;
      }
    }
    setState(() {
      _hasStarted = false;
      _authMode = null;
      _displayName = 'Sunshine';
      _avatarId = 'girl';
      _themeMode = ThemeMode.light;
    });
  }
}
