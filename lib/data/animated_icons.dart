import 'dart:math' as math;

import '../models.dart';
import '../svg/svg_raster.dart';

/// One piece of an animated icon. x and y move the piece from the middle of the icon, w and h are its size;
/// all of them in icon units (1 = the whole icon). Times are in milliseconds from the moment the icon starts.
class AnimPart {
  const AnimPart({
    this.shape = 'circle',
    this.icon = '',
    required this.color,
    this.x = 0,
    this.y = 0,
    this.w = 1,
    this.h = 1,
    this.rot = 0,
    this.at = 0,
    this.until = -1,
    this.inKind = 'pop',
    this.inMs = 450,
    this.outKind = 'none',
    this.outMs = 300,
    this.loop = 'none',
  });

  /// circle, round, or a shape id from shapes.dart (heart, star, cross, arrow...). Ignored when icon is set.
  final String shape;

  /// An everyday icon from the app (assets/icons_ui/...svg), drawn in [color].
  final String icon;
  final int color;
  final double x;
  final double y;
  final double w;
  final double h;

  /// Turn in radians.
  final double rot;
  final int at;

  /// When the piece goes away. -1 = it stays as long as the whole icon.
  final int until;
  final String inKind;
  final int inMs;
  final String outKind;
  final int outMs;
  final String loop;
}

class AnimIconPreset {
  const AnimIconPreset(this.id, this.name, this.size, this.totalMs, this.parts);

  final String id;
  final String name;

  /// Width of the icon as a fraction of a landscape slide.
  final double size;

  /// When the last piece has finished moving in.
  final int totalMs;
  final List<AnimPart> parts;
}

const int _green = 0xFF2ECC71;
const int _red = 0xFFE74C3C;
const int _white = 0xFFFFFFFF;
const int _gold = 0xFFF6C101;
const int _blue = 0xFF3B82F6;
const int _purple = 0xFF7351FF;
const int _grey = 0xFFE3E0F0;

const String _ui = 'assets/icons_ui/';

const List<AnimIconPreset> kAnimatedIcons = [
  AnimIconPreset('success', 'Success', 0.2, 2000, [
    AnimPart(icon: '${_ui}check.svg', color: _white, w: 0.8, h: 0.8, at: 0, until: 1100, inKind: 'pop', inMs: 400, outKind: 'zoom', outMs: 300),
    AnimPart(shape: 'circle', color: _green, at: 1000, inKind: 'jump', inMs: 600),
    AnimPart(icon: '${_ui}check.svg', color: _white, w: 0.55, h: 0.55, at: 1300, inKind: 'draw', inMs: 600),
  ]),
  AnimIconPreset('error', 'Error', 0.2, 900, [
    AnimPart(shape: 'circle', color: _red, inKind: 'pop', inMs: 450),
    AnimPart(shape: 'cross', color: _white, w: 0.62, h: 0.62, rot: math.pi / 4, at: 400, inKind: 'pop', inMs: 400, loop: 'shake'),
  ]),
  AnimIconPreset('checklist', 'Checklist', 0.4, 2400, [
    AnimPart(shape: 'circle', color: _green, x: -0.36, y: -0.3, w: 0.2, h: 0.2, at: 0),
    AnimPart(icon: '${_ui}check.svg', color: _white, x: -0.36, y: -0.3, w: 0.12, h: 0.12, at: 250, inKind: 'draw', inMs: 350),
    AnimPart(shape: 'round', color: _grey, x: 0.14, y: -0.3, w: 0.62, h: 0.09, at: 150, inKind: 'draw', inMs: 450),
    AnimPart(shape: 'circle', color: _green, x: -0.36, y: 0, w: 0.2, h: 0.2, at: 800),
    AnimPart(icon: '${_ui}check.svg', color: _white, x: -0.36, y: 0, w: 0.12, h: 0.12, at: 1050, inKind: 'draw', inMs: 350),
    AnimPart(shape: 'round', color: _grey, x: 0.14, y: 0, w: 0.62, h: 0.09, at: 950, inKind: 'draw', inMs: 450),
    AnimPart(shape: 'circle', color: _green, x: -0.36, y: 0.3, w: 0.2, h: 0.2, at: 1600),
    AnimPart(icon: '${_ui}check.svg', color: _white, x: -0.36, y: 0.3, w: 0.12, h: 0.12, at: 1850, inKind: 'draw', inMs: 350),
    AnimPart(shape: 'round', color: _grey, x: 0.14, y: 0.3, w: 0.62, h: 0.09, at: 1750, inKind: 'draw', inMs: 450),
  ]),
  AnimIconPreset('bell', 'Bell', 0.2, 900, [
    AnimPart(icon: '${_ui}bell.svg', color: _gold, w: 0.9, h: 0.9, inKind: 'pop', inMs: 450, loop: 'swing'),
    AnimPart(shape: 'circle', color: _red, x: 0.3, y: -0.3, w: 0.28, h: 0.28, at: 700, inKind: 'pop', inMs: 300),
  ]),
  AnimIconPreset('heart', 'Beating heart', 0.2, 600, [
    AnimPart(shape: 'heart', color: _red, w: 0.9, h: 0.9, inKind: 'pop', inMs: 500, loop: 'heartbeat'),
  ]),
  AnimIconPreset('like', 'Like', 0.2, 1000, [
    AnimPart(shape: 'circle', color: _blue, inKind: 'pop', inMs: 400),
    AnimPart(icon: '${_ui}thumb-up.svg', color: _white, w: 0.55, h: 0.55, at: 400, inKind: 'jump', inMs: 600, loop: 'pulse'),
  ]),
  AnimIconPreset('loading', 'Loading', 0.2, 500, [
    AnimPart(icon: '${_ui}refresh.svg', color: _purple, w: 0.9, h: 0.9, inKind: 'fade', inMs: 400, loop: 'spin'),
  ]),
  AnimIconPreset('arrow', 'Pointing arrow', 0.2, 600, [
    AnimPart(shape: 'arrow', color: _gold, w: 0.9, h: 0.9, rot: math.pi / 2, inKind: 'drop', inMs: 500, loop: 'bounce'),
  ]),
  AnimIconPreset('coin', 'Spinning coin', 0.2, 600, [
    AnimPart(icon: '${_ui}coin.svg', color: _gold, w: 0.9, h: 0.9, inKind: 'pop', inMs: 450, loop: 'flip'),
  ]),
  AnimIconPreset('stars', 'Star rating', 0.45, 1600, [
    AnimPart(shape: 'star', color: _gold, x: -0.4, w: 0.19, h: 0.19, at: 0, inMs: 350),
    AnimPart(shape: 'star', color: _gold, x: -0.2, w: 0.19, h: 0.19, at: 300, inMs: 350),
    AnimPart(shape: 'star', color: _gold, x: 0, w: 0.19, h: 0.19, at: 600, inMs: 350),
    AnimPart(shape: 'star', color: _gold, x: 0.2, w: 0.19, h: 0.19, at: 900, inMs: 350),
    AnimPart(shape: 'star', color: _gold, x: 0.4, w: 0.19, h: 0.19, at: 1200, inMs: 350),
  ]),
];

