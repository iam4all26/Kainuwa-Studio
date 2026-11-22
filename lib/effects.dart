import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One floating effect: [id] is stored in Layer.shape as "fx_<id>".
class FxKind {
  const FxKind(this.id, this.name, this.icon);

  final String id;
  final String name;
  final IconData icon;
}

const List<FxKind> kFxKinds = [
  FxKind('snow', 'Snow', Icons.ac_unit),
  FxKind('rain', 'Rain', Icons.water_drop_outlined),
  FxKind('embers', 'Fire sparks', Icons.local_fire_department_outlined),
  FxKind('confetti', 'Confetti', Icons.celebration_outlined),
  FxKind('bubbles', 'Bubbles', Icons.bubble_chart_outlined),
  FxKind('leaves', 'Leaves', Icons.eco_outlined),
  FxKind('dust', 'Floating dust', Icons.grain),
  FxKind('sparkle', 'Sparkles', Icons.auto_awesome),
  FxKind('stars', 'Starfield', Icons.star_outline),
  FxKind('streaks', 'Light streaks', Icons.density_small),
];

bool isFxLayerShape(String shape) => shape.startsWith('fx_');

/// The effect repeats every this many milliseconds, so the export only has to draw one loop.
const int kFxPeriodMs = 4000;

/// Number of pictures per loop in the export (15 per second).
const int kFxFrames = 60;

/// Particles falling, rising or floating over the slide. Everything depends only on the time,
/// so the preview and the export show the same thing.
class EffectView extends StatelessWidget {
  const EffectView({super.key, required this.kind, required this.timeMs, this.solid = false});

  /// The effect name without the "fx_" start.
  final String kind;

  /// Milliseconds since the effect started.
  final int timeMs;

  /// True for the video export: particles are fully solid (the exporter darkens see-through pixels).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(painter: _FxPainter(kind, timeMs, solid)),
      ),
    );
  }
}

