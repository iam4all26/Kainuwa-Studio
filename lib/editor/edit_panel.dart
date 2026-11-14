import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animation_math.dart';
import '../models.dart';
import '../scene_canvas.dart';
import '../store/store_service.dart';
import 'hand_picker.dart';
import '../text_reveal.dart';
import '../theme.dart';
import '../widgets.dart';

/// Fonts that every Android phone has. The first entry is the default font.
const List<(String, String)> kFontFamilies = [
  ('', 'Default'),
  ('sans-serif-black', 'Sans Black'),
  ('sans-serif-medium', 'Sans Medium'),
  ('sans-serif-condensed', 'Sans Condensed'),
  ('serif', 'Serif'),
  ('monospace', 'Monospace'),
  ('cursive', 'Cursive'),
  ('casual', 'Casual'),
];

/// Built-in fonts plus the fonts downloaded from the store.
List<(String, String)> fontChoices() => [
      ...kFontFamilies,
      for (final f in StoreService.instance.ofType('font')) (f.family, f.name),
    ];

/// The edit panel for the selected item. Changes are applied straight away and
/// [onLive] is called after each one so the slide behind the panel updates.
/// [initialTab] is one of: content, style, transform, arrange, animation.
Future<void> showEditPanel(
  BuildContext context, {
  required Layer layer,
  required Scene scene,
  required String initialTab,
  required VoidCallback onLive,
  required ValueChanged<Layer?> onDemo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x22000000),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: FractionallySizedBox(
        // The Animate tab is shorter so the slide stays visible above it.
        heightFactor: initialTab == 'animation' ? 0.5 : 0.62,
        child: _EditPanel(
          layer: layer,
          scene: scene,
          initialTab: initialTab,
          onLive: onLive,
          onDemo: onDemo,
        ),
      ),
    ),
  );
}

class _EditPanel extends StatefulWidget {
  const _EditPanel({
    required this.layer,
    required this.scene,
    required this.initialTab,
    required this.onLive,
    required this.onDemo,
  });

  final Layer layer;
  final Scene scene;
  final String initialTab;
  final VoidCallback onLive;

  /// Asks the editor to play this item's animations on the canvas (null to stop).
  final ValueChanged<Layer?> onDemo;

  @override
  State<_EditPanel> createState() => _EditPanelState();
}

class _EditPanelState extends State<_EditPanel> {
  late String _tab;
  late final TextEditingController _text = TextEditingController(text: widget.layer.text);
  late final double _baseW = widget.layer.w;
  late final double _baseH = widget.layer.h;

