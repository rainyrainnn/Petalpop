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

bool _isConnectivityError(Object error) {
  if (error is AuthRetryableFetchException) return true;
  final message = error.toString();
  return message.contains('SocketException') ||
      message.contains('Failed host lookup') ||
      message.contains('Connection refused') ||
      message.contains('Connection timed out') ||
      message.contains('Network is unreachable');
}

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
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
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
      scaffoldMessengerKey: _scaffoldMessengerKey,
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
              onGetStarted: () => setState(() => _authMode = AuthMode.signUp),
              onLogIn: () => setState(() => _authMode = AuthMode.logIn),
              onSignUp: () => setState(() => _authMode = AuthMode.signUp),
            )
          : AuthScreen(
              mode: _authMode!,
              onBack: () => setState(() => _authMode = null),
              isSupabaseConfigured: _backend != null,
              onAuthenticate: _authenticate,
            ),
    );
  }

  Future<void> _loadProfile() async {
    final cloudUser = widget.client?.auth.currentUser;
    late final Map<String, String> cachedProfile;
    late final String? deviceTheme;
    try {
      cachedProfile = await _storage.loadProfile();
      deviceTheme = await _storage.loadDeviceTheme();
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
      _themeMode = (deviceTheme ?? cachedProfile['theme']) == 'dark'
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
      final deviceTheme = await _storage.loadDeviceTheme();
      final effectiveTheme = deviceTheme ?? theme;
      if (deviceTheme == null) await _storage.saveDeviceTheme(theme);
      await _storage.saveProfile(
        name: displayName,
        avatar: avatarId,
        theme: theme,
      );
      if (!mounted) return;
      setState(() {
        _displayName = displayName;
        _avatarId = avatarId;
        _themeMode = effectiveTheme == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light;
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
        // Connectivity failures use the cached profile without alarming the user.
        _profileLoadError = _isConnectivityError(error)
            ? null
            : 'Could not sync profile preferences. Your saved settings are '
                  'still available.';
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

  Future<void> _onThemeModeChanged(ThemeMode mode) async {
    final previous = _themeMode;
    setState(() => _themeMode = mode);
    try {
      await _storage.saveDeviceTheme(mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (error) {
      if (!mounted) return;
      setState(() => _themeMode = previous);
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Could not save this device theme: $error')),
      );
    }
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
      _scaffoldMessengerKey.currentState?.showSnackBar(
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
      throw StateError(
        'Supabase authentication is not configured. Set SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY, then restart the app.',
      );
    }

    if (mode == AuthMode.signUp) {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      if (response.session == null) {
        if (response.user?.identities?.isEmpty == true) {
          return 'An account with this email already exists. Please log in.';
        }
        return 'Account created. Check your email to confirm it, then log in.';
      }
    } else {
      await client.auth.signInWithPassword(email: email, password: password);
    }

    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Authentication completed without an active session.');
    }
    final metadataName = user.userMetadata?['display_name'];
    final initialName =
        displayName ??
        (metadataName is String && metadataName.isNotEmpty
            ? metadataName
            : _displayName);
    if (!mounted) return null;
    setState(() {
      _displayName = initialName;
      _authMode = null;
      _hasStarted = true;
      _profileLoadError = null;
    });

    try {
      final profile = await backend.loadProfile();
      final profileName = profile['display_name'] as String;
      final profileAvatarId = profile['avatar_id'] as String;
      final profileTheme = profile['theme'] as String;
      final deviceTheme = await _storage.loadDeviceTheme();
      final effectiveTheme = deviceTheme ?? profileTheme;
      if (deviceTheme == null) {
        await _storage.saveDeviceTheme(profileTheme);
      }
      await _storage.saveProfile(
        name: profileName,
        avatar: profileAvatarId,
        theme: profileTheme,
      );
      if (!mounted) return null;
      setState(() {
        _displayName = profileName;
        _avatarId = profileAvatarId;
        _themeMode = effectiveTheme == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light;
      });
      final timeZone = await FlutterTimezone.getLocalTimezone();
      await backend.saveProfile(
        displayName: profileName,
        avatarId: profileAvatarId,
        theme: profileTheme,
        timeZone: timeZone.identifier,
      );
    } catch (error) {
      if (!mounted) return null;
      setState(() {
        _profileLoadError = _isConnectivityError(error)
            ? null
            : 'You are signed in, but your profile settings could not be '
                  'synced. Your saved settings are still available.';
      });
    }
    return null;
  }

  Future<void> _logout() async {
    final deviceTheme = await _storage.loadDeviceTheme();
    Future<void>? remoteSignOut;
    if (_backend != null) {
      remoteSignOut = widget.client!.auth.signOut(scope: SignOutScope.local);
    }
    if (!mounted) return;
    setState(() {
      _hasStarted = false;
      _authMode = null;
      _displayName = 'Sunshine';
      _avatarId = 'girl';
      _themeMode = deviceTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _profileLoadError = null;
    });
    if (remoteSignOut != null) {
      try {
        await remoteSignOut;
      } catch (error) {
        if (!mounted) return;
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              error is AuthRetryableFetchException
                  ? 'Signed out on this device. The server could not be '
                        'reached to revoke the session.'
                  : 'Signed out on this device, but server session revocation '
                        'failed: $error',
            ),
          ),
        );
      }
    }
  }
}
