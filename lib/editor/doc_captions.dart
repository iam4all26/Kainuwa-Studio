import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../scene_canvas.dart';

/// One look for captions.
class CaptionStyle {
  const CaptionStyle({
    required this.id,
    required this.name,
    this.font = 'sans-serif-black',
    this.color = 0xFFFFFFFF,
    this.highlight = 0,
    this.outline = 0,
    this.glow = 0,
    this.box = 0,
    this.gradient = false,
    this.shadow = false,
    this.upper = true,
  });

  final String id;
  final String name;
  final String font;
  final int color;

  /// Colour of the word being spoken (0 = none).
  final int highlight;

  /// Outline colour (0 = none).
  final int outline;

  /// Glow colour (0 = none).
  final int glow;

  /// Box colour behind the words (0 = none).
  final int box;
  final bool gradient;
  final bool shadow;
  final bool upper;
}

const List<CaptionStyle> kCaptionStyles = [
  CaptionStyle(id: 'white', name: 'White outline', outline: 0xFF000000),
  CaptionStyle(id: 'yellow', name: 'Yellow pop', color: 0xFFFFD54F, outline: 0xFF000000),
  CaptionStyle(id: 'karaoke', name: 'Karaoke', highlight: 0xFFFFD54F, outline: 0xFF000000),
  CaptionStyle(id: 'red', name: 'Red highlight', highlight: 0xFFFF1744, outline: 0xFF000000),
  CaptionStyle(id: 'green', name: 'Green highlight', highlight: 0xFF69F0AE, outline: 0xFF000000),
  CaptionStyle(id: 'neon', name: 'Neon cyan', highlight: 0xFF00E5FF, glow: 0xFF00E5FF),
  CaptionStyle(id: 'gradient', name: 'Orange gradient', gradient: true, outline: 0xFF3E2000),
  CaptionStyle(id: 'soft', name: 'Soft shadow', font: 'sans-serif-medium', shadow: true, upper: false),
  CaptionStyle(id: 'boxhi', name: 'Box and highlight', highlight: 0xFFFFD54F, box: 0xCC000000, upper: false),
  CaptionStyle(id: 'box', name: 'Classic box', font: '', box: 0xCC000000, upper: false),
];

/// Shows the caption tool. Returns the number of caption items added, -1 when they were removed, null when cancelled.
Future<int?> showCaptionTool(BuildContext context, List<Scene> scenes) {
  return showDialog<int>(
    context: context,
    builder: (_) => _CaptionDialog(scenes: scenes),
  );
}

bool _isCaption(Layer l) => l.id.startsWith('cap_');

class _CaptionDialog extends StatefulWidget {
  const _CaptionDialog({required this.scenes});

  final List<Scene> scenes;

  @override
  State<_CaptionDialog> createState() => _CaptionDialogState();
}

class _CaptionDialogState extends State<_CaptionDialog> {
  int _mode = 1; // 0 one word, 1 short phrase, 2 lines
  String _style = 'karaoke';
  double _size = 46;
  double _cy = 0.78;
  bool _test = true;

  CaptionStyle get _current => kCaptionStyles.firstWhere((s) => s.id == _style);

  void _add() {
    var count = 0;
    final list = _test ? widget.scenes.take(3).toList() : widget.scenes;
    for (final s in widget.scenes) {
      s.layers.removeWhere(_isCaption);
    }
    for (final s in list) {
      count += _captionScene(s, _mode, _current, _size, _cy);
    }
    Navigator.of(context).pop(count);
  }

  void _remove() {
    for (final s in widget.scenes) {
      s.layers.removeWhere(_isCaption);
    }
    Navigator.of(context).pop(-1);
  }

  Widget _tile(CaptionStyle st) {
    final sel = st.id == _style;
    final base = TextStyle(
      fontFamily: st.font.isEmpty ? null : st.font,
      fontWeight: FontWeight.w900,
      fontSize: 15,
      color: Color(st.color),
    );
    Widget word(String t, {bool hi = false}) {
      final color = hi && st.highlight != 0 ? Color(st.highlight) : Color(st.color);
      final txt = st.upper ? t.toUpperCase() : t;
      final fill = Text(txt, style: base.copyWith(color: color, shadows: [
        if (st.glow != 0) Shadow(color: Color(st.glow), blurRadius: 8),
        if (st.shadow) const Shadow(color: Color(0xB3000000), blurRadius: 4, offset: Offset(1, 2)),
      ]));
      if (st.outline == 0) return fill;
      return Stack(
        children: [
          Text(txt, style: TextStyle(
            fontFamily: st.font.isEmpty ? null : st.font,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Color(st.outline),
          )),
          fill,
        ],
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _style = st.id),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? const Color(0xFF7351FF) : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: st.box != 0 ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3) : EdgeInsets.zero,
              color: st.box != 0 ? Color(st.box) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [word('Sannu '), word('da', hi: true)],
              ),
            ),
            const SizedBox(height: 4),
            Text(st.name, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final withWords = widget.scenes.where((s) => s.narrationText.trim().isNotEmpty).length;
    final st = _current;
    final highlightOk = st.highlight != 0;
    return AlertDialog(
      title: const Text('Captions from the script'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$withWords scenes have words. Add the voices first so the timing fits. '
                  'Captions made earlier are replaced.',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              const Text('How the words come', style: TextStyle(fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in const [(0, 'One word'), (1, 'Short phrase'), (2, 'Lines')])
                    ChoiceChip(label: Text(o.$2), selected: _mode == o.$1, onSelected: (_) => setState(() => _mode = o.$1)),
                ],
              ),
              if (_mode == 1 && !highlightOk)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('This style has no highlight colour, so the phrase appears whole. Pick Karaoke, Red, Green, Neon or Box and highlight to light up each word.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFFFB74D))),
                ),
              const SizedBox(height: 10),
              const Text('Style', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final s in kCaptionStyles) _tile(s)]),
              const SizedBox(height: 10),
              const Text('Size', style: TextStyle(fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in const [(36.0, 'Small'), (46.0, 'Medium'), (58.0, 'Large')])
                    ChoiceChip(label: Text(o.$2), selected: _size == o.$1, onSelected: (_) => setState(() => _size = o.$1)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Place', style: TextStyle(fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in const [(0.5, 'Middle'), (0.78, 'Lower'), (0.88, 'Bottom')])
                    ChoiceChip(label: Text(o.$2), selected: _cy == o.$1, onSelected: (_) => setState(() => _cy = o.$1)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(child: Text('Test: only the first 3 scenes')),
                  Switch(value: _test, onChanged: (v) => setState(() => _test = v)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _remove, child: const Text('Remove all')),
        FilledButton(onPressed: _add, child: const Text('Add captions')),
      ],
    );
  }
}

