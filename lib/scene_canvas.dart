import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'animation_math.dart';
import 'models.dart';
import 'theme.dart';

/// Draws one scene. Everything is sized from fractions of the slide, so the
/// same widget works for the editor, small thumbnails and, later, video export.
class SceneCanvas extends StatefulWidget {
  const SceneCanvas({
    super.key,
    required this.scene,
    this.selectedId,
    this.onSelect,
    this.onCommit,
    this.interactive = false,
    this.previewMs,
  });

  final Scene scene;
  final String? selectedId;
  final ValueChanged<String?>? onSelect;
  final VoidCallback? onCommit;
  final bool interactive;

  /// When set, the scene is drawn as it looks at this time (in milliseconds),
  /// with entrance animations applied.
  final int? previewMs;

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
        for (final layer in widget.scene.layers) {
          children.add(_buildLayer(layer, width, height));
        }
        return ClipRect(child: Stack(children: children));
      },
    );
  }

  Widget _buildLayer(Layer layer, double width, double height) {
    final selected = widget.interactive && layer.id == widget.selectedId;

    Widget content = LayerContent(layer: layer);
    if (selected) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          content,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: KColors.gold, width: 2),
              ),
            ),
          ),
        ],
      );
    }

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
      final frame = animationFrame(layer.animIn, previewMs, layer.animStartMs, layer.animDurationMs);
      if (frame.alpha <= 0) return const SizedBox.shrink();
      placed = Opacity(
        opacity: frame.alpha.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(frame.dx * width, 0),
          child: Transform.scale(scale: frame.scale, child: placed),
        ),
      );
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

/// What a single layer looks like, without any gestures.
class LayerContent extends StatelessWidget {
  const LayerContent({super.key, required this.layer});

  final Layer layer;

  @override
  Widget build(BuildContext context) {
    final color = Color(layer.color);
    switch (layer.type) {
      case 'text':
        final light = color.computeLuminance() > 0.7;
        return FittedBox(
          fit: BoxFit.contain,
          child: Text(
            layer.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 100,
              height: 1.15,
              fontWeight: layer.bold ? FontWeight.w800 : FontWeight.w500,
              color: color,
              shadows: light
                  ? const [Shadow(color: Color(0x66000000), blurRadius: 8)]
                  : null,
            ),
          ),
        );
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
}