AnimIconPreset? animatedIconById(String id) {
  for (final p in kAnimatedIcons) {
    if (p.id == id) return p;
  }
  return null;
}

/// Makes the pieces of an animated icon as ordinary slide items. [aspect] is the slide's width divided by its
/// height. [base] is when the icon starts, [end] when it leaves (-1 = the end of the slide). [cx] and [cy] are
/// the middle of the icon as fractions of the slide.
Future<List<Layer>> buildAnimatedIcon(
  AnimIconPreset preset, {
  required double aspect,
  int base = 0,
  int end = -1,
  double cx = 0.5,
  double cy = 0.5,
  double? size,
}) async {
  // On a tall slide the icon may be wider, because the slide is narrow.
  final s = size ?? math.min(0.8, preset.size * (aspect < 1 ? 1.6 : 1.0));
  final layers = <Layer>[];
  for (final p in preset.parts) {
    var wf = s * p.w;
    var hf = s * p.h * aspect;
    String path = '';
    if (p.icon.isNotEmpty) {
      final raster = await rasterizeSvgAsset(p.icon);
      if (raster == null) return <Layer>[];
      path = raster.path;
      // Keep the picture's own shape inside the piece's box.
      final boxW = wf;
      final boxH = hf;
      wf = boxW;
      hf = wf * aspect / raster.aspect;
      if (hf > boxH) {
        hf = boxH;
        wf = hf * raster.aspect / aspect;
      }
    }
    final layer = Layer(
      id: newId(),
      type: p.icon.isNotEmpty ? 'image' : 'shape',
      cx: cx + p.x * s,
      cy: cy + p.y * s * aspect,
      w: wf,
      h: hf,
      rotation: p.rot,
      path: path,
      shape: p.icon.isNotEmpty ? 'tint' : p.shape,
      color: p.color,
      startMs: base + p.at,
      endMs: p.until < 0 ? end : base + p.until,
      animIn: p.inKind,
      animDurationMs: p.inMs,
      animOut: p.outKind,
      animOutDurationMs: p.outMs,
      animLoop: p.loop,
    );
    layers.add(layer);
  }
  return layers;
}
