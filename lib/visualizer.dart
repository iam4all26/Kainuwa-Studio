import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'avatar.dart';

/// Audio picture styles. [id] is stored in Layer.shape as "viz_<id>".
class VizKind {
  const VizKind(this.id, this.name);

  final String id;
  final String name;
}

const List<VizKind> kVizKinds = [
  VizKind('bars', 'Bars'),
  VizKind('dots', 'Dots'),
  VizKind('wave', 'Wave'),
  VizKind('pulse', 'Pulse'),
  VizKind('rise', 'Spectrum'),
  VizKind('blocks', 'Blocks'),
  VizKind('circle', 'Ring around the record'),
];

bool isVizLayerShape(String shape) => shape.startsWith('viz_');

/// The music player look (back, pause and forward buttons with a moving bar). It is stored as
/// "viz_player" so it travels the same way as the audio pictures, but it is not in [kVizKinds].
const String kPlayerKind = 'player';

/// How far the song has played: [progress in thousandths, seconds played, seconds in all].
List<int> playerValues(AvatarSpec spec, int absMs) {
  final dur = math.max(1, spec.sourceMs - spec.trimMs);
  final pos = (absMs - spec.startMs).clamp(0, dur).toInt();
  return [(pos / dur * 1000).round(), pos ~/ 1000, dur ~/ 1000];
}

List<int> vizValuesFor(String kind, AvatarSpec spec, int absMs) =>
    kind == kPlayerKind ? playerValues(spec, absMs) : vizValues(spec, absMs);

