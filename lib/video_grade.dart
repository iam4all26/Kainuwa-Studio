import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colour grading of a video clip: exposure, temperature, tint, hue and red, green and blue balance.
/// Stored as one short text "exposure;temperature;tint;hue;red;green;blue" (empty = none).
/// The same maths is in KainuwaEncoderPlugin.java (addVideoGrade); keep them identical.
class VideoGrade {
  const VideoGrade({
    this.exposure = 0,
    this.temperature = 0,
    this.tint = 0,
    this.hue = 0,
    this.red = 0,
    this.green = 0,
    this.blue = 0,
  });

  /// -1 to 1 (stops: the picture is multiplied by 2 to the power of this)
  final double exposure;

  /// -1 (cooler, bluer) to 1 (warmer, redder)
  final double temperature;

  /// -1 (greener) to 1 (more magenta)
  final double tint;

  /// -180 to 180 degrees
  final double hue;

  /// -0.5 to 0.5 gain of each colour
  final double red;
  final double green;
  final double blue;

  bool get isNone =>
      exposure == 0 && temperature == 0 && tint == 0 && hue == 0 && red == 0 && green == 0 && blue == 0;

  VideoGrade copyWith({
    double? exposure,
    double? temperature,
    double? tint,
    double? hue,
    double? red,
    double? green,
    double? blue,
  }) =>
      VideoGrade(
        exposure: exposure ?? this.exposure,
        temperature: temperature ?? this.temperature,
        tint: tint ?? this.tint,
        hue: hue ?? this.hue,
        red: red ?? this.red,
        green: green ?? this.green,
        blue: blue ?? this.blue,
      );

  String encode() => isNone ? '' : '$exposure;$temperature;$tint;$hue;$red;$green;$blue';

  static VideoGrade parse(String s) {
    if (s.isEmpty) return const VideoGrade();
    final p = s.split(';');
    double d(int i, double lo, double hi) =>
        (i < p.length ? (double.tryParse(p[i]) ?? 0) : 0).clamp(lo, hi).toDouble();
    return VideoGrade(
      exposure: d(0, -1, 1),
      temperature: d(1, -1, 1),
      tint: d(2, -1, 1),
      hue: d(3, -180, 180),
      red: d(4, -0.5, 0.5),
      green: d(5, -0.5, 0.5),
      blue: d(6, -0.5, 0.5),
    );
  }

  double get scaleRed => math.pow(2, exposure).toDouble() * (1 + 0.25 * temperature) * (1 + red);
  double get scaleGreen => math.pow(2, exposure).toDouble() * (1 - 0.2 * tint) * (1 + green);
  double get scaleBlue => math.pow(2, exposure).toDouble() * (1 - 0.25 * temperature) * (1 + blue);

  /// 4 rows of 5 (offsets 0..255): hue rotation first, then the channel scales.
  List<double> matrix() {
    final a = hue * math.pi / 180;
    final c = math.cos(a), s = math.sin(a);
    final h = [
      0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, //
      0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283,
      0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072,
    ];
    final k = [scaleRed, scaleGreen, scaleBlue];
    final m = List<double>.filled(20, 0);
    for (var r = 0; r < 3; r++) {
      for (var col = 0; col < 3; col++) {
        m[r * 5 + col] = h[r * 3 + col] * k[r];
      }
    }
    m[18] = 1;
    return m;
  }

  Widget wrap(Widget child) {
    if (isNone) return child;
    return ColorFiltered(colorFilter: ColorFilter.matrix(matrix()), child: child);
  }
}
