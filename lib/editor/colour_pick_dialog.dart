import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shows a picture from the video and lets you tap a colour. Returns the colour you added, or null.
Future<Color?> showColourPicker(BuildContext context, String framePath) {
  return showDialog<Color>(context: context, builder: (_) => _PickDialog(path: framePath));
}

class _PickDialog extends StatefulWidget {
  const _PickDialog({required this.path});

  final String path;

  @override
  State<_PickDialog> createState() => _PickDialogState();
}

class _PickDialogState extends State<_PickDialog> {
  ui.Image? _img;
  Uint8List? _px;
  int _w = 1, _h = 1;
  Offset? _tap;
  Color? _color;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _img?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 480);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted || data == null) return;
      setState(() {
        _img = frame.image;
        _w = frame.image.width;
        _h = frame.image.height;
        _px = data.buffer.asUint8List();
      });
    } catch (_) {}
  }

  void _pick(Offset local, Size box) {
    final px = _px;
    if (px == null) return;
    final fx = (local.dx / box.width).clamp(0.0, 1.0).toDouble();
    final fy = (local.dy / box.height).clamp(0.0, 1.0).toDouble();
    final cx = (fx * (_w - 1)).round();
    final cy = (fy * (_h - 1)).round();
    var r = 0, g = 0, b = 0, n = 0;
    for (var y = cy - 2; y <= cy + 2; y++) {
      for (var x = cx - 2; x <= cx + 2; x++) {
        if (x < 0 || y < 0 || x >= _w || y >= _h) continue;
        final o = (y * _w + x) * 4;
        r += px[o];
        g += px[o + 1];
        b += px[o + 2];
        n++;
      }
    }
    if (n == 0) return;
    setState(() {
      _tap = Offset(fx, fy);
      _color = Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
    });
  }

  bool get _colourful {
    final c = _color;
    if (c == null) return false;
    return HSVColor.fromColor(c).saturation >= 0.15;
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    return AlertDialog(
      title: const Text('Tap a colour'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (img == null)
              const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            else
              AspectRatio(
                aspectRatio: _w / _h,
                child: LayoutBuilder(builder: (context, c) {
                  final box = Size(c.maxWidth, c.maxHeight);
                  return GestureDetector(
                    onTapDown: (d) => _pick(d.localPosition, box),
                    onPanUpdate: (d) => _pick(d.localPosition, box),
                    child: Stack(
                      children: [
                        Positioned.fill(child: RawImage(image: img, fit: BoxFit.fill)),
                        if (_tap != null)
                          Positioned(
                            left: _tap!.dx * box.width - 11,
                            top: _tap!.dy * box.height - 11,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                color: _color,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _color ?? Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _color == null
                        ? 'Touch the picture'
                        : (_colourful ? 'Colour picked' : 'That spot is grey. Pick a coloured spot.'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _colourful ? () => Navigator.of(context).pop(_color) : null,
          child: const Text('Add colour'),
        ),
      ],
    );
  }
}