String _clock(int sec) {
  final m = sec ~/ 60;
  final r = sec % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

const int _kCols = 48;
const int _kStepMs = 45;
const int _kLevels = 20;

/// The height of every column (0 to 20) at [absMs]. The middle column is "now"; the columns on
/// each side show the sound a little before and after, so the picture moves with the real audio.
List<int> vizValues(AvatarSpec spec, int absMs) {
  final out = List<int>.filled(_kCols, 0);
  for (var i = 0; i < _kCols; i++) {
    final t = absMs + ((i - _kCols / 2) * _kStepMs).round();
    final v = math.sqrt(AvatarLevels.raw(spec, t));
    final taper = math.pow(math.sin(math.pi * (i + 0.5) / _kCols), 0.7).toDouble();
    out[i] = (v * taper * _kLevels).round().clamp(0, _kLevels).toInt();
  }
  return out;
}

/// Two moments with the same signature look exactly the same.
String vizSignature(AvatarSpec spec, int absMs, [String kind = '']) => vizValuesFor(kind, spec, absMs).join(',');

/// Draws one audio picture straight into an image, without building any widgets. It is many
/// times faster than drawing the widget, which matters for a video export that needs thousands.
/// [boxW] and [boxH] are the whole picture (with its edge room), [layerW] and [layerH] the item.
Future<ui.Image> renderVizImage({
  required String kind,
  required String avatar,
  required Color color,
  required int absMs,
  required double boxW,
  required double boxH,
  required double layerW,
  required double layerH,
  required double ratio,
}) {
  final spec = AvatarSpec.parse(avatar);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(ratio);
  canvas.translate((boxW - layerW) / 2, (boxH - layerH) / 2);
  _VizPainter(kind, vizValuesFor(kind, spec, absMs), color).paint(canvas, Size(layerW, layerH));
  final picture = recorder.endRecording();
  final image = picture.toImage((boxW * ratio).ceil(), (boxH * ratio).ceil());
  picture.dispose();
  return image;
}

/// The audio picture of a sound. [absMs] is the time in the whole video (null when paused,
/// then a moment inside the song is shown).
class VizView extends StatelessWidget {
  const VizView({super.key, required this.kind, required this.avatar, required this.color, this.absMs});

  final String kind;
  final String avatar;
  final Color color;
  final int? absMs;

  @override
  Widget build(BuildContext context) {
    final spec = AvatarSpec.parse(avatar);
    if (spec.audio.isNotEmpty && !AvatarLevels.isLoaded(spec.audio)) {
      AvatarLevels.load(spec.audio, spec.sourceMs);
    }
    return IgnorePointer(
      child: ValueListenableBuilder<int>(
        valueListenable: AvatarLevels.changed,
        builder: (context, _, __) {
          final t = absMs ?? (spec.startMs + (kind == kPlayerKind ? spec.sourceMs ~/ 3 : math.min(8000, spec.sourceMs ~/ 3)));
          return SizedBox.expand(
            child: CustomPaint(painter: _VizPainter(kind, vizValuesFor(kind, spec, t), color)),
          );
        },
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  _VizPainter(this.kind, this.values, this.color);

  final String kind;
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final colW = w / _kCols;
    final mid = h / 2;
    final paint = Paint()..color = color;
    switch (kind) {
      case 'player':
        _player(canvas, size);
        break;
      case 'dots':
        final r = math.min(colW * 0.24, h * 0.06);
        final gap = r * 2.7;
        for (var i = 0; i < _kCols; i++) {
          final x = (i + 0.5) * colW;
          paint.color = Color.lerp(color, Colors.white, 0.25)!;
          canvas.drawCircle(Offset(x, mid), r * 0.75, paint);
          final k = ((values[i] / _kLevels) * (mid - r) / gap).floor();
          for (var j = 1; j <= k; j++) {
            paint.color = Color.lerp(color, Colors.white, math.min(0.6, j * 0.07))!;
            canvas.drawCircle(Offset(x, mid - j * gap), r, paint);
            canvas.drawCircle(Offset(x, mid + j * gap), r, paint);
          }
        }
        break;
      case 'wave':
        // Three flowing lines whose height follows the sound (like a voice wave).
        const waves = [
          (3.0, 0.0, 1.0, 1.0, 3.0),
          (5.0, 1.7, 0.7, 0.65, 2.0),
          (7.0, 3.1, 0.45, 0.4, 1.5),
        ];
        const samples = 200;
        for (final wv in waves) {
          final path = Path();
          for (var k = 0; k <= samples; k++) {
            final x = k / samples;
            final pos = (x * _kCols - 0.5).clamp(0.0, _kCols - 1.0).toDouble();
            final i0 = pos.floor();
            final i1 = math.min(_kCols - 1, i0 + 1);
            final fr = pos - i0;
            final env = (values[i0] + (values[i1] - values[i0]) * fr) / _kLevels;
            final y = mid + math.sin(2 * math.pi * wv.$1 * x + wv.$2) * (math.max(0.02, env) * h * 0.46 * wv.$3);
            if (k == 0) {
              path.moveTo(0, y);
            } else {
              path.lineTo(x * w, y);
            }
          }
          paint
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(1.5, h * 0.03 * wv.$5)
            ..color = Color.lerp(color, Colors.white, 1.0 - wv.$4)!;
          canvas.drawPath(path, paint);
        }
        break;
      case 'circle':
        // Short bars all around a ring. The top shows the sound now, and both sides trail down.
        final centre = Offset(w / 2, h / 2);
        final side = math.min(w, h);
        final r0 = side * 0.35;
        final maxLen = side * 0.15;
        paint
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(2.0, 2 * math.pi * r0 / 48 * 0.55)
          ..color = color;
        for (var j = 0; j < 48; j++) {
          final m = j < 24 ? j : 47 - j;
          final len = math.max(side * 0.012, values[24 + m] / _kLevels * maxLen);
          final a = 2 * math.pi * j / 48 - math.pi / 2;
          final dir = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(centre + dir * r0, centre + dir * (r0 + len), paint);
        }
        break;
      case 'pulse':
        // One sharp line, up and down on each column, like a heart monitor.
        final line = Path();
        for (var i = 0; i < _kCols; i++) {
          final x = (i + 0.5) * colW;
          final amp = values[i] / _kLevels * h * 0.46;
          final y = mid + (i.isEven ? -amp : amp);
          if (i == 0) {
            line.moveTo(0, mid);
          }
          line.lineTo(x, y);
        }
        line.lineTo(w, mid);
        paint
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(2.0, h * 0.045)
          ..color = color;
        canvas.drawPath(line, paint);
        break;
      case 'rise':
        // Bars standing on the bottom line, getting lighter towards the top.
        final barW2 = colW * 0.62;
        final light = Color.lerp(color, Colors.white, 0.55)!;
        for (var i = 0; i < _kCols; i++) {
          final x = (i + 0.5) * colW;
          final bh = math.max(h * 0.04, values[i] / _kLevels * h * 0.97);
          final rect = Rect.fromLTWH(x - barW2 / 2, h - bh, barW2, bh);
          paint
            ..style = PaintingStyle.fill
            ..shader = ui.Gradient.linear(Offset(0, h), Offset(0, h - bh), [color, light]);
          canvas.drawRRect(
            RRect.fromRectAndCorners(rect, topLeft: Radius.circular(barW2 / 2), topRight: Radius.circular(barW2 / 2)),
            paint,
          );
        }
        paint.shader = null;
        break;
      case 'blocks':
        // Columns of small blocks that light up from the bottom, like a stereo.
        const rows = 8;
        final cell = h / rows;
        final bw = colW * 0.7;
        paint.style = PaintingStyle.fill;
        for (var i = 0; i < _kCols; i++) {
          final x = (i + 0.5) * colW;
          final lit = math.max(1, (values[i] / _kLevels * rows).round());
          for (var r = 0; r < lit; r++) {
            final top = h - (r + 1) * cell;
            final t = r / (rows - 1);
            paint.color = Color.lerp(color, Colors.white, 0.5 * t)!;
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(x - bw / 2, top + cell * 0.12, bw, cell * 0.76), Radius.circular(cell * 0.2)),
              paint,
            );
          }
        }
        break;
      default:
        final barW = colW * 0.58;
        for (var i = 0; i < _kCols; i++) {
          final x = (i + 0.5) * colW;
          final bh = math.max(h * 0.05, values[i] / _kLevels * h * 0.95);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, mid), width: barW, height: bh),
              Radius.circular(barW / 2),
            ),
            paint,
          );
        }
    }
  }

  /// Back, pause and forward buttons, a moving bar and the time played and in all.
  void _player(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final progress = (values.isNotEmpty ? values[0] : 0) / 1000.0;
    final played = values.length > 1 ? values[1] : 0;
    final total = values.length > 2 ? values[2] : 0;
    final paint = Paint();
    // The bar.
    final th = math.max(3.0, h * 0.07);
    final knob = th * 1.25;
    final by = h * 0.16;
    final x0 = knob;
    final x1 = w - knob;
    paint.color = const Color(0x55FFFFFF);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x0, by - th / 2, x1, by + th / 2), Radius.circular(th / 2)), paint);
    final xp = x0 + (x1 - x0) * progress.clamp(0.0, 1.0);
    paint.color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x0, by - th / 2, math.max(x0 + th, xp), by + th / 2), Radius.circular(th / 2)), paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(xp, by), knob, paint);
    // The times under the bar.
    final fs = math.max(8.0, h * 0.14);
    for (final side in const [0, 1]) {
      final tp = TextPainter(
        text: TextSpan(
          text: _clock(side == 0 ? played : total),
          style: TextStyle(color: const Color(0xCCFFFFFF), fontSize: fs, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(side == 0 ? x0 - knob * 0.5 : x1 + knob * 0.5 - tp.width, h * 0.27));
    }
    // The three buttons.
    final cy = h * 0.74;
    final s = h * 0.24;
    final gap = math.min(w * 0.2, s * 3.6);
    paint.color = Colors.white;
    for (final dir in const [-1.0, 1.0]) {
      final cx = w / 2 + dir * gap;
      final tip = Offset(cx + dir * s * 0.4, cy);
      final top = Offset(cx - dir * s * 0.5, cy - s * 0.5);
      final bottom = Offset(cx - dir * s * 0.5, cy + s * 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(top.dx, top.dy)
          ..lineTo(bottom.dx, bottom.dy)
          ..close(),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + dir * s * 0.55, cy), width: s * 0.17, height: s), Radius.circular(s * 0.05)),
        paint,
      );
    }
    paint.color = color;
    canvas.drawCircle(Offset(w / 2, cy), s * 1.05, paint);
    paint.color = const Color(0xFF14141C);
    for (final dx in const [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2 + dx * s * 0.27, cy), width: s * 0.26, height: s * 0.95), Radius.circular(s * 0.06)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VizPainter old) => old.kind != kind || old.color != color || old.values.join(',') != values.join(',');
}
