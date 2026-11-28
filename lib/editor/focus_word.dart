import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../models.dart';
import '../stage_shape.dart';

/// What the person chose in the Focus word dialog.
class FocusChoice {
  FocusChoice({required this.word, required this.lines, required this.stepMs, this.look = 0});

  final String word;

  /// Sentences. Each one has the word in it (or not, when the person wrote their own).
  final List<String> lines;
  final int stepMs;

  /// 0 mixed, 1 newspapers, 2 typewriter and plain pages
  final int look;
}

const List<String> kFocusEnglish = [
  'Ten years later, {w} is still a mystery',
  'Most people had never heard of {w}',
  'How {w} changed everything',
  'Nobody expected {w} to happen',
  'The truth about {w}, finally',
  'Neighbours split over {w}',
  'Experts are still talking about {w}',
  '{w}, explained',
  'What they never told you about {w}',
  'Everyone is asking about {w}',
];

const List<String> kFocusHausa = [
  'Mutane da yawa suna magana game da {w}',
  'Shekaru da dama bayan haka, {w} har yanzu abin mamaki ne',
  'Gaskiya game da {w}, a ƙarshe',
  'Ba wanda ya yi tsammanin {w} zai faru',
  'Yadda {w} ya canza komai',
  'Abin da ake faɗi game da {w}',
  'Me ya sa kowa yake magana a kan {w}?',
  'Dubi abin da ya faru game da {w}',
  '{w}: abin da ba ka sani ba',
  'Labari mai muhimmanci game da {w}',
];

/// Asks for the word and where the sentences come from. Null when cancelled.
Future<FocusChoice?> showFocusDialog(BuildContext context) {
  return showDialog<FocusChoice>(context: context, builder: (_) => const _FocusDialog());
}

class _FocusDialog extends StatefulWidget {
  const _FocusDialog();

  @override
  State<_FocusDialog> createState() => _FocusDialogState();
}

class _FocusDialogState extends State<_FocusDialog> {
  final TextEditingController _word = TextEditingController();
  final TextEditingController _own = TextEditingController();
  int _source = 0; // 0 English, 1 Hausa, 2 my own lines
  int _step = 700;
  int _look = 0;

  @override
  void dispose() {
    _word.dispose();
    _own.dispose();
    super.dispose();
  }

  void _go() {
    final word = _word.text.trim();
    if (word.isEmpty) return;
    List<String> lines;
    if (_source == 2) {
      lines = _own.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) lines = [word];
    } else {
      final bank = _source == 1 ? kFocusHausa : kFocusEnglish;
      lines = [for (final t in bank) t.replaceAll('{w}', word)];
    }
    Navigator.of(context).pop(FocusChoice(word: word, lines: lines, stepMs: _step, look: _look));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      title: const Text('Focus word'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Each cut is a different page of text. Only the line in the middle is sharp, with your word on a yellow marker. '
                'The pages are made as pictures, so to change the word make it again.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _word,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, labelText: 'The word'),
            ),
            const SizedBox(height: 12),
            const Text('Sentences', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 8,
              children: [
                for (final o in const [(0, 'English'), (1, 'Hausa'), (2, 'My own lines')])
                  ChoiceChip(label: Text(o.$2), selected: _source == o.$1, onSelected: (_) => setState(() => _source = o.$1)),
              ],
            ),
            if (_source == 1)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('The Hausa sentences are short drafts. Read them, and use your own lines if a word does not fit.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFFFB74D))),
              ),
            if (_source == 2) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _own,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'One sentence on each line. Put the word inside it.',
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Pages', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 8,
              children: [
                for (final o in const [(0, 'Mixed'), (1, 'Newspapers'), (2, 'Typewriter and plain')])
                  ChoiceChip(label: Text(o.$2), selected: _look == o.$1, onSelected: (_) => setState(() => _look = o.$1)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('How fast the sentences change', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 8,
              children: [
                for (final o in const [(450, 'Fast'), (700, 'Medium'), (1100, 'Slow')])
                  ChoiceChip(label: Text(o.$2), selected: _step == o.$1, onSelected: (_) => setState(() => _step = o.$1)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _go, child: const Text('Add')),
      ],
    );
  }
}

const int _marker = 0xFFFFE02E;

class _Look {
  const _Look(this.paper, this.ink, this.font, this.size, this.bold, this.italic, this.col, this.lh);

