import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

/// One hand picture (a transparent PNG). tipX and tipY say where the tip of the
/// pen or pointer is inside the picture, as fractions of its width and height.
class HandSpec {
  const HandSpec(this.id, this.name, this.aspect, this.tipX, this.tipY);

  final String id;
  final String name;

  /// width divided by height of the picture
  final double aspect;
  final double tipX;
  final double tipY;

  String get asset => 'assets/hands/$id.png';
}

const List<HandSpec> kHands = [
  HandSpec('hand_01', 'Gold pen', 313 / 365, 0.016, 0.707),
  HandSpec('hand_02', 'Silver pen', 321 / 395, 0.016, 0.587),
  HandSpec('hand_03', 'Robot black', 288 / 369, 0.017, 0.622),
  HandSpec('hand_04', 'Glove pen', 320 / 383, 0.016, 0.610),
  HandSpec('hand_05', 'Robot blue', 317 / 407, 0.016, 0.612),
  HandSpec('hand_06', 'Marker', 304 / 391, 0.016, 0.514),
  HandSpec('hand_07', 'Pencil', 351 / 403, 0.014, 0.500),
  HandSpec('hand_08', 'Quill', 329 / 445, 0.015, 0.646),
  HandSpec('hand_09', 'Neon stylus', 355 / 397, 0.011, 0.484),
  HandSpec('hand_10', 'Silver gold', 340 / 404, 0.015, 0.533),
];

HandSpec? handById(String id) {
  for (final h in kHands) {
    if (h.id == id) return h;
  }
  return null;
}

/// The hand is this wide, as a fraction of the slide width.
const double kHandWidthFrac = 0.20;

/// The hand slides in, draws, then slides out.
const int kHandEnterMs = 350;
const int kHandExitMs = 450;

/// Where the hand and the reveal are at one moment.
class HandState {
  const HandState(this.reveal, this.visible, this.tipX, this.tipY);

  /// 0 (nothing shown) to 1 (all shown)
  final double reveal;
  final bool visible;

  /// Tip of the pen as fractions of the slide.
  final double tipX;
  final double tipY;
}

double _wave(double cycles, double p) {
  final t = (cycles * p) % 1.0;
  return t < 0.5 ? t * 2 : 2 - t * 2;
}

/// [tMs] is the time since the hand animation started (negative before it).
HandState handStateAt(Layer l, int tMs) {
  final left = l.cx - l.w / 2;
  final top = l.cy - l.h / 2;
  final cycles = (l.w * 1280 / 60).clamp(3.0, 16.0).toDouble();
  double yAt(double p) => top + l.h * (0.1 + 0.8 * _wave(cycles, p));
  final startX = left;
  final startY = yAt(0);
  final endX = left + l.w;
  final endY = yAt(1);
  final reveal = math.max(1, l.handMs);

  if (tMs < 0) return HandState(0, false, startX, startY);
  if (tMs < kHandEnterMs) {
    final u = tMs / kHandEnterMs;
    final e = 1 - math.pow(1 - u, 3).toDouble();
    return HandState(
      0,
      true,
      1.1 + (startX - 1.1) * e,
      startY + 0.15 * (1 - e),
    );
  }
  final r = tMs - kHandEnterMs;
  if (r < reveal) {
    final p = r / reveal;
    return HandState(p, true, left + l.w * p, yAt(p));
  }
  final x = r - reveal;
  if (x < kHandExitMs) {
    final u = x / kHandExitMs;
    final e = u * u;
    return HandState(1, true, endX + (1.1 - endX) * e, endY + 0.2 * e);
  }
  return HandState(1, false, endX, endY);
}

int handTotalMs(Layer l) => kHandEnterMs + math.max<int>(1, l.handMs) + kHandExitMs;

/// Shows only the left part of its child.
class FractionClipper extends CustomClipper<Rect> {
  const FractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(FractionClipper old) => old.fraction != fraction;
}
