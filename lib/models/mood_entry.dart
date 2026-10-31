class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.mood,
    required this.emoji,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String mood;
  final String emoji;
  final String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mood': mood,
        'emoji': emoji,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String? ?? '',
      mood: json['mood'] as String,
      emoji: json['emoji'] as String,
      note: json['note'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}