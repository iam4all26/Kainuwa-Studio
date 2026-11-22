import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'avatar.dart';

/// Audio picture styles. [id] is stored in Layer.shape as "viz_<id>".
class VizKind {
  const VizKind(this.id, this.name);

  final String id;
  final String name;
}

const List<VizKind> kVizKinds = [
  VizKind('bars', 'Bars'),
  VizKind('dots', 'Dots'),
  VizKind('wave', 'Wave'),
];

bool isVizLayerShape(String shape) => shape.startsWith('viz_');

const int _kCols = 48;
const int _kStepMs = 45;
const int _kLevels = 20;

/// The height of every column (0 to 20) at [absMs]. The middle column is "now"; the columns on
/// each side show the sound a little before and after, so the picture moves with the real audio.
List<int> vizValues(AvatarSpec spec, int absMs) {
  final out = List<int>.filled(_kCols, 0);
  for (var i = 0; i < _kCols; i++) {
    final t = absMs + ((i - _kCols / 2) * _kStepMs).round();
    final v = math.sqrt(AvatarLevels.raw(spec, t));
    final taper = math.pow(math.sin(math.pi * (i + 0.5) / _kCols), 0.7).toDouble();
    out[i] = (v * taper * _kLevels).round().clamp(0, _kLevels).toInt();
  }
  return out;
}

/// Two moments with the same signature look exactly the same.
String vizSignature(AvatarSpec spec, int absMs) => vizValues(spec, absMs).join(',');

/// Draws one audio picture straight into an image, without building any widgets. It is many
/// times faster than drawing the widget, which matters for a video export that needs thousands.
/// [boxW] and [boxH] are the whole picture (with its edge room), [layerW] and [layerH] the item.
Future<ui.Image> renderVizImage({
  required String kind,
  required String avatar,
  required Color color,
  required int absMs,
  required double boxW,
  required double boxH,
  required double layerW,
  required double layerH,
  required double ratio,
}) {
  final spec = AvatarSpec.parse(avatar);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(ratio);
  canvas.translate((boxW - layerW) / 2, (boxH - layerH) / 2);
  _VizPainter(kind, vizValues(spec, absMs), color).paint(canvas, Size(layerW, layerH));
  final picture = recorder.endRecording();
  final image = picture.toImage((boxW * ratio).ceil(), (boxH * ratio).ceil());
  picture.dispose();
  return image;
}

/// The audio picture of a sound. [absMs] is the time in the whole video (null when paused,
/// then a moment inside the song is shown).
class VizView extends StatelessWidget {
  const VizView({super.key, required this.kind, required this.avatar, required this.color, this.absMs});

  final String kind;
  final String avatar;
  final Color color;
  final int? absMs;

  @override
  Widget build(BuildContext context) {
    final spec = AvatarSpec.parse(avatar);
    if (spec.audio.isNotEmpty && !AvatarLevels.isLoaded(spec.audio)) {
      AvatarLevels.load(spec.audio, spec.sourceMs);
    }
    return IgnorePointer(
      child: ValueListenableBuilder<int>(
        valueListenable: AvatarLevels.changed,
        builder: (context, _, __) {
          final t = absMs ?? (spec.startMs + math.min(8000, spec.sourceMs ~/ 3));
          return SizedBox.expand(
            child: CustomPaint(painter: _VizPainter(kind, vizValues(spec, t), color)),
          );
        },
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  _VizPainter(this.kind, this.values, this.color);

  final String kind;
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final colW = w / _kCols;
    final mid = h / 2;
    final paint = Paint()..color = color;
    switch (kind) {
      case 'dots':
        final r = math.min(colW * 0.24, h * 0.06);
        final gap = r * 2.7;
        for (var i = 0; i < _kCols; i++) {
          final x = (i + 0.5) * colW;
          paint.color = color.withOpacity(0.75);
          canvas.drawCircle(Offset(x, mid), r * 0.75, paint);
          final k = ((values[i] / _kLevels) * (mid - r) / gap).floor();
          for (var j = 1; j <= k; j++) {
            paint.color = color.withOpacity(math.max(0.35, 1.0 - j * 0.07));
            canvas.drawCircle(Offset(x, mid - j * gap), r, paint);
            canvas.drawCircle(Offset(x, mid + j * gap), r, paint);
          }
        }
        break;
      case 'wave':
        final top = Path();
        final bottom = <Offset>[];
        for (var i = 0; i < _kCols; i++) {
          final x = (i + 0.5) * colW;
          final half = math.max(h * 0.015, values[i] / _kLevels * h * 0.48);
          if (i == 0) {
            top.moveTo(x, mid - half);
          } else {
            top.lineTo(x, mid - half);
          }
          bottom.add(Offset(x, mid + half));
        }
        for (var i = bottom.length - 1; i >= 0; i--) {
          top.lineTo(bottom[i].dx, bottom[i].dy);
        }
        top.close();
        paint
          ..color = color.withOpacity(0.35)
          ..style = PaintingStyle.fill;
        canvas.drawPath(top, paint);
        paint
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, h * 0.025)
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(top, paint);
        break;
      default:
        final barW = colW * 0.58;
        for (var i = 0; i < _kCols; i++) {
          final x = (i + 0.5) * colW;
          final bh = math.max(h * 0.05, values[i] / _kLevels * h * 0.95);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, mid), width: barW, height: bh),
              Radius.circular(barW / 2),
            ),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_VizPainter old) => old.kind != kind || old.color != color || old.values.join(',') != values.join(',');
}
