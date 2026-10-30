import 'package:flutter/material.dart';

import '../services/app_session.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({
    required this.session,
    required this.onBack,
    super.key,
  });

  final AppSession session;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifications = session.notifications;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to Home',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              'Little moments from your garden and daily challenges.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: session.notificationError != null
                ? _NotificationError(
                    error: session.notificationError!,
                    onRetry: session.refreshNotifications,
                  )
                : notifications.isEmpty
                ? const _EmptyNotifications()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return Card(
                        color: notification.isRead
                            ? theme.colorScheme.surfaceContainerLow
                            : theme.colorScheme.primaryContainer.withValues(
                                alpha: .48,
                              ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                notification.kind == 'flower_unlocked'
                                    ? Icons.local_florist_rounded
                                    : Icons.auto_awesome_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(notification.body),
                                    const SizedBox(height: 6),
                                    Text(
                                      MaterialLocalizations.of(
                                        context,
                                      ).formatMediumDate(
                                        notification.createdAt,
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (!notification.isRead)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () async {
                                            try {
                                              await session
                                                  .markNotificationRead(
                                                    notification.id,
                                                  );
                                            } catch (error) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                ..hideCurrentSnackBar()
                                                ..showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Could not mark this '
                                                      'notification as read: '
                                                      '$error',
                                                    ),
                                                  ),
                                                );
                                            }
                                          },
                                          child: const Text('Mark as read'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'All quiet in the garden',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New challenge and flower updates appear here when available '
              'for your account.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 38,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(
              'Notifications could not be loaded',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
