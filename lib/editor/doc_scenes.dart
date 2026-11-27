import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../media/media_library.dart';
import '../models.dart';

/// A list of the slides with their words and notes, where a clip, a picture and a voice can be added to each.
/// [onChanged] is called after every change. Returns true when the person asks for the editor.
Future<bool> showDocScenes(BuildContext context, Lesson lesson, VoidCallback onChanged) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => _DocScenesPage(lesson: lesson, onChanged: onChanged)),
  );
  return result ?? false;
}

String _title(Scene s, int index) {
  final first = s.note.split('\n').first.trim();
  return first.isEmpty || first.startsWith('[') || first.startsWith('(') ? 'Slide ${index + 1}' : first;
}

String _kind(Scene s) {
  final m = RegExp(r'^\[(.+)\]$', multiLine: true).firstMatch(s.note);
  return m?.group(1) ?? '';
}

bool _hasPicture(Scene s) => !s.hasVideo && s.bgType == 'file' && s.bgValue.isNotEmpty;

bool _presenterSound(Scene s) => s.hasVideo && !s.videoMuted;

class _DocScenesPage extends StatefulWidget {
  const _DocScenesPage({required this.lesson, required this.onChanged});

  final Lesson lesson;
  final VoidCallback onChanged;

  @override
  State<_DocScenesPage> createState() => _DocScenesPageState();
}

class _DocScenesPageState extends State<_DocScenesPage> {
  int _filter = 0; // 0 all, 1 without clip or picture, 2 without voice

  List<Scene> get _scenes => widget.lesson.scenes;

