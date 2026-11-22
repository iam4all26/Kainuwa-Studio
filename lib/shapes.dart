import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Extra flat shapes for the Add shape sheet. A layer of type 'shape' stores the id in Layer.shape.
class ShapeKind {
  const ShapeKind(this.id, this.label);

  final String id;
  final String label;
}

const List<ShapeKind> kShapeKinds = [
  ShapeKind('triangle', 'Triangle'),
  ShapeKind('diamond', 'Diamond'),
  ShapeKind('pentagon', 'Pentagon'),
  ShapeKind('hexagon', 'Hexagon'),
  ShapeKind('octagon', 'Octagon'),
  ShapeKind('star', 'Star'),
  ShapeKind('star4', 'Sparkle'),
  ShapeKind('heart', 'Heart'),
  ShapeKind('cross', 'Cross'),
  ShapeKind('arrow', 'Arrow'),
  ShapeKind('chevron', 'Chevron'),
  ShapeKind('ring', 'Ring'),
  ShapeKind('half', 'Half circle'),
  ShapeKind('trapezoid', 'Trapezoid'),
  ShapeKind('parallelogram', 'Slanted'),
  ShapeKind('bubble', 'Speech'),
  ShapeKind('moon', 'Moon'),
];

bool isPathShape(String id) => kShapeKinds.any((k) => k.id == id);

String shapeLabel(String id) {
  for (final k in kShapeKinds) {
    if (k.id == id) return k.label;
  }
  return 'Box';
}

/// A shape that fills a box: the box is the shape's bounding rectangle.
Path shapePath(String kind, Rect r) {
  final w = r.width;
  final h = r.height;
  Offset p(double fx, double fy) => Offset(r.left + w * fx, r.top + h * fy);
  Path poly(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path..close();
  }

  List<Offset> regular(int n, {double start = -math.pi / 2}) => [
        for (var i = 0; i < n; i++)
          Offset(
            r.center.dx + w / 2 * math.cos(start + 2 * math.pi * i / n),
            r.center.dy + h / 2 * math.sin(start + 2 * math.pi * i / n),
          ),
      ];
  List<Offset> starPts(int tips, double inner) => [
        for (var i = 0; i < tips * 2; i++)
          Offset(
            r.center.dx + (i.isEven ? 1.0 : inner) * w / 2 * math.cos(-math.pi / 2 + i * math.pi / tips),
            r.center.dy + (i.isEven ? 1.0 : inner) * h / 2 * math.sin(-math.pi / 2 + i * math.pi / tips),
          ),
      ];

  switch (kind) {
    case 'triangle':
      return poly([p(0.5, 0), p(1, 1), p(0, 1)]);
    case 'diamond':
      return poly([p(0.5, 0), p(1, 0.5), p(0.5, 1), p(0, 0.5)]);
    case 'pentagon':
      return poly(regular(5));
    case 'hexagon':
      return poly(regular(6, start: 0));
    case 'octagon':
      return poly(regular(8, start: math.pi / 8));
    case 'star':
      return poly(starPts(5, 0.45));
    case 'star4':
      return poly(starPts(4, 0.3));
    case 'heart':
      return Path()
        ..moveTo(r.left + w * 0.5, r.top + h * 0.95)
        ..cubicTo(r.left - w * 0.15, r.top + h * 0.55, r.left + w * 0.02, r.top - h * 0.02, r.left + w * 0.5, r.top + h * 0.28)
        ..cubicTo(r.right - w * 0.02, r.top - h * 0.02, r.right + w * 0.15, r.top + h * 0.55, r.left + w * 0.5, r.top + h * 0.95)
        ..close();
    case 'cross':
      return poly([
        p(0.33, 0), p(0.67, 0), p(0.67, 0.33), p(1, 0.33), p(1, 0.67), p(0.67, 0.67),
        p(0.67, 1), p(0.33, 1), p(0.33, 0.67), p(0, 0.67), p(0, 0.33), p(0.33, 0.33),
      ]);
    case 'arrow':
      return poly([p(0, 0.3), p(0.55, 0.3), p(0.55, 0), p(1, 0.5), p(0.55, 1), p(0.55, 0.7), p(0, 0.7)]);
    case 'chevron':
      return poly([p(0, 0), p(0.6, 0), p(1, 0.5), p(0.6, 1), p(0, 1), p(0.4, 0.5)]);
    case 'ring':
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(r)
        ..addOval(Rect.fromCenter(center: r.center, width: w * 0.56, height: h * 0.56));
    case 'half':
      return Path()
        ..moveTo(r.left, r.bottom)
        ..arcTo(Rect.fromLTWH(r.left, r.top, w, h * 2), math.pi, math.pi, false)
        ..close();
    case 'trapezoid':
      return poly([p(0.2, 0), p(0.8, 0), p(1, 1), p(0, 1)]);
    case 'parallelogram':
      return poly([p(0.25, 0), p(1, 0), p(0.75, 1), p(0, 1)]);
    case 'bubble':
      final body = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, w, h * 0.78), Radius.circular(math.min(w, h) * 0.2)));
      final tail = poly([p(0.2, 0.7), p(0.18, 1), p(0.45, 0.7)]);
      return Path.combine(PathOperation.union, body, tail);
    case 'moon':
      final a = Path()..addOval(r);
      final b = Path()..addOval(Rect.fromLTWH(r.left + w * 0.3, r.top - h * 0.05, w * 0.85, h * 1.1));
      return Path.combine(PathOperation.difference, a, b);
    default:
      return Path()..addRect(r);
  }
}

class ShapeFill extends StatelessWidget {
  const ShapeFill({super.key, required this.kind, required this.color});

  final String kind;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ShapeFillPainter(kind, color), child: const SizedBox.expand());
}

class _ShapeFillPainter extends CustomPainter {
  _ShapeFillPainter(this.kind, this.color);

  final String kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(shapePath(kind, Offset.zero & size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ShapeFillPainter old) => old.kind != kind || old.color != color;
}
