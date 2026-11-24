import 'dart:io';

import 'package:flutter/material.dart';

import 'editor/edit_panel.dart' show fontMenuItems, fontChoices;
import 'media/media_library.dart';
import 'models.dart';
import 'scene_canvas.dart';
import 'theme.dart';
import 'widgets.dart';

/// The nine places a watermark can sit: top, middle or bottom, then left, centre or right.
const List<String> kWatermarkSpots = ['tl', 'tc', 'tr', 'ml', 'mc', 'mr', 'bl', 'bc', 'br'];

Alignment _alignFor(String spot) {
  switch (spot) {
    case 'tl':
      return Alignment.topLeft;
    case 'tc':
      return Alignment.topCenter;
    case 'tr':
      return Alignment.topRight;
    case 'ml':
      return Alignment.centerLeft;
    case 'mc':
      return Alignment.center;
    case 'mr':
      return Alignment.centerRight;
    case 'bl':
      return Alignment.bottomLeft;
    case 'bc':
      return Alignment.bottomCenter;
    default:
      return Alignment.bottomRight;
  }
}

/// The watermark drawn over every slide of an exported video.
Widget watermarkOverlay(Watermark wm, double w, double h) {
  if (!wm.on) return const SizedBox.shrink();
  final hasImage = wm.kind == 'image' && wm.image.isNotEmpty && File(wm.image).existsSync();
  final hasText = wm.kind != 'image' && wm.text.trim().isNotEmpty;
  if (!hasImage && !hasText) return const SizedBox.shrink();
  final margin = w * 0.025;
  final ink = Color(wm.color);
  // A dark shadow behind light text, a light one behind dark text.
  final shadowColor = ink.computeLuminance() > 0.5 ? const Color(0xAA000000) : const Color(0xAAFFFFFF);
  final child = Opacity(
    opacity: wm.opacity.clamp(0.1, 1.0).toDouble(),
    child: hasImage
        ? Image.file(File(wm.image), width: w * wm.size, fit: BoxFit.contain)
        : Text(
            wm.text,
            style: TextStyle(
              color: ink,
              fontFamily: wm.font.isEmpty ? null : wm.font,
              fontSize: w * wm.size * 0.2,
              fontWeight: wm.bold ? FontWeight.w700 : FontWeight.w400,
              shadows: wm.shadow ? [Shadow(color: shadowColor, blurRadius: 6)] : null,
            ),
          ),
  );
  return Positioned.fill(
    child: Padding(
      padding: EdgeInsets.all(margin),
      child: Align(alignment: _alignFor(wm.corner), child: child),
    ),
  );
}

const List<int> _kQuickColors = [
  0xFFFFFFFF,
  0xFF000000,
  0xFFFFC107,
  0xFF7351FF,
  0xFFFF5252,
  0xFF4CAF50,
  0xFF29B6F6,
];

/// The watermark settings card of the export screen. It shows a live preview of the video
/// frame with the watermark in place; tap the preview or the grid to move it.
class WatermarkCard extends StatefulWidget {
  const WatermarkCard({
    super.key,
    required this.wm,
    required this.onChanged,
    this.enabled = true,
    this.previewScene,
    this.stageW = 1280,
    this.stageH = 720,
  });

  final Watermark wm;
  final ValueChanged<Watermark> onChanged;
  final bool enabled;

  /// The first slide of the video, shown behind the watermark in the preview.
  final Scene? previewScene;
  final double stageW;
  final double stageH;

  @override
  State<WatermarkCard> createState() => _WatermarkCardState();
}

