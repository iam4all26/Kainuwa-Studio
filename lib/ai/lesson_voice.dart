import 'dart:io';
import 'dart:math' as math;

import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../models.dart';
import 'lesson_plan.dart';

/// Gives a slide a new length and moves its items' times along with it.
void _rescale(Scene s, int newMs) {
  final old = s.durationMs;
  if (old <= 0 || newMs == old) {
    s.durationMs = newMs;
    return;
  }
  final f = newMs / old;
  for (final l in s.layers) {
    l.startMs = (l.startMs * f).round();
    if (l.endMs >= 0) l.endMs = math.min((l.endMs * f).round(), newMs);
    l.animStartMs = (l.animStartMs * f).round();
  }
  s.durationMs = newMs;
}

int _words(String text) => text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// Makes a voice for every slide with the phone's own text to speech (offline). Each slide gets
/// its voice as narration and lasts at least as long as the voice. Returns how many slides got no voice.
Future<int> applyTtsVoices(
  Lesson lesson,
  LessonPlan plan, {
  String lang = '',
  void Function(int done, int total)? onProgress,
}) async {
  final base = await KainuwaEncoder.filesDir();
  final dir = Directory('$base/kainuwa_data/tts');
  await dir.create(recursive: true);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final n = math.min(lesson.scenes.length, plan.slides.length);
  var failed = 0;
  for (var i = 0; i < n; i++) {
    onProgress?.call(i + 1, n);
    final text = plan.slides[i].narration.trim();
    if (text.isEmpty) continue;
    try {
      final path = '${dir.path}/slide_${stamp}_$i.wav';
      await KainuwaEncoder.ttsToFile(text, path, lang: lang);
      final ms = await KainuwaEncoder.audioDuration(path);
      if (ms <= 0) {
        failed++;
        continue;
      }
      final scene = lesson.scenes[i];
      scene.narrationPath = path;
      scene.narrationMs = ms;
      scene.narrationClean = false;
      _rescale(scene, math.max(scene.durationMs, ms + 600));
    } catch (_) {
      failed++;
    }
  }
  return failed;
}

/// Puts the person's own voice-over under the whole video and times the slides to it, by the
/// number of words in each slide's narration.
void applyOwnVoice(Lesson lesson, LessonPlan plan, String path, int audioMs) {
  final n = math.min(lesson.scenes.length, plan.slides.length);
  if (n == 0 || audioMs <= 0) return;
  final weights = <double>[];
  for (var i = 0; i < n; i++) {
    final w = _words(plan.slides[i].narration);
    weights.add(w > 0 ? w.toDouble() : plan.slides[i].seconds * 2.5);
  }
  final sum = weights.fold<double>(0, (a, b) => a + b);
  var used = 0;
  for (var i = 0; i < n; i++) {
    var ms = math.max(3000, (audioMs * weights[i] / sum).round());
    if (i == n - 1 && used + ms < audioMs) ms = audioMs - used;
    _rescale(lesson.scenes[i], ms);
    used += ms;
  }
  lesson.audioClips.add(AudioClip(
    id: newId(),
    path: path,
    label: 'Voice-over',
    kind: 'voice',
    startMs: 0,
    durationMs: audioMs,
    sourceMs: audioMs,
    volume: 1.0,
  ));
}
