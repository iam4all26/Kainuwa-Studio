import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../models.dart';

/// Where a moment of the lesson falls: which scene, and how far into it.
class SceneSpot {
  const SceneSpot(this.index, this.localMs);

  final int index;
  final int localMs;
}

SceneSpot sceneAt(Lesson lesson, int ms) {
  if (lesson.scenes.isEmpty) return const SceneSpot(0, 0);
  var start = 0;
  for (var i = 0; i < lesson.scenes.length; i++) {
    final end = start + lesson.scenes[i].durationMs;
    if (ms < end || i == lesson.scenes.length - 1) {
      return SceneSpot(i, math.max(0, math.min(ms - start, lesson.scenes[i].durationMs)));
    }
    start = end;
  }
  return const SceneSpot(0, 0);
}

int sceneStartMs(Lesson lesson, int index) {
  var start = 0;
  for (var i = 0; i < index && i < lesson.scenes.length; i++) {
    start += lesson.scenes[i].durationMs;
  }
  return start;
}

/// Plays a whole lesson inside the editor: one playhead for the entire lesson.
class LessonPlayer extends ChangeNotifier {
  LessonPlayer({required TickerProvider vsync, required this.lesson}) {
    _ticker = vsync.createTicker(_onTick);
  }

  final Lesson lesson;
  late final Ticker _ticker;

  int positionMs = 0;
  bool playing = false;

  /// When true, narration is not played during preview.
  bool muted = false;

  int _baseMs = 0;
  int _audioSceneIndex = -1;
  bool _disposed = false;

  int get totalMs => lesson.durationMs;

  void _onTick(Duration elapsed) {
    final next = _baseMs + elapsed.inMilliseconds;
    final total = totalMs;
    if (next >= total) {
      positionMs = total;
      _finish();
      return;
    }
    positionMs = next;
    _syncAudio();
    notifyListeners();
  }

  void _syncAudio() {
    final spot = sceneAt(lesson, positionMs);
    if (spot.index == _audioSceneIndex) return;
    _audioSceneIndex = spot.index;
    KainuwaEncoder.stopAudio().then((_) {}, onError: (_) {});
    if (muted || spot.localMs > 400) return;
    final scene = lesson.scenes[spot.index];
    if (scene.narrationPath.isNotEmpty) {
      KainuwaEncoder.playAudio(scene.narrationPath, volume: scene.narrationVolume)
          .then((_) {}, onError: (_) {});
    }
  }

  void _finish() {
    _ticker.stop();
    playing = false;
    _audioSceneIndex = -1;
    KainuwaEncoder.stopAudio().then((_) {}, onError: (_) {});
    notifyListeners();
  }

  void play() {
    if (playing || lesson.scenes.isEmpty) return;
    if (positionMs >= totalMs) positionMs = 0;
    _baseMs = positionMs;
    _audioSceneIndex = -1;
    playing = true;
    _ticker.stop();
    _ticker.start();
    _syncAudio();
    notifyListeners();
  }

  void pause() {
    if (!playing) return;
    _ticker.stop();
    playing = false;
    _audioSceneIndex = -1;
    KainuwaEncoder.stopAudio().then((_) {}, onError: (_) {});
    notifyListeners();
  }

  void toggle() => playing ? pause() : play();

  /// Moves the playhead. Playback carries on from the new place when it was running.
  void seek(int ms) {
    positionMs = math.max(0, math.min(ms, totalMs));
    if (playing) {
      _ticker.stop();
      _baseMs = positionMs;
      _audioSceneIndex = -1;
      _ticker.start();
      _syncAudio();
    }
    notifyListeners();
  }

  /// Keeps the playhead inside the lesson after scenes were changed.
  void clampToLesson() {
    if (positionMs > totalMs) {
      positionMs = totalMs;
      if (playing) _finish();
    }
  }

  void previous() {
    final spot = sceneAt(lesson, positionMs);
    if (spot.localMs > 1500 || spot.index == 0) {
      seek(sceneStartMs(lesson, spot.index));
    } else {
      seek(sceneStartMs(lesson, spot.index - 1));
    }
  }

  void next() {
    final spot = sceneAt(lesson, positionMs);
    if (spot.index >= lesson.scenes.length - 1) {
      seek(totalMs);
    } else {
      seek(sceneStartMs(lesson, spot.index + 1));
    }
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    KainuwaEncoder.stopAudio().then((_) {}, onError: (_) {});
    super.dispose();
  }
}
