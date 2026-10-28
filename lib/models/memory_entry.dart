enum MemoryType { photo, note, voice }

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    this.filePath,
    this.storagePath,
    this.signedUrl,
    this.durationSeconds = 0,
  });

  final String id;
  final MemoryType type;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? filePath;
  final String? storagePath;
  final String? signedUrl;
  final int durationSeconds;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'filePath': filePath,
    'storagePath': storagePath,
    'durationSeconds': durationSeconds,
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
    id: json['id'] as String,
    type: MemoryType.values.byName(json['type'] as String),
    title: json['title'] as String,
    description: json['description'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    filePath: json['filePath'] as String?,
    storagePath: json['storagePath'] as String?,
    durationSeconds: json['durationSeconds'] as int? ?? 0,
  );
}
