import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/mood_entry.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/mood_face_illustration.dart';

class MoodCheckinScreen extends StatefulWidget {
  const MoodCheckinScreen({required this.session, this.onBack, super.key});

  final AppSession session;
  final VoidCallback? onBack;

  @override
  State<MoodCheckinScreen> createState() => _MoodCheckinScreenState();
}

class _MoodCheckinScreenState extends State<MoodCheckinScreen> {
  static const _moods = [
    ('Happy', '😊'),
    ('Calm', '😌'),
    ('Loved', '🥰'),
    ('Excited', '🤩'),
    ('Tired', '😴'),
    ('Sad', '😢'),
    ('Anxious', '😟'),
    ('Angry', '😠'),
    ('Other', '🙂'),
  ];

  final _noteController = TextEditingController();
  String? _selectedMood;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final cardExtent = ((screenWidth - 40 - 20) / 3).clamp(78.0, 130.0);
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    tooltip: 'Back to Home',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  const Text('🌸', style: TextStyle(fontSize: 24)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'How are you feeling today?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: PetalPopColors.deepPink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose the little face that feels like you today.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _moods.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: cardExtent,
                ),
                itemBuilder: (context, index) {
                  final (name, _) = _moods[index];
                  final selected = _selectedMood == name;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: name,
                    child: Material(
                      color: selected
                          ? PetalPopColors.softPink
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => _selectedMood = name),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? PetalPopColors.hotPink
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MoodFaceIllustration(
                                mood: name,
                                size: cardExtent < 90 ? 42 : 52,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                name,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              SectionLabel('Add a little note (optional)'),
              TextField(
                controller: _noteController,
                maxLength: 140,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What’s on your mind?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveMood,
                  icon: const Icon(Icons.favorite_rounded),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(height: 24),
              SectionLabel('Recent check-ins'),
              PetalCard(
                child: widget.session.moodEntries.isEmpty
                    ? const EmptyState(
                        emoji: '🌷',
                        title: 'Your mood notes live here',
                        message:
                            'Save a check-in and it will appear in this list.',
                      )
                    : Column(
                        children: [
                          for (
                            var i = 0;
                            i < widget.session.moodEntries.length;
                            i++
                          ) ...[
                            _MoodHistoryRow(
                              entry: widget.session.moodEntries[i],
                            ),
                            if (i < widget.session.moodEntries.length - 1)
                              const Divider(height: 20),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveMood() async {
    final mood = _selectedMood;
    if (mood == null) {
      _showMessage('Choose a mood before saving your check-in.');
      return;
    }
    final selection = _moods.firstWhere((item) => item.$1 == mood);
    try {
      await widget.session.addMoodEntry(
        MoodEntry(
  id: const Uuid().v4(),
  mood: mood,
  emoji: selection.$2,
  note: _noteController.text.trim(),
  createdAt: DateTime.now(),
),
      );
      if (!mounted) return;
      setState(() {
        _selectedMood = null;
        _noteController.clear();
      });
      _showMessage('Your mood check-in is saved on this device 💗');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not save your mood check-in: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MoodHistoryRow extends StatelessWidget {
  const _MoodHistoryRow({required this.entry});

  final MoodEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MoodFaceIllustration(mood: entry.mood, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.mood,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 15),
              ),
              if (entry.note.isNotEmpty) Text(entry.note),
            ],
          ),
        ),
        Text(
          MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.createdAt)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
