import 'dart:math' as math;

/// The look of an item at one moment of its entrance animation.
class AnimFrame {
  const AnimFrame(this.alpha, this.dx, this.scale);

  /// 0 (invisible) to 1 (fully visible)
  final double alpha;

  /// Sideways shift as a fraction of the slide width
  final double dx;
  final double scale;
}

const List<String> kAnimKinds = ['none', 'appear', 'fade', 'slide', 'pop', 'zoom'];

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
    default:
      return 'None';
  }
}

/// The same formulas are used by the video export, so the preview matches the video.
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
  }
  if (progress <= 0) alpha = 0;
  return AnimFrame(alpha, dx, math.max(0.01, scale));
}
