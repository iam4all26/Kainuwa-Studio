import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;

import 'avatar.dart';
import 'models.dart';
import 'scene_canvas.dart';
import 'srt_import.dart';
import 'stage_shape.dart';

/// One word or line of the lyrics, with the time it shows.
class LyricCue {
  const LyricCue(this.startMs, this.endMs, this.text);
  final int startMs;
  final int endMs;
  final String text;
}

/// A ready-made look: the glow colours that change from word to word, a font, the night colour and the moving background.
class LyricsLook {
  const LyricsLook({
    required this.id,
    required this.name,
    required this.palette,
    required this.font,
    required this.bg,
    this.fx = const [],
    this.anim = 'pop',
    this.layout = 0,
    this.byWord = true,
    this.viz = 'bars',
  });

  /// The audio picture under the cover in the record layouts ('none' for no picture).
  final String viz;

  /// How each word comes in: an entrance from animation_math.dart.
  final String anim;

  /// 0 lyrics in the middle, 1 record and cover on the left with the lyrics on the right, 2 the other way round.
  final int layout;

  /// True for one word at a time, false for one line at a time.
  final bool byWord;

  final String id;
  final String name;
  final List<int> palette;
  final String font;
  final int bg;

  /// Effect ids from effects.dart drawn behind the words.
  final List<String> fx;
}

const List<LyricsLook> kLyricsLooks = [
  LyricsLook(
    id: 'neon',
    name: 'Neon Night',
    palette: [0xFFFFF59D, 0xFF9BE7FF, 0xFFFFFFFF, 0xFFFF8A65, 0xFFF48FFF, 0xFFFFD54F],
    font: 'Sacramento',
    bg: 0xFF03040B,
    fx: ['stars', 'streaks'],
    anim: 'jump',
  ),
  LyricsLook(
    id: 'fire',
    name: 'Fire',
    palette: [0xFFFF8A65, 0xFFFFB74D, 0xFFFF5252, 0xFFFFD54F],
    font: 'Bebas Neue',
    bg: 0xFF110404,
    fx: ['embers'],
    anim: 'drop',
  ),
  LyricsLook(
    id: 'ocean',
    name: 'Ocean',
    palette: [0xFF80DEEA, 0xFF9BE7FF, 0xFFFFFFFF, 0xFF82B1FF],
    font: 'Quicksand',
    bg: 0xFF02091A,
    fx: ['stars'],
    anim: 'rise',
  ),
  LyricsLook(
    id: 'candy',
    name: 'Candy',
    palette: [0xFFF48FFF, 0xFFFF80AB, 0xFFB388FF, 0xFFFFFFFF],
    font: 'Pacifico',
    bg: 0xFF12051C,
    fx: ['sparkle'],
    anim: 'flipin',
  ),
  LyricsLook(
    id: 'clean',
    name: 'Clean White',
    palette: [0xFFFFFFFF],
    font: 'Montserrat',
    bg: 0xFF000000,
    anim: 'fade',
  ),
  LyricsLook(
    id: 'vinyl_left',
    name: 'Record Left',
    palette: [0xFFFFE0B2, 0xFFFFCC80, 0xFFFFFFFF],
    font: 'Playfair Display',
    bg: 0xFF120B06,
    anim: 'rise',
    layout: 1,
    byWord: false,
    viz: 'wave',
  ),
  LyricsLook(
    id: 'vinyl_right',
    name: 'Record Right',
    palette: [0xFFB388FF, 0xFFF48FFF, 0xFFFFFFFF],
    font: 'Montserrat',
    bg: 0xFF0C0618,
    fx: ['sparkle'],
    anim: 'jump',
    layout: 2,
    byWord: false,
    viz: 'bars',
  ),
  LyricsLook(
    id: 'gold',
    name: 'Golden Hour',
    palette: [0xFFFFE082, 0xFFFFCA28, 0xFFFFFFFF],
    font: 'Playfair Display',
    bg: 0xFF0D0903,
    fx: ['sparkle'],
    anim: 'rise',
    byWord: false,
  ),
  LyricsLook(
    id: 'party',
    name: 'Party Lights',
    palette: [0xFFFF4D6D, 0xFFFFD54F, 0xFF69F0AE, 0xFF4DD0E1, 0xFFB388FF],
    font: 'Bungee',
    bg: 0xFF08040F,
    fx: ['sparkle', 'streaks'],
    anim: 'drop',
  ),
  LyricsLook(
    id: 'arcade',
    name: 'Retro Arcade',
    palette: [0xFF69F0AE, 0xFF4DD0E1, 0xFFFFEB3B],
    font: 'Press Start 2P',
    bg: 0xFF020A05,
    fx: ['stars'],
    anim: 'appear',
  ),
  LyricsLook(
    id: 'soft',
    name: 'Soft Script',
    palette: [0xFFFFFFFF, 0xFFFFC1E3, 0xFFFFE0F0],
    font: 'Dancing Script',
    bg: 0xFF140A12,
    fx: ['sparkle'],
    anim: 'fade',
    byWord: false,
  ),
  LyricsLook(
    id: 'ice',
    name: 'Ice',
    palette: [0xFF9BE7FF, 0xFFE1F5FE, 0xFF82B1FF],
    font: 'Raleway',
    bg: 0xFF020A12,
    fx: ['snow'],
    anim: 'zoom',
  ),
  LyricsLook(
    id: 'sunset',
    name: 'Sunset',
    palette: [0xFFFF8A65, 0xFFFF80AB, 0xFFFFD54F],
    font: 'Pacifico',
    bg: 0xFF14060A,
    fx: ['streaks'],
    anim: 'slide',
    byWord: false,
  ),
  LyricsLook(
    id: 'bold',
    name: 'Bold Impact',
    palette: [0xFFFFFFFF, 0xFFFFEB3B],
    font: 'Bebas Neue',
    bg: 0xFF000000,
    anim: 'pop',
  ),
  LyricsLook(
    id: 'gospel',
    name: 'Gospel Light',
    palette: [0xFFFFF3E0, 0xFFFFE0B2],
    font: 'Cormorant Garamond',
    bg: 0xFF0A0A14,
    fx: ['stars'],
    anim: 'rise',
    byWord: false,
  ),
  LyricsLook(
    id: 'hype',
    name: 'Hype',
    palette: [0xFFFF4D6D, 0xFFFFEB3B, 0xFF4DD0E1],
    font: 'Righteous',
    bg: 0xFF050308,
    fx: ['streaks', 'stars'],
    anim: 'jump',
  ),
  LyricsLook(
    id: 'vinyl_neon',
    name: 'Record Neon',
    palette: [0xFF4DD0E1, 0xFFFF80AB, 0xFFFFFFFF],
    font: 'Orbitron',
    bg: 0xFF04030C,
    fx: ['stars'],
    anim: 'flipin',
    layout: 2,
    byWord: false,
    viz: 'rise',
  ),
  LyricsLook(
    id: 'vinyl_sun',
    name: 'Record Sunset',
    palette: [0xFFFFAB91, 0xFFFFCC80, 0xFFFFFFFF],
    font: 'Dancing Script',
    bg: 0xFF14060A,
    fx: ['embers'],
    anim: 'jump',
    layout: 1,
    byWord: false,
    viz: 'pulse',
  ),
];

