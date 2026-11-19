import 'package:flutter/material.dart';

import '../pic_filter.dart';
import '../theme.dart';

/// Preset chips and four sliders. Calls [onChanged] with the new look as you drag.
class FilterEditor extends StatefulWidget {
  const FilterEditor({super.key, required this.initial, required this.onChanged});

  final PicFilter initial;
  final ValueChanged<PicFilter> onChanged;

  @override
  State<FilterEditor> createState() => _FilterEditorState();
}

class _FilterEditorState extends State<FilterEditor> {
  late PicFilter _f = widget.initial;

  void _set(PicFilter f) {
    setState(() => _f = f);
    widget.onChanged(f);
  }

  Widget _slider(String label, double value, double min, double max, PicFilter Function(double) make) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: const TextStyle(fontSize: 12, color: KColors.ink))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: (v) => _set(make(v)),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text('${(value * 100).round()}', style: const TextStyle(fontSize: 12, color: KColors.ink)),
        ),
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
          runSpacing: 4,
          children: [
            for (final p in PicFilter.presets)
              ChoiceChip(
                label: Text(p.$2),
                selected: _f.preset == p.$1,
                onSelected: (_) => _set(_f.copyWith(preset: p.$1)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _slider('Brightness', _f.brightness, -0.5, 0.5, (v) => _f.copyWith(brightness: v)),
        _slider('Contrast', _f.contrast, -0.5, 0.8, (v) => _f.copyWith(contrast: v)),
        _slider('Saturation', _f.saturation, -1, 1, (v) => _f.copyWith(saturation: v)),
        _slider('Blur', _f.blur, 0, 0.05, (v) => _f.copyWith(blur: v)),
        _slider('Darken', _f.dim, 0, 0.9, (v) => _f.copyWith(dim: v)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _f.isNone ? null : () => _set(const PicFilter()),
            child: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}