  final int paper;
  final int ink;
  final String font;

  /// Text size as a part of the picture height.
  final double size;
  final bool bold;
  final bool italic;

  /// Width of the text column as a part of the picture width.
  final double col;
  final double lh;
}

const List<_Look> _looks = [
  _Look(0xFFEAE3D0, 0xFF2B2824, 'serif', 0.036, false, false, 0.50, 1.35),
  _Look(0xFFF2F1EA, 0xFF35332E, 'monospace', 0.048, false, false, 0.86, 1.4),
  _Look(0xFFE3CFA0, 0xFF4A3B24, 'serif', 0.062, false, false, 0.84, 1.3),
  _Look(0xFFF5F4F0, 0xFF111111, 'sans-serif-condensed', 0.05, true, false, 0.8, 1.2),
  _Look(0xFFD9D6CC, 0xFF2A2A2A, 'serif', 0.042, true, false, 0.6, 1.3),
  _Look(0xFFEDE3C8, 0xFF2B2824, 'serif', 0.082, false, false, 0.9, 1.25),
  _Look(0xFFEFE9DA, 0xFF3A342B, 'serif', 0.055, false, true, 0.8, 1.35),
  _Look(0xFFE8D7A5, 0xFF3B2F1A, 'serif', 0.045, false, false, 0.56, 1.35),
];

const List<List<int>> _lookSets = [
  [0, 1, 2, 3, 4, 5, 6, 7],
  [0, 4, 7, 2],
  [1, 3, 6, 5],
];

const List<String> _filler = [
  'The council announced a full report after a short delay.',
  'Residents said the road had been closed since early morning.',
  'Officials gave no reason, though several people were asked.',
  'A spokesman said the matter would be reviewed next week.',
  'Nobody could say exactly when the work would be finished.',
  'The market was busy again by noon and the mood was calm.',
  'Several families waited outside for news until late evening.',
  'It was the third time this year that the same thing happened.',
  'Local leaders met on Tuesday to talk about what comes next.',
  'The figures, released on Friday, were higher than expected.',
  'Some said it was fine, others said they had seen it before.',
  'Weather was mild and the roads were mostly clear all week.',
];

const List<String> _headlines = [
  'Council to decide on new plan',
  'Annual report is out',
  'Survey: most people found nothing unusual',
  'Fog clears by afternoon',
  'Market opens early this season',
];

double _rand(int seed, int salt) {
  var x = (seed * 374761393 + salt * 668265263 + 12345) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  x = x ^ (x >> 16);
  return (x & 0xffff) / 65535.0;
}

String _fill(int seed, int sentences) {
  final b = StringBuffer();
  for (var i = 0; i < sentences; i++) {
    if (i > 0) b.write(' ');
    b.write(_filler[(seed * 3 + i * 5) % _filler.length]);
  }
  return b.toString();
}

ui.Paragraph _para(String text, double width, double size, _Look look, {bool? bold, double scale = 1, ui.TextAlign align = ui.TextAlign.left}) {
  final b = bold ?? look.bold;
  final style = ui.TextStyle(
    color: Color(look.ink).withOpacity(0.86),
    fontFamily: look.font,
    fontSize: size * scale,
    height: look.lh,
    fontWeight: b ? FontWeight.w800 : FontWeight.w400,
    fontStyle: look.italic ? FontStyle.italic : FontStyle.normal,
  );
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: align, fontFamily: look.font, fontSize: size * scale, height: look.lh))
    ..pushStyle(style)
    ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

