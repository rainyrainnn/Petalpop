import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/challenge_illustration.dart';
import '../widgets/flower_illustration.dart';
import '../widgets/mood_face_illustration.dart';
import '../widgets/profile_avatar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.session,
    required this.onOpenMood,
    required this.onOpenMemories,
    required this.onOpenChallenges,
    required this.onOpenGarden,
    required this.displayName,
    required this.avatarId,
    super.key,
  });

  final AppSession session;
  final VoidCallback onOpenMood;
  final VoidCallback onOpenMemories;
  final VoidCallback onOpenChallenges;
  final VoidCallback onOpenGarden;
  final String displayName;
  final String avatarId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = session.now;
    final date = MaterialLocalizations.of(context).formatMediumDate(now);
    final challenge = session.dailyChallenge;
    final challengeDone =
        challenge != null && session.completedToday.contains(challenge.id);
    final todaysMoods = session.moodEntries.where((entry) {
      final createdAt = entry.createdAt;
      return createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
    }).toList();
    final todaysMood = todaysMoods.isEmpty ? null : todaysMoods.first;
    final memories = session.memories;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        children: [
          Row(
            children: [
              Semantics(
                image: true,
                label: 'Profile avatar',
                child: ProfileAvatar(avatarId: avatarId, radius: 27),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppSession.greetingFor(now, displayName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notifications are not connected',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications are not connected yet.'),
                  ),
                ),
                color: theme.colorScheme.primary,
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _HomeFlowerCard(session: session),
          const SizedBox(height: 8),
          _FlowerProgressCard(session: session),
          const SizedBox(height: 12),
          SectionLabel(
            "Today's Challenge",
            trailing: TextButton(
              onPressed: onOpenChallenges,
              child: const Text('See all'),
            ),
          ),
          if (challenge == null)
            const PetalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today’s challenge is unavailable'),
                  SizedBox(height: 6),
                  Text(
                    'The assigned daily challenge could not be loaded. Try '
                    'refreshing.',
                  ),
                ],
              ),
            )
          else
            PetalCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${session.completedTodayCount} of '
                    '${AppSession.dailyChallengeCount} completed today',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChallengeIllustration(challenge: challenge, size: 62),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              challenge.description,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onOpenChallenges,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        challengeDone ? 'View completed' : 'View challenge',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  key: const ValueKey('home-mood-card'),
                  height: 120,
                  child: _ShortcutCard(
                    illustration: MoodFaceIllustration(
                      mood: todaysMood?.mood ?? 'Happy',
                      size: 36,
                    ),
                    title: 'My Mood',
                    subtitle: todaysMood == null
                        ? 'Save a little check-in'
                        : todaysMood.note.isEmpty
                        ? todaysMood.mood
                        : todaysMood.note,
                    onTap: onOpenMood,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  key: const ValueKey('home-memories-card'),
                  height: 120,
                  child: _ShortcutCard(
                    illustration: const Icon(
                      Icons.auto_stories_rounded,
                      size: 29,
                    ),
                    title: 'Memories',
                    subtitle: memories.isEmpty
                        ? 'Keep a little moment close'
                        : '${memories.length} saved · ${memories.first.title}',
                    onTap: onOpenMemories,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SectionLabel(
            'My Garden',
            trailing: TextButton(
              onPressed: onOpenGarden,
              child: const Text('View'),
            ),
          ),
          PetalCard(
            color: Color.alphaBlend(
              theme.colorScheme.tertiary.withValues(alpha: .1),
              theme.colorScheme.surface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 58,
                  child: FlowerIllustration(
                    color:
                        session.activeFlower?.color ??
                        session.flowerCatalog.lastOrNull?.color ??
                        PetalPopColors.petalPink,
                    growthPoints: session.activeFlower == null
                        ? AppSession.growthStagesPerFlower
                        : session.growthPoints,
                    variety:
                        session.activeFlower?.sortOrder ??
                        session.flowerCatalog.lastOrNull?.sortOrder ??
                        1,
                    petalCount: AppSession.activeFlowerVisualStages,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.activeFlower?.name ?? 'Garden in full bloom',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.activeFlower == null
                            ? '${session.unlockedFlowerCount}/'
                                  '${session.flowerCatalog.length} flowers · '
                                  'Fully bloomed'
                            : '${session.growthPoints}/'
                                  '${AppSession.growthStagesPerFlower} petals · '
                                  '${session.unlockedFlowerCount}/'
                                  '${session.flowerCatalog.length} flowers',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (session.activeFlower != null) ...[
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: session.activeFlowerProgress,
                            minHeight: 5,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onOpenGarden,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View Garden'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFlowerCard extends StatelessWidget {
  const _HomeFlowerCard({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flower = session.activeFlower ?? session.flowerCatalog.lastOrNull;
    final growthPoints = session.activeFlower == null
        ? AppSession.growthStagesPerFlower
        : session.growthPoints;
    final flowerVariety = flower == null
        ? 1
        : flower.sortOrder > 0
        ? flower.sortOrder
        : session.flowerCatalog.indexOf(flower) + 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        final illustrationSize = compact ? 172.0 : 140.0;
        final illustration = SizedBox(
          width: illustrationSize,
          height: illustrationSize,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: .82, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: Stack(
              key: ValueKey('${flower?.id}:$growthPoints'),
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            theme.colorScheme.surface.withValues(alpha: .88),
                            theme.colorScheme.surface.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: FlowerIllustration(
                      color: flower?.color ?? const Color(0xFFFFB1CB),
                      growthPoints: growthPoints,
                      variety: flowerVariety,
                      petalCount: AppSession.activeFlowerVisualStages,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: theme.colorScheme.primary.withValues(alpha: .8),
                    ),
                  ),
                ],
            ),
          ),
        );
        final flowerDetails = Column(
          crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
                '“Bloom your day, one petal at a time.”',
                textAlign: compact
                    ? TextAlign.center
                    : TextAlign.left,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  height: 1.2,
                  color: theme.colorScheme.primary,
                ),
            ),
            const SizedBox(height: 7),
            Text(
                session.activeFlower == null
                    ? 'All your flowers are blooming beautifully.'
                    : 'One gentle challenge at a time, your next bloom is closer.',
                textAlign: compact
                    ? TextAlign.center
                    : TextAlign.left,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
            ),
          ],
        );

        return PetalCard(
          color: Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: .12),
            theme.colorScheme.surface,
          ),
          padding: const EdgeInsets.all(10),
          child: compact
                ? Column(
                    children: [
                      illustration,
                      const SizedBox(height: 2),
                      flowerDetails,
                    ],
                  )
                : Row(
                    children: [
                      illustration,
                      const SizedBox(width: 8),
                      Expanded(child: flowerDetails),
                    ],
                ),
        );
      },
    );
  }
}

class _FlowerProgressCard extends StatelessWidget {
  const _FlowerProgressCard({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flower = session.activeFlower;
    return PetalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .12),
                shape: BoxShape.circle,
            ),
            child: Icon(
                Icons.local_florist_rounded,
                color: theme.colorScheme.primary,
                size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          flower?.name ?? 'Your garden is in full bloom',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        flower == null
                            ? '${session.unlockedFlowerCount}/${session.flowerCatalog.length} blooms'
                            : '${session.growthPoints}/${AppSession.growthStagesPerFlower} petals',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: flower == null ? 1 : session.activeFlowerProgress,
                      minHeight: 7,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flower == null
                        ? 'Every flower you grew is here to stay.'
                        : 'Each completed challenge adds one growth point.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.illustration,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget illustration;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PetalCard(
      padding: const EdgeInsets.all(12),
      child: SizedBox.expand(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              illustration,
              const SizedBox(height: 6),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 14),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
