class MoodEntry {
  const MoodEntry({
    required this.mood,
    required this.emoji,
    required this.note,
    required this.createdAt,
  });

  final String mood;
  final String emoji;
  final String note;
  final DateTime createdAt;
}
