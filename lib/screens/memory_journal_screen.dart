import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../models/memory_entry.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class MemoryJournalScreen extends StatefulWidget {
  const MemoryJournalScreen({required this.session, super.key});

  final AppSession session;

  @override
  State<MemoryJournalScreen> createState() => _MemoryJournalScreenState();
}

class _MemoryJournalScreenState extends State<MemoryJournalScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _favoriteMemoryIds = {};
  StreamSubscription<PlayerState>? _playerSubscription;
  Timer? _recordingTimer;
  bool _isRecording = false;
  bool _isSavingMemory = false;
  String _selectedFilter = 'All';
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  String? _playingMemoryId;
  PlayerState _playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _playerSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _playingMemoryId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playerSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  List<MemoryEntry> get _visibleMemories {
    final memories = widget.session.memories.toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    final type = switch (_selectedFilter) {
      'Photos' => MemoryType.photo,
      'Notes' => MemoryType.note,
      'Voice' => MemoryType.voice,
      _ => null,
    };
    return type == null
        ? memories
        : memories.where((memory) => memory.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: AppPageHeader(
                  title: 'Little memory journal',
                  subtitle: 'Keep the moments you want to remember.',
                  emoji: '💌',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final (index, filter) in [
                      'All',
                      'Photos',
                      'Notes',
                      'Voice',
                    ].indexed) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _MemoryFilterPill(
                          label: filter,
                          selected: _selectedFilter == filter,
                          onTap: () => setState(() => _selectedFilter = filter),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isSavingMemory)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: PetalCard(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Saving memory…',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: PetalCard(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Theme.of(context).colorScheme.primary,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recording · ${_formatDuration(_recordingDuration)}',
                          ),
                        ),
                        TextButton(
                          onPressed: _stopRecording,
                          child: const Text('Stop and save'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.session.isLoading
                    ? _loading()
                    : _buildMemoryGrid(),
              ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 18,
            child: SizedBox(
              width: 56,
              height: 56,
              child: FloatingActionButton(
                heroTag: 'add-memory',
                onPressed: _isSavingMemory ? null : _showAddMemoryOptions,
                backgroundColor: PetalPopColors.hotPink,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 5,
                tooltip: 'Add a memory',
                child: const Icon(Icons.add_rounded, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryGrid() {
    final memories = _visibleMemories;
    if (memories.isEmpty) {
      final (emoji, title, message) = switch (_selectedFilter) {
        'Photos' => (
          '📷',
          'Your photo memories will bloom here',
          'Choose a photo from your gallery to save it privately.',
        ),
        'Notes' => (
          '🌸',
          'A little space for lovely days',
          'Your saved notes will appear here.',
        ),
        'Voice' => (
          '🎙️',
          'No voice memories yet',
          'Save a recording and you can listen to it here.',
        ),
        _ => (
          '💌',
          'Your memories will bloom here',
          'Add a photo, note, or voice memory to keep a moment.',
        ),
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 84),
          child: PetalCard(
            child: EmptyState(emoji: emoji, title: title, message: message),
          ),
        ),
      );
    }

    return GridView.builder(
      key: const PageStorageKey('memory-grid'),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 92),
      itemCount: memories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .82,
      ),
      itemBuilder: (context, index) {
        final entry = memories[index];
        return _MemoryGridCard(
          key: ValueKey(entry.id),
          entry: entry,
          isFavorite: _favoriteMemoryIds.contains(entry.id),
          isPlaying:
              _playingMemoryId == entry.id &&
              _playerState == PlayerState.playing,
          onFavorite: () => _toggleFavorite(entry),
          onPlay: () => _togglePlayback(entry),
          onEdit: entry.type == MemoryType.note
              ? () => _editNote(existing: entry)
              : null,
          onDelete: () => _deleteMemory(entry),
        );
      },
    );
  }

  Future<void> _showAddMemoryOptions() async {
    switch (_selectedFilter) {
      case 'Photos':
        await _pickPhoto();
        return;
      case 'Notes':
        await _editNote();
        return;
      case 'Voice':
        await _startRecording();
        return;
    }
    if (!mounted) return;

    final surfaceColor = Theme.of(context).colorScheme.surface;
    final action = await showModalBottomSheet<_AddMemoryAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: surfaceColor,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a Memory',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Text('📷', style: TextStyle(fontSize: 24)),
                title: const Text('Photo'),
                onTap: () => Navigator.pop(context, _AddMemoryAction.photo),
              ),
              ListTile(
                leading: const Text('📝', style: TextStyle(fontSize: 24)),
                title: const Text('Note'),
                onTap: () => Navigator.pop(context, _AddMemoryAction.note),
              ),
              ListTile(
                leading: const Text('🎤', style: TextStyle(fontSize: 24)),
                title: const Text('Voice'),
                onTap: () => Navigator.pop(context, _AddMemoryAction.voice),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AddMemoryAction.photo:
        await _pickPhoto();
      case _AddMemoryAction.note:
        await _editNote();
      case _AddMemoryAction.voice:
        await _startRecording();
    }
  }

  void _toggleFavorite(MemoryEntry entry) {
    final nowFavorite = !_favoriteMemoryIds.contains(entry.id);
    setState(() {
      if (nowFavorite) {
        _favoriteMemoryIds.add(entry.id);
      } else {
        _favoriteMemoryIds.remove(entry.id);
      }
    });
    _showMessage(
      nowFavorite ? '♥ Added to favorites' : 'Removed from favorites',
    );
  }

  Widget _loading() => const Center(child: CircularProgressIndicator());

  Future<void> _pickPhoto() async {
    if (_isSavingMemory) return;
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (!mounted || selected == null) return;
      final caption = await _captionDialog();
      if (!mounted || caption == null) return;
      setState(() => _isSavingMemory = true);
      final stored = await widget.session.storage.copyMediaIntoApp(
        sourcePath: selected.path,
        type: MemoryType.photo,
        extension: _extensionFrom(selected.path, 'jpg'),
      );
      final photo = MemoryEntry(
        id: stored.id,
        type: MemoryType.photo,
        title: caption.isEmpty ? 'A little photo memory' : caption,
        description: caption,
        createdAt: DateTime.now(),
        filePath: stored.filePath,
      );
      await widget.session.addMemory(photo);
      if (!mounted) return;
      _showMessage('Photo saved on this device 🌸');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Could not add that photo. Check gallery access and try again. ($error)',
      );
    } finally {
      if (mounted && _isSavingMemory) {
        setState(() => _isSavingMemory = false);
      }
    }
  }

  Future<String?> _captionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _PhotoCaptionDialog(),
    );
  }

  Future<void> _editNote({MemoryEntry? existing}) async {
    if (_isSavingMemory) return;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _MemoryEditorDialog(existing: existing),
    );
    if (result == null || !mounted || _isSavingMemory) return;

    setState(() => _isSavingMemory = true);
    try {
      if (existing == null) {
        await widget.session.addMemory(
          MemoryEntry(
            id: const Uuid().v4(),
            type: MemoryType.note,
            title: result.$1,
            description: result.$2,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await widget.session.updateMemory(
          MemoryEntry(
            id: existing.id,
            type: existing.type,
            title: result.$1,
            description: result.$2,
            createdAt: existing.createdAt,
            filePath: existing.filePath,
            durationSeconds: existing.durationSeconds,
          ),
        );
      }
      if (mounted) {
        _showMessage(existing == null ? 'Note saved 🌷' : 'Note updated 🌷');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not save your note: $error');
    } finally {
      if (mounted) setState(() => _isSavingMemory = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        _showMessage(
          'Microphone access was not granted. Allow it in Android app permissions to record a voice memory.',
        );
        return;
      }
      final path = await widget.session.storage.createMediaPath(
        type: MemoryType.voice,
        extension: 'm4a',
      );
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _recordingPath = path;
      _recordingDuration = Duration.zero;
      final startedAt = DateTime.now();
      setState(() => _isRecording = true);
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        setState(() {
          _recordingDuration = DateTime.now().difference(startedAt);
        });
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not start the microphone recording: $error');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    try {
      final stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? _recordingPath;
      if (path == null) {
        throw StateError('The recorder did not return a saved audio file.');
      }
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        if (await file.exists()) await file.delete();
        throw StateError('The recording file is empty.');
      }
      final duration = _recordingDuration.inSeconds;
      final entry = MemoryEntry(
       id: const Uuid().v4(),
        type: MemoryType.voice,
        title: 'Voice memory',
        description: '',
        createdAt: DateTime.now(),
        filePath: path,
        durationSeconds: duration,
      );
      await widget.session.addMemory(entry);
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });
      _showMessage('Voice memory saved on this device 🎙️');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });
      _showMessage('Could not save the recording: $error');
    }
  }

  Future<void> _togglePlayback(MemoryEntry entry) async {
    final path = entry.filePath;
    final signedUrl = entry.signedUrl;
    if (path == null && signedUrl == null) {
      _showMessage('This recording does not have a saved audio file.');
      return;
    }
    if (path != null && !await File(path).exists() && signedUrl == null) {
      _showMessage('The recording file is missing from this device.');
      return;
    }
    try {
      if (_playingMemoryId == entry.id && _playerState == PlayerState.playing) {
        await _player.pause();
        return;
      }
      setState(() => _playingMemoryId = entry.id);
      if (signedUrl != null) {
        await _player.play(UrlSource(signedUrl));
      } else {
        await _player.play(DeviceFileSource(path!));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _playingMemoryId = null);
      _showMessage('Could not play this recording: $error');
    }
  }

  Future<void> _deleteMemory(MemoryEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text('This also removes its saved photo or recording.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    try {
      if (_playingMemoryId == entry.id) {
        await _player.stop();
        _playingMemoryId = null;
      }
      await widget.session.deleteMemory(entry.id);
      if (mounted) _showMessage('Memory deleted.');
    } catch (error) {
      if (mounted) _showMessage('Could not delete this memory: $error');
    }
  }

  void _showMessage(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: scheme.onInverseSurface),
          ),
          duration: const Duration(milliseconds: 1700),
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.inverseSurface,
        ),
      );
  }

  String _extensionFrom(String path, String fallback) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? fallback : name.substring(dot + 1);
  }
}

