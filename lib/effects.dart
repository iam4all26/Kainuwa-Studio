import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'shapes.dart';

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
  FxKind('spotlight', 'Moving spotlights', Icons.flashlight_on_outlined),
  FxKind('smoke', 'Smoke', Icons.cloud_outlined),
  FxKind('fairies', 'Fairies', Icons.auto_fix_high),
  FxKind('fireflies', 'Fireflies', Icons.emoji_objects_outlined),
  FxKind('bokeh', 'Bokeh lights', Icons.blur_on),
  FxKind('hearts', 'Floating hearts', Icons.favorite_border),
  FxKind('meteors', 'Shooting stars', Icons.nights_stay_outlined),
  FxKind('docs', 'Blurred newspapers and documents', Icons.newspaper),
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
      case 'spotlight':
        _spotlight(canvas, size, p, u);
        break;
      case 'smoke':
        _smoke(canvas, size, p, u);
        break;
      case 'fairies':
        _fairies(canvas, size, p, u);
        break;
      case 'fireflies':
        _fireflies(canvas, size, p, u);
        break;
      case 'bokeh':
        _bokeh(canvas, size, p, u);
        break;
      case 'hearts':
        _hearts(canvas, size, p, u);
        break;
      case 'meteors':
        _meteors(canvas, size, p, u);
        break;
      case 'docs':
        _docs(canvas, size, p, u);
        break;
    }
  }

  /// Light on a dark night sky. In the export (solid) the brightness is mixed into near-black instead of see-through.
  Color _b(Color c, double o) =>
      solid ? Color.lerp(const Color(0xFF05060F), c, o.clamp(0.0, 1.0).toDouble())! : c.withOpacity(o.clamp(0.0, 1.0).toDouble());

  // ---- Blurred newspapers, documents and books drifting behind a sharp word ----

  /// Lines of small text (grey bars) inside [area].
  void _textLines(Canvas c, Rect area, double lineH, double gap, int seed, Color col) {
    final paint = Paint()..color = col;
    var y = area.top;
    var n = 0;
    var left = 3 + (_rnd(seed, 1) * 5).floor();
    while (y + lineH <= area.bottom) {
      var w = area.width * (0.82 + 0.18 * _rnd(seed + n, 7));
      if (left == 0) {
        // the last line of a paragraph is short, then a bigger gap
        w = area.width * (0.3 + 0.4 * _rnd(seed + n, 8));
      }
      c.drawRect(Rect.fromLTWH(area.left, y, w, lineH), paint);
      y += lineH + gap;
      left--;
      if (left < 0) {
        y += gap * 1.6;
        left = 4 + (_rnd(seed + n, 9) * 6).floor();
      }
      n++;
    }
  }

  void _page(Canvas c, Rect r, int type, double u, int seed) {
    c.drawRect(r.shift(Offset(4 * u, 5 * u)), Paint()..color = const Color(0x66000000));
    final ink = const Color(0xCC3A3631);
    final line = 3.2 * u;
    final gap = 3.0 * u;
    if (type == 0) {
      // Newspaper
      c.drawRect(r, Paint()..color = const Color(0xFFE9E2CF));
      final pad = r.width * 0.06;
      final inner = Rect.fromLTWH(r.left + pad, r.top + pad, r.width - 2 * pad, r.height - 2 * pad);
      c.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width, inner.height * 0.075), Paint()..color = const Color(0xFF2A2622));
      c.drawRect(Rect.fromLTWH(inner.left, inner.top + inner.height * 0.09, inner.width, 1.5 * u), Paint()..color = ink);
      final headTop = inner.top + inner.height * 0.12;
      c.drawRect(Rect.fromLTWH(inner.left, headTop, inner.width * 0.7, inner.height * 0.055), Paint()..color = const Color(0xFF2A2622));
      c.drawRect(Rect.fromLTWH(inner.left, headTop + inner.height * 0.07, inner.width * 0.45, inner.height * 0.03), Paint()..color = ink);
      final photo = Rect.fromLTWH(inner.left + inner.width * 0.58, headTop + inner.height * 0.065, inner.width * 0.42, inner.height * 0.2);
      c.drawRect(photo, Paint()..color = const Color(0xFF8C867A));
      final body = Rect.fromLTWH(inner.left, headTop + inner.height * 0.12, inner.width, inner.bottom - headTop - inner.height * 0.12);
      const cols = 3;
      final cw = (body.width - (cols - 1) * 6 * u) / cols;
      for (var k = 0; k < cols; k++) {
        var top = body.top;
        if (k == 2) top = photo.bottom + 6 * u;
        _textLines(c, Rect.fromLTWH(body.left + k * (cw + 6 * u), top, cw, body.bottom - top), line, gap, seed * 7 + k, ink);
      }
    } else if (type == 1) {
      // Document with a table and a stamp
      c.drawRect(r, Paint()..color = const Color(0xFFF7F6F0));
      final pad = r.width * 0.1;
      final inner = Rect.fromLTWH(r.left + pad, r.top + pad, r.width - 2 * pad, r.height - 2 * pad);
      c.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width * 0.55, inner.height * 0.05), Paint()..color = const Color(0xFF2C3E6B));
      _textLines(c, Rect.fromLTWH(inner.left, inner.top + inner.height * 0.09, inner.width, inner.height * 0.3), line, gap, seed * 5, ink);
      final table = Rect.fromLTWH(inner.left, inner.top + inner.height * 0.44, inner.width, inner.height * 0.22);
      final grid = Paint()
        ..color = const Color(0x99555555)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * u;
      c.drawRect(table, grid);
      for (var k = 1; k < 4; k++) {
        c.drawLine(Offset(table.left, table.top + table.height * k / 4), Offset(table.right, table.top + table.height * k / 4), grid);
        c.drawLine(Offset(table.left + table.width * k / 4, table.top), Offset(table.left + table.width * k / 4, table.bottom), grid);
      }
      _textLines(c, Rect.fromLTWH(inner.left, table.bottom + inner.height * 0.05, inner.width, inner.bottom - table.bottom - inner.height * 0.05), line, gap, seed * 3, ink);
      final stamp = Paint()
        ..color = const Color(0xCCB3261E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * u;
      c.drawCircle(Offset(inner.right - inner.width * 0.18, inner.top + inner.height * 0.22), inner.width * 0.13, stamp);
    } else {
      // Open book: two pages
      c.drawRect(r, Paint()..color = const Color(0xFFF0E2BD));
      final mid = r.center.dx;
      c.drawRect(
        Rect.fromLTWH(mid - 5 * u, r.top, 10 * u, r.height),
        Paint()..shader = ui.Gradient.linear(Offset(mid - 5 * u, 0), Offset(mid + 5 * u, 0), const [Color(0x00000000), Color(0x66000000), Color(0x00000000)], const [0, 0.5, 1]),
      );
      final pad = r.width * 0.07;
      for (var side = 0; side < 2; side++) {
        final left = side == 0 ? r.left + pad : mid + pad * 0.5;
        final area = Rect.fromLTWH(left, r.top + pad, r.width / 2 - pad * 1.5, r.height - 2 * pad);
        if (side == 0) {
          c.drawRect(Rect.fromLTWH(area.left, area.top, area.width * 0.5, area.height * 0.04), Paint()..color = const Color(0xFF5B3A1E));
          _textLines(c, Rect.fromLTWH(area.left, area.top + area.height * 0.1, area.width, area.height * 0.9), line, gap, seed * 11, ink);
        } else {
          _textLines(c, area, line, gap, seed * 13, ink);
        }
      }
    }
  }

  void _docs(Canvas c, Size s, double p, double u) {
    final bounds = Offset.zero & s;
    final sigma = (7 + 1.0 * math.sin(2 * math.pi * p)) * u;
    c.save();
    c.clipRect(bounds);
    c.saveLayer(bounds, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp));
    c.drawRect(bounds, Paint()..color = const Color(0xFF1B1712));
    final cols = (s.width / (s.height * 0.55)).ceil().clamp(3, 5).toInt();
    final colW = s.width / cols;
    final pageH = s.height * 0.62;
    final gap = s.height * 0.04;
    final period = pageH + gap;
    for (var i = 0; i < cols; i++) {
      final dir = i.isEven ? -1.0 : 1.0;
      final off = dir * p * period;
      final cx = colW * (i + 0.5);
      c.save();
      c.translate(cx, s.height / 2);
      c.rotate((i.isEven ? -1 : 1) * 0.05);
      c.translate(-cx, -s.height / 2);
      final tiles = (s.height * 1.3 / period).ceil() + 2;
      for (var k = -tiles; k <= tiles; k++) {
        final top = s.height / 2 - pageH / 2 + k * period + off;
        if (top > s.height * 1.3 || top + pageH < -s.height * 0.3) continue;
        _page(c, Rect.fromLTWH(colW * i + colW * 0.06, top, colW * 0.88, pageH), (i + 0) % 3, u, i + 1);
      }
      c.restore();
    }
    c.restore();
    // Darken a little so a white word stands out, more at the edges.
    c.drawRect(bounds, Paint()..color = const Color(0x55000000));
    c.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.radial(
          bounds.center,
          s.longestSide * 0.7,
          const [Color(0x00000000), Color(0xAA000000)],
          const [0.35, 1.0],
        ),
    );
    c.restore();
  }

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

  /// The see-through end of a soft glow (near-black in the export, where nothing is see-through).
  Color _edge(Color c) => solid ? const Color(0xFF05060F) : c.withOpacity(0.0);

  void _glow(Canvas c, Offset at, double r, Color col, double o) {
    if (r <= 0 || o <= 0) return;
    c.drawCircle(
      at,
      r,
      Paint()..shader = ui.Gradient.radial(at, r, [_b(col, o), _edge(col)]),
    );
  }

  void _spotlight(Canvas c, Size s, double p, double u) {
    const cols = [0xFFFFF3C4, 0xFF9FD8FF, 0xFFFFA8E0, 0xFFFFE08A];
    for (var i = 0; i < 4; i++) {
      final sx = s.width * (0.12 + 0.253 * i);
      final k = 1 + i % 2;
      final ang = math.sin(2 * math.pi * (p * k + i * 0.27)) * 0.55 - (i - 1.5) * 0.12;
      final len = s.height * 1.25;
      final half = 0.11 + 0.03 * (i % 2);
      final src = Offset(sx, -s.height * 0.02);
      Offset pt(double a) => Offset(src.dx + math.sin(a) * len, src.dy + math.cos(a) * len);
      final a1 = pt(ang - half);
      final a2 = pt(ang + half);
      final end = pt(ang);
      final col = Color(cols[i]);
      final path = Path()
        ..moveTo(src.dx, src.dy)
        ..lineTo(a1.dx, a1.dy)
        ..lineTo(a2.dx, a2.dy)
        ..close();
      c.drawPath(
        path,
        Paint()..shader = ui.Gradient.linear(src, end, [_b(col, 0.55), _edge(col)]),
      );
      _glow(c, src, 22 * u, col, 0.9);
    }
  }

  void _smoke(Canvas c, Size s, double p, double u) {
    const grey = Color(0xFFC9CCD6);
    for (var i = 0; i < 14; i++) {
      final t = (_rnd(i, 2) + p) % 1.0;
      final x = s.width * _rnd(i, 1) + math.sin(2 * math.pi * (_rnd(i, 5) + p)) * 0.05 * s.width;
      final y = s.height * (1.1 - 1.25 * t);
      final r = (40 + 90 * t + _rnd(i, 6) * 40) * u;
      _glow(c, Offset(x, y), r, grey, math.sin(math.pi * t) * 0.26);
    }
  }

  Offset _wander(int i, double q, Size s, double amp) {
    final m = 1 + (_rnd(i, 4) * 2).floor();
    final x = s.width * (0.08 + 0.84 * _rnd(i, 1)) + math.sin(2 * math.pi * (_rnd(i, 5) + m * q)) * amp * s.width;
    final y = s.height * (0.12 + 0.76 * _rnd(i, 2)) + math.sin(2 * math.pi * (_rnd(i, 7) + (m + 1) * q)) * amp * 0.8 * s.height;
    return Offset(x, y);
  }

  void _fairies(Canvas c, Size s, double p, double u) {
    const cols = [0xFFFFB3F0, 0xFFB9F2FF, 0xFFFFF2A8, 0xFFC9B6FF, 0xFFB6FFCB];
    final paint = Paint();
    for (var i = 0; i < 18; i++) {
      final col = Color(cols[i % cols.length]);
      final pos = _wander(i, p, s, 0.07);
      final tw = 0.65 + 0.35 * math.sin(2 * math.pi * (_rnd(i, 9) + 3 * p));
      final size = (5 + _rnd(i, 6) * 5) * u;
      // A short trail of sparkles where the fairy just was.
      for (var j = 1; j <= 5; j++) {
        final q = p - j * 0.01;
        final tp = _wander(i, q < 0 ? q + 1 : q, s, 0.07);
        paint.color = _b(col, 0.55 * (1 - j / 6) * tw);
        c.drawCircle(tp, size * 0.28 * (1 - j / 7), paint);
      }
      _glow(c, pos, size * 3.2, col, 0.6 * tw);
      // Two little wings that flap.
      final flap = 0.55 + 0.45 * math.sin(2 * math.pi * (_rnd(i, 3) + 8 * p));
      paint.color = _b(Colors.white, 0.5 * tw);
      for (final side in const [-1.0, 1.0]) {
        c.save();
        c.translate(pos.dx, pos.dy);
        c.rotate(side * 0.7);
        c.drawOval(Rect.fromCenter(center: Offset(side * size * 0.9, -size * 0.2), width: size * 1.5 * flap, height: size * 0.8), paint);
        c.restore();
      }
      paint.color = _b(Colors.white, 0.95);
      c.drawCircle(pos, size * 0.38, paint);
    }
  }

  void _fireflies(Canvas c, Size s, double p, double u) {
    const col = Color(0xFFE6F27A);
    final paint = Paint();
    for (var i = 0; i < 26; i++) {
      final pos = _wander(i, p, s, 0.04);
      final k = 1 + (_rnd(i, 8) * 2).floor();
      final raw = math.sin(2 * math.pi * (_rnd(i, 9) + k * p));
      final blink = raw <= 0 ? 0.0 : raw * raw;
      final r = (3 + _rnd(i, 6) * 3) * u;
      _glow(c, pos, r * 4.5, col, 0.55 * blink);
      paint.color = _b(const Color(0xFFFFFBD0), 0.2 + 0.8 * blink);
      c.drawCircle(pos, r * 0.6, paint);
    }
  }

  void _bokeh(Canvas c, Size s, double p, double u) {
    const cols = [0xFFFFD27A, 0xFFFF9EC7, 0xFF9ED8FF, 0xFFFFFFFF, 0xFFC7A6FF];
    final fill = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * u;
    for (var i = 0; i < 16; i++) {
      final col = Color(cols[i % cols.length]);
      final r = (18 + _rnd(i, 3) * 40) * u;
      final x = s.width * _rnd(i, 1) + math.sin(2 * math.pi * (_rnd(i, 5) + p)) * 0.04 * s.width;
      final y = s.height * _rnd(i, 2) + math.sin(2 * math.pi * (_rnd(i, 6) + p)) * 0.05 * s.height;
      final pulse = 0.6 + 0.4 * math.sin(2 * math.pi * (_rnd(i, 9) + p));
      fill.color = _b(col, 0.16 * pulse);
      ring.color = _b(col, 0.3 * pulse);
      c.drawCircle(Offset(x, y), r, fill);
      c.drawCircle(Offset(x, y), r, ring);
    }
  }

  void _hearts(Canvas c, Size s, double p, double u) {
    const cols = [0xFFFF4D6D, 0xFFFF8FA3, 0xFFFFB3C6, 0xFFE63970];
    final paint = Paint();
    for (var i = 0; i < 14; i++) {
      final t = (_rnd(i, 2) + p) % 1.0;
      final m = 1 + (_rnd(i, 4) * 2).floor();
      final x = s.width * _rnd(i, 1) + math.sin(2 * math.pi * (_rnd(i, 5) + m * p)) * 0.04 * s.width;
      final y = s.height * (1.1 - 1.2 * t);
      final size = (14 + _rnd(i, 6) * 22) * u;
      paint.color = _b(Color(cols[i % cols.length]), math.sin(math.pi * t) * 0.9);
      c.drawPath(shapePath('heart', Rect.fromCenter(center: Offset(x, y), width: size, height: size)), paint);
    }
  }

  void _meteors(Canvas c, Size s, double p, double u) {
    const dx = -0.62;
    const dy = 0.78;
    for (var i = 0; i < 4; i++) {
      final t = (p + _rnd(i, 1)) % 1.0;
      if (t > 0.38) continue;
      final f = t / 0.38;
      final fade = math.sin(math.pi * f);
      final sx = s.width * (0.35 + 0.65 * _rnd(i, 2));
      final sy = -s.height * 0.05;
      final head = Offset(sx + dx * s.height * 1.0 * f, sy + dy * s.height * 1.0 * f);
      final tail = Offset(head.dx - dx * s.height * 0.22, head.dy - dy * s.height * 0.22);
      const col = Color(0xFFDDE8FF);
      c.drawLine(
        head,
        tail,
        Paint()
          ..strokeWidth = (2.2 + _rnd(i, 3) * 1.6) * u
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(head, tail, [_b(col, 0.95 * fade), _edge(col)]),
      );
      _glow(c, head, 9 * u, col, 0.9 * fade);
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