/// One page of a newspaper, book or typewritten sheet. The sentence is a line of the page itself, in the middle,
/// and the lines around it get more blurred the farther they are from it.
Future<ui.Image> _renderPage(_Look look, String sentence, String word, int seed, double w, double h, {double lineScale = 1}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final bounds = Rect.fromLTWH(0, 0, w, h);
  final size = h * look.size;
  final lh = size * look.lh * lineScale;
  final lineSize = size * lineScale;
  final cy = h / 2;
  final colW = w * look.col;
  final colX = (w - colW) / 2 + (_rand(seed, 1) - 0.5) * w * 0.1;
  final paper = Color(look.paper);
  c.drawRect(bounds, Paint()..color = paper);

  // Text above and below the sharp line.
  final above = _para(_fill(seed, 40), colW, size, look);
  c.save();
  c.clipRect(Rect.fromLTWH(0, 0, w, cy - lh * 0.5));
  c.drawParagraph(above, Offset(colX, cy - lh * 0.5 - above.height));
  c.restore();
  final below = _para(_fill(seed + 4, 40), colW, size, look);
  c.save();
  c.clipRect(Rect.fromLTWH(0, cy + lh * 0.5, w, h));
  c.drawParagraph(below, Offset(colX, cy + lh * 0.5));
  c.restore();

  // A headline and a photo, sometimes, far from the middle.
  if (_rand(seed, 3) > 0.35) {
    final head = _para(_headlines[seed % _headlines.length], colW, size, look, bold: true, scale: 1.7);
    var top = _rand(seed, 5) > 0.5;
    // Only where it does not come near the sharp line in the middle.
    bool fits(bool atTop) => atTop ? h * 0.04 + head.height < cy - lh * 3 : h - head.height - h * 0.05 > cy + lh * 3;
    if (!fits(top)) top = !top;
    if (fits(top)) {
      final y = top ? h * 0.04 : h - head.height - h * 0.05;
      c.drawRect(Rect.fromLTWH(colX - 6, y - 4, colW + 12, head.height + 8), Paint()..color = paper);
      c.drawParagraph(head, Offset(colX, y));
    }
  }
  // The sharp line: the sentence with the word on a marker, the word in the middle of the picture.
  final at = word.isEmpty ? -1 : sentence.toLowerCase().indexOf(word.toLowerCase());
  final base = ui.TextStyle(
    color: Color(look.ink),
    fontFamily: look.font,
    fontSize: lineSize,
    height: look.lh,
    fontWeight: look.bold ? FontWeight.w800 : FontWeight.w400,
    fontStyle: look.italic ? FontStyle.italic : FontStyle.normal,
  );
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: look.font, fontSize: lineSize, height: look.lh));
  if (at >= 0) {
    builder
      ..pushStyle(base)
      ..addText(sentence.substring(0, at))
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFF000000),
        background: Paint()..color = const Color(_marker),
        fontFamily: look.font,
        fontSize: lineSize,
        height: look.lh,
        fontWeight: FontWeight.w800,
        fontStyle: look.italic ? FontStyle.italic : FontStyle.normal,
      ))
      ..addText(sentence.substring(at, at + word.length))
      ..pushStyle(base)
      ..addText(sentence.substring(at + word.length));
  } else {
    builder
      ..pushStyle(base)
      ..addText(sentence);
  }
  var line = builder.build()..layout(const ui.ParagraphConstraints(width: 100000));
  final maxW = w * 0.92;
  if (line.longestLine > maxW) {
    // Too long for the picture: draw the whole sentence again, smaller, so none of it is cut off.
    final f = maxW / line.longestLine;
    final small = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: look.font, fontSize: lineSize * f, height: look.lh));
    ui.TextStyle st(bool mark) => ui.TextStyle(
          color: mark ? const Color(0xFF000000) : Color(look.ink),
          background: mark ? (Paint()..color = const Color(_marker)) : null,
          fontFamily: look.font,
          fontSize: lineSize * f,
          height: look.lh,
          fontWeight: (mark || look.bold) ? FontWeight.w800 : FontWeight.w400,
          fontStyle: look.italic ? FontStyle.italic : FontStyle.normal,
        );
    if (at >= 0) {
      small
        ..pushStyle(st(false))
        ..addText(sentence.substring(0, at))
        ..pushStyle(st(true))
        ..addText(sentence.substring(at, at + word.length))
        ..pushStyle(st(false))
        ..addText(sentence.substring(at + word.length));
    } else {
      small
        ..pushStyle(st(false))
        ..addText(sentence);
    }
    line = small.build()..layout(const ui.ParagraphConstraints(width: 100000));
  }
  var centre = line.longestLine / 2;
  if (at >= 0) {
    final boxes = line.getBoxesForRange(at, at + word.length);
    if (boxes.isNotEmpty) centre = (boxes.first.left + boxes.last.right) / 2;
  }
  // The word goes to the middle of the picture, but the sentence always stays inside it.
  final margin = w * 0.04;
  var dx = w / 2 - centre;
  dx = math.min(dx, w - margin - line.longestLine);
  dx = math.max(dx, margin);
  // A paper strip behind the line hides the page text under it.
  c.drawRect(Rect.fromLTWH(0, cy - lh * 0.5, w, lh), Paint()..color = paper);
  c.drawParagraph(line, Offset(dx, cy - line.height / 2));
  final page = rec.endRecording();

  // Blur: the farther from the middle line, the stronger.
  final out = ui.PictureRecorder();
  final o = Canvas(out);
  final u = h / 720;
  o.saveLayer(bounds, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 7 * u, sigmaY: 7 * u, tileMode: TileMode.clamp));
  o.drawPicture(page);
  o.restore();
  final lhn = lh / h;
  void level(double sigma, double inner, double outer) {
    final inn = inner.clamp(0.01, 0.46).toDouble();
    final outr = math.max(inn + 0.01, math.min(outer, 0.49)).toDouble();
    o.saveLayer(bounds, Paint());
    if (sigma > 0) {
      o.saveLayer(bounds, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma * u, sigmaY: sigma * u, tileMode: TileMode.clamp));
      o.drawPicture(page);
      o.restore();
    } else {
      o.drawPicture(page);
    }
    o.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          bounds.topCenter,
          bounds.bottomCenter,
          const [Color(0x00000000), Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000), Color(0x00000000)],
          [0, 0.5 - outr, 0.5 - inn, 0.5 + inn, 0.5 + outr, 1],
        ),
    );
    o.restore();
  }

  // The focus zone covers the sentence and a few lines around it; only farther away does the page go soft.
  level(4.2, lhn * 7.0, lhn * 10.0);
  level(2.2, lhn * 4.0, lhn * 6.0);
  level(1.0, lhn * 2.4, lhn * 3.6);
  level(0, lhn * 1.3, lhn * 2.1);
  final result = out.endRecording();
  final image = await result.toImage(w.round(), h.round());
  page.dispose();
  result.dispose();
  return image;
}