/// The entrances offered for lyrics.
const List<String> kLyricAnims = ['pop', 'jump', 'drop', 'rise', 'flipin', 'zoom', 'fade', 'slide', 'appear'];

/// What the person chose for a lyrics video.
class LyricsSetup {
  const LyricsSetup({
    required this.audio,
    required this.audioMs,
    required this.cues,
    required this.aspectW,
    required this.aspectH,
    required this.palette,
    required this.font,
    required this.bg,
    required this.fx,
    required this.byWord,
    this.anim = 'pop',
    this.cover = '',
    this.coverAspect = 1.0,
    this.layout = 0,
    this.vizKind = 'bars',
    this.artist = '',
    this.title = '',
    this.form = const {},
  });

  final String audio;
  final int audioMs;
  final List<LyricCue> cues;
  final int aspectW;
  final int aspectH;
  final List<int> palette;
  final String font;
  final int bg;
  final List<String> fx;
  final bool byWord;

  /// How each word comes in.
  final String anim;

  /// The cover art, and where the record sits (see [LyricsLook.layout]). Empty cover: a plain coloured one is drawn.
  final String cover;
  final double coverAspect;
  final int layout;

  /// With a record layout: the audio picture, and the artist shown under the cover (the title is [title]).
  final String vizKind;
  final String artist;
  final String title;

  /// The choices of the setup screen, saved with the video so the setup can be opened again.
  final Map<String, dynamic> form;
}

/// The lyrics cut into words, or into lines.
List<String> lyricUnits(String text, bool byWord) {
  final out = <String>[];
  for (final line in text.replaceAll('\r', '').split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (byWord) {
      out.addAll(t.split(RegExp(r'\s+')));
    } else {
      out.add(t);
    }
  }
  return out;
}

