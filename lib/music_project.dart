import 'dart:convert';
import 'dart:math' as math;

import 'avatar.dart';
import 'models.dart';
import 'pic_filter.dart';
import 'scene_canvas.dart';
import 'stage_shape.dart';

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
    this.layout = 0,
    this.titleFont = '',
    this.artistFont = '',
    this.form = const {},
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

  /// Where the cover and record go on a wide video: 0 centre, 1 left, 2 right.
  final int layout;
  final String titleFont;
  final String artistFont;

  /// The choices of the setup screen, saved with the video so the setup can be opened again.
  final Map<String, dynamic> form;
}

/// The one slide of a music video: blurred cover as the background, the cover, a record turning
/// behind it, the audio picture, the title and the artist. Call [Stage.use] with the video shape
/// first (the text sizes depend on it). Used for the preview and for the real project.
Scene buildMusicScene(MusicSetup s) {
  final w = Stage.w;
  final h = Stage.h;
  final wide = w / h >= 1.3;
  final side = wide && s.layout != 0;
  final left = s.layout == 1;

  final ring = s.vizKind == 'circle';
  // The record is never taller than the cover. With the ring style the ring (not the record)
  // fills the cover's height, so the record is smaller and the ring grows around it.
  final cs = math.min(0.58 * h, 0.86 * w / (ring ? 1.5 : 1.4));
  final shift = (ring ? 0.5 : 0.40) * cs;
  final discD = (ring ? 0.66 : 0.96) * cs;
  final groupW = cs + shift;
  final groupCx = side ? (left ? 0.30 * w : 0.70 * w) : w / 2;
  final coverCx = groupCx - groupW / 2 + cs / 2;
  final discCx = coverCx + shift;
  final portrait = h > w;
  final cy = side ? 0.5 * h : (portrait ? 0.34 : 0.38) * h;

  final textCx = side ? (left ? 0.72 * w : 0.28 * w) : w / 2;
  final textMaxW = side ? 0.42 : 0.9;

  // The cover cut to a square, so it fills a round record.
  double cropSide = 0;
  double cropTop = 0;
  if (s.coverAspect > 1.0) {
    cropSide = (1 - 1 / s.coverAspect) / 2;
  } else if (s.coverAspect > 0 && s.coverAspect < 1.0) {
    cropTop = (1 - s.coverAspect) / 2;
  }

  Layer square(String type, double centerX, double centerY, double sideLen) {
    final l = Layer(id: newId(), type: type, w: sideLen / w, h: sideLen / h);
    l.cx = centerX / w;
    l.cy = centerY / h;
    return l;
  }

  final layers = <Layer>[];

  layers.add(square('shape', discCx, cy, discD * (ring ? 1.06 : 1.04))
    ..shape = 'circle'
    ..color = 0xFF0B0B0B);

  // Without a cover (the template previews) a plain coloured record and cover are drawn instead.
  final noCover = s.cover.isEmpty;
  final sample = Color.lerp(Color(s.accent), const Color(0xFF000000), 0.45)!.toARGB32();
  layers.add(noCover
      ? (square('shape', discCx, cy, discD)
        ..shape = 'circle'
        ..color = sample)
      : (square('image', discCx, cy, discD)
        ..path = s.cover
        ..mask = 'circle'
        ..srcAspect = s.coverAspect
        ..cropL = cropSide
        ..cropR = cropSide
        ..cropT = cropTop
        ..cropB = cropTop
        ..animLoop = 'spin'
        ..animLoopMs = 9000));

  layers.add(square('shape', discCx, cy, discD * 0.2)
    ..shape = 'circle'
    ..color = 0x66FFFFFF);
  layers.add(square('shape', discCx, cy, discD * 0.13)
    ..shape = 'circle'
    ..color = 0xFF0B0B0B);

  final coverLayer = noCover
      ? (square('shape', coverCx, cy, cs)
        ..shape = 'rect'
        ..color = sample
        ..shadowOn = true)
      : (square('image', coverCx, cy, cs)
        ..path = s.cover
        ..srcAspect = s.coverAspect
        ..cropL = cropSide
        ..cropR = cropSide
        ..cropT = cropTop
        ..cropB = cropTop
        ..shadowOn = true);

  final spec = AvatarSpec(audio: s.audio, startMs: 0, sourceMs: s.audioMs);
  final viz = Layer(
    id: newId(),
    type: 'shape',
    shape: 'viz_${s.vizKind}',
    color: s.accent,
    w: ring ? cs / w : (side ? 0.40 : 0.78),
    h: ring ? cs / h : side ? 0.12 : ((s.vizKind == 'rise' || s.vizKind == 'blocks') ? 0.15 : (s.vizKind == 'wave' ? 0.13 : 0.1)),
  );
  viz.cx = ring ? discCx / w : (side ? textCx / w : 0.5);
  viz.cy = ring ? cy / h : (side ? 0.64 : 0.7);
  viz.avatar = spec.encode();
  // The ring goes behind the cover, so only the part beside the cover shows.
  if (ring) layers.add(viz);
  layers.add(coverLayer);
  if (!ring) layers.add(viz);

  Layer fitted(Layer t, double px) {
    setLayerTextSizePx(t, px);
    if (t.w > textMaxW) {
      final f = textMaxW / t.w;
      t.w = textMaxW;
      t.h = t.h * f;
    }
    t.cx = textCx / w;
    return t;
  }

  if (s.title.trim().isNotEmpty) {
    final t = Layer(id: newId(), type: 'text', text: s.title.trim(), color: 0xFFFFFFFF, fontFamily: s.titleFont);
    fitted(t, side ? 56 : 64).cy = side ? 0.38 : 0.8;
    layers.add(t);
  }
  if (s.artist.trim().isNotEmpty) {
    final a = Layer(id: newId(), type: 'text', text: s.artist.trim(), color: s.accent, bold: false, fontFamily: s.artistFont);
    fitted(a, side ? 34 : 36).cy = side ? 0.50 : 0.88;
    layers.add(a);
  }

  return Scene(
    id: newId(),
    durationMs: math.max(1000, s.audioMs),
    bgType: 'file',
    bgValue: s.cover,
    bgFilter: const PicFilter(blur: 0.04, dim: 0.5).encode(),
    layers: layers,
  );
}

/// Fills a new, empty video with the music slide and the song as sound.
void buildMusicProject(Lesson lesson, MusicSetup s) {
  lesson.aspectW = s.aspectW;
  lesson.aspectH = s.aspectH;
  lesson.setupKind = 'music';
  lesson.setupForm = jsonEncode(s.form);
  Stage.use(s.aspectW, s.aspectH);
  try {
    final scene = buildMusicScene(s);
    lesson.scenes
      ..clear()
      ..add(scene);
  } finally {
    Stage.reset();
  }
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
