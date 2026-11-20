import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Curves and tone controls for a video clip, baked into a 3D colour table for the exporter.
/// Stored as one text: "master|red|green|blue|shadows|highlights|vibrance" (empty = none).
/// A curve is "x,y,x,y..." (points from 0 to 1); an empty curve is the straight line.
/// All the maths lives here: the exporter only reads the table written by [writeLutPng].
class VideoCurves {
  VideoCurves({
    List<Offset>? master,
    List<Offset>? red,
    List<Offset>? green,
    List<Offset>? blue,
    this.shadows = 0,
    this.highlights = 0,
    this.vibrance = 0,
    List<double>? keyHues,
    this.keyMode = 0,
    this.keyRange = 30,
    this.keySoft = 0.5,
  })  : keyHues = keyHues ?? const <double>[],
        master = master ?? identity(),
        red = red ?? identity(),
        green = green ?? identity(),
        blue = blue ?? identity();

  final List<Offset> master;
  final List<Offset> red;
  final List<Offset> green;
  final List<Offset> blue;

  /// -1 to 1: lifts (or lowers) the dark parts.
  final double shadows;

  /// -1 to 1: brightens (or darkens) the bright parts.
  final double highlights;

  /// -1 to 1: saturation that mostly affects dull colours.
  final double vibrance;

  /// Picked colours (hue in degrees, 0 to 360). Empty means the colour tool is off.
  final List<double> keyHues;

  /// 0 = remove these colours (they turn grey), 1 = keep only these colours.
  final int keyMode;

  /// Half width of the picked hue range in degrees (5 to 90).
  final double keyRange;

  /// 0 = hard edge, 1 = very soft edge.
  final double keySoft;

  static List<Offset> identity() => [const Offset(0, 0), const Offset(1, 1)];

  static bool _isIdentity(List<Offset> p) =>
      p.length == 2 && p[0] == const Offset(0, 0) && p[1] == const Offset(1, 1);

  bool get isNone =>
      _isIdentity(master) &&
      _isIdentity(red) &&
      _isIdentity(green) &&
      _isIdentity(blue) &&
      shadows == 0 &&
      highlights == 0 &&
      vibrance == 0 &&
      keyHues.isEmpty;

  List<Offset> channel(int i) => i == 0 ? master : (i == 1 ? red : (i == 2 ? green : blue));

  VideoCurves withChannel(int i, List<Offset> pts) => VideoCurves(
        master: i == 0 ? pts : master,
        red: i == 1 ? pts : red,
        green: i == 2 ? pts : green,
        blue: i == 3 ? pts : blue,
        shadows: shadows,
        highlights: highlights,
        vibrance: vibrance,
        keyHues: keyHues,
        keyMode: keyMode,
        keyRange: keyRange,
        keySoft: keySoft,
      );

  VideoCurves copyWith({double? shadows, double? highlights, double? vibrance}) => VideoCurves(
        master: master,
        red: red,
        green: green,
        blue: blue,
        shadows: shadows ?? this.shadows,
        highlights: highlights ?? this.highlights,
        vibrance: vibrance ?? this.vibrance,
        keyHues: keyHues,
        keyMode: keyMode,
        keyRange: keyRange,
        keySoft: keySoft,
      );

  /// Changes the colour remove or keep settings.
  VideoCurves withKey({List<double>? hues, int? mode, double? range, double? soft}) => VideoCurves(
        master: master,
        red: red,
        green: green,
        blue: blue,
        shadows: shadows,
        highlights: highlights,
        vibrance: vibrance,
        keyHues: hues ?? keyHues,
        keyMode: mode ?? keyMode,
        keyRange: range ?? keyRange,
        keySoft: soft ?? keySoft,
      );

  static String _enc(List<Offset> p) =>
      _isIdentity(p) ? '' : p.map((o) => '${o.dx.toStringAsFixed(4)},${o.dy.toStringAsFixed(4)}').join(',');

  static List<Offset> _dec(String s) {
    if (s.isEmpty) return identity();
    final v = s.split(',').map((e) => double.tryParse(e) ?? 0).toList();
    final pts = <Offset>[];
    for (var i = 0; i + 1 < v.length; i += 2) {
      pts.add(Offset(v[i].clamp(0.0, 1.0).toDouble(), v[i + 1].clamp(0.0, 1.0).toDouble()));
    }
    pts.sort((a, b) => a.dx.compareTo(b.dx));
    final out = <Offset>[];
    for (final p in pts) {
      if (out.isEmpty || p.dx - out.last.dx > 0.005) out.add(p);
    }
    if (out.length < 2 || out.first.dx != 0 || out.last.dx != 1) return identity();
    return out;
  }

  String encode() => isNone
      ? ''
      : '${_enc(master)}|${_enc(red)}|${_enc(green)}|${_enc(blue)}|$shadows|$highlights|$vibrance|'
          '${keyHues.isEmpty ? '' : '$keyMode,$keyRange,$keySoft,${keyHues.join(',')}'}';

