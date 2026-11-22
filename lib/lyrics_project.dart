import 'dart:math' as math;

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
  });

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
  ),
  LyricsLook(
    id: 'fire',
    name: 'Fire',
    palette: [0xFFFF8A65, 0xFFFFB74D, 0xFFFF5252, 0xFFFFD54F],
    font: 'Bebas Neue',
    bg: 0xFF110404,
    fx: ['embers'],
  ),
  LyricsLook(
    id: 'ocean',
    name: 'Ocean',
    palette: [0xFF80DEEA, 0xFF9BE7FF, 0xFFFFFFFF, 0xFF82B1FF],
    font: 'Quicksand',
    bg: 0xFF02091A,
    fx: ['stars'],
  ),
  LyricsLook(
    id: 'candy',
    name: 'Candy',
    palette: [0xFFF48FFF, 0xFFFF80AB, 0xFFB388FF, 0xFFFFFFFF],
    font: 'Pacifico',
    bg: 0xFF12051C,
    fx: ['sparkle'],
  ),
  LyricsLook(
    id: 'clean',
    name: 'Clean White',
    palette: [0xFFFFFFFF],
    font: 'Montserrat',
    bg: 0xFF000000,
  ),
];

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
    this.title = '',
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
  final String title;
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
  final cues = sampleOnly ? [s.cues.isEmpty ? const LyricCue(0, 1000, 'Lyrics') : s.cues.first] : s.cues;
  final px = s.byWord ? 110.0 : 72.0;
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
    if (t.w > 0.9) {
      final f = 0.9 / t.w;
      t.w = 0.9;
      t.h = t.h * f;
    }
    t.cx = 0.5;
    t.cy = 0.5;
    if (!sampleOnly) {
      t.startMs = c.startMs;
      t.endMs = c.endMs;
      t.animIn = 'pop';
      t.animDurationMs = 220;
    }
    layers.add(t);
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
