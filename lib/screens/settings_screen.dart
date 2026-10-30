import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.displayName,
    required this.profileLoadError,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.onDisplayNameChanged,
    required this.onOpenProfile,
    required this.onThemeModeChanged,
    required this.onNotificationsChanged,
    required this.onLogout,
    required this.onBack,
    super.key,
  });

  final String displayName;
  final String? profileLoadError;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final ValueChanged<String> onDisplayNameChanged;
  final VoidCallback onOpenProfile;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onLogout;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: onBack,
          tooltip: 'Back to Home',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            AppPageHeader(
              title: 'A little just for you',
              subtitle: 'Make PetalPop feel like your happy space.',
              emoji: '🌷',
            ),
            if (profileLoadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  profileLoadError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SectionLabel('Your profile'),
            PetalCard(
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: PetalPopColors.softPink,
                    child: Icon(
                      Icons.person_rounded,
                      color: PetalPopColors.deepPink,
                    ),
                  ),
                  title: const Text('Edit Profile'),
                  subtitle: Text(displayName),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editProfile(context),
                ),
              ),
            ),
            const SizedBox(height: 8),
            PetalCard(
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(
                    Icons.account_circle_outlined,
                    color: PetalPopColors.hotPink,
                  ),
                  title: const Text('My Profile'),
                  subtitle: const Text('Choose an avatar and view your garden'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: onOpenProfile,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SectionLabel('Preferences'),
            PetalCard(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: notificationsEnabled,
                      onChanged: onNotificationsChanged,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: PetalPopColors.hotPink,
                      ),
                      title: const Text('Notifications'),
                      subtitle: const Text('Saved for this app session only'),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.palette_outlined,
                                color: PetalPopColors.hotPink,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Appearance',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_outlined),
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_outlined),
                                  label: Text('Dark'),
                                ),
                              ],
                              selected: {themeMode},
                              onSelectionChanged: (selection) {
                                onThemeModeChanged(selection.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SectionLabel('About'),
            PetalCard(
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(
                    Icons.local_florist_outlined,
                    color: PetalPopColors.hotPink,
                  ),
                  title: const Text('About PetalPop'),
                  subtitle: const Text('Your Daily Happy Space'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showAbout(context),
                ),
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PetalPopColors.deepPink,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'PetalPop demo · Your entries are saved on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _EditProfileDialog(initialName: displayName),
    );
    if (name != null && name.isNotEmpty) onDisplayNameChanged(name);
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'PetalPop',
      applicationVersion: 'Demo',
      applicationIcon: const Icon(
        Icons.local_florist_rounded,
        color: PetalPopColors.hotPink,
        size: 36,
      ),
      children: const [
        Text(
          'Your Daily Happy Space. This version stores mood check-ins, '
          'memories, and challenge progress in memory on this device session. '
          'Signed-in data uses the configured backend. In-app challenge and '
          'flower alerts appear in the Home bell after its database migration '
          'is installed; push notifications are not configured.',
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: PetalPopColors.hotPink),
        title: const Text('Log out of PetalPop?'),
        content: const Text(
          'You will return to the welcome screen. Your locally saved mood '
          'notes, memories, and garden progress will stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) onLogout();
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit your name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Please enter a name.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
