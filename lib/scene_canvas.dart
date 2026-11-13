import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'animation_math.dart';
import 'models.dart';

/// Draws one scene. Everything is sized from fractions of the slide, so the
/// same widget works for the editor, small thumbnails and video export.
class SceneCanvas extends StatefulWidget {
  const SceneCanvas({
    super.key,
    required this.scene,
    this.selectedId,
    this.onSelect,
    this.onCommit,
    this.onDuplicate,
    this.onDelete,
    this.interactive = false,
    this.previewMs,
    this.ghostAtMs,
  });

  final Scene scene;
  final String? selectedId;
  final ValueChanged<String?>? onSelect;
  final VoidCallback? onCommit;

  /// Called with the layer id when the copy button on the selection is tapped.
  final ValueChanged<String>? onDuplicate;

  /// Called with the layer id when the delete button on the selection is tapped.
  final ValueChanged<String>? onDelete;
  final bool interactive;

  /// When set, the scene is drawn as it looks at this time (in milliseconds),
  /// with entrance animations applied.
  final int? previewMs;

  /// Editor only: while paused at this time (milliseconds into the slide), items
  /// that are not on screen at that moment are drawn faded so they can still be edited.
  final int? ghostAtMs;

  @override
  State<SceneCanvas> createState() => _SceneCanvasState();
}

