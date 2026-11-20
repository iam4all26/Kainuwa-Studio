import 'package:flutter/material.dart';

import '../theme.dart';
import '../video_curves.dart';

/// Remove colours (they turn grey) or keep only some colours (everything else turns grey).
/// Pick up to three colours from the picture; range and softness are shared.
class ColourKeyEditor extends StatefulWidget {
  const ColourKeyEditor({super.key, required this.initial, required this.onChanged, required this.onPick});

  final VideoCurves initial;
  final ValueChanged<VideoCurves> onChanged;

  /// Opens the colour picker. Returns the colour the user added, or null.
  final Future<Color?> Function() onPick;

  @override
  State<ColourKeyEditor> createState() => _ColourKeyEditorState();
}

class _ColourKeyEditorState extends State<ColourKeyEditor> {
  late VideoCurves _c = widget.initial;

  void _push(VideoCurves c) {
    setState(() => _c = c);
    widget.onChanged(c);
  }

  Future<void> _pick() async {
    final colour = await widget.onPick();
    if (colour == null || !mounted) return;
    final hue = HSVColor.fromColor(colour).hue;
    final hues = List<double>.of(_c.keyHues);
    if (hues.length >= 3) return;
    hues.add(double.parse(hue.toStringAsFixed(1)));
    _push(_c.withKey(hues: hues));
  }

  Widget _slider(String label, double value, double min, double max, String shown, VideoCurves Function(double) make) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: const TextStyle(fontSize: 12, color: KColors.ink))),
        Expanded(child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, onChanged: (v) => _push(make(v)))),
        SizedBox(width: 38, child: Text(shown, style: const TextStyle(fontSize: 12, color: KColors.ink))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hues = _c.keyHues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Remove colours')),
              ButtonSegment<int>(value: 1, label: Text('Keep only')),
            ],
            selected: {_c.keyMode},
            onSelectionChanged: (s) => _push(_c.withKey(mode: s.first)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < hues.length; i++)
              InputChip(
                avatar: CircleAvatar(backgroundColor: HSVColor.fromAHSV(1, hues[i], 0.85, 0.9).toColor()),
                label: Text('Colour ${i + 1}'),
                onDeleted: () {
                  final next = List<double>.of(hues)..removeAt(i);
                  _push(_c.withKey(hues: next));
                },
              ),
            if (hues.length < 3)
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.colorize, size: 18),
                label: const Text('Pick colour'),
              ),
          ],
        ),
        _slider('Range', _c.keyRange, 5, 90, '${_c.keyRange.round()}', (v) => _c.withKey(range: v)),
        _slider('Softness', _c.keySoft, 0, 1, '${(_c.keySoft * 100).round()}', (v) => _c.withKey(soft: v)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: hues.isEmpty ? null : () => _push(_c.withKey(hues: const <double>[])),
            child: const Text('Clear colours'),
          ),
        ),
      ],
    );
  }
}
