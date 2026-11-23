import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'scene_canvas.dart';

/// Text-only animations: the text shows up piece by piece.
const List<String> kTextAnimKinds = ['none', 'letter', 'word', 'line', 'wordpop', 'wordslide', 'karaoke'];

String textAnimLabel(String kind) {
  switch (kind) {
    case 'letter':
      return 'Letter by letter';
    case 'word':
      return 'Word by word';
    case 'line':
      return 'Line by line';
    case 'wordpop':
      return 'Word pop';
    case 'wordslide':
      return 'Word slide';
    case 'karaoke':
      return 'Karaoke sweep';
    default:
      return 'None';
  }
}

/// What one piece is called in the editor.
String textUnitName(String kind) {
  switch (kind) {
    case 'letter':
      return 'letter';
    case 'line':
      return 'line';
    default:
      return 'word';
  }
}

int defaultUnitMs(String kind) {
  switch (kind) {
    case 'letter':
      return 45;
    case 'line':
      return 700;
    case 'karaoke':
      return 400;
    default:
      return 280;
  }
}

int _unitDurMs(String kind) {
  switch (kind) {
    case 'letter':
      return 140;
    case 'word':
      return 220;
    case 'line':
      return 300;
    case 'wordpop':
      return 420;
    default:
      return 450;
  }
}

/// Time between the start of one piece and the next.
int textUnitMs(Layer layer) =>
    layer.textAnimMs > 0 ? layer.textAnimMs : defaultUnitMs(layer.textAnim);

/// The character ranges of the pieces of [text].
List<TextRange> textUnits(String text, String kind) {
  final out = <TextRange>[];
  if (kind == 'letter') {
    var i = 0;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      var len = 1;
      if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) len = 2;
      final piece = text.substring(i, i + len);
      if (piece.trim().isNotEmpty) out.add(TextRange(start: i, end: i + len));
      i += len;
    }
  } else if (kind == 'line') {
    var start = 0;
    while (start <= text.length) {
      var end = text.indexOf('\n', start);
      if (end < 0) end = text.length;
      if (text.substring(start, end).trim().isNotEmpty) {
        out.add(TextRange(start: start, end: end));
      }
      start = end + 1;
    }
  } else {
    for (final m in RegExp(r'\S+').allMatches(text)) {
      out.add(TextRange(start: m.start, end: m.end));
    }
  }
  return out;
}

/// How long the whole text takes to show up, in milliseconds.
int textRevealTotalMs(Layer layer) {
  final n = textUnits(layer.text, layer.textAnim).length;
  if (n == 0) return 0;
  // Karaoke: each word takes the whole time of its piece to fill with colour.
  if (layer.textAnim == 'karaoke') return n * textUnitMs(layer);
  return (n - 1) * textUnitMs(layer) + _unitDurMs(layer.textAnim);
}

/// Draws a text item with the first pieces shown, as it looks [timeMs] after the
/// animation started. Before 0 nothing is shown, after the end everything is.
class TextRevealView extends StatefulWidget {
  const TextRevealView({super.key, required this.layer, required this.timeMs});

  final Layer layer;
  final int timeMs;

  @override
  State<TextRevealView> createState() => _TextRevealViewState();
}

class _TextRevealViewState extends State<TextRevealView> {
  TextPainter? _painter;
  List<TextRange> _units = const [];
  String _key = '';

  String _keyOf(Layer l) =>
      '${l.text}|${l.fontFamily}|${l.bold}|${l.italic}|${l.underline}|${l.strike}|'
      '${l.letterSpacing}|${l.lineHeight}|${l.align}|${l.color}|${l.textAnim}|${l.colorSpans}|${l.wrapW}';

