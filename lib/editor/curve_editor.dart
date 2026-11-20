import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../video_curves.dart';

/// Curve editor for a video clip: drag a point, touch an empty spot to add one,
/// double tap a point to remove it. Master, Red, Green and Blue curves plus three tone sliders.
class CurveEditor extends StatefulWidget {
  const CurveEditor({super.key, required this.initial, required this.onChanged});

  final VideoCurves initial;
  final ValueChanged<VideoCurves> onChanged;

  @override
  State<CurveEditor> createState() => _CurveEditorState();
}

class _CurveEditorState extends State<CurveEditor> {
  static const _names = ['Master', 'Red', 'Green', 'Blue'];
  static const _colors = [Colors.white, Color(0xFFFF5A5A), Color(0xFF5AE08A), Color(0xFF5A8CFF)];
  static const _gap = 0.02;

  late VideoCurves _c = widget.initial;
  int _ch = 0;
  int? _grab;
  int? _lastIdx;
  DateTime _lastUp = DateTime(2000);

  List<Offset> get _pts => _c.channel(_ch);

  void _push(VideoCurves c) {
    setState(() => _c = c);
    widget.onChanged(c);
  }

  void _setPts(List<Offset> p) => _push(_c.withChannel(_ch, p));

  Offset _norm(Offset local, double side) => Offset(
        (local.dx / side).clamp(0.0, 1.0).toDouble(),
        (1 - local.dy / side).clamp(0.0, 1.0).toDouble(),
      );

  void _down(Offset local, double side) {
    final p = _norm(local, side);
    final pts = List<Offset>.of(_pts);
    int? hit;
    var best = 26.0;
    for (var i = 0; i < pts.length; i++) {
      final d = (Offset(pts[i].dx * side, (1 - pts[i].dy) * side) - local).distance;
      if (d < best) {
        best = d;
        hit = i;
      }
    }
    if (hit != null) {
      final quick = DateTime.now().difference(_lastUp).inMilliseconds < 350;
      if (quick && _lastIdx == hit && hit != 0 && hit != pts.length - 1) {
        pts.removeAt(hit);
        _grab = null;
        _lastIdx = null;
        _setPts(pts);
        return;
      }
      _grab = hit;
      return;
    }
    for (final q in pts) {
      if ((q.dx - p.dx).abs() < _gap) return;
    }
    pts.add(p);
    pts.sort((a, b) => a.dx.compareTo(b.dx));
    _grab = pts.indexOf(p);
    _setPts(pts);
  }

  void _move(Offset local, double side) {
    final g = _grab;
    if (g == null) return;
    final pts = List<Offset>.of(_pts);
    final p = _norm(local, side);
    var x = p.dx;
    if (g == 0) {
      x = 0;
    } else if (g == pts.length - 1) {
      x = 1;
    } else {
      x = x.clamp(pts[g - 1].dx + _gap, pts[g + 1].dx - _gap).toDouble();
    }
    pts[g] = Offset(x, p.dy);
    _setPts(pts);
  }

  void _up() {
    _lastIdx = _grab;
    _lastUp = DateTime.now();
    _grab = null;
  }

  Widget _slider(String label, double value, VideoCurves Function(double) make) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: const TextStyle(fontSize: 12, color: KColors.ink))),
        Expanded(
          child: Slider(value: value.clamp(-1.0, 1.0).toDouble(), min: -1, max: 1, onChanged: (v) => _push(make(v))),
        ),
        SizedBox(width: 34, child: Text('${(value * 100).round()}', style: const TextStyle(fontSize: 12, color: KColors.ink))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < 4; i++)
              ChoiceChip(
                label: Text(_names[i]),
                selected: _ch == i,
                onSelected: (_) => setState(() {
                  _ch = i;
                  _grab = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 210,
            height: 210,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _down(e.localPosition, 210),
              onPointerMove: (e) => _move(e.localPosition, 210),
              onPointerUp: (_) => _up(),
              onPointerCancel: (_) => _up(),
              child: RawGestureDetector(
                // Claims the touch so the sheet does not scroll while you drag a point.
                gestures: {
                  EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                    (_) {},
                  ),
                },
                child: CustomPaint(
                  painter: _CurvePainter(_pts, _colors[_ch]),
                  size: const Size(210, 210),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _slider('Shadows', _c.shadows, (v) => _c.copyWith(shadows: v)),
        _slider('Highlights', _c.highlights, (v) => _c.copyWith(highlights: v)),
        _slider('Vibrance', _c.vibrance, (v) => _c.copyWith(vibrance: v)),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: _isFlat(_pts) ? null : () => _setPts(VideoCurves.identity()),
                child: Text('Reset ${_names[_ch].toLowerCase()} curve'),
              ),
              TextButton(
                onPressed: _c.isNone ? null : () => _push(VideoCurves()),
                child: const Text('Reset all'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static bool _isFlat(List<Offset> p) => p.length == 2 && p[0] == const Offset(0, 0) && p[1] == const Offset(1, 1);
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.pts, this.color);

  final List<Offset> pts;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bg = Paint()..color = const Color(0xFF1B1636);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)), bg);
    final grid = Paint()
      ..color = const Color(0x24FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(s * i / 4, 0), Offset(s * i / 4, s), grid);
      canvas.drawLine(Offset(0, s * i / 4), Offset(s, s * i / 4), grid);
    }
    canvas.drawLine(Offset(0, s), Offset(s, 0), grid);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i <= 64; i++) {
      final x = i / 64;
      final y = VideoCurves.curveAt(pts, x);
      final o = Offset(x * s, (1 - y) * s);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, line);
    for (final p in pts) {
      final o = Offset(p.dx * s, (1 - p.dy) * s);
      canvas.drawCircle(o, 8, Paint()..color = Colors.white);
      canvas.drawCircle(o, 5.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) => true;
}