  static (int, double, double, List<double>) _decKey(String s) {
    if (s.isEmpty) return (0, 30.0, 0.5, <double>[]);
    final v = s.split(',');
    if (v.length < 4) return (0, 30.0, 0.5, <double>[]);
    final mode = (int.tryParse(v[0]) ?? 0).clamp(0, 1).toInt();
    final range = (double.tryParse(v[1]) ?? 30).clamp(5.0, 90.0).toDouble();
    final soft = (double.tryParse(v[2]) ?? 0.5).clamp(0.0, 1.0).toDouble();
    final hues = <double>[];
    for (var i = 3; i < v.length && hues.length < 3; i++) {
      final h = double.tryParse(v[i]);
      if (h != null) hues.add(h.clamp(0.0, 360.0).toDouble());
    }
    return (mode, range, soft, hues);
  }

  static VideoCurves parse(String s) {
    if (s.isEmpty) return VideoCurves();
    final p = s.split('|');
    String at(int i) => i < p.length ? p[i] : '';
    double d(int i) => (double.tryParse(at(i)) ?? 0).clamp(-1.0, 1.0).toDouble();
    return VideoCurves(
      master: _dec(at(0)),
      red: _dec(at(1)),
      green: _dec(at(2)),
      blue: _dec(at(3)),
      shadows: d(4),
      highlights: d(5),
      vibrance: d(6),
      keyHues: _decKey(at(7)).$4,
      keyMode: _decKey(at(7)).$1,
      keyRange: _decKey(at(7)).$2,
      keySoft: _decKey(at(7)).$3,
    );
  }

  // ---- curve maths (monotone cubic through the points) ----

  /// Value of the curve through [pts] at [x] (0 to 1).
  static double curveAt(List<Offset> pts, double x) {
    final n = pts.length;
    if (n < 2) return x;
    if (x <= pts.first.dx) return pts.first.dy;
    if (x >= pts.last.dx) return pts.last.dy;
    final d = List<double>.generate(n - 1, (k) => (pts[k + 1].dy - pts[k].dy) / (pts[k + 1].dx - pts[k].dx));
    final m = List<double>.filled(n, 0);
    m[0] = d[0];
    m[n - 1] = d[n - 2];
    for (var k = 1; k < n - 1; k++) {
      m[k] = d[k - 1] * d[k] <= 0 ? 0 : (d[k - 1] + d[k]) / 2;
    }
    for (var k = 0; k < n - 1; k++) {
      if (d[k] == 0) {
        m[k] = 0;
        m[k + 1] = 0;
      } else {
        final a = m[k] / d[k], b = m[k + 1] / d[k];
        final s = a * a + b * b;
        if (s > 9) {
          final t = 3 / math.sqrt(s);
          m[k] = t * a * d[k];
          m[k + 1] = t * b * d[k];
        }
      }
    }
    var k = 0;
    while (k < n - 2 && x > pts[k + 1].dx) {
      k++;
    }
    final h = pts[k + 1].dx - pts[k].dx;
    final t = (x - pts[k].dx) / h;
    final t2 = t * t, t3 = t2 * t;
    final y = (2 * t3 - 3 * t2 + 1) * pts[k].dy +
        (t3 - 2 * t2 + t) * h * m[k] +
        (-2 * t3 + 3 * t2) * pts[k + 1].dy +
        (t3 - t2) * h * m[k + 1];
    return y.clamp(0.0, 1.0).toDouble();
  }

  static Float64List _table(List<Offset> pts) {
    final t = Float64List(256);
    for (var i = 0; i < 256; i++) {
      t[i] = curveAt(pts, i / 255);
    }
    return t;
  }

  late final Float64List _tm = _table(master);
  late final Float64List _tr = _table(red);
  late final Float64List _tg = _table(green);
  late final Float64List _tb = _table(blue);

  static double _look(Float64List t, double v) {
    final f = v.clamp(0.0, 1.0) * 255;
    final i = f.floor();
    if (i >= 255) return t[255];
    final fr = f - i;
    return t[i] * (1 - fr) + t[i + 1] * fr;
  }

  /// The look of one colour (all values 0 to 1). The order is: tone, vibrance, master curve, colour curves.
  /// How much a colour belongs to the picked colours (0 to 1). Grey pixels never count.
  double _keyWeight(double r, double g, double b) {
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    final dl = mx - mn;
    if (dl < 0.02) return 0;
    double h;
    if (mx == r) {
      h = 60 * (((g - b) / dl) % 6);
    } else if (mx == g) {
      h = 60 * ((b - r) / dl + 2);
    } else {
      h = 60 * ((r - g) / dl + 4);
    }
    final sat = mx == 0 ? 0.0 : dl / mx;
    final inner = keyRange * (1 - keySoft);
    var w = 0.0;
    for (final target in keyHues) {
      var d = (h - target).abs();
      if (d > 180) d = 360 - d;
      double t;
      if (d <= inner) {
        t = 1;
      } else if (d >= keyRange) {
        t = 0;
      } else {
        final x = (keyRange - d) / (keyRange - inner);
        t = x * x * (3 - 2 * x);
      }
      if (t > w) w = t;
    }
    return w * (sat / 0.2).clamp(0.0, 1.0);
  }

