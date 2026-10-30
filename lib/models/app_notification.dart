class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.sourceKey,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.isRetracted = false,
  });

  final String id;
  final String kind;
  final String sourceKey;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final bool isRetracted;

  AppNotification markRead() => AppNotification(
    id: id,
    kind: kind,
    sourceKey: sourceKey,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: true,
    isRetracted: isRetracted,
  );

  AppNotification retract() => AppNotification(
    id: id,
    kind: kind,
    sourceKey: sourceKey,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead,
    isRetracted: true,
  );
}