class _WatermarkCardState extends State<WatermarkCard> {
  late final TextEditingController _text = TextEditingController(text: widget.wm.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    String? path;
    try {
      path = await pickMedia(context, MediaKind.image);
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    widget.onChanged(widget.wm.copyWith(image: path, kind: 'image'));
  }

  Future<void> _pickColor() async {
    final v = await pickColor(context, initial: widget.wm.color, title: 'Watermark colour');
    if (v != null && mounted) widget.onChanged(widget.wm.copyWith(color: v));
  }

  /// The spot nearest to a tap on the preview.
  void _tapPreview(Offset p, Size size) {
    final col = (p.dx / size.width * 3).floor().clamp(0, 2).toInt();
    final row = (p.dy / size.height * 3).floor().clamp(0, 2).toInt();
    widget.onChanged(widget.wm.copyWith(corner: kWatermarkSpots[row * 3 + col]));
  }

  Widget _preview(Watermark wm) {
    final w = widget.stageW;
    final h = widget.stageH;
    final scene = widget.previewScene;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final height = width * h / w;
        return GestureDetector(
          onTapUp: widget.enabled ? (d) => _tapPreview(d.localPosition, Size(width, height)) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: width,
              height: height,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: scene == null
                            ? const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF3B2A7A), Color(0xFF1A1438)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              )
                            : IgnorePointer(child: SceneCanvas(scene: scene)),
                      ),
                      // Faint thirds, so the nine places are easy to see.
                      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ThirdsPainter(w, h)))),
                      watermarkOverlay(wm, w, h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _spotGrid(Watermark wm, bool on) {
    return SizedBox(
      width: 96,
      height: 66,
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.45,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final s in kWatermarkSpots)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: on ? () => widget.onChanged(wm.copyWith(corner: s)) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: wm.corner == s ? KColors.purple : const Color(0x33808080),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wm = widget.wm;
    final on = widget.enabled;
    final isText = wm.kind != 'image';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.branding_watermark_outlined, color: KColors.purple),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Watermark', style: TextStyle(fontWeight: FontWeight.w700, color: KColors.accent)),
            ),
            Switch(
              value: wm.on,
              onChanged: on ? (v) => widget.onChanged(wm.copyWith(on: v)) : null,
            ),
          ],
        ),
        if (wm.on) ...[
          const SizedBox(height: 6),
          _preview(wm),
          const SizedBox(height: 4),
          const Text('Tap the picture or a square to move the watermark.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB5ABD6))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Text'),
                selected: isText,
                onSelected: on ? (_) => widget.onChanged(wm.copyWith(kind: 'text')) : null,
              ),
              ChoiceChip(
                label: const Text('Image'),
                selected: !isText,
                onSelected: on ? (_) => widget.onChanged(wm.copyWith(kind: 'image')) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isText)
            OutlinedButton.icon(
              onPressed: on ? _pickImage : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(wm.image.isEmpty ? 'Choose an image' : 'Change image'),
            )
          else ...[
            TextField(
              controller: _text,
              enabled: on,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Watermark text', counterText: ''),
              onChanged: (v) => widget.onChanged(wm.copyWith(text: v)),
            ),
            const SizedBox(height: 8),
            const Text('Font', style: TextStyle(fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFF2A2150), borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: fontChoices().any((f) => f.$1 == wm.font) ? wm.font : '',
                  items: fontMenuItems(),
                  onChanged: on ? (v) => widget.onChanged(wm.copyWith(font: v ?? '')) : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Colour', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final c in _kQuickColors)
                  InkWell(
                    onTap: on ? () => widget.onChanged(wm.copyWith(color: c)) : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: wm.color == c ? KColors.purple : const Color(0xFF3D3266),
                          width: wm.color == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: on ? _pickColor : null,
                  icon: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: Color(wm.color), shape: BoxShape.circle),
                  ),
                  label: const Text('More'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Bold'),
                  selected: wm.bold,
                  onSelected: on ? (v) => widget.onChanged(wm.copyWith(bold: v)) : null,
                ),
                FilterChip(
                  label: const Text('Shadow'),
                  selected: wm.shadow,
                  onSelected: on ? (v) => widget.onChanged(wm.copyWith(shadow: v)) : null,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: Text('Place', style: TextStyle(fontSize: 12))),
              _spotGrid(wm, on),
            ],
          ),
          Text('Size: ${(wm.size * 100).round()} percent', style: const TextStyle(fontSize: 12)),
          Slider(
            value: wm.size.clamp(0.05, 0.4).toDouble(),
            min: 0.05,
            max: 0.4,
            onChanged: on ? (v) => widget.onChanged(wm.copyWith(size: v)) : null,
          ),
          Text('Strength: ${(wm.opacity * 100).round()} percent', style: const TextStyle(fontSize: 12)),
          Slider(
            value: wm.opacity.clamp(0.1, 1.0).toDouble(),
            min: 0.1,
            max: 1.0,
            onChanged: on ? (v) => widget.onChanged(wm.copyWith(opacity: v)) : null,
          ),
        ],
      ],
    );
  }
}

/// Faint lines that divide the preview into nine places.
class _ThirdsPainter extends CustomPainter {
  const _ThirdsPainter(this.w, this.h);

  final double w;
  final double h;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = size.width / 400;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ThirdsPainter old) => old.w != w || old.h != h;
}