  Layer get l => widget.layer;
  bool get _isText => l.type == 'text';

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    if (!_tabs.any((t) => t.$1 == _tab)) _tab = _tabs.first.$1;
    if (_tab == 'animation') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDemo(l);
      });
    }
    if ((l.type == 'image' || l.type == 'asset') && l.srcAspect <= 0) {
      _loadAspect().then((a) {
        l.srcAspect = a;
        if (mounted) _changed();
      });
    }
  }

  /// Width divided by height of the picture, read once and remembered in the item.
  Future<double> _loadAspect() {
    final ImageProvider<Object> provider = l.type == 'asset'    ? AssetImage(l.path) as ImageProvider<Object>    : FileImage(File(l.path)) as ImageProvider<Object>;
    final completer = Completer<double>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image.width / info.image.height);
        stream.removeListener(listener);
      },
      onError: (error, trace) {
        if (!completer.isCompleted) completer.complete(1.0);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(const Duration(seconds: 6), onTimeout: () => 1.0);
  }

  /// Makes the item box fit the visible part of the picture, so the frame hugs it.
  void _hugCrop() {
    final a = l.srcAspect;
    if (a <= 0) return;
    final vw = 1 - l.cropL - l.cropR;
    final vh = 1 - l.cropT - l.cropB;
    final aspect = a * vw / vh;
    var w = l.w;
    var h = w * (16 / 9) / aspect;
    if (h > 0.95) {
      h = 0.95;
      w = h * aspect * (9 / 16);
    }
    l.w = w.clamp(0.03, 1.6).toDouble();
    l.h = h.clamp(0.03, 1.6).toDouble();
  }

  void _setCrop({double? left, double? right, double? top, double? bottom}) {
    var cl = (left ?? l.cropL).clamp(0.0, 0.8).toDouble();
    var cr = (right ?? l.cropR).clamp(0.0, 0.8).toDouble();
    var ct = (top ?? l.cropT).clamp(0.0, 0.8).toDouble();
    var cb = (bottom ?? l.cropB).clamp(0.0, 0.8).toDouble();
    if (cl + cr > 0.9) {
      if (left != null) {
        cl = 0.9 - cr;
      } else {
        cr = 0.9 - cl;
      }
    }
    if (ct + cb > 0.9) {
      if (top != null) {
        ct = 0.9 - cb;
      } else {
        cb = 0.9 - ct;
      }
    }
    l.cropL = cl;
    l.cropR = cr;
    l.cropT = ct;
    l.cropB = cb;
    _hugCrop();
    _changed();
  }

  /// Crops the middle of the picture to the given shape (width divided by height).
  void _cropPreset(double? target) {
    if (target == null) {
      l.cropL = 0;
      l.cropR = 0;
      l.cropT = 0;
      l.cropB = 0;
    } else {
      final a = l.srcAspect > 0 ? l.srcAspect : 1.0;
      if (target < a) {
        final vw = target / a;
        l.cropL = (1 - vw) / 2;
        l.cropR = (1 - vw) / 2;
        l.cropT = 0;
        l.cropB = 0;
      } else {
        final vh = a / target;
        l.cropT = (1 - vh) / 2;
        l.cropB = (1 - vh) / 2;
        l.cropL = 0;
        l.cropR = 0;
      }
    }
    _hugCrop();
    _changed();
  }

  Widget _cutField(String label, double value, void Function(double) apply) {
    return _labeled(
      label,
      _NumField(
        value: value * 100,
        min: 0,
        max: 80,
        step: 5,
        suffix: '%',
        width: 52,
        onChanged: (v) => apply(v / 100),
      ),
    );
  }

  Widget _cropMaskCard() {
    const presets = <(String, double?)>[
      ('Original', null),
      ('Square', 1.0),
      ('4:3', 4 / 3),
      ('16:9', 16 / 9),
      ('3:4', 3 / 4),
    ];
    const masks = <(String, String)>[
      ('none', 'None'),
      ('circle', 'Circle'),
      ('round', 'Rounded'),
      ('diamond', 'Diamond'),
      ('star', 'Star'),
      ('heart', 'Heart'),
    ];
    return _card(
      'Crop & Mask',
      Icons.crop,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Crop to a shape', style: TextStyle(fontSize: 12, color: KColors.ink)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in presets)
                ActionChip(label: Text(p.$1), onPressed: () => _cropPreset(p.$2)),
            ],
          ),
          const SizedBox(height: 8),
          _cutField('Cut from the left', l.cropL, (v) => _setCrop(left: v)),
          _cutField('Cut from the right', l.cropR, (v) => _setCrop(right: v)),
          _cutField('Cut from the top', l.cropT, (v) => _setCrop(top: v)),
          _cutField('Cut from the bottom', l.cropB, (v) => _setCrop(bottom: v)),
          const SizedBox(height: 8),
          const Text('Mask', style: TextStyle(fontSize: 12, color: KColors.ink)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final m in masks)
                ChoiceChip(
                  label: Text(m.$2),
                  selected: l.mask == m.$1,
                  onSelected: (_) {
                    l.mask = m.$1;
                    _changed();
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Circle, Star and Heart look best on a Square crop.',
            style: TextStyle(fontSize: 11),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                l.mask = 'none';
                _cropPreset(null);
              },
              child: const Text('Reset crop and mask'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDemo(null));
    _text.dispose();
    super.dispose();
  }

  List<(String, String, IconData)> get _tabs => [
        if (_isText) ('content', 'Content', Icons.edit_outlined),
        ('style', 'Style', Icons.palette_outlined),
        ('transform', 'Transform', Icons.open_with),
        ('arrange', 'Arrange', Icons.layers_outlined),
        ('animation', 'Animation', Icons.auto_awesome_outlined),
      ];

  void _changed() {
    setState(() {});
    widget.onLive();
    if (_tab == 'animation') widget.onDemo(l);
  }

  /// Applies a text style change and keeps the text the same size.
  void _restyle(VoidCallback change) {
    if (_isText) {
      final size = layerTextSizePx(l);
      change();
      setLayerTextSizePx(l, size);
    } else {
      change();
    }
    _changed();
  }

  String get _title {
    switch (l.type) {
      case 'text':
        return 'Edit Text';
      case 'asset':
        return 'Edit Icon';
      case 'image':
        return 'Edit Image';
      default:
        return 'Edit Shape';
    }
  }

  IconData get _titleIcon {
    switch (l.type) {
      case 'text':
        return Icons.title;
      case 'asset':
        return Icons.emoji_objects_outlined;
      case 'image':
        return Icons.image_outlined;
      default:
        return Icons.crop_square;
    }
  }

  // ---- building blocks ----

  Widget _card(String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1333),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3D3266)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: KColors.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget field) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: KColors.ink))),
        field,
      ],
    );
  }

  Widget _toggle(Widget child, bool on, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: on ? KColors.purple : const Color(0xFF2A2150),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(height: 38, child: Center(child: child)),
          ),
        ),
      ),
    );
  }

  Widget _chips(List<String> kinds, String selected, ValueChanged<String> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final kind in kinds)
          ChoiceChip(
            label: Text(animLabel(kind)),
            selected: selected == kind,
            onSelected: (_) => onPick(kind),
          ),
      ],
    );
  }

  Widget _colorEditor(int argb, ValueChanged<int> onColor) {
    final color = Color(argb);
    int ch(int shift) => (argb >> shift) & 0xFF;
    void setRgb({int? r, int? g, int? b}) {
      final a = (argb >> 24) & 0xFF;
      onColor((a << 24) | ((r ?? ch(16)) << 16) | ((g ?? ch(8)) << 8) | (b ?? ch(0)));
    }

    return Row(
      children: [
        InkWell(
          onTap: () async {
            final value = await pickColor(context, initial: argb, title: _isText ? 'Text Color' : 'Color');
            if (value != null) onColor(value);
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3D3266)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _HexField(argb: argb, onColor: onColor),
        const SizedBox(width: 6),
        Expanded(child: _NumField(label: 'R', value: ch(16).toDouble(), min: 0, max: 255, width: 34, onChanged: (v) => setRgb(r: v.round()))),
        Expanded(child: _NumField(label: 'G', value: ch(8).toDouble(), min: 0, max: 255, width: 34, onChanged: (v) => setRgb(g: v.round()))),
        Expanded(child: _NumField(label: 'B', value: ch(0).toDouble(), min: 0, max: 255, width: 34, onChanged: (v) => setRgb(b: v.round()))),
      ],
    );
  }

  // ---- tabs ----

  Widget _contentTab() {
    return Column(
      children: [
        _card(
          'Text Content',
          Icons.title,
          TextField(
            controller: _text,
            minLines: 1,
            maxLines: 4,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF2A2150),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) {
              final size = layerTextSizePx(l);
              l.text = v;
              setLayerTextSizePx(l, size);
              _changed();
            },
          ),
        ),
        _card(
          'Text Size',
          Icons.format_size,
          _labeled(
            'Size in pixels',
            _NumField(
              value: layerTextSizePx(l),
              min: 8,
              max: 400,
              step: 2,
              suffix: 'px',
              width: 60,
              onChanged: (v) {
                setLayerTextSizePx(l, v);
                _changed();
              },
            ),
          ),
        ),
        _card(
          'Font Family',
          Icons.text_fields,
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFF2A2150), borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<String>(
                isExpanded: true,
                value: fontChoices().any((f) => f.$1 == l.fontFamily) ? l.fontFamily : '',
                items: [
                  for (final f in fontChoices())
                    DropdownMenuItem<String>(
                      value: f.$1,
                      child: Text(f.$2, style: TextStyle(fontFamily: f.$1.isEmpty ? null : f.$1)),
                    ),
                ],
                onChanged: (v) => _restyle(() => l.fontFamily = v ?? ''),
              ),
            ),
          ),
        ),
        _card(
          'Font Style',
          Icons.format_bold,
          Row(
            children: [
              _toggle(const Text('B', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)).withColor(l.bold), l.bold, () => _restyle(() => l.bold = !l.bold)),
              _toggle(const Text('I', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 17)).withColor(l.italic), l.italic, () => _restyle(() => l.italic = !l.italic)),
              _toggle(const Text('U', style: TextStyle(decoration: TextDecoration.underline, fontSize: 17)).withColor(l.underline), l.underline, () => _restyle(() => l.underline = !l.underline)),
              _toggle(const Text('S', style: TextStyle(decoration: TextDecoration.lineThrough, fontSize: 17)).withColor(l.strike), l.strike, () => _restyle(() => l.strike = !l.strike)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _styleTab() {
    final colorable = _isText || l.type == 'shape' || (l.type == 'image' && l.shape == 'tint');
    return Column(
      children: [
        if (l.type == 'image' || l.type == 'asset') _cropMaskCard(),
        if (l.type == 'image')
          _card(
            'Single color',
            Icons.invert_colors_outlined,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labeled(
                  'Paint the whole picture in one color',
                  Switch(
                    value: l.shape == 'tint',
                    onChanged: (v) {
                      l.shape = v ? 'tint' : 'rect';
                      if (v && l.color == 0xFFFFFFFF) l.color = 0xFFF6C101;
                      _changed();
                    },
                  ),
                ),
                const Text(
                  'Best for icons and drawings. Photos lose their colors.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        if (colorable)
          _card(
            _isText ? 'Text Color' : 'Color',
            Icons.water_drop_outlined,
            _colorEditor(l.color, (v) {
              l.color = v;
              _changed();
            }),
          ),
        if (_isText)
          _card(
            'Background (Box)',
            Icons.crop_din,
            Column(
              children: [
                _labeled(
                  'Show a box behind the text',
                  Switch(value: l.bgBox, onChanged: (v) => _restyle(() => l.bgBox = v)),
                ),
                if (l.bgBox)
                  _colorEditor(l.bgColor, (v) {
                    final a = (l.bgColor >> 24) & 0xFF;
                    l.bgColor = (a << 24) | (v & 0xFFFFFF);
                    _changed();
                  }),
                if (l.bgBox)
                  _labeled(
                    'Box opacity',
                    _NumField(
                      value: ((l.bgColor >> 24) & 0xFF) * 100 / 255,
                      min: 0,
                      max: 100,
                      step: 5,
                      suffix: '%',
                      width: 52,
                      onChanged: (v) {
                        l.bgColor = ((v * 255 / 100).round() << 24) | (l.bgColor & 0xFFFFFF);
                        _changed();
                      },
                    ),
                  ),
              ],
            ),
          ),
        _card(
          'Opacity',
          Icons.opacity,
          _labeled(
            'How solid the item is',
            _NumField(
              value: l.opacity * 100,
              min: 0,
              max: 100,
              step: 5,
              suffix: '%',
              width: 52,
              onChanged: (v) {
                l.opacity = v / 100;
                _changed();
              },
            ),
          ),
        ),
        if (_isText) ...[
          _card(
            'Letter Spacing',
            Icons.space_bar,
            _labeled(
              'Space between letters',
              _NumField(
                value: l.letterSpacing,
                min: -10,
                max: 60,
                step: 1,
                suffix: 'px',
                width: 52,
                onChanged: (v) => _restyle(() => l.letterSpacing = v),
              ),
            ),
          ),
          _card(
            'Line Height',
            Icons.format_line_spacing,
            _labeled(
              'Space between lines',
              _NumField(
                value: l.lineHeight,
                min: 0.6,
                max: 3,
                step: 0.1,
                decimals: 1,
                width: 52,
                onChanged: (v) => _restyle(() => l.lineHeight = v),
              ),
            ),
          ),
          _card(
            'Alignment',
            Icons.format_align_center,
            Row(
              children: [
                _toggle(Icon(Icons.format_align_left, color: l.align == 'left' ? Colors.white : KColors.ink), l.align == 'left', () => _restyle(() => l.align = 'left')),
                _toggle(Icon(Icons.format_align_center, color: l.align == 'center' ? Colors.white : KColors.ink), l.align == 'center', () => _restyle(() => l.align = 'center')),
                _toggle(Icon(Icons.format_align_right, color: l.align == 'right' ? Colors.white : KColors.ink), l.align == 'right', () => _restyle(() => l.align = 'right')),
                _toggle(Icon(Icons.format_align_justify, color: l.align == 'justify' ? Colors.white : KColors.ink), l.align == 'justify', () => _restyle(() => l.align = 'justify')),
              ],
            ),
          ),
        ],
      ],
    );
  }

  double get _degrees {
    var d = l.rotation * 180 / math.pi;
    d = d % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  Widget _transformTab() {
    return Column(
      children: [
        _card(
          'Position (X, Y)',
          Icons.open_with,
          Row(
            children: [
              Expanded(
                child: _NumField(
                  label: 'X',
                  value: l.cx * 1280,
                  min: -400,
                  max: 1680,
                  step: 10,
                  suffix: 'px',
                  width: 60,
                  onChanged: (v) {
                    l.cx = v / 1280;
                    _changed();
                  },
                ),
              ),
              Expanded(
                child: _NumField(
                  label: 'Y',
                  value: l.cy * 720,
                  min: -300,
                  max: 1020,
                  step: 10,
                  suffix: 'px',
                  width: 60,
                  onChanged: (v) {
                    l.cy = v / 720;
                    _changed();
                  },
                ),
              ),
            ],
          ),
        ),
        _card(
          'Rotation',
          Icons.rotate_right,
          _labeled(
            'Turn the item',
            _NumField(
              value: _degrees,
              min: -180,
              max: 180,
              step: 5,
              suffix: 'deg',
              width: 56,
              onChanged: (v) {
                l.rotation = v * math.pi / 180;
                _changed();
              },
            ),
          ),
        ),
        _card(
          'Scale (W, H)',
          Icons.open_in_full,
          Row(
            children: [
              Expanded(
                child: _NumField(
                  label: 'W',
                  value: _baseW <= 0 ? 100 : l.w / _baseW * 100,
                  min: 5,
                  max: 800,
                  step: 5,
                  suffix: '%',
                  width: 56,
                  onChanged: (v) {
                    l.w = (_baseW * v / 100).clamp(0.02, 1.6).toDouble();
                    _changed();
                  },
                ),
              ),
              Expanded(
                child: _NumField(
                  label: 'H',
                  value: _baseH <= 0 ? 100 : l.h / _baseH * 100,
                  min: 5,
                  max: 800,
                  step: 5,
                  suffix: '%',
                  width: 56,
                  onChanged: (v) {
                    l.h = (_baseH * v / 100).clamp(0.02, 1.6).toDouble();
                    _changed();
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
            onPressed: () {
              l.cx = 0.5;
              l.cy = 0.5;
              l.rotation = 0;
              l.w = _baseW;
              l.h = _baseH;
              l.opacity = 1;
              _changed();
            },
          ),
        ),
      ],
    );
  }

  void _order(String how) {
    final list = widget.scene.layers;
    final i = list.indexOf(l);
    if (i < 0) return;
    list.removeAt(i);
    switch (how) {
      case 'front':
        list.add(l);
        break;
      case 'forward':
        list.insert(math.min(i + 1, list.length), l);
        break;
      case 'backward':
        list.insert(math.max(i - 1, 0), l);
        break;
      default:
        list.insert(0, l);
    }
    _changed();
  }

  Widget _orderButton(IconData icon, String label, String how) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2)),
          onPressed: () => _order(how),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 11))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrangeTab() {
    final list = widget.scene.layers;
    final position = list.length - list.indexOf(l);
    return _card(
      'Order (Layer)',
      Icons.layers_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This item is number $position from the front of ${list.length}.', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              _orderButton(Icons.keyboard_double_arrow_up, 'Bring to Front', 'front'),
              _orderButton(Icons.arrow_upward, 'Bring Forward', 'forward'),
              _orderButton(Icons.arrow_downward, 'Send Backward', 'backward'),
              _orderButton(Icons.keyboard_double_arrow_down, 'Send to Back', 'back'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _animationTab() {
    final sceneMs = widget.scene.durationMs;
    final end = layerEndMs(l, sceneMs);
    return Column(
      children: [
        _card(
          'On screen',
          Icons.timer_outlined,
          Column(
            children: [
              _labeled(
                'Appears at',
                _NumField(
                  value: l.startMs / 1000,
                  min: 0,
                  max: math.max(0, (end - 200) / 1000),
                  step: 0.1,
                  decimals: 1,
                  suffix: 's',
                  width: 56,
                  onChanged: (v) {
                    l.startMs = (v * 1000).round();
                    _changed();
                  },
                ),
              ),
              _labeled(
                'Stays until the slide ends',
                Switch(
                  value: l.endMs < 0,
                  onChanged: (v) {
                    l.endMs = v ? -1 : sceneMs;
                    _changed();
                  },
                ),
              ),
              if (l.endMs >= 0)
                _labeled(
                  'Leaves at',
                  _NumField(
                    value: end / 1000,
                    min: (l.startMs + 200) / 1000,
                    max: sceneMs / 1000,
                    step: 0.1,
                    decimals: 1,
                    suffix: 's',
                    width: 56,
                    onChanged: (v) {
                      final ms = (v * 1000).round();
                      l.endMs = ms >= sceneMs ? -1 : ms;
                      _changed();
                    },
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'The slide is ${(sceneMs / 1000).toStringAsFixed(1)} s long. You can also drag the ends of the item on the timeline.',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        _card(
          'In animation',
          Icons.login,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chips(kAnimKinds, l.animIn, (k) {
                l.animIn = k;
                _changed();
              }),
              if (l.animIn != 'none' && l.animIn != 'appear') ...[
                const SizedBox(height: 8),
                _labeled(
                  'Length',
                  _NumField(
                    value: l.animDurationMs / 1000,
                    min: 0.2,
                    max: 5,
                    step: 0.1,
                    decimals: 1,
                    suffix: 's',
                    width: 56,
                    onChanged: (v) {
                      l.animDurationMs = (v * 1000).round();
                      _changed();
                    },
                  ),
                ),
              ],
              if (l.animIn != 'none')
                _labeled(
                  'Delay after it appears',
                  _NumField(
                    value: l.animStartMs / 1000,
                    min: 0,
                    max: 30,
                    step: 0.1,
                    decimals: 1,
                    suffix: 's',
                    width: 56,
                    onChanged: (v) {
                      l.animStartMs = (v * 1000).round();
                      _changed();
                    },
                  ),
                ),
            ],
          ),
        ),
        _card(
          'Hand reveal',
          Icons.pan_tool_outlined,
          HandPicker(layer: l, onChanged: _changed),
        ),
        if (_isText)
          _card(
            'Text animation',
            Icons.text_fields,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final kind in kTextAnimKinds)
                      ChoiceChip(
                        label: Text(textAnimLabel(kind)),
                        selected: l.textAnim == kind,
                        onSelected: (_) {
                          l.textAnim = kind;
                          _changed();
                        },
                      ),
                  ],
                ),
                if (l.textAnim != 'none') ...[
                  const SizedBox(height: 8),
                  _labeled(
                    'Time per ${textUnitName(l.textAnim)}',
                    _NumField(
                      value: textUnitMs(l) / 1000,
                      min: 0.02,
                      max: 3,
                      step: 0.05,
                      decimals: 2,
                      suffix: 's',
                      width: 64,
                      onChanged: (v) {
                        l.textAnimMs = (v * 1000).round();
                        _changed();
                      },
                    ),
                  ),
                  if (l.animIn == 'none')
                    _labeled(
                      'Delay after it appears',
                      _NumField(
                        value: l.animStartMs / 1000,
                        min: 0,
                        max: 30,
                        step: 0.1,
                        decimals: 1,
                        suffix: 's',
                        width: 56,
                        onChanged: (v) {
                          l.animStartMs = (v * 1000).round();
                          _changed();
                        },
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'The whole text takes ${(textRevealTotalMs(l) / 1000).toStringAsFixed(1)} s to appear.',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        _card(
          'Overall animation',
          Icons.autorenew,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final kind in kLoopKinds)
                    ChoiceChip(
                      label: Text(loopLabel(kind)),
                      selected: l.animLoop == kind,
                      onSelected: (_) {
                        l.animLoop = kind;
                        _changed();
                      },
                    ),
                ],
              ),
              if (l.animLoop != 'none') ...[
                const SizedBox(height: 8),
                _labeled(
                  'Time for one round',
                  _NumField(
                    value: loopPeriodMs(l) / 1000,
                    min: 0.2,
                    max: 20,
                    step: 0.1,
                    decimals: 1,
                    suffix: 's',
                    width: 60,
                    onChanged: (v) {
                      l.animLoopMs = (v * 1000).round();
                      _changed();
                    },
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Keeps going the whole time the item is on screen.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
        _card(
          'Out animation',
          Icons.logout,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chips(kExitKinds, l.animOut, (k) {
                l.animOut = k;
                _changed();
              }),
              if (l.animOut != 'none') ...[
                const SizedBox(height: 8),
                _labeled(
                  'Length',
                  _NumField(
                    value: l.animOutDurationMs / 1000,
                    min: 0.2,
                    max: 5,
                    step: 0.1,
                    decimals: 1,
                    suffix: 's',
                    width: 56,
                    onChanged: (v) {
                      l.animOutDurationMs = (v * 1000).round();
                      _changed();
                    },
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Close this panel and press play to see the animations.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    switch (_tab) {
      case 'content':
        return _contentTab();
      case 'transform':
        return _transformTab();
      case 'arrange':
        return _arrangeTab();
      case 'animation':
        return _animationTab();
      default:
        return _styleTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF211A3F), Color(0xFF251C47)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: const Color(0xFF5A4C8E), borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [KColors.purple, Color(0xFF8B3DF0)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_titleIcon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KColors.ink)),
                        Text(
                          _isText
                              ? 'Customize the selected text on the slide'
                              : 'Customize the selected item on the slide',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB5ABD6)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1333),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final t in tabs)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _tab = t.$1);
                            widget.onDemo(t.$1 == 'animation' ? l : null);
                          },
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: _tab == t.$1 ? KColors.purple : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(t.$3, size: 17, color: _tab == t.$1 ? Colors.white : KColors.deepPurple),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.$2,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _tab == t.$1 ? Colors.white : KColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _StyledText on Text {
  /// The letter of a style button: white on a purple button, dark otherwise.
  Widget withColor(bool on) => DefaultTextStyle.merge(
        style: TextStyle(color: on ? Colors.white : KColors.ink),
        child: this,
      );
}

/// A number box with optional minus and plus buttons.
class _NumField extends StatefulWidget {
  const _NumField({
    required this.value,
    required this.onChanged,
    this.label,
    this.min = -100000,
    this.max = 100000,
    this.step,
    this.decimals = 0,
    this.suffix = '',
    this.width = 64,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String? label;
  final double min;
  final double max;
  final double? step;
  final int decimals;
  final String suffix;
  final double width;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _c = TextEditingController(text: _fmt(widget.value));
  final FocusNode _focus = FocusNode();

  String _fmt(double v) => v.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _c.text = _fmt(widget.value);
    });
  }

  @override
  void didUpdateWidget(covariant _NumField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus) {
      final t = _fmt(widget.value);
      if (_c.text != t) _c.text = t;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String v) {
    final n = double.tryParse(v.trim());
    if (n == null) return;
    widget.onChanged(n.clamp(widget.min, widget.max).toDouble());
  }

  void _step(double delta) {
    widget.onChanged((widget.value + delta).clamp(widget.min, widget.max).toDouble());
  }

  Widget _button(IconData icon, double delta) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _step(delta),
      child: Container(
        width: 28,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: KColors.accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(widget.label!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        if (step != null) _button(Icons.remove, -step),
        SizedBox(
          width: widget.width,
          height: 34,
          child: TextField(
            controller: _c,
            focusNode: _focus,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              suffixText: widget.suffix.isEmpty ? null : widget.suffix,
              suffixStyle: const TextStyle(fontSize: 10),
              filled: true,
              fillColor: const Color(0xFF2A2150),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            onChanged: _typed,
            onSubmitted: _typed,
          ),
        ),
        if (step != null) _button(Icons.add, step),
      ],
    );
  }
}

/// A box for a color written as #RRGGBB.
class _HexField extends StatefulWidget {
  const _HexField({required this.argb, required this.onColor});

  final int argb;
  final ValueChanged<int> onColor;

  @override
  State<_HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<_HexField> {
  late final TextEditingController _c = TextEditingController(text: _hex(widget.argb));
  final FocusNode _focus = FocusNode();

  String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _c.text = _hex(widget.argb);
    });
  }

  @override
  void didUpdateWidget(covariant _HexField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus) {
      final t = _hex(widget.argb);
      if (_c.text != t) _c.text = t;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String v) {
    var t = v.trim();
    if (t.startsWith('#')) t = t.substring(1);
    if (t.length != 6) return;
    final n = int.tryParse(t, radix: 16);
    if (n == null) return;
    widget.onColor(((widget.argb >> 24) & 0xFF) << 24 | n);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 34,
      child: TextField(
        controller: _c,
        focusNode: _focus,
        textAlign: TextAlign.center,
        maxLength: 7,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]'))],
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          filled: true,
          fillColor: const Color(0xFF2A2150),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
        onChanged: _typed,
        onSubmitted: _typed,
      ),
    );
  }
}