int _weight(String w) {
  var n = w.length + 2;
  if (RegExp(r'[.!?]$').hasMatch(w)) {
    n += 5;
  } else if (RegExp(r'[,;:]$').hasMatch(w)) {
    n += 3;
  }
  return n;
}

Layer _layer(String text, CaptionStyle st, double size, double cy, int from, int to, {bool pop = false, int wrap = 1100, int? hiFrom, int? hiTo}) {
  final layer = Layer(
    id: 'cap_${newId()}',
    type: 'text',
    text: st.upper ? text.toUpperCase() : text,
    cy: cy,
    color: st.color,
    bold: true,
    fontFamily: st.font,
    bgBox: st.box != 0,
    bgColor: st.box != 0 ? st.box : 0xCC000000,
    outlineOn: st.outline != 0,
    outlineColor: st.outline == 0 ? 0xFF000000 : st.outline,
    outlineWidth: 0.05,
    glowOn: st.glow != 0,
    glowColor: st.glow == 0 ? 0xFFFFD54F : st.glow,
    shadowOn: st.shadow,
    gradOn: st.gradient,
    startMs: from,
    endMs: to,
    animIn: pop ? 'pop' : 'none',
    animDurationMs: 180,
  );
  if (hiFrom != null && hiTo != null && st.highlight != 0) {
    layer.colorSpans = [
      [hiFrom, hiTo, st.highlight],
    ];
  }
  layer.wrapW = wrap.toDouble();
  setLayerTextSizePx(layer, size);
  if (layer.w > 0.94) {
    final f = 0.94 / layer.w;
    layer.w = 0.94;
    layer.h = layer.h * f;
  }
  return layer;
}

/// Puts the scene's words on the slide in the chosen way, timed across the voice. Returns the number of items.
int _captionScene(Scene s, int mode, CaptionStyle st, double size, double cy) {
  s.layers.removeWhere(_isCaption);
  final words = s.narrationText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 0;
  final span = s.narrationMs > 0 ? s.narrationLenMs : math.max(1000, s.durationMs - 300);
  final total = words.fold<int>(0, (a, w) => a + _weight(w));
  // Start and end time of every word.
  final starts = <int>[];
  final ends = <int>[];
  var at = 0.0;
  for (final w in words) {
    starts.add(at.round());
    at += span * _weight(w) / total;
    ends.add(at.round());
  }
  final made = <Layer>[];
  if (mode == 0) {
    for (var i = 0; i < words.length; i++) {
      made.add(_layer(words[i], st, size * 1.9, cy, starts[i], ends[i], pop: true, wrap: 0));
    }
  } else {
    // Groups: 3 words for a phrase, about 9 for a line (shorter at a comma or full stop).
    final per = mode == 1 ? 3 : 9;
    final min = mode == 1 ? 2 : 4;
    var i = 0;
    while (i < words.length) {
      var j = i;
      while (j < words.length) {
        j++;
        final stop = RegExp(r'[.!?;:,]$').hasMatch(words[j - 1]);
        if (j - i >= per || (stop && j - i >= min)) break;
      }
      if (words.length - j > 0 && words.length - j < (mode == 1 ? 1 : 3)) j = words.length;
      final group = words.sublist(i, j);
      final text = group.join(' ');
      if (mode == 1 && st.highlight != 0) {
        var offset = 0;
        for (var k = 0; k < group.length; k++) {
          final shown = st.upper ? group[k].toUpperCase() : group[k];
          made.add(_layer(text, st, size, cy, starts[i + k], ends[i + k], hiFrom: offset, hiTo: offset + shown.length));
          offset += shown.length + 1;
        }
      } else {
        made.add(_layer(text, st, size, cy, starts[i], ends[j - 1], pop: mode == 1));
      }
      i = j;
    }
  }
  s.layers.addAll(made);
  return made.length;
}
