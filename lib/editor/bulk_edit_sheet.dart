import 'package:flutter/material.dart';

import '../models.dart';
import '../scene_canvas.dart';
import '../theme.dart';
import '../widgets.dart';
import 'edit_panel.dart' show fontMenuItems, fontChoices;
import 'side_sheet.dart';

/// Opens the "edit many items" sheet. Returns how many items were changed, or null.
Future<int?> showBulkEdit(BuildContext context, Lesson lesson, int currentIndex) {
  return showEditorSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _BulkEditSheet(lesson: lesson, currentIndex: currentIndex),
    ),
  );
}

class _BulkEditSheet extends StatefulWidget {
  const _BulkEditSheet({required this.lesson, required this.currentIndex});

  final Lesson lesson;
  final int currentIndex;

  @override
  State<_BulkEditSheet> createState() => _BulkEditSheetState();
}

class _BulkEditSheetState extends State<_BulkEditSheet> {
  int _scope = 0; // 0 this slide, 1 all slides, 2 chosen slides
  late final Set<int> _slides = {widget.currentIndex};
  bool _text = true;
  bool _pics = false;
  bool _shapes = false;

  // changes; each one only applies when switched on
  bool _onColor = false;
  int _color = 0xFFFFFFFF;
  bool _onFont = false;
  String _font = '';
  bool _onScale = false;
  double _scale = 100;
  int _bold = 0; // 0 leave, 1 on, 2 off
  int _italic = 0;
  bool _onShapeColor = false;
  int _shapeColor = 0xFF7351FF;
  bool _onOpacity = false;
  double _opacity = 100;
  int _outline = 0;
  int _outlineColor = 0xFF000000;
  double _outlineWidth = 0.03;
  int _glow = 0;
  int _glowColor = 0xFFFFD54F;
  int _shadow = 0;

  Iterable<Scene> get _scenes sync* {
    final all = widget.lesson.scenes;
    if (_scope == 1) {
      yield* all;
    } else {
      final picked = _scope == 0 ? {widget.currentIndex} : _slides;
      for (var i = 0; i < all.length; i++) {
        if (picked.contains(i)) yield all[i];
      }
    }
  }

  bool _matches(Layer l) {
    if (l.type == 'text') return _text;
    if (l.type == 'shape') return _shapes;
    return _pics;
  }

  List<Layer> get _targets => [
        for (final s in _scenes)
          for (final l in s.layers)
            if (_matches(l)) l,
      ];

