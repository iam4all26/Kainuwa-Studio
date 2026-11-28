import 'package:flutter/material.dart';

import '../models.dart';
import '../scene_canvas.dart';

/// What the person chose in the Focus word dialog.
class FocusChoice {
  FocusChoice({required this.word, required this.lines, required this.stepMs});

  final String word;

  /// Sentences. Each one has the word in it (or not, when the person wrote their own).
  final List<String> lines;
  final int stepMs;
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
    Navigator.of(context).pop(FocusChoice(word: word, lines: lines, stepMs: _step));
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
            const Text('Blurred newspapers and books drift behind. Sentences change quickly in the middle, '
                'and your word sits on a yellow marker in each one.',
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

Layer _sentence(String text, String word, int from, int to, {double size = 54, bool first = false}) {
  final layer = Layer(
    id: 'foc_${newId()}',
    type: 'text',
    text: text,
    color: 0xFF1E1B18,
    bold: false,
    fontFamily: 'serif',
    startMs: from,
    endMs: to,
    animIn: first ? 'fade' : 'none',
    animDurationMs: 150,
  );
  final at = word.isEmpty ? -1 : text.toLowerCase().indexOf(word.toLowerCase());
  if (at >= 0) {
    layer.colorSpans = [
      [at, at + word.length, _marker, 1, 0xFF000000],
    ];
  }
  layer.wrapW = 1000;
  setLayerTextSizePx(layer, size);
  if (layer.w > 0.92) {
    final f = 0.92 / layer.w;
    layer.w = 0.92;
    layer.h = layer.h * f;
  }
  return layer;
}

/// The layers of a focus word: the blurred pages, the changing sentences and, at the end, the word alone.
/// [startMs] is where it begins in the slide. Returns the layers in drawing order (pages first).
List<Layer> buildFocusWord(FocusChoice choice, int startMs, int availableMs) {
  final back = Layer(id: newId(), type: 'shape', shape: 'fx_docs', w: 1.0, h: 1.0);
  back.startMs = startMs;
  back.endMs = -1;
  final out = <Layer>[back];
  final step = choice.stepMs;
  // Leave about 1.4 seconds for the word alone at the end.
  var cuts = ((availableMs - 1400) / step).floor();
  if (cuts > 10) cuts = 10;
  if (cuts < 3) cuts = 3;
  for (var k = 0; k < cuts; k++) {
    final line = choice.lines[k % choice.lines.length];
    out.add(_sentence(line, choice.word, startMs + k * step, startMs + (k + 1) * step, first: k == 0));
  }
  final last = _sentence(choice.word, choice.word, startMs + cuts * step, -1, size: 120);
  last.animIn = 'pop';
  last.animDurationMs = 300;
  out.add(last);
  return out;
}

/// How long the slide must be (from its start) to fit the whole focus word.
int focusNeededMs(FocusChoice choice, int startMs) => startMs + 3 * choice.stepMs + 1400;