  void _prepare() {
    final l = widget.layer;
    final key = _keyOf(l);
    if (key == _key && _painter != null) return;
    _key = key;
    _painter?.dispose();
    _painter = TextPainter(
      text: layerTextSpan(l, layerTextStyle(l)),
      textDirection: TextDirection.ltr,
      textAlign: layerTextAlign(l),
      textWidthBasis: l.wrapW > 0 ? TextWidthBasis.longestLine : TextWidthBasis.parent,
    )..layout(maxWidth: l.wrapW > 0 ? l.wrapW : double.infinity);
    _units = textUnits(l.text, l.textAnim);
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _prepare();
    final painter = _painter!;
    final l = widget.layer;
    return CustomPaint(
      size: Size(math.max(1, painter.width), math.max(1, painter.height)),
      painter: _RevealPainter(
        painter: painter,
        units: _units,
        kind: l.textAnim,
        unitMs: textUnitMs(l),
        durMs: l.textAnim == 'karaoke' ? textUnitMs(l) : _unitDurMs(l.textAnim),
        timeMs: widget.timeMs,
      ),
    );
  }
}

class _RevealPainter extends CustomPainter {
  _RevealPainter({
    required this.painter,
    required this.units,
    required this.kind,
    required this.unitMs,
    required this.durMs,
    required this.timeMs,
  });

  final TextPainter painter;
  final List<TextRange> units;
  final String kind;
  final int unitMs;
  final int durMs;
  final int timeMs;

  Rect? _rectOf(TextRange r) {
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: r.start, extentOffset: r.end),
    );
    Rect? out;
    for (final b in boxes) {
      final rect = b.toRect();
      out = out == null ? rect : out.expandToInclude(rect);
    }
    return out;
  }

  /// Karaoke: the whole text is dim, and each word fills with full colour from left to right
  /// during its own piece of time.
  void _paintKaraoke(Canvas canvas, Size size) {
    canvas.saveLayer(
      Rect.fromLTWH(-24, -24, size.width + 48, size.height + 48),
      Paint()..color = const Color.fromRGBO(0, 0, 0, 0.4),
    );
    painter.paint(canvas, Offset.zero);
    canvas.restore();
    for (var i = 0; i < units.length; i++) {
      final p = ((timeMs - i * unitMs) / math.max(1, unitMs)).clamp(0.0, 1.0).toDouble();
      if (p <= 0) break;
      final rect = _rectOf(units[i]);
      if (rect == null) continue;
      final right = p >= 1 ? rect.right + 6 : rect.left + rect.width * p;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(rect.left - 4, rect.top - 8, right, rect.bottom + 8));
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (kind == 'karaoke') {
      _paintKaraoke(canvas, size);
      return;
    }
    final done = Path();
    var anyDone = false;
    for (var i = 0; i < units.length; i++) {
      final t = timeMs - i * unitMs;
      if (t <= 0) break;
      final rect = _rectOf(units[i]);
      if (rect == null) continue;
      final p = (t / durMs).clamp(0.0, 1.0).toDouble();
      if (p >= 1) {
        done.addRect(rect.inflate(2));
        anyDone = true;
        continue;
      }
      final eased = 1 - math.pow(1 - p, 3).toDouble();
      var alpha = p;
      var dy = 0.0;
      var scale = 1.0;
      if (kind == 'wordpop') {
        final q = p - 1;
        scale = 0.5 + 0.5 * (1 + 2.70158 * q * q * q + 1.70158 * q * q);
        alpha = math.min(1.0, p * 3);
      } else if (kind == 'wordslide') {
        alpha = eased;
        dy = rect.height * 0.45 * (1 - eased);
      }
      final c = rect.center;
      canvas.save();
      canvas.translate(c.dx, c.dy + dy);
      canvas.scale(scale);
      canvas.translate(-c.dx, -c.dy);
      canvas.clipRect(rect.inflate(2));
      canvas.saveLayer(
        rect.inflate(2),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0).toDouble()),
      );
      painter.paint(canvas, Offset.zero);
      canvas.restore();
      canvas.restore();
    }
    if (anyDone) {
      canvas.save();
      canvas.clipPath(done);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.timeMs != timeMs ||
      old.painter != painter ||
      old.kind != kind ||
      old.unitMs != unitMs ||
      old.units != units;
}
