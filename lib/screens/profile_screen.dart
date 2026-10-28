import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.displayName,
    required this.avatarId,
    required this.session,
    required this.onDisplayNameChanged,
    required this.onAvatarChanged,
    required this.onOpenMoodHistory,
    required this.onOpenMemories,
    required this.onOpenGarden,
    required this.onOpenSettings,
    required this.onOpenHelp,
    super.key,
  });

  final String displayName;
  final String avatarId;
  final AppSession session;
  final ValueChanged<String> onDisplayNameChanged;
  final ValueChanged<String> onAvatarChanged;
  final VoidCallback onOpenMoodHistory;
  final VoidCallback onOpenMemories;
  final VoidCallback onOpenGarden;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: session.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  PetalCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _chooseAvatar(context),
                          borderRadius: BorderRadius.circular(48),
                          child: ProfileAvatar(avatarId: avatarId, radius: 39),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(fontSize: 20),
                              ),
                              TextButton.icon(
                                onPressed: () => _editName(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 36),
                                  alignment: Alignment.centerLeft,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: const Text('Edit name'),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onOpenSettings,
                          tooltip: 'Settings',
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: PetalPopColors.hotPink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.65,
                    children: [
                      _ProfileStatCard(
                        key: const ValueKey('profile-challenges-stat'),
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Challenges',
                        value: '${session.completedChallengeCount}',
                        color: const Color(0xFFFFE6EF),
                      ),
                      _ProfileStatCard(
                        key: const ValueKey('profile-petals-stat'),
                        icon: Icons.auto_awesome_rounded,
                        label: 'Petals',
                        value: '${session.lifetimeGrowthPoints}',
                        color: const Color(0xFFFFF1CF),
                      ),
                      _ProfileStatCard(
                        key: const ValueKey('profile-memories-stat'),
                        icon: Icons.book_rounded,
                        label: 'Memories',
                        value: '${session.memories.length}',
                        color: const Color(0xFFEDE5FF),
                      ),
                      _ProfileStatCard(
                        key: const ValueKey('profile-garden-stat'),
                        icon: Icons.local_florist_rounded,
                        label: 'Garden',
                        value:
                            '${session.unlockedFlowerCount}/'
                            '${session.flowerCatalog.length}',
                        color: const Color(0xFFE6F4E0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionLabel('Your space'),
                  PetalCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.mood_rounded),
                            title: const Text('Mood History'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: onOpenMoodHistory,
                          ),
                          ListTile(
                            leading: const Icon(Icons.book_rounded),
                            title: const Text('Memories'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: onOpenMemories,
                          ),
                          ListTile(
                            leading: const Icon(Icons.local_florist_rounded),
                            title: const Text('My Garden'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: onOpenGarden,
                          ),
                          ListTile(
                            leading: const Icon(Icons.support_agent_rounded),
                            title: const Text('Help & Support'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: onOpenHelp,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (session.loadError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Some saved progress could not be loaded. '
                      'Please restart the app and try again.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _chooseAvatar(BuildContext context) async {
    var selectedId = avatarId;
    final compactPicker = MediaQuery.sizeOf(context).height < 600;
    final chosenId = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose your avatar'),
          content: SizedBox(
            width: 340,
            height: compactPicker ? 154 : 174,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: .55),
                ),
              ),
              child: GridView.count(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
                childAspectRatio: compactPicker ? 1.2 : 1.15,
                children: [
                  for (final avatar in PetalAvatarChoice.choices)
                    Builder(
                      builder: (context) {
                        final isSelected = avatar.id == selectedId;
                        final theme = Theme.of(context);
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          label: '${avatar.label} avatar',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () => setDialogState(
                              () => selectedId = avatar.id,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: .14,
                                      )
                                    : theme.colorScheme.surface,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ProfileAvatar(
                                        avatarId: avatar.id,
                                        radius: compactPicker ? 16 : 18,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        avatar.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        size: 15,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedId),
              child: const Text('Save avatar'),
            ),
          ],
        ),
      ),
    );
    if (chosenId != null && chosenId != avatarId) onAvatarChanged(chosenId);
  }

  Future<void> _editName(BuildContext context) async {
    final dialogClosed = Completer<void>();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final route = ModalRoute.of(dialogContext);
        if (route == null) {
          throw StateError('The display-name dialog route is unavailable.');
        }
        route.completed.then((_) {
          if (!dialogClosed.isCompleted) dialogClosed.complete();
        });
        return _EditNameDialog(initialName: displayName);
      },
    );
    await dialogClosed.future;
    if (name != null) onDisplayNameChanged(name);
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

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
  Widget build(BuildContext context) => AlertDialog(
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
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? Color.alphaBlend(
            color.withValues(alpha: .17),
            theme.colorScheme.surface,
          )
        : color;
    return PetalCard(
      color: cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 23),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