class _SceneCanvasState extends State<SceneCanvas> {
  Offset? _startFocal;
  double _startCx = 0;
  double _startCy = 0;
  double _startW = 0;
  double _startH = 0;
  double _startRotation = 0;
  double _startDistance = 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final children = <Widget>[
          Positioned.fill(child: SceneBackground(scene: widget.scene)),
        ];
        if (widget.interactive) {
          children.add(
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelect?.call(null),
              ),
            ),
          );
        }
        Layer? selected;
        for (final layer in widget.scene.layers) {
          children.add(_buildLayer(layer, width, height));
          if (widget.interactive && layer.id == widget.selectedId) selected = layer;
        }
        if (selected != null) {
          children.add(_buildSelection(selected, width, height));
        }
        return ClipRect(child: Stack(children: children));
      },
    );
  }

  // ---- selection frame with handles (as in the mockup) ----

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject();
    if (box is RenderBox) return box.globalToLocal(global);
    return global;
  }

  Offset _centerOf(Layer layer, double width, double height) =>
      Offset(layer.cx * width, layer.cy * height);

  Widget _roundButton(double size, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Icon(icon, size: size * 0.58, color: const Color(0xFF5B21B6)),
      ),
    );
  }

  Widget _buildSelection(Layer layer, double width, double height) {
    final k = width / 885.0;
    final btn = math.max(28.0, 52 * k);
    final dot = math.max(10.0, 18 * k);
    final hit = dot * 2.4;
    final gap = math.max(8.0, 14 * k);
    final pad = btn + gap + 4;
    final boxW = layer.w * width;
    final boxH = layer.h * height;
    final center = _centerOf(layer, width, height);

    Widget corner(double dx, double dy) {
      return Positioned(
        left: pad + dx - hit / 2,
        top: pad + dy - hit / 2,
        width: hit,
        height: hit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            _startW = layer.w;
            _startH = layer.h;
            _startDistance = math.max(4.0, (_toLocal(d.globalPosition) - center).distance);
          },
          onPanUpdate: (d) {
            final dist = (_toLocal(d.globalPosition) - center).distance;
            final f = dist / _startDistance;
            setState(() {
              layer.w = (_startW * f).clamp(0.03, 1.6).toDouble();
              layer.h = (_startH * f).clamp(0.03, 1.6).toDouble();
            });
          },
          onPanEnd: (_) => widget.onCommit?.call(),
          onPanCancel: () => widget.onCommit?.call(),
          child: Center(
            child: Container(
              width: dot,
              height: dot,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 3)],
              ),
            ),
          ),
        ),
      );
    }

    Widget line(double left, double top, double w, double h) {
      return Positioned(
        left: left,
        top: top,
        width: w,
        height: h,
        child: const IgnorePointer(child: ColoredBox(color: Colors.white)),
      );
    }

    final midX = pad + boxW / 2;
    final midY = pad + boxH / 2;

    final overlay = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: pad - 1,
          top: pad - 1,
          width: boxW + 2,
          height: boxH + 2,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: const Color(0x66000000), width: 1)),
            ),
          ),
        ),
        Positioned(
          left: pad,
          top: pad,
          width: boxW,
          height: boxH,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.6)),
            ),
          ),
        ),
        // connectors to the three round buttons
        line(midX - 0.8, pad - gap, 1.6, gap),
        line(pad - gap, midY - 0.8, gap, 1.6),
        line(pad + boxW, midY - 0.8, gap, 1.6),
        corner(0, 0),
        corner(boxW, 0),
        corner(0, boxH),
        corner(boxW, boxH),
        // turn
        Positioned(
          left: midX - btn / 2,
          top: pad - gap - btn,
          width: btn,
          height: btn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) {
              final p = _toLocal(d.globalPosition) - center;
              var angle = math.atan2(p.dy, p.dx) + math.pi / 2;
              final step = math.pi / 4;
              final nearest = (angle / step).round() * step;
              if ((angle - nearest).abs() < 0.05) angle = nearest;
              setState(() => layer.rotation = angle);
            },
            onPanEnd: (_) => widget.onCommit?.call(),
            onPanCancel: () => widget.onCommit?.call(),
            child: _roundButton(btn, Icons.rotate_right, null),
          ),
        ),
        // copy
        Positioned(
          left: pad - gap - btn,
          top: midY - btn / 2,
          width: btn,
          height: btn,
          child: _roundButton(btn, Icons.copy_all_outlined, () => widget.onDuplicate?.call(layer.id)),
        ),
        // delete
        Positioned(
          left: pad + boxW + gap,
          top: midY - btn / 2,
          width: btn,
          height: btn,
          child: _roundButton(btn, Icons.delete_outline, () => widget.onDelete?.call(layer.id)),
        ),
      ],
    );

    return Positioned(
      left: center.dx - boxW / 2 - pad,
      top: center.dy - boxH / 2 - pad,
      width: boxW + 2 * pad,
      height: boxH + 2 * pad,
      child: Transform.rotate(angle: layer.rotation, child: overlay),
    );
  }

  Widget _buildLayer(Layer layer, double width, double height) {
    Widget content = LayerContent(layer: layer);

    if (widget.interactive) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect?.call(layer.id),
        onScaleStart: (details) {
          widget.onSelect?.call(layer.id);
          _startFocal = details.focalPoint;
          _startCx = layer.cx;
          _startCy = layer.cy;
          _startW = layer.w;
          _startH = layer.h;
          _startRotation = layer.rotation;
        },
        onScaleUpdate: (details) {
          final start = _startFocal;
          if (start == null) return;
          setState(() {
            layer.cx = (_startCx + (details.focalPoint.dx - start.dx) / width)
                .clamp(0.0, 1.0)
                .toDouble();
            layer.cy = (_startCy + (details.focalPoint.dy - start.dy) / height)
                .clamp(0.0, 1.0)
                .toDouble();
            layer.w = (_startW * details.scale).clamp(0.03, 1.6).toDouble();
            layer.h = (_startH * details.scale).clamp(0.03, 1.6).toDouble();
            layer.rotation = _startRotation + details.rotation;
          });
        },
        onScaleEnd: (_) {
          _startFocal = null;
          widget.onCommit?.call();
        },
        child: content,
      );
    } else {
      content = IgnorePointer(child: content);
    }

    Widget placed = Transform.rotate(angle: layer.rotation, child: content);
    final previewMs = widget.previewMs;
    if (previewMs != null) {
      final frame = layerFrame(layer, previewMs, widget.scene.durationMs);
      if (frame.alpha <= 0) return const SizedBox.shrink();
      placed = Opacity(
        opacity: frame.alpha.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(frame.dx * width, 0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(frame.scale * frame.scaleX, frame.scale, 1),
            child: placed,
          ),
        ),
      );
    } else if (widget.ghostAtMs != null) {
      final t = widget.ghostAtMs!;
      final end = layerEndMs(layer, widget.scene.durationMs);
      if (t < layer.startMs || t >= end) {
        placed = Opacity(opacity: 0.25, child: placed);
      }
    }

    return Positioned(
      left: (layer.cx - layer.w / 2) * width,
      top: (layer.cy - layer.h / 2) * height,
      width: layer.w * width,
      height: layer.h * height,
      child: placed,
    );
  }
}

class SceneBackground extends StatelessWidget {
  const SceneBackground({super.key, required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    switch (scene.bgType) {
      case 'asset':
        return Image.asset(
          scene.bgValue,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      case 'file':
        return Image.file(
          File(scene.bgValue),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFDDDDDD)),
        );
      default:
        return ColoredBox(color: Color(int.tryParse(scene.bgValue) ?? 0xFFFFFFFF));
    }
  }
}