Future<String> _savePage(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw Exception('A page could not be drawn.');
  await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
  return path;
}

/// The pictures of a focus word: one page for every sentence, each shown for a short time, and at the end a page
/// with the word alone, big. [startMs] is where it begins in the slide. Returns the layers (full-slide pictures).
Future<List<Layer>> buildFocusWord(FocusChoice choice, int startMs, int availableMs) async {
  final step = choice.stepMs;
  // Leave about 1.4 seconds for the word alone at the end.
  var cuts = ((availableMs - 1400) / step).floor();
  if (cuts > 10) cuts = 10;
  if (cuts < 3) cuts = 3;
  final dir = '${await KainuwaEncoder.filesDir()}/kainuwa_data/focus';
  await Directory(dir).create(recursive: true);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final set = _lookSets[choice.look.clamp(0, _lookSets.length - 1).toInt()];
  final w = Stage.w;
  final h = Stage.h;
  final out = <Layer>[];
  for (var k = 0; k <= cuts; k++) {
    final last = k == cuts;
    final sentence = last ? choice.word : choice.lines[k % choice.lines.length];
    final look = last ? _looks[5] : _looks[set[(k * 3 + 1) % set.length]];
    final image = await _renderPage(look, sentence, choice.word, stamp % 1000 + k * 7, w, h, lineScale: last ? 2.6 : 1);
    final path = await _savePage(image, '$dir/focus_${stamp}_$k.png');
    final layer = Layer(id: 'foc_${newId()}', type: 'image', path: path, w: 1.0, h: 1.0);
    layer.srcAspect = w / h;
    layer.startMs = startMs + k * step;
    layer.endMs = last ? -1 : startMs + (k + 1) * step;
    out.add(layer);
  }
  return out;
}