/// Spreads [units] over [fromMs] to [toMs], a longer word getting a little more time.
List<LyricCue> spreadCues(List<String> units, int fromMs, int toMs) {
  if (units.isEmpty || toMs <= fromMs) return const [];
  final weights = [for (final u in units) u.length + 2.0];
  final total = weights.fold<double>(0, (a, b) => a + b);
  final cues = <LyricCue>[];
  var at = fromMs.toDouble();
  for (var i = 0; i < units.length; i++) {
    final len = (toMs - fromMs) * weights[i] / total;
    final end = i == units.length - 1 ? toMs : (at + len).round();
    cues.add(LyricCue(at.round(), end, units[i]));
    at += len;
  }
  return cues;
}

/// Cues from the times the person tapped (one start per unit, in order). A unit that was not tapped
/// shares the time that is left after the last tap.
List<LyricCue> cuesFromStarts(List<String> units, List<int> starts, int totalMs) {
  if (units.isEmpty) return const [];
  final n = math.min(units.length, starts.length);
  final cues = <LyricCue>[];
  for (var i = 0; i < n; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : totalMs;
    cues.add(LyricCue(starts[i], math.max(starts[i] + 200, math.min(end, totalMs)), units[i]));
  }
  if (n < units.length) {
    final from = n == 0 ? 0 : cues.last.endMs;
    cues.addAll(spreadCues(units.sublist(n), from, totalMs));
  }
  return cues;
}

/// Cues from an .srt file. By word, each caption's time is shared between its words.
List<LyricCue> cuesFromSrt(String raw, bool byWord) {
  final out = <LyricCue>[];
  for (final c in parseSrt(raw)) {
    final text = c.text.replaceAll('\n', ' ').trim();
    if (!byWord) {
      out.add(LyricCue(c.startMs, c.endMs, text));
    } else {
      out.addAll(spreadCues(lyricUnits(text, true), c.startMs, c.endMs));
    }
  }
  return out;
}

