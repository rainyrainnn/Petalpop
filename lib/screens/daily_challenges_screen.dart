import 'package:flutter/material.dart';

import '../models/daily_challenge.dart';
import '../services/app_session.dart';
import '../widgets/app_widgets.dart';
import '../widgets/challenge_illustration.dart';

class DailyChallengesScreen extends StatefulWidget {
  const DailyChallengesScreen({required this.session, super.key});

  final AppSession session;

  @override
  State<DailyChallengesScreen> createState() => _DailyChallengesScreenState();
}

class _DailyChallengesScreenState extends State<DailyChallengesScreen> {
  bool _isRefreshing = false;

  AppSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedIds = session.completedToday;
    final unfinishedChallenges = session.dailyChallenges
        .where((challenge) => !completedIds.contains(challenge.id))
        .toList();
    final completedChallenges = session.dailyChallenges
        .where((challenge) => completedIds.contains(challenge.id))
        .toList();

    return SessionPage(
      title: 'Today’s happy challenges',
      subtitle: 'Complete a little challenge to help your flower grow.',
      emoji: '',
      action: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          color: theme.colorScheme.primary,
        ),
      ),
      children: [
        PetalCard(
          color: Color.alphaBlend(
            theme.colorScheme.tertiary.withValues(alpha: .12),
            theme.colorScheme.surface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: .72),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_florist_rounded,
                  color: theme.colorScheme.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily challenges: ${session.completedTodayCount} of '
                      '${AppSession.dailyChallengeCount} completed today',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.activeFlower == null
                          ? session.flowerCatalog.isEmpty
                                ? 'Flower collection: no flowers are available'
                                : 'Flower collection: all '
                                      '${session.flowerCatalog.length} flowers '
                                      'unlocked · '
                                      '${session.lifetimeGrowthPoints} lifetime '
                                      'challenge points; new flowers will '
                                      'continue your garden'
                          : 'Saved flower growth: ${session.growthPoints} of '
                                '${AppSession.growthStagesPerFlower} points · '
                                '${session.unlockedFlowerCount} of '
                                '${session.flowerCatalog.length} flowers unlocked '
                                '(progress carries across days)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: session.completedTodayCount / AppSession.dailyChallengeCount,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        if (session.dailyChallenges.isEmpty)
          PetalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s assigned challenges could not be loaded. Check your '
                  'connection and try again.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isRefreshing ? null : _refreshChallenges,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_isRefreshing ? 'Retrying…' : 'Retry'),
                ),
              ],
            ),
          )
        else if (unfinishedChallenges.isNotEmpty) ...[
          Text('Still to do', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final challenge in unfinishedChallenges) ...[
            _ChallengeCard(
              challenge: challenge,
              completed: false,
              saving: session.isChallengeSaving(challenge.id),
              onComplete: () => _completeChallenge(context, challenge.id),
              onUndo: null,
            ),
            if (challenge != unfinishedChallenges.last)
              const SizedBox(height: 12),
          ],
        ],
        if (completedChallenges.isNotEmpty) ...[
          if (unfinishedChallenges.isNotEmpty) const SizedBox(height: 20),
          Text('Completed', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final challenge in completedChallenges) ...[
            _ChallengeCard(
              challenge: challenge,
              completed: true,
              saving: session.isChallengeUndoing(challenge.id),
              onComplete: null,
              onUndo: () => _undoChallenge(context, challenge.id),
            ),
            if (challenge != completedChallenges.last)
              const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Future<void> _completeChallenge(
    BuildContext context,
    String challengeId,
  ) async {
    try {
      final unlockedBefore = session.unlockedFlowerCount;
      final lifetimeGrowthBefore = session.lifetimeGrowthPoints;
      final completed = await session.completeDailyChallenge(challengeId);
      final markedDone = session.completedToday.contains(challengeId);
      if (!completed && !markedDone) return;
      final String message;
      if (!completed) {
        message = markedDone
            ? 'This challenge was already complete. It is now marked DONE. 🌸'
            : 'This challenge is already being saved. Please wait.';
      } else if (session.isFullBloom) {
        message = 'Your garden is in full bloom! Congratulations! 🌸';
      } else if (session.unlockedFlowerCount > unlockedBefore) {
        message = 'A mystery flower bloomed! It joined your garden 🌸';
      } else if (session.lifetimeGrowthPoints > lifetimeGrowthBefore) {
        message = 'Lovely work! Your flower grew a little 🌱';
      } else {
        message = 'Another challenge done! Your flower already grew today 🌸';
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) return;
      final message = error is ChallengeProgressRefreshException
          ? error.toString()
          : 'Could not save challenge progress: $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _undoChallenge(BuildContext context, String challengeId) async {
    try {
      final undone = await session.undoDailyChallenge(challengeId);
      if (!context.mounted || !undone) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completion undone · 1 growth point returned.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not undo challenge completion: $error')),
      );
    }
  }

  Future<void> _refreshChallenges() async {
    setState(() => _isRefreshing = true);
    try {
      await session.refreshDailyChallenges();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reload daily challenges: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.completed,
    required this.saving,
    required this.onComplete,
    required this.onUndo,
  });

  final DailyChallenge challenge;
  final bool completed;
  final bool saving;
  final VoidCallback? onComplete;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return PetalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChallengeIllustration(challenge: challenge, size: 66),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      challenge.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completed ? '1 growth point earned' : '+1 growth point',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (saving) const LinearProgressIndicator(),
          if (saving) const SizedBox(height: 10),
          if (completed)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'DONE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: saving ? null : onUndo,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.undo_rounded, size: 18),
                  label: Text(saving ? 'Undoing…' : 'Undo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .55),
                    ),
                    minimumSize: const Size(90, 40),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : onComplete,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(saving ? 'Saving…' : 'Got it'),
              ),
            ),
        ],
      ),
    );
  }
}
