import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../app_state.dart';
import '../models.dart';

/// The text written on a slide (its text items, in order), as the words for the voice.
String voiceTextOf(Scene scene) {
  final parts = <String>[];
  for (final l in scene.layers) {
    if (l.type != 'text') continue;
    final t = l.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isNotEmpty) parts.add(t);
  }
  return parts.join('. ');
}

/// One slide in the list: the words to say, and whether to make its voice.
class _Pick {
  _Pick(this.index, this.controller, this.fromSlide, this.include);
  final int index;
  final TextEditingController controller;
  final bool fromSlide;
  bool include;
}

class _VoiceAllPage extends StatefulWidget {
  const _VoiceAllPage({required this.lesson});
  final Lesson lesson;

  @override
  State<_VoiceAllPage> createState() => _VoiceAllPageState();
}

class _VoiceAllPageState extends State<_VoiceAllPage> {
  final List<_Pick> _items = <_Pick>[];
  bool _onlyMissing = true;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.lesson.scenes.length; i++) {
      final s = widget.lesson.scenes[i];
      final saved = s.narrationText.trim();
      final text = saved.isNotEmpty ? saved : voiceTextOf(s);
      _items.add(_Pick(i, TextEditingController(text: text), saved.isEmpty, true));
    }
    _applyFilter();
  }

  @override
  void dispose() {
    for (final p in _items) {
      p.controller.dispose();
    }
    super.dispose();
  }

  void _applyFilter() {
    for (final p in _items) {
      final s = widget.lesson.scenes[p.index];
      p.include = !_onlyMissing || s.narrationPath.isEmpty;
    }
  }

  void _start() {
    final out = <MapEntry<int, String>>[];
    for (final p in _items) {
      final text = p.controller.text.trim();
      if (p.include && text.isNotEmpty) out.add(MapEntry<int, String>(p.index, text));
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Voice for all slides')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              (st.settings.realVoice
                      ? 'Each slide is read with the real voice you chose (English). '
                      : 'The real voice is off, so the phone voice will be used. ') +
                  'Change the words if you like. They are never written on the slide. '
                      'Each slide then lasts at least as long as its voice, and a long list can take a while.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6)),
            ),
          ),
          SwitchListTile(
            title: const Text('Only slides without a voice'),
            value: _onlyMissing,
            onChanged: (v) => setState(() {
              _onlyMissing = v;
              _applyFilter();
            }),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _items.length,
              itemBuilder: (c, i) {
                final p = _items[i];
                final has = widget.lesson.scenes[p.index].narrationPath.isNotEmpty;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(value: p.include, onChanged: (v) => setState(() => p.include = v ?? false)),
                            Expanded(
                              child: Text(
                                'Slide ${p.index + 1}${has ? '  (has a voice)' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        TextField(
                          controller: p.controller,
                          minLines: 2,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: 'What should the voice say?',
                            helperText: p.fromSlide && p.controller.text.isNotEmpty
                                ? 'Taken from the words on the slide. Write the narration here if you want more.'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _start, child: const Text('Make the voices')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Makes a voice for the slides of a lesson from the narration text saved on each slide (or the
/// words written on it, when there is none). The person can edit every text first.
/// [onChanged] is called after each slide so nothing is lost if the person stops.
Future<void> showVoiceAll(BuildContext context, Lesson lesson, VoidCallback onChanged) async {
  KainuwaEncoder.neuralWarmup();
  final picked = await Navigator.of(context).push<List<MapEntry<int, String>>>(
    MaterialPageRoute<List<MapEntry<int, String>>>(builder: (_) => _VoiceAllPage(lesson: lesson)),
  );
  if (picked == null || !context.mounted) return;
  final todo = picked.map((e) => e.key).toList();
  final texts = <int, String>{for (final e in picked) e.key: e.value};
  if (todo.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('There is no slide to make a voice for.')));
    return;
  }

  final progress = ValueNotifier<int>(0);
  var cancelled = false;
  var failed = 0;
  var done = 0;
  var finished = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Making the voices'),
      content: ValueListenableBuilder<int>(
        valueListenable: progress,
        builder: (c, n, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: todo.isEmpty ? 0 : n / todo.length),
            const SizedBox(height: 8),
            Text('Slide ${math.min(n + 1, todo.length)} of ${todo.length}'),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => cancelled = true, child: const Text('Stop'))],
    ),
  );

  try {
    final base = await KainuwaEncoder.filesDir();
    final dir = Directory('$base/kainuwa_data/tts');
    await dir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final i in todo) {
      if (cancelled) break;
      final scene = lesson.scenes[i];
      try {
        final path = '${dir.path}/slide_${stamp}_$i.wav';
        await KainuwaEncoder.ttsToFile(texts[i] ?? voiceTextOf(scene), path);
        final ms = await KainuwaEncoder.audioDuration(path);
        if (ms <= 0) {
          failed++;
        } else {
          scene.narrationPath = path;
          scene.narrationText = texts[i] ?? scene.narrationText;
          scene.narrationMs = ms;
          scene.narrationClean = false;
          scene.durationMs = math.max(scene.durationMs, ms + 600);
          done++;
          onChanged();
        }
      } catch (_) {
        failed++;
      }
      progress.value = progress.value + 1;
    }
  } catch (_) {
    failed++;
  }
  finished = true;
  if (finished && context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    final msg = cancelled
        ? 'Stopped. $done slide${done == 1 ? '' : 's'} got a voice.'
        : (failed == 0 ? 'Done. $done slide${done == 1 ? '' : 's'} got a voice.' : '$done slides got a voice, $failed could not.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  progress.dispose();
}