  (double, double, double) mapRgb(double r, double g, double b) {
    if (keyHues.isNotEmpty) {
      final w = _keyWeight(r, g, b);
      final k = keyMode == 0 ? 1 - w : w;
      final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      r = l + (r - l) * k;
      g = l + (g - l) * k;
      b = l + (b - l) * k;
    }
    if (shadows != 0 || highlights != 0) {
      final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final d = shadows * 0.3 * (1 - l) * (1 - l) + highlights * 0.3 * l * l;
      r += d;
      g += d;
      b += d;
    }
    if (vibrance != 0) {
      final hi = math.max(r, math.max(g, b)), lo = math.min(r, math.min(g, b));
      final f = 1 + vibrance * (1 - (hi - lo).clamp(0.0, 1.0));
      final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      r = l + (r - l) * f;
      g = l + (g - l) * f;
      b = l + (b - l) * f;
    }
    r = _look(_tr, _look(_tm, r));
    g = _look(_tg, _look(_tm, g));
    b = _look(_tb, _look(_tm, b));
    return (r, g, b);
  }

  /// Writes the 3D table as a PNG for the exporter: size (n*n) wide and n high.
  /// The pixel for red r, green g, blue b is at x = b * n + r, y = g.
  Future<void> writeLutPng(String path, {int n = 33}) async {
    final w = n * n;
    final bytes = Uint8List(w * n * 4);
    for (var b = 0; b < n; b++) {
      for (var g = 0; g < n; g++) {
        for (var r = 0; r < n; r++) {
          final c = mapRgb(r / (n - 1), g / (n - 1), b / (n - 1));
          final o = (g * w + b * n + r) * 4;
          bytes[o] = (c.$1.clamp(0.0, 1.0) * 255).round();
          bytes[o + 1] = (c.$2.clamp(0.0, 1.0) * 255).round();
          bytes[o + 2] = (c.$3.clamp(0.0, 1.0) * 255).round();
          bytes[o + 3] = 255;
        }
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, w, n, ui.PixelFormat.rgba8888, done.complete);
    final img = await done.future;
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw StateError('Could not write the colour table.');
    await File(path).writeAsBytes(png.buffer.asUint8List(), flush: true);
  }
}

/// A paused video frame with the curves applied exactly (the same maths as the export).
class CurvedFrame extends StatefulWidget {
  const CurvedFrame({super.key, required this.path, required this.spec, required this.fit});

  final String path;
  final String spec;
  final BoxFit fit;

  @override
  State<CurvedFrame> createState() => _CurvedFrameState();
}

class _CurvedFrameState extends State<CurvedFrame> {
  Uint8List? _base;
  int _w = 0, _h = 0;
  ui.Image? _shown;
  int _run = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CurvedFrame old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _base = null;
      _load();
    } else if (old.spec != widget.spec) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 60), _apply);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _shown?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final run = ++_run;
    try {
      final bytes = await File(widget.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 480);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (run != _run || data == null || !mounted) return;
      _w = frame.image.width;
      _h = frame.image.height;
      _base = data.buffer.asUint8List();
      await _apply();
    } catch (_) {}
  }

  Future<void> _apply() async {
    final base = _base;
    if (base == null || !mounted) return;
    final run = ++_run;
    final c = VideoCurves.parse(widget.spec);
    final out = Uint8List(base.length);
    for (var i = 0; i < base.length; i += 4) {
      final m = c.mapRgb(base[i] / 255, base[i + 1] / 255, base[i + 2] / 255);
      out[i] = (m.$1.clamp(0.0, 1.0) * 255).round();
      out[i + 1] = (m.$2.clamp(0.0, 1.0) * 255).round();
      out[i + 2] = (m.$3.clamp(0.0, 1.0) * 255).round();
      out[i + 3] = base[i + 3];
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(out, _w, _h, ui.PixelFormat.rgba8888, done.complete);
    final img = await done.future;
    if (run != _run || !mounted) {
      img.dispose();
      return;
    }
    final old = _shown;
    setState(() => _shown = img);
    old?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _shown;
    if (img == null) {
      return Image.file(File(widget.path),
          fit: widget.fit, width: double.infinity, height: double.infinity, gaplessPlayback: true);
    }
    return RawImage(image: img, fit: widget.fit, width: double.infinity, height: double.infinity);
  }
}