  void _changed() {
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _seconds(int ms) => '${(ms / 1000).toStringAsFixed(1)} s';

  Future<void> _clip(Scene s) async {
    String? path;
    try {
      path = await pickMedia(context, MediaKind.video);
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    var ms = 0;
    try {
      ms = await KainuwaEncoder.audioDuration(path);
    } catch (_) {
      ms = 0;
    }
    if (!mounted) return;
    if (ms <= 0) {
      _say('This video could not be read.');
      return;
    }
    s.videoPath = path;
    s.videoMs = ms;
    s.videoStartMs = 0;
    s.videoFill = true;
    s.bgType = 'color';
    s.bgValue = '4278190080';
    // A presenter clip keeps its own sound. Other clips are silent, because your voice-over is the sound.
    s.videoMuted = !_kind(s).toUpperCase().contains('PRESENTER');
    s.durationMs = ms;
    _changed();
  }

  Future<void> _picture(Scene s) async {
    String? path;
    try {
      path = await pickMedia(context, MediaKind.image);
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    s.videoPath = '';
    s.videoMs = 0;
    s.bgType = 'file';
    s.bgValue = path;
    if (s.narrationMs > 0) s.durationMs = math.max(s.durationMs, s.narrationLenMs + 500);
    _changed();
  }

  Future<void> _voice(Scene s) async {
    String? path;
    try {
      path = await pickMedia(context, MediaKind.audio);
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    var ms = 0;
    try {
      ms = await KainuwaEncoder.audioDuration(path);
    } catch (_) {
      ms = 0;
    }
    if (!mounted) return;
    if (ms <= 0) {
      _say('That file could not be read as audio.');
      return;
    }
    s.narrationPath = path;
    s.narrationMs = ms;
    s.narrationSpeed = 1.0;
    // A slide with a picture or no picture lasts as long as the voice. A slide with a clip keeps the clip's length.
    if (!s.hasVideo) s.durationMs = ms + 500;
    _changed();
  }

  void _clear(Scene s, String what) {
    if (what == 'clip') {
      s.videoPath = '';
      s.videoMs = 0;
    } else if (what == 'picture') {
      s.bgType = 'color';
      s.bgValue = '4278190080';
    } else if (what == 'voice') {
      s.narrationPath = '';
      s.narrationMs = 0;
    }
    _changed();
  }

  void _addAfter(int index) {
    final s = _scenes[index];
    _scenes.insert(
      index + 1,
      Scene(
        id: newId(),
        durationMs: 5000,
        bgType: 'color',
        bgValue: '4278190080',
        note: '${_title(s, index)} (continued)',
      ),
    );
    _changed();
  }

  void _details(Scene s, int index) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_title(s, index)),
        content: SingleChildScrollView(
          child: SelectableText([
            if (s.narrationText.isNotEmpty) 'WORDS\n${s.narrationText}',
            if (s.note.trim().isNotEmpty) 'NOTES\n${s.note}',
          ].join('\n\n')),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  Widget _tag(IconData icon, String text, {bool ok = false, bool warn = false}) {
    final color = warn ? const Color(0xFFFFB74D) : (ok ? const Color(0xFF66BB6A) : const Color(0xFF9E9E9E));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _row(int index) {
    final s = _scenes[index];
    final kind = _kind(s);
    final tooLong = s.hasVideo && s.narrationMs > 0 && s.narrationLenMs > (s.videoMs - s.videoStartMs) + 300;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${index + 1}. ${_title(s, index).replaceFirst(RegExp(r'^\d+\.\s*'), '')}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (kind.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0x337351FF), borderRadius: BorderRadius.circular(8)),
                    child: Text(kind, style: const TextStyle(fontSize: 11)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'after') {
                      _addAfter(index);
                    } else if (v == 'details') {
                      _details(s, index);
                    } else {
                      _clear(s, v);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'details', child: Text('Words and notes')),
                    const PopupMenuItem(value: 'after', child: Text('Add a slide after this one')),
                    if (s.hasVideo) const PopupMenuItem(value: 'clip', child: Text('Remove the clip')),
                    if (_hasPicture(s)) const PopupMenuItem(value: 'picture', child: Text('Remove the picture')),
                    if (s.narrationPath.isNotEmpty) const PopupMenuItem(value: 'voice', child: Text('Remove the voice')),
                  ],
                ),
              ],
            ),
            if (s.narrationText.isNotEmpty)
              GestureDetector(
                onTap: () => _details(s, index),
                child: Text(s.narrationText, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _tag(Icons.movie_outlined, s.hasVideo ? 'Clip ${_seconds(s.videoMs)}' : 'No clip', ok: s.hasVideo),
                _tag(Icons.image_outlined, _hasPicture(s) ? 'Picture' : 'No picture', ok: _hasPicture(s)),
                _tag(
                  Icons.mic_none,
                  s.narrationPath.isNotEmpty
                      ? 'Voice ${_seconds(s.narrationLenMs)}'
                      : (_presenterSound(s) ? 'Clip sound' : 'No voice'),
                  ok: s.narrationPath.isNotEmpty || _presenterSound(s),
                ),
              ],
            ),
            if (tooLong)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'The voice is ${_seconds(s.narrationLenMs - (s.videoMs - s.videoStartMs))} longer than the clip, so the end will be cut. '
                  'Use a longer clip, a picture instead, or add a slide after this one and put the rest of the voice there.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFFB74D)),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(onPressed: () => _clip(s), icon: const Icon(Icons.movie_outlined, size: 18), label: Text(s.hasVideo ? 'Change clip' : 'Add clip')),
                OutlinedButton.icon(onPressed: () => _picture(s), icon: const Icon(Icons.image_outlined, size: 18), label: Text(_hasPicture(s) ? 'Change picture' : 'Add picture')),
                OutlinedButton.icon(onPressed: () => _voice(s), icon: const Icon(Icons.mic_none, size: 18), label: Text(s.narrationPath.isNotEmpty ? 'Change voice' : 'Add voice')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenes = _scenes;
    final visual = scenes.where((s) => s.hasVideo || _hasPicture(s)).length;
    final voice = scenes.where((s) => s.narrationPath.isNotEmpty || _presenterSound(s)).length;
    final shown = <int>[
      for (var i = 0; i < scenes.length; i++)
        if (_filter == 0 ||
            (_filter == 1 && !(scenes[i].hasVideo || _hasPicture(scenes[i]))) ||
            (_filter == 2 && !(scenes[i].narrationPath.isNotEmpty || _presenterSound(scenes[i]))))
          i,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Scenes (${scenes.length})'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Open editor'))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text('Clips or pictures $visual of ${scenes.length}.  Voices $voice of ${scenes.length}.')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('All'), selected: _filter == 0, onSelected: (_) => setState(() => _filter = 0)),
                ChoiceChip(label: const Text('No clip or picture'), selected: _filter == 1, onSelected: (_) => setState(() => _filter = 1)),
                ChoiceChip(label: const Text('No voice'), selected: _filter == 2, onSelected: (_) => setState(() => _filter = 2)),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('Nothing here.'))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _row(shown[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
