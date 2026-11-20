import 'package:flutter/material.dart';

import '../theme.dart';
import '../video_grade.dart';

/// Sliders for the colour grading of a video clip. Calls [onChanged] while you drag.
class GradeEditor extends StatefulWidget {
  const GradeEditor({super.key, required this.initial, required this.onChanged});

  final VideoGrade initial;
  final ValueChanged<VideoGrade> onChanged;

  @override
  State<GradeEditor> createState() => _GradeEditorState();
}

class _GradeEditorState extends State<GradeEditor> {
  late VideoGrade _g = widget.initial;

  void _set(VideoGrade g) {
    setState(() => _g = g);
    widget.onChanged(g);
  }

  /// [shown] is the number printed at the right (value scaled to about -100..100).
  Widget _slider(String label, double value, double min, double max, double shownScale, VideoGrade Function(double) make) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 12, color: KColors.ink))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: (v) => _set(make(v)),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text('${(value * shownScale).round()}', style: const TextStyle(fontSize: 12, color: KColors.ink)),
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
        _slider('Exposure', _g.exposure, -1, 1, 100, (v) => _g.copyWith(exposure: v)),
        _slider('Temperature', _g.temperature, -1, 1, 100, (v) => _g.copyWith(temperature: v)),
        _slider('Tint', _g.tint, -1, 1, 100, (v) => _g.copyWith(tint: v)),
        _slider('Hue', _g.hue, -180, 180, 1, (v) => _g.copyWith(hue: v)),
        _slider('Red', _g.red, -0.5, 0.5, 200, (v) => _g.copyWith(red: v)),
        _slider('Green', _g.green, -0.5, 0.5, 200, (v) => _g.copyWith(green: v)),
        _slider('Blue', _g.blue, -0.5, 0.5, 200, (v) => _g.copyWith(blue: v)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _g.isNone ? null : () => _set(const VideoGrade()),
            child: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}