/// The one slide of a lyrics video. [sampleOnly] draws just the first word with no timing, for the preview.
/// Call [Stage.use] with the video shape first.
Scene buildLyricsScene(LyricsSetup s, {bool sampleOnly = false}) {
  final layers = <Layer>[];
  for (final id in s.fx) {
    final l = Layer(id: newId(), type: 'shape', shape: 'fx_$id', w: 1.0, h: 1.0);
    l.cx = 0.5;
    l.cy = 0.5;
    layers.add(l);
  }
  final w = Stage.w;
  final h = Stage.h;
  final wide = w / h >= 1.3;
  final hasRec = s.layout != 0;
  var textCx = 0.5;
  var textCy = 0.5;
  var textMaxW = 0.9;
  if (hasRec) {
    final recLeft = s.layout == 1;
    final cs = wide ? math.min(0.46 * h, 0.40 * w / 1.4) : math.min(0.26 * h, 0.80 * w / 1.4);
    final shift = 0.40 * cs;
    final discD = 0.96 * cs;
    final groupW = cs + shift;
    final groupCx = wide ? (recLeft ? 0.27 * w : 0.73 * w) : w / 2;
    final cy = wide ? 0.36 * h : 0.22 * h;
    final coverCx = groupCx - groupW / 2 + cs / 2;
    final discCx = coverCx + shift;
    textCx = wide ? (recLeft ? 0.70 : 0.30) : 0.5;
    textCy = wide ? 0.5 : 0.75;
    textMaxW = wide ? 0.42 : 0.9;

    Layer square(String type, double cx, double cyy, double side) {
      final l = Layer(id: newId(), type: type, w: side / w, h: side / h);
      l.cx = cx / w;
      l.cy = cyy / h;
      return l;
    }

    double cropSide = 0;
    double cropTop = 0;
    if (s.coverAspect > 1.0) {
      cropSide = (1 - 1 / s.coverAspect) / 2;
    } else if (s.coverAspect > 0 && s.coverAspect < 1.0) {
      cropTop = (1 - s.coverAspect) / 2;
    }
    final noCover = s.cover.isEmpty;
    final sample = Color.lerp(Color(s.palette.first), const Color(0xFF000000), 0.45)!.toARGB32();
    layers.add(square('shape', discCx, cy, discD * 1.04)
      ..shape = 'circle'
      ..color = 0xFF0B0B0B);
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
    layers.add(noCover
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
          ..shadowOn = true));

    // Under the cover: the audio picture, the song name and the artist.
    final kind = (s.vizKind == 'circle' || s.vizKind.isEmpty) ? 'bars' : s.vizKind;
    if (s.vizKind != 'none') {
      final spec = AvatarSpec(audio: s.audio, startMs: 0, sourceMs: s.audioMs);
      final tall = kind == 'rise' || kind == 'blocks' || kind == 'wave';
      final viz = Layer(
        id: newId(),
        type: 'shape',
        shape: 'viz_$kind',
        color: s.palette.first,
        w: math.min(0.9, groupW / w),
        h: wide ? (tall ? 0.10 : 0.07) : (tall ? 0.05 : 0.035),
      );
      viz.cx = groupCx / w;
      viz.cy = wide ? 0.67 : 0.41;
      viz.avatar = spec.encode();
      layers.add(viz);
    }
    final shownTitle = s.title.trim().isEmpty ? (sampleOnly ? 'Song title' : '') : s.title.trim();
    final shownArtist = s.artist.trim().isEmpty ? (sampleOnly ? 'Artist name' : '') : s.artist.trim();
    final underW = math.min(0.9, groupW * 1.2 / w);
    void under(String text, double px, int colour, double cyFrac, bool bold) {
      final t = Layer(id: newId(), type: 'text', text: text, color: colour, bold: bold, fontFamily: s.font);
      setLayerTextSizePx(t, px);
      if (t.w > underW) {
        final f = underW / t.w;
        t.w = underW;
        t.h = t.h * f;
      }
      t.cx = groupCx / w;
      t.cy = cyFrac;
      layers.add(t);
    }

    if (shownTitle.isNotEmpty) under(shownTitle, wide ? 44 : 40, 0xFFFFFFFF, wide ? 0.78 : 0.48, true);
    if (shownArtist.isNotEmpty) under(shownArtist, wide ? 28 : 26, s.palette.first, wide ? 0.86 : 0.54, false);
  }
  final cues = sampleOnly ? [s.cues.isEmpty ? const LyricCue(0, 1000, 'Lyrics') : s.cues.first] : s.cues;
  final px = hasRec ? (s.byWord ? 90.0 : 56.0) : (s.byWord ? 110.0 : 72.0);
  for (var i = 0; i < cues.length; i++) {
    final c = cues[i];
    final colour = s.palette[i % s.palette.length];
    final t = Layer(
      id: newId(),
      type: 'text',
      text: c.text,
      bold: false,
      fontFamily: s.font,
      color: lighten(colour, 0.45),
    );
    t.glowOn = true;
    t.glowColor = colour;
    t.glowSize = 0.1;
    t.glowStrength = 0.8;
    setLayerTextSizePx(t, px);
    if (t.w > textMaxW) {
      final f = textMaxW / t.w;
      t.w = textMaxW;
      t.h = t.h * f;
    }
    t.cx = textCx;
    t.cy = textCy;
    if (!sampleOnly) {
      t.startMs = c.startMs;
      t.endMs = c.endMs;
      t.animIn = s.anim;
      t.animInDir = 'up';
      t.animDurationMs = math.max(120, math.min(s.anim == 'drop' ? 600 : (s.anim == 'jump' ? 420 : 260), ((c.endMs - c.startMs) * 0.7).round()));
    }
    layers.add(t);
    if (hasRec && !s.byWord && !sampleOnly && i + 1 < cues.length) {
      // The next line, small and dim, under the line that is sung now.
      final next = Layer(id: newId(), type: 'text', text: cues[i + 1].text, bold: false, fontFamily: s.font, color: 0x99FFFFFF);
      setLayerTextSizePx(next, px * 0.55);
      if (next.w > textMaxW) {
        final f = textMaxW / next.w;
        next.w = textMaxW;
        next.h = next.h * f;
      }
      next.cx = textCx;
      next.cy = math.min(0.92, textCy + 0.17);
      next.startMs = c.startMs;
      next.endMs = c.endMs;
      next.animIn = 'fade';
      next.animDurationMs = 200;
      layers.add(next);
    }
  }
  return Scene(
    id: newId(),
    durationMs: math.max(1000, s.audioMs),
    bgType: 'color',
    bgValue: s.bg.toString(),
    layers: layers,
  );
}

int lighten(int argb, double f) {
  int ch(int shift) {
    final v = (argb >> shift) & 0xFF;
    return (v + (255 - v) * f).round().clamp(0, 255).toInt();
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// Fills a new, empty video with the lyrics slide and the song as sound.
void buildLyricsProject(Lesson lesson, LyricsSetup s) {
  lesson.aspectW = s.aspectW;
  lesson.aspectH = s.aspectH;
  lesson.setupKind = 'lyrics';
  lesson.setupForm = jsonEncode(s.form);
  Stage.use(s.aspectW, s.aspectH);
  try {
    final scene = buildLyricsScene(s);
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