  void _apply() {
    var count = 0;
    for (final l in _targets) {
      final isText = l.type == 'text';
      if (isText) {
        final size = layerTextSizePx(l);
        if (_onColor) l.color = _color;
        if (_onFont) l.fontFamily = _font;
        if (_bold != 0) l.bold = _bold == 1;
        if (_italic != 0) l.italic = _italic == 1;
        setLayerTextSizePx(l, _onScale ? (size * _scale / 100).clamp(8.0, 600.0).toDouble() : size);
      } else if (l.type == 'shape' && _onShapeColor) {
        l.color = _shapeColor;
      }
      if (_onOpacity) l.opacity = (_opacity / 100).clamp(0.0, 1.0).toDouble();
      if (_outline != 0) {
        l.outlineOn = _outline == 1;
        if (_outline == 1) {
          l.outlineColor = _outlineColor;
          l.outlineWidth = _outlineWidth;
        }
      }
      if (_glow != 0) {
        l.glowOn = _glow == 1;
        if (_glow == 1) l.glowColor = _glowColor;
      }
      if (_shadow != 0) l.shadowOn = _shadow == 1;
      count++;
    }
    Navigator.of(context).pop(count);
  }

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 13, color: Color(0xFFB5ABD6), fontWeight: FontWeight.w500)),
      );

  Widget _swatch(int argb, ValueChanged<int> on, String title) {
    return InkWell(
      onTap: () async {
        final v = await pickColor(context, initial: argb, title: title);
        if (v != null) setState(() => on(v));
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color(argb),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3D3266)),
        ),
      ),
    );
  }

  Widget _row(String label, bool on, ValueChanged<bool> setOn, {Widget? control}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Switch(value: on, onChanged: (v) => setState(() => setOn(v))),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (control != null && on) control,
        ],
      ),
    );
  }

  Widget _tri(String label, int value, ValueChanged<int> on, {Widget? extra}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (extra != null && value == 1) ...[extra, const SizedBox(width: 8)],
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 0, label: Text('Leave')),
              ButtonSegment(value: 1, label: Text('On')),
              ButtonSegment(value: 2, label: Text('Off')),
            ],
            selected: {value},
            onSelectionChanged: (s) => setState(() => on(s.first)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool value, ValueChanged<bool> on) =>
      FilterChip(label: Text(label), selected: value, onSelected: (v) => setState(() => on(v)));

  @override
  Widget build(BuildContext context) {
    final count = _targets.length;
    final slides = widget.lesson.scenes.length;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                const Text('Edit many items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                _head('Which slides'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in const [(0, 'This slide'), (1, 'All slides'), (2, 'Choose slides')])
                      ChoiceChip(
                        label: Text(e.$2),
                        selected: _scope == e.$1,
                        onSelected: (_) => setState(() => _scope = e.$1),
                      ),
                  ],
                ),
                if (_scope == 2) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < slides; i++)
                        FilterChip(
                          label: Text('${i + 1}'),
                          selected: _slides.contains(i),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _slides.add(i);
                            } else {
                              _slides.remove(i);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                _head('Which items'),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('Text', _text, (v) => _text = v),
                    _chip('Icons and images', _pics, (v) => _pics = v),
                    _chip('Shapes', _shapes, (v) => _shapes = v),
                  ],
                ),
                _head('What to change (only switched-on rows are applied)'),
                if (_text) ...[
                  _row('Text colour', _onColor, (v) => _onColor = v,
                      control: _swatch(_color, (v) => _color = v, 'Text colour')),
                  _row('Font', _onFont, (v) => _onFont = v),
                  if (_onFont)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration:
                          BoxDecoration(color: const Color(0xFF2A2150), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: fontChoices().any((f) => f.$1 == _font) ? _font : '',
                          items: fontMenuItems(),
                          onChanged: (v) => setState(() => _font = v ?? ''),
                        ),
                      ),
                    ),
                  _row('Text size', _onScale, (v) => _onScale = v),
                  if (_onScale)
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _scale,
                            min: 40,
                            max: 250,
                            onChanged: (v) => setState(() => _scale = v),
                          ),
                        ),
                        SizedBox(width: 54, child: Text('${_scale.round()}%')),
                      ],
                    ),
                  _tri('Bold', _bold, (v) => _bold = v),
                  _tri('Italic', _italic, (v) => _italic = v),
                ],
                if (_shapes)
                  _row('Shape colour', _onShapeColor, (v) => _onShapeColor = v,
                      control: _swatch(_shapeColor, (v) => _shapeColor = v, 'Shape colour')),
                _row('Opacity', _onOpacity, (v) => _onOpacity = v),
                if (_onOpacity)
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _opacity,
                          min: 5,
                          max: 100,
                          onChanged: (v) => setState(() => _opacity = v),
                        ),
                      ),
                      SizedBox(width: 54, child: Text('${_opacity.round()}%')),
                    ],
                  ),
                _tri('Outline', _outline, (v) => _outline = v,
                    extra: _swatch(_outlineColor, (v) => _outlineColor = v, 'Outline colour')),
                if (_outline == 1)
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      const Text('Width', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _outlineWidth,
                          min: 0.005,
                          max: 0.12,
                          onChanged: (v) => setState(() => _outlineWidth = v),
                        ),
                      ),
                    ],
                  ),
                _tri('Glow', _glow, (v) => _glow = v,
                    extra: _swatch(_glowColor, (v) => _glowColor = v, 'Glow colour')),
                _tri('Shadow', _shadow, (v) => _shadow = v),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: count == 0 ? null : _apply,
              child: Text(count == 0 ? 'No matching items' : 'Apply to $count items'),
            ),
          ),
        ],
      ),
    );
  }
}
