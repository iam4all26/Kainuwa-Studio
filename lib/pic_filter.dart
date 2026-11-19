import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// A look for a picture or background: a preset plus brightness, contrast,
/// saturation and blur. Stored as one short text so it fits any item.
class PicFilter {
  const PicFilter({
    this.preset = 'none',
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.blur = 0,
    this.dim = 0,
  });

  final String preset;

  /// -0.5 to 0.5
  final double brightness;

  /// -0.5 to 0.8
  final double contrast;

  /// -1 to 1
  final double saturation;

  /// Fraction of the item's smaller side, 0 to 0.05
  final double blur;

  /// How much darker, 0 (none) to 0.9
  final double dim;

  static const List<(String, String)> presets = [
    ('none', 'None'),
    ('gray', 'Black and white'),
    ('sepia', 'Sepia'),
    ('warm', 'Warm'),
    ('cool', 'Cool'),
    ('vivid', 'Vivid'),
    ('faded', 'Faded'),
    ('dramatic', 'Dramatic'),
    ('invert', 'Invert'),
  ];

  bool get isNone =>
      preset == 'none' && brightness == 0 && contrast == 0 && saturation == 0 && blur == 0 && dim == 0;

  PicFilter copyWith({String? preset, double? brightness, double? contrast, double? saturation, double? blur, double? dim}) =>
      PicFilter(
        preset: preset ?? this.preset,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        blur: blur ?? this.blur,
        dim: dim ?? this.dim,
      );

  /// Empty text means no filter.
  String encode() => isNone ? '' : '$preset;$brightness;$contrast;$saturation;$blur;$dim';

  static PicFilter parse(String s) {
    if (s.isEmpty) return const PicFilter();
    final p = s.split(';');
    double d(int i) => i < p.length ? (double.tryParse(p[i]) ?? 0) : 0;
    final known = presets.any((e) => e.$1 == p[0]);
    return PicFilter(
      preset: known ? p[0] : 'none',
      brightness: d(1).clamp(-0.5, 0.5).toDouble(),
      contrast: d(2).clamp(-0.5, 0.8).toDouble(),
      saturation: d(3).clamp(-1.0, 1.0).toDouble(),
      blur: d(4).clamp(0.0, 0.05).toDouble(),
      dim: d(5).clamp(0.0, 0.9).toDouble(),
    );
  }

  // ---- colour matrices (4 rows of 5, offsets in 0..255) ----

  static const List<double> _identity = [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Result of applying [a] after [b].
  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        var v = 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[r * 5 + k] * b[k * 5 + c];
        }
        if (c == 4) v += a[r * 5 + 4];
        out[r * 5 + c] = v;
      }
    }
    return out;
  }

  static List<double> _sat(double s) => [
        0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
        0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
        0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
        0, 0, 0, 1, 0,
      ];

  static List<double> _contrast(double f) {
    final t = 128 * (1 - f);
    return [f, 0, 0, 0, t, 0, f, 0, 0, t, 0, 0, f, 0, t, 0, 0, 0, 1, 0];
  }

  static List<double> _bright(double b) {
    final t = b * 255;
    return [1, 0, 0, 0, t, 0, 1, 0, 0, t, 0, 0, 1, 0, t, 0, 0, 0, 1, 0];
  }

  List<double> _presetMatrix() {
    switch (preset) {
      case 'gray':
        return _sat(0);
      case 'sepia':
        return [
          0.393, 0.769, 0.189, 0, 0, //
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case 'warm':
        return [1.12, 0, 0, 0, 8, 0, 1.0, 0, 0, 0, 0, 0, 0.86, 0, -8, 0, 0, 0, 1, 0];
      case 'cool':
        return [0.88, 0, 0, 0, -8, 0, 1.0, 0, 0, 0, 0, 0, 1.14, 0, 8, 0, 0, 0, 1, 0];
      case 'vivid':
        return _mul(_contrast(1.1), _sat(1.45));
      case 'faded':
        return _mul(_bright(0.07), _mul(_contrast(0.82), _sat(0.75)));
      case 'dramatic':
        return _mul(_contrast(1.3), _sat(0.8));
      case 'invert':
        return [-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0];
      default:
        return _identity;
    }
  }

  List<double> matrix() {
    var m = _presetMatrix();
    if (saturation != 0) m = _mul(_sat(1 + saturation), m);
    if (contrast != 0) m = _mul(_contrast(1 + contrast), m);
    if (brightness != 0) m = _mul(_bright(brightness), m);
    if (dim > 0) {
      final k = 1 - dim;
      m = _mul([k, 0, 0, 0, 0, 0, k, 0, 0, 0, 0, 0, k, 0, 0, 0, 0, 0, 1, 0], m);
    }
    return m;
  }

  /// Draws [child] with this look.
  Widget wrap(Widget child) {
    if (isNone) return child;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 100.0;
      final h = c.maxHeight.isFinite ? c.maxHeight : 100.0;
      Widget out = child;
      if (preset != 'none' || brightness != 0 || contrast != 0 || saturation != 0 || dim != 0) {
        out = ColorFiltered(colorFilter: ColorFilter.matrix(matrix()), child: out);
      }
      final sigma = blur * math.min(w, h);
      if (sigma >= 0.3) {
        out = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
          child: out,
        );
      }
      return out;
    });
  }
}
