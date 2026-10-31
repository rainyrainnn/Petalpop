import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:url_launcher/url_launcher.dart';

import '../screens/daily_challenges_screen.dart';
import '../screens/flower_garden_screen.dart';
import '../screens/home_screen.dart';
import '../screens/memory_journal_screen.dart';
import '../screens/mood_checkin_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../services/app_session.dart';
import '../services/local_data_service.dart';
import '../services/supabase_data_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    required this.storage,
    this.backend,
    this.clock,
    required this.displayName,
    required this.avatarId,
    required this.themeMode,
    required this.profileLoadError,
    required this.onDisplayNameChanged,
    required this.onAvatarChanged,
    required this.onThemeModeChanged,
    required this.onLogout,
    super.key,
  });

  final LocalDataService storage;
  final SupabaseDataService? backend;
  final DateTime Function()? clock;
  final String displayName;
  final String avatarId;
  final ThemeMode themeMode;
  final String? profileLoadError;
  final ValueChanged<String> onDisplayNameChanged;
  final ValueChanged<String> onAvatarChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onLogout;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  late final AppSession _session = AppSession(
    widget.storage,
    clock: widget.clock,
    backend: widget.backend,
  );
  int _selectedIndex = 0;
  bool _isSettingsOpen = false;
  bool _isMoodOpen = false;
  bool _isMemoriesOpen = false;
  bool _isNotificationsOpen = false;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _session.refreshForResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          !_isSettingsOpen &&
          !_isMoodOpen &&
          !_isMemoriesOpen &&
          !_isNotificationsOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop &&
            (_isSettingsOpen ||
                _isMoodOpen ||
                _isMemoriesOpen ||
                _isNotificationsOpen)) {
          setState(() {
            _isSettingsOpen = false;
            _isMoodOpen = false;
            _isMemoriesOpen = false;
            _isNotificationsOpen = false;
          });
        }
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _session,
          builder: (context, child) {
            if (_session.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                if (_session.loadError != null ||
                    widget.profileLoadError != null)
                  MaterialBanner(
                    content: Text(
                      _session.loadError != null
                          ? 'Some saved PetalPop data could not be loaded: '
                                '${_session.loadError}'
                          : widget.profileLoadError!,
                    ),
                    leading: const Icon(Icons.warning_amber_rounded),
                    actions: [
                      TextButton(
                        onPressed: _session.initialize,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _isSettingsOpen
                        ? 6
                        : _isMoodOpen
                        ? 4
                        : _isMemoriesOpen
                        ? 5
                        : _isNotificationsOpen
                        ? 7
                        : _selectedIndex,
                    children: [
                      HomeScreen(
                        session: _session,
                        onOpenMood: _openMood,
                        onOpenMemories: _openMemories,
                        onOpenChallenges: () => _selectTab(1),
                        onOpenGarden: () => _selectTab(2),
                        onOpenNotifications: _openNotifications,
                        unreadNotificationCount:
                            _session.unreadNotificationCount,
                        displayName: widget.displayName,
                        avatarId: widget.avatarId,
                      ),
                      DailyChallengesScreen(session: _session),
                      FlowerGardenScreen(session: _session),
                      ProfileScreen(
                        displayName: widget.displayName,
                        avatarId: widget.avatarId,
                        session: _session,
                        onDisplayNameChanged: widget.onDisplayNameChanged,
                        onAvatarChanged: widget.onAvatarChanged,
                        onOpenMoodHistory: _openMood,
                        onOpenMemories: _openMemories,
                        onOpenGarden: () => _selectTab(2),
                        onOpenSettings: () => setState(() {
                          _isMoodOpen = false;
                          _isMemoriesOpen = false;
                          _isSettingsOpen = true;
                        }),
                        onOpenHelp: _showHelpDialog,
                      ),
                      MoodCheckinScreen(
                        session: _session,
                        onBack: () => setState(() {
                          _isMoodOpen = false;
                          _selectedIndex = 0;
                        }),
                      ),
                      MemoryJournalScreen(session: _session),
                      SettingsScreen(
                        displayName: widget.displayName,
                        profileLoadError: widget.profileLoadError,
                        themeMode: widget.themeMode,
                        notificationsEnabled: _notificationsEnabled,
                        onDisplayNameChanged: widget.onDisplayNameChanged,
                        onOpenProfile: () {
                          setState(() {
                            _isSettingsOpen = false;
                            _selectedIndex = 3;
                          });
                        },
                        onThemeModeChanged: widget.onThemeModeChanged,
                        onNotificationsChanged: _setNotificationsEnabled,
                        onLogout: widget.onLogout,
                        onBack: () => setState(() => _isSettingsOpen = false),
                      ),
                      NotificationScreen(
                        session: _session,
                        onBack: () => setState(() {
                          _isNotificationsOpen = false;
                          _selectedIndex = 0;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .18),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Challenges',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_florist_outlined),
              selectedIcon: Icon(Icons.local_florist_rounded),
              label: 'Garden',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _isSettingsOpen = false;
      _isMoodOpen = false;
      _isMemoriesOpen = false;
      _isNotificationsOpen = false;
      _selectedIndex = index;
    });
    if (index == 1 || index == 2) {
      unawaited(_refreshDailyContentAndGarden());
    }
  }

  void _openMood() {
    setState(() {
      _selectedIndex = 0;
      _isSettingsOpen = false;
      _isMoodOpen = true;
      _isMemoriesOpen = false;
      _isNotificationsOpen = false;
    });
  }

  void _openMemories() {
    setState(() {
      _selectedIndex = 0;
      _isSettingsOpen = false;
      _isMoodOpen = false;
      _isMemoriesOpen = true;
      _isNotificationsOpen = false;
    });
  }

  void _openNotifications() {
    setState(() {
      _selectedIndex = 0;
      _isSettingsOpen = false;
      _isMoodOpen = false;
      _isMemoriesOpen = false;
      _isNotificationsOpen = true;
    });
    unawaited(_session.refreshNotifications());
  }

  Future<void> _refreshDailyContentAndGarden() async {
    try {
      await _session.refreshDailyChallenges();
    } catch (error) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'You’re offline. Your saved garden data is still available. 🌷',
      ),
    ),
  );
}
  }

  void _setNotificationsEnabled(bool enabled) {
    setState(() => _notificationsEnabled = enabled);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Preference saved for this session. Phone notifications are not connected yet.'
                : 'Notification preference turned off for this session.',
          ),
        ),
      );
  }

  Future<void> _showHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For account or saved-data support, email the PetalPop support '
              'team:',
            ),
            const SizedBox(height: 8),
            Semantics(
              link: true,
              child: InkWell(
                onTap: () => _openSupportEmail(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'reynaannjoybausin@gmail.com',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupportEmail(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri(scheme: 'mailto', path: 'reynaannjoybausin@gmail.com'),
      );
      if (opened || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app is available on this device.'),
        ),
      );
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the email app: ${error.message ?? error.code}',
          ),
        ),
      );
    }
  }
}
