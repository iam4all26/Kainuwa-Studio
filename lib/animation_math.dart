import 'dart:math' as math;

import 'models.dart';

/// The look of an item at one moment of its animation.
class AnimFrame {
  const AnimFrame(this.alpha, this.dx, this.scale, [this.scaleX = 1]);

  /// 0 (invisible) to 1 (fully visible)
  final double alpha;

  /// Sideways shift as a fraction of the slide width
  final double dx;
  final double scale;

  /// Extra stretch across the width only (used by Draw)
  final double scaleX;
}

const List<String> kAnimKinds = ['none', 'appear', 'fade', 'slide', 'pop', 'zoom', 'draw'];
const List<String> kExitKinds = ['none', 'fade', 'slide', 'pop', 'zoom', 'draw'];

String animLabel(String kind) {
  switch (kind) {
    case 'appear':
      return 'Appear';
    case 'fade':
      return 'Fade';
    case 'slide':
      return 'Slide';
    case 'pop':
      return 'Pop';
    case 'zoom':
      return 'Zoom';
    case 'draw':
      return 'Draw';
    default:
      return 'None';
  }
}

/// Entrance. The same formulas are used by the video export (LessonOverlays.java),
/// so the preview matches the video.
AnimFrame animationFrame(String kind, int timeMs, int startMs, int durationMs) {
  if (kind == 'none') return const AnimFrame(1, 0, 1);
  final duration = math.max(1, durationMs);
  final double progress =
      timeMs <= startMs ? 0.0 : math.min(1.0, (timeMs - startMs) / duration);
  if (kind == 'appear') return AnimFrame(progress > 0 ? 1 : 0, 0, 1);

  final eased = 1 - math.pow(1 - progress, 3).toDouble();
  var alpha = eased;
  var dx = 0.0;
  var scale = 1.0;
  var scaleX = 1.0;
  switch (kind) {
    case 'slide':
      dx = -0.175 * (1 - eased);
      break;
    case 'pop':
      {
        final q = progress - 1;
        scale = 1 + 2.70158 * q * q * q + 1.70158 * q * q;
        alpha = math.min(1.0, progress * 4);
      }
      break;
    case 'zoom':
      scale = 1.6 - 0.6 * eased;
      break;
    case 'draw':
      alpha = 1;
      scaleX = math.max(0.01, eased);
      break;
  }
  if (progress <= 0) alpha = 0;
  return AnimFrame(alpha, dx, math.max(0.01, scale), scaleX);
}

/// Exit, played during the last [outDurMs] before the item leaves.
AnimFrame exitFrame(String kind, int timeMs, int outStartMs, int outDurMs) {
  if (kind == 'none') return const AnimFrame(1, 0, 1);
  final duration = math.max(1, outDurMs);
  final double p = timeMs <= outStartMs ? 0.0 : math.min(1.0, (timeMs - outStartMs) / duration);
  final e = p * p;
  switch (kind) {
    case 'fade':
      return AnimFrame(1 - e, 0, 1);
    case 'slide':
      return AnimFrame(1 - e, 0.175 * e, 1);
    case 'pop':
      return AnimFrame(1 - e, 0, math.max(0.01, 1 - 0.5 * e));
    case 'zoom':
      return AnimFrame(1 - e, 0, 1 + 0.6 * e);
    case 'draw':
      return AnimFrame(1, 0, 1, math.max(0.01, 1 - e));
  }
  return const AnimFrame(1, 0, 1);
}

/// The last millisecond (exclusive) an item is on screen.
int layerEndMs(Layer layer, int sceneMs) =>
    layer.endMs < 0 ? sceneMs : math.min(layer.endMs, sceneMs);

/// Everything about an item at [timeMs] into its slide: timing, entrance and exit.
AnimFrame layerFrame(Layer layer, int timeMs, int sceneMs) {
  final end = layerEndMs(layer, sceneMs);
  if (timeMs < layer.startMs || timeMs >= end) return const AnimFrame(0, 0, 1);
  final enter = animationFrame(
    layer.animIn,
    timeMs,
    layer.startMs + layer.animStartMs,
    layer.animDurationMs,
  );
  if (layer.animOut == 'none') return enter;
  final out = exitFrame(layer.animOut, timeMs, end - layer.animOutDurationMs, layer.animOutDurationMs);
  return AnimFrame(
    enter.alpha * out.alpha,
    enter.dx + out.dx,
    enter.scale * out.scale,
    enter.scaleX * out.scaleX,
  );
}

/// True when the item needs to be animated by the video encoder instead of
/// being part of the slide picture.
bool layerNeedsOverlay(Layer layer) =>
    layer.animIn != 'none' ||
    layer.animOut != 'none' ||
    layer.startMs > 0 ||
    layer.endMs >= 0;
