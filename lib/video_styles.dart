import 'package:flutter/material.dart';

import 'pic_filter.dart';
import 'video_curves.dart';
import 'video_grade.dart';

/// A ready-made look for a video clip: a Look preset, a colour grade and curves in one tap.
class VideoStyle {
  const VideoStyle(this.name, this.look, this.grade, this.curves);

  final String name;

  /// Encoded PicFilter (empty = none).
  final String look;

  /// Encoded VideoGrade (empty = none).
  final String grade;

  /// Encoded VideoCurves (empty = none).
  final String curves;
}

List<Offset> _p(List<List<double>> v) => [for (final e in v) Offset(e[0], e[1])];

final List<VideoStyle> kVideoStyles = _build();

List<VideoStyle> _build() {
  String look(String preset) => PicFilter(preset: preset).encode();
  String grade({double e = 0, double t = 0, double ti = 0, double h = 0, double r = 0, double g = 0, double b = 0}) =>
      VideoGrade(exposure: e, temperature: t, tint: ti, hue: h, red: r, green: g, blue: b).encode();
  String curves({
    List<List<double>>? m,
    List<List<double>>? r,
    List<List<double>>? g,
    List<List<double>>? b,
    double sh = 0,
    double hi = 0,
    double vib = 0,
  }) =>
      VideoCurves(
        master: m == null ? null : _p(m),
        red: r == null ? null : _p(r),
        green: g == null ? null : _p(g),
        blue: b == null ? null : _p(b),
        shadows: sh,
        highlights: hi,
        vibrance: vib,
      ).encode();

  return [
    VideoStyle('None', '', '', ''),
    VideoStyle(
      'Teal and orange',
      '',
      grade(t: 0.1),
      curves(
        m: [[0, 0], [0.25, 0.22], [0.75, 0.78], [1, 1]],
        r: [[0, 0], [0.25, 0.18], [0.75, 0.82], [1, 1]],
        b: [[0, 0.04], [0.25, 0.32], [0.75, 0.68], [1, 0.96]],
        vib: 0.2,
      ),
    ),
    VideoStyle(
      'Cinematic',
      look('dramatic'),
      grade(t: -0.05),
      curves(m: [[0, 0], [0.25, 0.18], [0.75, 0.82], [1, 1]], hi: -0.1, vib: 0.15),
    ),
    VideoStyle(
      'Vintage',
      look('faded'),
      grade(t: 0.25, ti: 0.1),
      curves(m: [[0, 0.08], [1, 0.94]]),
    ),
    VideoStyle('Night', '', grade(e: -0.3, t: -0.4, b: 0.1), curves(sh: 0.15, vib: -0.1)),
    VideoStyle('Matte', '', '', curves(m: [[0, 0.12], [1, 0.92]], vib: -0.1)),
    VideoStyle(
      'Bright and airy',
      '',
      grade(e: 0.25, t: 0.05),
      curves(m: [[0, 0], [0.25, 0.32], [0.75, 0.82], [1, 1]], hi: -0.2, vib: 0.2),
    ),
    VideoStyle(
      'Moody',
      '',
      grade(e: -0.2, t: -0.1),
      curves(m: [[0, 0], [0.25, 0.15], [0.75, 0.78], [1, 0.97]], vib: -0.2),
    ),
    VideoStyle('Golden hour', '', grade(e: 0.1, t: 0.5, ti: 0.1), curves(vib: 0.3, hi: -0.1)),
    VideoStyle('Cold blue', '', grade(t: -0.5, b: 0.1), curves(m: [[0, 0], [0.25, 0.2], [0.75, 0.8], [1, 1]])),
    VideoStyle(
      'Punchy',
      '',
      '',
      curves(m: [[0, 0], [0.25, 0.14], [0.75, 0.87], [1, 1]], vib: 0.5),
    ),
    VideoStyle(
      'Film fade',
      '',
      grade(t: 0.1),
      curves(
        m: [[0, 0], [1, 0.95]],
        r: [[0, 0.05], [1, 1]],
        b: [[0, 0.1], [1, 0.94]],
        vib: -0.1,
      ),
    ),
    VideoStyle(
      'Noir',
      look('gray'),
      '',
      curves(m: [[0, 0], [0.25, 0.12], [0.75, 0.88], [1, 1]]),
    ),
  ];
}