/// The text style of a text item, drawn at [size] (the slide scales it to fit the box).
TextStyle layerTextStyle(Layer layer, {double size = 100}) {
  final color = Color(layer.color);
  final light = color.computeLuminance() > 0.7 && !layer.bgBox;
  final decorations = <TextDecoration>[
    if (layer.underline) TextDecoration.underline,
    if (layer.strike) TextDecoration.lineThrough,
  ];
  return TextStyle(
    fontSize: size,
    height: layer.lineHeight,
    fontWeight: layer.bold ? FontWeight.w800 : FontWeight.w500,
    fontStyle: layer.italic ? FontStyle.italic : FontStyle.normal,
    fontFamily: layer.fontFamily.isEmpty ? null : layer.fontFamily,
    letterSpacing: layer.letterSpacing * size / 72,
    decoration: decorations.isEmpty ? TextDecoration.none : TextDecoration.combine(decorations),
    decorationColor: color,
    color: color,
    shadows: light ? const [Shadow(color: Color(0x66000000), blurRadius: 8)] : null,
  );
}

TextAlign layerTextAlign(Layer layer) {
  switch (layer.align) {
    case 'left':
      return TextAlign.left;
    case 'right':
      return TextAlign.right;
    case 'justify':
      return TextAlign.justify;
    default:
      return TextAlign.center;
  }
}

const double _kBoxPadX = 24;
const double _kBoxPadY = 8;

/// Natural width and height of a text item at a 100 px font, box padding included.
Size measureLayerText(Layer layer) {
  final painter = TextPainter(
    text: TextSpan(text: layer.text.isEmpty ? ' ' : layer.text, style: layerTextStyle(layer)),
    textDirection: TextDirection.ltr,
    textAlign: layerTextAlign(layer),
  )..layout();
  var w = painter.width;
  var h = painter.height;
  painter.dispose();
  if (layer.bgBox) {
    w += _kBoxPadX * 2;
    h += _kBoxPadY * 2;
  }
  return Size(math.max(1, w), math.max(1, h));
}

double layerTextAspect(Layer layer) {
  final size = measureLayerText(layer);
  return size.width / size.height;
}

/// Text size in pixels of the 1280 x 720 video.
double layerTextSizePx(Layer layer) {
  final size = measureLayerText(layer);
  return layer.h * 720 * 100 / size.height;
}

/// Changes the box so the text has the given size in pixels of the 1280 x 720 video.
void setLayerTextSizePx(Layer layer, double px) {
  final size = measureLayerText(layer);
  final scale = px / 100;
  layer.h = (size.height * scale / 720).clamp(0.02, 1.6).toDouble();
  layer.w = (size.width * scale / 1280).clamp(0.02, 1.6).toDouble();
}

/// Re-fits the box to the text after the text or its style changed, keeping the
/// text size.
void refitLayerText(Layer layer, double keepSizePx) {
  setLayerTextSizePx(layer, keepSizePx);
}

/// What a single layer looks like, without any gestures.
class LayerContent extends StatelessWidget {
  const LayerContent({super.key, required this.layer});

  final Layer layer;

  Widget _body() {
    final color = Color(layer.color);
    switch (layer.type) {
      case 'text':
        Widget text = Text(
          layer.text,
          textAlign: layerTextAlign(layer),
          style: layerTextStyle(layer),
        );
        if (layer.bgBox) {
          text = Container(
            padding: const EdgeInsets.symmetric(horizontal: _kBoxPadX, vertical: _kBoxPadY),
            decoration: BoxDecoration(
              color: Color(layer.bgColor),
              borderRadius: BorderRadius.circular(18),
            ),
            child: text,
          );
        }
        return FittedBox(fit: BoxFit.contain, child: text);
      case 'asset':
        return Image.asset(layer.path, fit: BoxFit.contain, gaplessPlayback: true);
      case 'image':
        return Image.file(
          File(layer.path),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xFFDDDDDD),
            child: Icon(Icons.broken_image_outlined),
          ),
        );
      case 'shape':
        switch (layer.shape) {
          case 'circle':
            return ClipOval(child: ColoredBox(color: color));
          case 'round':
            return LayoutBuilder(
              builder: (context, c) => ClipRRect(
                borderRadius: BorderRadius.circular(math.min(c.maxWidth, c.maxHeight) * 0.18),
                child: ColoredBox(color: color),
              ),
            );
          default:
            return ColoredBox(color: color);
        }
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (layer.opacity >= 0.999) return body;
    return Opacity(opacity: layer.opacity.clamp(0.0, 1.0).toDouble(), child: body);
  }
}
