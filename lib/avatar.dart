import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

/// How a talking picture ("Avatar") moves its mouth. Stored as JSON in Layer.avatar.
///
///  a: the sound file          g: lesson time (ms) where that sound starts
///  s: length of the sound     t: part of the sound skipped at the start (ms)
///  x, y: mouth centre as a fraction of the picture   w: mouth width as a fraction
///  j: how far the jaw drops (1 = normal)
class AvatarSpec {
  const AvatarSpec({
    this.audio = '',
    this.startMs = 0,
    this.sourceMs = 0,
    this.trimMs = 0,
    this.x = 0.5,
    this.y = 0.72,
    this.w = 0.22,
    this.jaw = 1.0,
  });

  final String audio;
  final int startMs;
  final int sourceMs;
  final int trimMs;
  final double x;
  final double y;
  final double w;
  final double jaw;

  static final Map<String, AvatarSpec> _cache = {};

  static AvatarSpec parse(String json) {
    if (json.isEmpty) return const AvatarSpec();
    final hit = _cache[json];
    if (hit != null) return hit;
    AvatarSpec spec;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      double d(String k, double fallback) => (m[k] is num) ? (m[k] as num).toDouble() : fallback;
      int i(String k) => (m[k] is num) ? (m[k] as num).round() : 0;
      spec = AvatarSpec(
        audio: m['a'] is String ? m['a'] as String : '',
        startMs: i('g'),
        sourceMs: i('s'),
        trimMs: i('t'),
        x: d('x', 0.5),
        y: d('y', 0.72),
        w: d('w', 0.22),
        jaw: d('j', 1.0),
      );
    } catch (_) {
      spec = const AvatarSpec();
    }
    if (_cache.length > 64) _cache.clear();
    _cache[json] = spec;
    return spec;
  }

  String encode() => jsonEncode({
        'a': audio,
        'g': startMs,
        's': sourceMs,
        't': trimMs,
        'x': double.parse(x.toStringAsFixed(4)),
        'y': double.parse(y.toStringAsFixed(4)),
        'w': double.parse(w.toStringAsFixed(4)),
        'j': double.parse(jaw.toStringAsFixed(3)),
      });

  AvatarSpec copyWith({
    String? audio,
    int? startMs,
    int? sourceMs,
    int? trimMs,
    double? x,
    double? y,
    double? w,
    double? jaw,
  }) =>
      AvatarSpec(
        audio: audio ?? this.audio,
        startMs: startMs ?? this.startMs,
        sourceMs: sourceMs ?? this.sourceMs,
        trimMs: trimMs ?? this.trimMs,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        jaw: jaw ?? this.jaw,
      );
}

/// Loudness of each sound file, in small steps, and the mouth opening (0 to 4) that follows from it.
/// The preview and the export both use [levelAt], so they always show the same mouth.
class AvatarLevels {
  AvatarLevels._();

  static final Map<String, List<double>> _data = {};
  static final Map<String, double> _binMs = {};
  static final Map<String, Future<void>> _loading = {};

  /// Bumped each time a sound finishes loading, so pictures can redraw.
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  static bool isLoaded(String path) => _data.containsKey(path);

  static Future<void> load(String path, int sourceMs) {
    if (path.isEmpty || sourceMs <= 0) return Future<void>.value();
    if (_data.containsKey(path)) return Future<void>.value();
    return _loading[path] ??= _fetch(path, sourceMs);
  }

  static Future<void> _fetch(String path, int sourceMs) async {
    var values = <double>[];
    try {
      final bins = (sourceMs / 50).ceil().clamp(20, 4000).toInt();
      final raw = await KainuwaEncoder.audioPeaks(path, bins: bins);
      var top = 0.0;
      for (final v in raw) {
        if (v > top) top = v;
      }
      if (top > 0) values = [for (final v in raw) v / top];
    } catch (_) {
      values = <double>[];
    }
    _data[path] = values;
    _binMs[path] = values.isEmpty ? 50.0 : sourceMs / values.length;
    _loading.remove(path);
    changed.value++;
  }

  /// Loudness 0 to 1 at [absMs] (smoothly between the small steps), 0 when there is no sound.
  static double raw(AvatarSpec spec, int absMs) {
    final values = _data[spec.audio];
    if (values == null || values.isEmpty) return 0;
    final t = absMs - spec.startMs + spec.trimMs;
    if (t < 0 || t >= spec.sourceMs) return 0;
    final binMs = _binMs[spec.audio] ?? 50.0;
    final f = t / binMs;
    final i = f.floor();
    final fr = f - i;
    final a = values[i.clamp(0, values.length - 1).toInt()];
    final b = values[(i + 1).clamp(0, values.length - 1).toInt()];
    return a + (b - a) * fr;
  }

