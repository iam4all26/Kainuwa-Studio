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

/// Makes a voice for the slides of an existing lesson from the text written on them.
/// [onChanged] is called after each slide so nothing is lost if the person stops.
Future<void> showVoiceAll(BuildContext context, Lesson lesson, VoidCallback onChanged) async {
  final st = AppScope.read(context);
  KainuwaEncoder.neuralWarmup();
  var onlyMissing = true;
  final start = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        scrollable: true,
        title: const Text('Voice for all slides'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              st.settings.realVoice
                  ? 'Each slide is read with the real voice you chose (English).'
                  : 'The real voice is off, so the phone voice will be used. You can turn the real voice on in Settings.',
              style: const TextStyle(fontSize: 13, color: Color(0xFFB5ABD6)),
            ),
            const SizedBox(height: 8),
            const Text(
              'The voice reads the text written on each slide. Slides with no text are skipped. '
              'Each slide then lasts at least as long as its voice. It can take a while on a phone, so keep the app open.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6)),
            ),
            const SizedBox(height: 8),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only slides without a voice'),
              value: true,
              groupValue: onlyMissing,
              onChanged: (v) => setS(() => onlyMissing = v ?? true),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              title: const Text('All slides (replace the old voices)'),
              value: false,
              groupValue: onlyMissing,
              onChanged: (v) => setS(() => onlyMissing = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Start')),
        ],
      ),
    ),
  );
  if (start != true || !context.mounted) return;

  final todo = <int>[];
  for (var i = 0; i < lesson.scenes.length; i++) {
    final s = lesson.scenes[i];
    if (voiceTextOf(s).isEmpty) continue;
    if (onlyMissing && s.narrationPath.isNotEmpty) continue;
    todo.add(i);
  }
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
        await KainuwaEncoder.ttsToFile(voiceTextOf(scene), path);
        final ms = await KainuwaEncoder.audioDuration(path);
        if (ms <= 0) {
          failed++;
        } else {
          scene.narrationPath = path;
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