enum _AddMemoryAction { photo, note, voice }

enum _MemoryAction { edit, delete }

class _MemoryFilterPill extends StatelessWidget {
  const _MemoryFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Semantics(
          button: true,
          selected: selected,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoCaptionDialog extends StatefulWidget {
  const _PhotoCaptionDialog();

  @override
  State<_PhotoCaptionDialog> createState() => _PhotoCaptionDialogState();
}

class _PhotoCaptionDialogState extends State<_PhotoCaptionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a caption'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'A little note about this photo (optional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save photo'),
        ),
      ],
    );
  }
}

class _MemoryEditorDialog extends StatefulWidget {
  const _MemoryEditorDialog({required this.existing});

  final MemoryEntry? existing;

  @override
  State<_MemoryEditorDialog> createState() => _MemoryEditorDialogState();
}

class _MemoryEditorDialogState extends State<_MemoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? 'Write a memory' : 'Edit memory'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please add a title.'
                    : null,
              ),
              TextFormField(
                controller: _descriptionController,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Your memory',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Write a few words about your memory.'
                    : null,
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
        FilledButton(onPressed: _save, child: const Text('Save note')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      _titleController.text.trim(),
      _descriptionController.text.trim(),
    ));
  }
}

class _MemoryGridCard extends StatelessWidget {
  const _MemoryGridCard({
    super.key,
    required this.entry,
    required this.isFavorite,
    required this.isPlaying,
    required this.onFavorite,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  final MemoryEntry entry;
  final bool isFavorite;
  final bool isPlaying;
  final VoidCallback onFavorite;
  final VoidCallback onPlay;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: PetalPopColors.deepPink.withValues(alpha: .08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.type == MemoryType.photo)
            _memoryPreview(context)
          else
            Expanded(child: _memoryPreview(context)),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  _memoryTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                padding: EdgeInsets.zero,
                tooltip: isFavorite ? 'Remove favorite' : 'Add to favorites',
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
              ),
              PopupMenuButton<_MemoryAction>(
                tooltip: 'Memory options',
                padding: EdgeInsets.zero,
                iconSize: 19,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onSelected: (action) {
                  if (action == _MemoryAction.delete) onDelete();
                  if (action == _MemoryAction.edit) onEdit?.call();
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: _MemoryAction.edit,
                      child: Text('Edit'),
                    ),
                  const PopupMenuItem(
                    value: _MemoryAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          Text(
            MaterialLocalizations.of(context).formatShortDate(entry.createdAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  String get _memoryTitle {
    if (entry.type == MemoryType.photo && entry.description.isNotEmpty) {
      return entry.description;
    }
    return entry.title;
  }

  Widget _memoryPreview(BuildContext context) {
    switch (entry.type) {
      case MemoryType.photo:
        final path = entry.filePath;
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: entry.signedUrl != null
                ? Image.network(
                    entry.signedUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _MissingMedia(
                          message: 'This private photo could not be loaded.',
                        ),
                  )
                : path != null && File(path).existsSync()
                ? Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _MissingMedia(
                          message: 'This photo could not be displayed.',
                        ),
                  )
                : const _MissingMedia(message: 'Photo file is not available.'),
          ),
        );
      case MemoryType.note:
        return Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📝', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  entry.description,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      case MemoryType.voice:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎤', style: TextStyle(fontSize: 29)),
              const SizedBox(height: 4),
              Text(
                'Voice memory',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: onPlay,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 17,
                ),
                label: Text(
                  _formatDuration(Duration(seconds: entry.durationSeconds)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _MissingMedia extends StatelessWidget {
  const _MissingMedia({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined),
          const SizedBox(height: 6),
          Text(message),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
