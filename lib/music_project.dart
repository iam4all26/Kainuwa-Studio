import 'dart:math' as math;

import 'avatar.dart';
import 'models.dart';
import 'pic_filter.dart';
import 'scene_canvas.dart';

/// What the person chose for a music video.
class MusicSetup {
  const MusicSetup({
    required this.cover,
    required this.coverAspect,
    required this.audio,
    required this.audioMs,
    required this.title,
    required this.artist,
    required this.aspectW,
    required this.aspectH,
    required this.vizKind,
    required this.accent,
  });

  final String cover;
  final double coverAspect;
  final String audio;
  final int audioMs;
  final String title;
  final String artist;
  final int aspectW;
  final int aspectH;
  final String vizKind;
  final int accent;
}

/// Fills a new, empty video with one slide: blurred cover as the background, the cover, a record
/// turning behind it, the audio picture, the title and the song as sound.
void buildMusicProject(Lesson lesson, MusicSetup s) {
  final size = lesson.stageSize;
  final w = size.$1;
  final h = size.$2;
  final portrait = h > w;

  final cs = math.min(0.58 * h, 0.62 * w);
  final shift = 0.34 * cs;
  final groupW = cs + shift;
  final coverCx = (w - groupW) / 2 + cs / 2;
  final discCx = coverCx + shift;
  final cy = (portrait ? 0.34 : 0.38) * h;

  // The cover cut to a square, so it fills a round record.
  double cropSide = 0;
  double cropTop = 0;
  if (s.coverAspect > 1.0) {
    cropSide = (1 - 1 / s.coverAspect) / 2;
  } else if (s.coverAspect > 0 && s.coverAspect < 1.0) {
    cropTop = (1 - s.coverAspect) / 2;
  }

  Layer square(String type, double centerX, double centerY, double side) {
    final l = Layer(id: newId(), type: type, w: side / w, h: side / h);
    l.cx = centerX / w;
    l.cy = centerY / h;
    return l;
  }

  final layers = <Layer>[];

  final rim = square('shape', discCx, cy, cs * 1.05)
    ..shape = 'circle'
    ..color = 0xFF0B0B0B;
  layers.add(rim);

  final disc = square('image', discCx, cy, cs)
    ..path = s.cover
    ..mask = 'circle'
    ..srcAspect = s.coverAspect
    ..cropL = cropSide
    ..cropR = cropSide
    ..cropT = cropTop
    ..cropB = cropTop
    ..animLoop = 'spin'
    ..animLoopMs = 9000;
  layers.add(disc);

  layers.add(square('shape', discCx, cy, cs * 0.2)
    ..shape = 'circle'
    ..color = 0x66FFFFFF);
  layers.add(square('shape', discCx, cy, cs * 0.13)
    ..shape = 'circle'
    ..color = 0xFF0B0B0B);

  final cover = square('image', coverCx, cy, cs)
    ..path = s.cover
    ..srcAspect = s.coverAspect
    ..cropL = cropSide
    ..cropR = cropSide
    ..cropT = cropTop
    ..cropB = cropTop
    ..shadowOn = true;
  layers.add(cover);

  final spec = AvatarSpec(audio: s.audio, startMs: 0, sourceMs: s.audioMs);
  final viz = Layer(id: newId(), type: 'shape', shape: 'viz_${s.vizKind}', color: s.accent, w: 0.78, h: 0.1);
  viz.cx = 0.5;
  viz.cy = 0.7;
  viz.avatar = spec.encode();
  layers.add(viz);

  if (s.title.trim().isNotEmpty) {
    final t = Layer(id: newId(), type: 'text', text: s.title.trim(), color: 0xFFFFFFFF);
    setLayerTextSizePx(t, 64);
    if (t.w > 0.9) {
      final f = 0.9 / t.w;
      t.w = 0.9;
      t.h = t.h * f;
    }
    t.cx = 0.5;
    t.cy = 0.8;
    layers.add(t);
  }
  if (s.artist.trim().isNotEmpty) {
    final a = Layer(id: newId(), type: 'text', text: s.artist.trim(), color: s.accent, bold: false);
    setLayerTextSizePx(a, 36);
    if (a.w > 0.9) {
      final f = 0.9 / a.w;
      a.w = 0.9;
      a.h = a.h * f;
    }
    a.cx = 0.5;
    a.cy = 0.88;
    layers.add(a);
  }

  final scene = Scene(
    id: newId(),
    durationMs: math.max(1000, s.audioMs),
    bgType: 'file',
    bgValue: s.cover,
    bgFilter: const PicFilter(blur: 0.04, dim: 0.5).encode(),
    layers: layers,
  );
  lesson.scenes
    ..clear()
    ..add(scene);

  lesson.audioClips
    ..clear()
    ..add(AudioClip(
      id: newId(),
      path: s.audio,
      label: s.title.trim().isEmpty ? 'Song' : s.title.trim(),
      kind: 'music',
      startMs: 0,
      durationMs: math.max(1000, s.audioMs),
      sourceMs: s.audioMs,
      volume: 1.0,
    ));
}