/// Draws one picture of an effect straight into an image, without building widgets (much faster
/// than a widget capture, which matters for the export that needs dozens of pictures per effect).
/// [boxW] and [boxH] are the whole picture (with its edge room), [layerW] and [layerH] the item.
Future<ui.Image> renderFxImage({
  required String kind,
  required int timeMs,
  required double boxW,
  required double boxH,
  required double layerW,
  required double layerH,
  required double ratio,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(ratio);
  canvas.translate((boxW - layerW) / 2, (boxH - layerH) / 2);
  _FxPainter(kind, timeMs, true).paint(canvas, Size(layerW, layerH));
  final picture = recorder.endRecording();
  final image = picture.toImage((boxW * ratio).ceil(), (boxH * ratio).ceil());
  picture.dispose();
  return image;
}

double _rnd(int i, int salt) {
  var x = (i * 374761393 + salt * 668265263 + 12345) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  x = x ^ (x >> 16);
  return (x & 0xffff) / 65535.0;
}

class _FxPainter extends CustomPainter {
  _FxPainter(this.kind, this.timeMs, this.solid);

  final String kind;
  final int timeMs;
  final bool solid;

  Color _a(Color c, double o) => solid ? c : c.withOpacity(o.clamp(0.0, 1.0).toDouble());

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final p = (timeMs % kFxPeriodMs) / kFxPeriodMs;
    final u = size.shortestSide / 400.0;
    switch (kind) {
      case 'snow':
        _snow(canvas, size, p, u);
        break;
      case 'rain':
        _rain(canvas, size, p, u);
        break;
      case 'embers':
        _embers(canvas, size, p, u);
        break;
      case 'confetti':
        _confetti(canvas, size, p, u);
        break;
      case 'bubbles':
        _bubbles(canvas, size, p, u);
        break;
      case 'leaves':
        _leaves(canvas, size, p, u);
        break;
      case 'dust':
        _dust(canvas, size, p, u);
        break;
      case 'sparkle':
        _sparkle(canvas, size, p, u);
        break;
      case 'stars':
        _stars(canvas, size, p, u);
        break;
      case 'streaks':
        _streaks(canvas, size, p, u);
        break;
    }
  }

  /// Light on a dark night sky. In the export (solid) the brightness is mixed into near-black instead of see-through.
  Color _b(Color c, double o) =>
      solid ? Color.lerp(const Color(0xFF05060F), c, o.clamp(0.0, 1.0).toDouble())! : c.withOpacity(o.clamp(0.0, 1.0).toDouble());

  void _stars(Canvas c, Size s, double p, double u) {
    final paint = Paint();
    for (var i = 0; i < 120; i++) {
      final depth = 0.3 + _rnd(i, 3) * 0.7;
      final cyc = 1 + (_rnd(i, 4) * 2).floor();
      final y = ((_rnd(i, 2) + cyc * p) % 1.0) * s.height;
      final k = 1 + (_rnd(i, 8) * 3).floor();
      final tw = 0.55 + 0.45 * math.sin(2 * math.pi * (_rnd(i, 9) + k * p));
      final r = (0.8 + _rnd(i, 6) * 2.6) * u * depth;
      final col = i % 5 == 0 ? const Color(0xFF9DB8FF) : Colors.white;
      paint.color = _b(col, tw * (0.4 + 0.6 * depth));
      c.drawCircle(Offset(_rnd(i, 1) * s.width, y), r, paint);
    }
  }

  void _streaks(Canvas c, Size s, double p, double u) {
    for (var i = 0; i < 7; i++) {
      final len = (0.45 + _rnd(i, 3) * 0.5) * s.width;
      final th = (2 + _rnd(i, 5) * 5) * u;
      final x = ((_rnd(i, 1) + p * (1 + i % 2)) % 1.0) * (s.width + len) - len;
      final y = _rnd(i, 2) * s.height;
      final peak = _b(const Color(0xFFCFC8E8), 0.22 + _rnd(i, 7) * 0.12);
      final edge = solid ? const Color(0xFF05060F) : peak.withOpacity(0.0);
      final rect = Rect.fromLTWH(x, y, len, th);
      c.drawRect(
        rect,
        Paint()..shader = LinearGradient(colors: [edge, peak, edge]).createShader(rect),
      );
    }
  }

  double _x(int i, double p, double amp, Size s) {
    final m = 1 + (_rnd(i, 4) * 2).floor();
    return (_rnd(i, 1) + math.sin(2 * math.pi * (_rnd(i, 5) + m * p)) * amp) * s.width;
  }

  void _snow(Canvas c, Size s, double p, double u) {
    final paint = Paint();
    for (var i = 0; i < 80; i++) {
      final cyc = 1 + (_rnd(i, 3) * 2).floor();
      final y = ((_rnd(i, 2) + cyc * p) % 1.0) * (s.height + 20 * u) - 10 * u;
      final r = (1.2 + _rnd(i, 6) * 3.2) * u;
      paint.color = _a(Colors.white, 0.45 + _rnd(i, 7) * 0.5);
      c.drawCircle(Offset(_x(i, p, 0.03, s), y), r, paint);
    }
  }

  void _rain(Canvas c, Size s, double p, double u) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, 1.2 * u);
    for (var i = 0; i < 110; i++) {
      final cyc = 3 + (_rnd(i, 3) * 3).floor();
      final fy = (_rnd(i, 2) + cyc * p) % 1.0;
      final x = _rnd(i, 1) * s.width * 1.2 - s.width * 0.1 - fy * 20 * u;
      final y = fy * (s.height + 60 * u) - 30 * u;
      paint.color = _a(const Color(0xFFCFE4FF), 0.25 + _rnd(i, 7) * 0.4);
      final len = (10 + _rnd(i, 6) * 14) * u;
      c.drawLine(Offset(x, y), Offset(x - len * 0.18, y + len), paint);
    }
  }

  void _embers(Canvas c, Size s, double p, double u) {
    final glow = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * u);
    final core = Paint();
    for (var i = 0; i < 60; i++) {
      final cyc = 1 + (_rnd(i, 3) * 2).floor();
      final life = (_rnd(i, 2) + cyc * p) % 1.0;
      final y = (1.0 - life) * (s.height + 20 * u) - 10 * u;
      final fade = math.sin(math.pi * life).clamp(0.0, 1.0);
      final r = (1.0 + _rnd(i, 6) * 2.4) * u * (1.1 - life * 0.5) * (solid ? math.sqrt(fade) : 1.0);
      final hot = _rnd(i, 8) > 0.5;
      final base = hot ? const Color(0xFFFFC04D) : const Color(0xFFFF6A1A);
      final pos = Offset(_x(i, p, 0.05, s), y);
      if (!solid) {
        glow.color = base.withOpacity(0.55 * fade);
        c.drawCircle(pos, r * 2.2, glow);
      }
      core.color = _a(solid ? base : const Color(0xFFFFE9A8), 0.95 * fade);
      c.drawCircle(pos, r, core);
    }
  }

  void _confetti(Canvas c, Size s, double p, double u) {
    const colors = [
      Color(0xFFFF4D6D),
      Color(0xFFFFC233),
      Color(0xFF4DD0E1),
      Color(0xFF7C4DFF),
      Color(0xFF69F0AE),
      Color(0xFFFF8A3D),
    ];
    final paint = Paint();
    for (var i = 0; i < 70; i++) {
      final cyc = 1 + (_rnd(i, 3) * 2).floor();
      final y = ((_rnd(i, 2) + cyc * p) % 1.0) * (s.height + 30 * u) - 15 * u;
      final turns = 1 + (_rnd(i, 9) * 3).floor();
      final angle = 2 * math.pi * (_rnd(i, 10) + turns * p);
      final flip = math.cos(2 * math.pi * (_rnd(i, 11) + 2 * p)).abs() * 0.8 + 0.2;
      paint.color = colors[(_rnd(i, 12) * colors.length).floor() % colors.length];
      c.save();
      c.translate(_x(i, p, 0.04, s), y);
      c.rotate(angle);
      final w = (4 + _rnd(i, 6) * 5) * u;
      final h = (2.5 + _rnd(i, 13) * 3) * u * flip;
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
      c.restore();
    }
  }

  void _bubbles(Canvas c, Size s, double p, double u) {
    final ring = Paint()..style = PaintingStyle.stroke;
    final fill = Paint();
    for (var i = 0; i < 28; i++) {
      final cyc = 1 + (_rnd(i, 3) * 1).floor();
      final life = (_rnd(i, 2) + cyc * p) % 1.0;
      final y = (1.0 - life) * (s.height + 60 * u) - 30 * u;
      final r = (5 + _rnd(i, 6) * 16) * u;
      final fade = math.sin(math.pi * life).clamp(0.0, 1.0);
      final pos = Offset(_x(i, p, 0.04, s), y);
      fill.color = _a(Colors.white, 0.07 * fade);
      ring.color = _a(Colors.white, 0.7 * fade);
      ring.strokeWidth = math.max(1.0, 1.4 * u);
      if (!solid) c.drawCircle(pos, r, fill);
      c.drawCircle(pos, r, ring);
      fill.color = _a(Colors.white, 0.55 * fade);
      c.drawCircle(pos + Offset(-r * 0.35, -r * 0.35), r * 0.16, fill);
    }
  }

  void _leaves(Canvas c, Size s, double p, double u) {
    const colors = [
      Color(0xFFE8862E),
      Color(0xFFC9531F),
      Color(0xFFD9A441),
      Color(0xFF8DA83C),
      Color(0xFF9C3D1E),
    ];
    final paint = Paint();
    for (var i = 0; i < 28; i++) {
      final y = ((_rnd(i, 2) + p) % 1.0) * (s.height + 40 * u) - 20 * u;
      final angle = 2 * math.pi * (_rnd(i, 10) + (1 + (_rnd(i, 9) * 2).floor()) * p);
      paint.color = colors[(_rnd(i, 12) * colors.length).floor() % colors.length];
      paint.color = _a(paint.color, 0.92);
      c.save();
      c.translate(_x(i, p, 0.08, s), y);
      c.rotate(angle);
      final w = (9 + _rnd(i, 6) * 9) * u;
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.5), paint);
      c.restore();
    }
  }

  void _dust(Canvas c, Size s, double p, double u) {
    final paint = Paint();
    if (!solid) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 1.2 * u);
    for (var i = 0; i < 55; i++) {
      final m = 1 + (_rnd(i, 4) * 2).floor();
      final x = (_rnd(i, 1) + math.sin(2 * math.pi * (_rnd(i, 5) + m * p)) * 0.05) * s.width;
      final y = (_rnd(i, 2) + math.cos(2 * math.pi * (_rnd(i, 14) + p)) * 0.04) * s.height;
      final tw = 0.5 + 0.5 * math.sin(2 * math.pi * (_rnd(i, 15) + 2 * p));
      paint.color = _a(const Color(0xFFFFF3D6), 0.15 + 0.5 * tw * _rnd(i, 7));
      c.drawCircle(Offset(x, y), (0.8 + _rnd(i, 6) * 2.2) * u * (solid ? (0.4 + 0.6 * tw) : 1.0), paint);
    }
  }

  void _sparkle(Canvas c, Size s, double p, double u) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 26; i++) {
      final tw = math.max(0.0, math.sin(2 * math.pi * (_rnd(i, 15) + 2 * p)));
      if (tw < 0.05) continue;
      final cx = _rnd(i, 1) * s.width;
      final cy = _rnd(i, 2) * s.height;
      final r = (3 + _rnd(i, 6) * 8) * u * tw;
      paint.color = _a(Colors.white, 0.9 * tw);
      final path = Path()
        ..moveTo(cx, cy - r)
        ..quadraticBezierTo(cx, cy, cx + r, cy)
        ..quadraticBezierTo(cx, cy, cx, cy + r)
        ..quadraticBezierTo(cx, cy, cx - r, cy)
        ..quadraticBezierTo(cx, cy, cx, cy - r)
        ..close();
      c.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FxPainter old) => old.kind != kind || old.timeMs != timeMs;
}

/// Lets the user choose an effect. Returns its id, or null when cancelled.
Future<String?> showEffectPicker(BuildContext context, {String? current}) {
  return showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Floating effect'),
      children: [
        for (final k in kFxKinds)
          ListTile(
            dense: true,
            leading: Icon(k.icon),
            title: Text(k.name),
            trailing: k.id == current ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(c).pop(k.id),
          ),
      ],
    ),
  );
}