  /// Mouth opening 0 (closed) to 4 (wide open) at [absMs], the time in the whole video.
  static int levelAt(AvatarSpec spec, int absMs) {
    final values = _data[spec.audio];
    if (values == null || values.isEmpty) return 0;
    final t = absMs - spec.startMs + spec.trimMs;
    if (t < 0 || t >= spec.sourceMs) return 0;
    final binMs = _binMs[spec.audio] ?? 50.0;
    final i = (t / binMs).floor();
    var v = 0.0;
    for (var k = i; k <= i + 1; k++) {
      if (k >= 0 && k < values.length && values[k] > v) v = values[k];
    }
    if (v < 0.09) return 0;
    if (v < 0.26) return 1;
    if (v < 0.45) return 2;
    if (v < 0.70) return 3;
    return 4;
  }
}

/// The picture with its mouth drawn open to [level] (0 closed to 4 wide open).
class AvatarPicture extends StatelessWidget {
  const AvatarPicture({
    super.key,
    required this.path,
    required this.aspect,
    required this.spec,
    required this.level,
    this.showMarker = false,
  });

  final String path;

  /// Width divided by height of the photo; 0 when not known.
  final double aspect;
  final AvatarSpec spec;
  final int level;
  final bool showMarker;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final bw = c.maxWidth.isFinite ? c.maxWidth : 100.0;
      final bh = c.maxHeight.isFinite ? c.maxHeight : 100.0;
      final a = aspect > 0 ? aspect : bw / math.max(1.0, bh);
      var rw = bw;
      var rh = bw / a;
      if (rh > bh) {
        rh = bh;
        rw = bh * a;
      }
      final ox = (bw - rw) / 2;
      final oy = (bh - rh) / 2;
      final cx = ox + spec.x * rw;
      final cy = oy + spec.y * rh;
      final mw = spec.w * rw;
      final f = level.clamp(0, 4) / 4.0;
      final drop = f * mw * 0.45 * spec.jaw;

      Widget photo() => Image.file(
            File(path),
            fit: BoxFit.contain,
            width: bw,
            height: bh,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFFDDDDDD),
              child: Icon(Icons.broken_image_outlined),
            ),
          );

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: photo()),
          if (drop > 0.5) ...[
            // The dark inside of the mouth, between the lips and the dropped jaw.
            Positioned(
              left: cx - mw * 0.40,
              top: cy - mw * 0.05,
              width: mw * 0.80,
              height: drop + mw * 0.16,
              child: const ClipOval(child: ColoredBox(color: Color(0xFF2B1012))),
            ),
            // The lower face, moved down.
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, drop),
                child: ClipPath(
                  clipper: _JawClipper(Rect.fromLTRB(cx - mw * 0.78, cy + mw * 0.02, cx + mw * 0.78, cy + mw * 1.6)),
                  child: photo(),
                ),
              ),
            ),
          ],
          if (showMarker)
            Positioned(
              left: cx - mw / 2,
              top: cy - mw * 0.12,
              width: mw,
              height: mw * 0.24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFC107), width: 2),
                    borderRadius: BorderRadius.circular(mw),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _JawClipper extends CustomClipper<Path> {
  const _JawClipper(this.rect);

  final Rect rect;

  @override
  Path getClip(Size size) => Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.3)));

  @override
  bool shouldReclip(_JawClipper old) => old.rect != rect;
}

/// A talking picture as an item on a slide. [absMs] is the time in the whole video while the
/// slide plays, or null when paused (then the mouth is closed). [level] forces a mouth opening.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.path, required this.aspect, required this.avatar, this.absMs, this.level});

  final String path;
  final double aspect;
  final String avatar;
  final int? absMs;
  final int? level;

  @override
  Widget build(BuildContext context) {
    final spec = AvatarSpec.parse(avatar);
    if (level == null && spec.audio.isNotEmpty && !AvatarLevels.isLoaded(spec.audio)) {
      AvatarLevels.load(spec.audio, spec.sourceMs);
    }
    return ValueListenableBuilder<int>(
      valueListenable: AvatarLevels.changed,
      builder: (context, _, __) {
        final shown = level ?? (absMs == null ? 0 : AvatarLevels.levelAt(spec, absMs!));
        return AvatarPicture(path: path, aspect: aspect, spec: spec, level: shown);
      },
    );
  }
}
