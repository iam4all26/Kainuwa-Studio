import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../scene_canvas.dart';
import '../theme.dart';
import 'editor_tools.dart';
import 'lesson_player.dart';

/// The four tracks of the multitrack timeline, in their default order.
const List<String> kDefaultTrackOrder = ['image', 'text', 'audio', 'video'];

String trackName(String id) {
  switch (id) {
    case 'image':
      return 'Image';
    case 'text':
      return 'Text';
    case 'audio':
      return 'Audio';
    default:
      return 'Video';
  }
}

IconData trackIcon(String id) {
  switch (id) {
    case 'image':
      return Icons.image_outlined;
    case 'text':
      return Icons.title;
    case 'audio':
      return Icons.headphones_outlined;
    default:
      return Icons.videocam_outlined;
  }
}

class _Clip {
  _Clip({
    required this.kind,
    required this.startMs,
    required this.endMs,
    required this.lane,
    required this.sceneIndex,
    this.layer,
    this.scene,
    this.label = '',
    this.seed = 1,
  });

  /// scene, layer, narration or music
  final String kind;
  final int startMs;
  final int endMs;
  final int lane;
  final int sceneIndex;
  final Layer? layer;
  final Scene? scene;
  final String label;
  final int seed;
}

class TimelinePanel extends StatefulWidget {
  const TimelinePanel({
    super.key,
    required this.lesson,
    required this.player,
    required this.order,
    required this.hidden,
    required this.selectedLayerId,
    required this.sceneSelected,
    required this.onSelectScene,
    required this.onSelectLayer,
    required this.onSceneMenu,
    required this.onSceneDuration,
    required this.onEditEnd,
    required this.onTrackMenu,
    required this.onToggleHidden,
    required this.onAddTrack,
    required this.onAddScene,
  });

  final Lesson lesson;
  final LessonPlayer player;
  final List<String> order;
  final Set<String> hidden;
  final String? selectedLayerId;
  final bool sceneSelected;
  final ValueChanged<int> onSelectScene;
  final void Function(int sceneIndex, String layerId) onSelectLayer;
  final ValueChanged<int> onSceneMenu;

  /// Live change of a scene length while a handle is dragged.
  final void Function(int sceneIndex, int ms) onSceneDuration;

  /// Called when a handle drag ends, so the change can be saved.
  final VoidCallback onEditEnd;
  final ValueChanged<String> onTrackMenu;
  final ValueChanged<String> onToggleHidden;
  final VoidCallback onAddTrack;
  final VoidCallback onAddScene;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  final ScrollController _scroll = ScrollController();
  double _zoom = 1.0;
  double _zoomStart = 1.0;
  double _pps = 22;

  // handle drag
  double _dragAccum = 0;
  int _dragStartThis = 0;
  int _dragStartPrev = 0;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_follow);
  }

  @override
  void didUpdateWidget(covariant TimelinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      oldWidget.player.removeListener(_follow);
      widget.player.addListener(_follow);
    }
  }

  @override
  void dispose() {
    widget.player.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the playhead on screen while the lesson plays.
  void _follow() {
    if (!widget.player.playing || !_scroll.hasClients) return;
    final x = widget.player.positionMs / 1000 * _pps;
    final position = _scroll.position;
    final left = position.pixels;
    final right = left + position.viewportDimension;
    if (x > right - 12 || x < left) {
      final target = (x - 24).clamp(0.0, position.maxScrollExtent).toDouble();
      _scroll.jumpTo(target);
    }
  }

  void _seekFromX(double dx) {
    widget.player.seek((dx / _pps * 1000).round());
  }

  String _pillText(int ms) {
    final totalTenths = ms ~/ 100;
    final tenths = totalTenths % 10;
    final seconds = (totalTenths ~/ 10) % 60;
    final minutes = totalTenths ~/ 600;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
  }

  // ---- building the clips of every track ----

  Map<String, List<_Clip>> _buildClips() {
    final lesson = widget.lesson;
    final image = <_Clip>[];
    final text = <_Clip>[];
    final audio = <_Clip>[];
    var start = 0;
    var anyNarration = false;
    for (var i = 0; i < lesson.scenes.length; i++) {
      final scene = lesson.scenes[i];
      final end = start + scene.durationMs;
      image.add(_Clip(
        kind: 'scene',
        startMs: start,
        endMs: end,
        lane: 0,
        sceneIndex: i,
        scene: scene,
        label: '${i + 1}',
      ));
      var imageLane = 1;
      var textLane = 0;
      for (final layer in scene.layers) {
        if (layer.type == 'text') {
          text.add(_Clip(
            kind: 'layer',
            startMs: start,
            endMs: end,
            lane: textLane++,
            sceneIndex: i,
            layer: layer,
            label: layerLabel(layer),
          ));
        } else {
          image.add(_Clip(
            kind: 'layer',
            startMs: start,
            endMs: end,
            lane: imageLane++,
            sceneIndex: i,
            layer: layer,
            label: layerLabel(layer),
          ));
        }
      }
      if (scene.narrationPath.isNotEmpty) {
        anyNarration = true;
        final length = scene.narrationMs > 0 ? math.min(scene.narrationMs, scene.durationMs) : scene.durationMs;
        audio.add(_Clip(
          kind: 'narration',
          startMs: start,
          endMs: start + length,
          lane: 0,
          sceneIndex: i,
          scene: scene,
          label: 'Narration',
          seed: scene.narrationPath.hashCode,
        ));
      }
      start = end;
    }
    if (lesson.musicPath.isNotEmpty) {
      audio.add(_Clip(
        kind: 'music',
        startMs: 0,
        endMs: start,
        lane: anyNarration ? 1 : 0,
        sceneIndex: 0,
        label: 'Music',
        seed: lesson.musicPath.hashCode,
      ));
    }
    return {'image': image, 'text': text, 'audio': audio, 'video': <_Clip>[]};
  }

  int _lanes(List<_Clip> clips) {
    var lanes = 1;
    for (final c in clips) {
      lanes = math.max(lanes, c.lane + 1);
    }
    return lanes;
  }

  // ---- handles on the selected slide clip ----

  Widget _grip(double u) {
    final d = math.max(2.5, 4 * u);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: d,
            height: d,
            margin: EdgeInsets.symmetric(vertical: d * 0.45),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
      ],
    );
  }

  Widget _handle({required bool left, required int index, required double u}) {
    final lesson = widget.lesson;
    final scene = lesson.scenes[index];
    final width = math.max(24.0, 40 * u);
    return Positioned(
      left: left ? 0.0 : null,
      right: left ? null : 0.0,
      top: 0,
      bottom: 0,
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _dragAccum = 0;
          _dragStartThis = scene.durationMs;
          _dragStartPrev = index > 0 ? lesson.scenes[index - 1].durationMs : 0;
        },
        onHorizontalDragUpdate: (d) {
          _dragAccum += d.delta.dx;
          var deltaMs = (_dragAccum / _pps * 1000);
          deltaMs = (deltaMs / 100).round() * 100.0;
          if (!left) {
            final minMs = math.max(500, scene.narrationMs);
            final ms = math.max(minMs, _dragStartThis + deltaMs.round());
            widget.onSceneDuration(index, ms);
          } else if (index > 0) {
            final prev = lesson.scenes[index - 1];
            final minPrev = math.max(500, prev.narrationMs);
            final minThis = math.max(500, scene.narrationMs);
            final low = (minPrev - _dragStartPrev).toDouble();
            final high = (_dragStartThis - minThis).toDouble();
            if (high >= low) {
              final delta = deltaMs.clamp(low, high).round();
              widget.onSceneDuration(index - 1, _dragStartPrev + delta);
              widget.onSceneDuration(index, _dragStartThis - delta);
            }
          }
        },
        onHorizontalDragEnd: (_) => widget.onEditEnd(),
        onHorizontalDragCancel: () => widget.onEditEnd(),
        child: Container(
          alignment: Alignment.center,
          color: const Color(0x33000000),
          child: (left && index == 0) ? const SizedBox.shrink() : _grip(u),
        ),
      ),
    );
  }

  // ---- one clip ----

  Widget _clipView(_Clip clip, double w, double h, double u) {
    final radius = BorderRadius.circular(math.max(6.0, 14 * u));
    final fontSize = math.max(10.5, 26 * u);
    Widget body;
    bool selected = false;
    VoidCallback? onTap;
    VoidCallback? onLong;

    switch (clip.kind) {
      case 'scene':
        selected = widget.sceneSelected && clip.sceneIndex == sceneIndexNow;
        onTap = () => widget.onSelectScene(clip.sceneIndex);
        onLong = () => widget.onSceneMenu(clip.sceneIndex);
        body = Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(child: SceneBackground(scene: clip.scene!)),
            Positioned(
              left: 6,
              top: 3,
              child: Text(
                clip.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: math.max(10.0, 22 * u),
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 4)],
                ),
              ),
            ),
          ],
        );
        break;
      case 'layer':
        final layer = clip.layer!;
        selected = !widget.sceneSelected && widget.selectedLayerId == layer.id;
        onTap = () => widget.onSelectLayer(clip.sceneIndex, layer.id);
        final isText = layer.type == 'text';
        final fg = isText ? KColors.ink : Colors.white;
        body = Container(
          color: isText ? KColors.clipText : KColors.clipPicture,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(layerIcon(layer), size: math.max(14.0, 34 * u), color: fg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  clip.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
        break;
      default:
        final music = clip.kind == 'music';
        onTap = () {
          widget.onSelectScene(clip.sceneIndex);
        };
        body = Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: music ? KColors.clipMusic : KColors.clipAudio),
            CustomPaint(painter: _WavePainter(seed: clip.seed)),
          ],
        );
    }

    Widget view = ClipRRect(borderRadius: radius, child: body);
    if (selected) {
      view = Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x663B0F8C), blurRadius: 6)],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(borderRadius: radius, child: body),
            if (clip.kind == 'scene') ...[
              _handle(left: true, index: clip.sceneIndex, u: u),
              _handle(left: false, index: clip.sceneIndex, u: u),
            ],
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLong,
      child: view,
    );
  }

  int get sceneIndexNow => sceneAt(widget.lesson, widget.player.positionMs).index;

  // ---- label column ----

  Widget _labelChip(String id, double height, double u, double labelW) {
    final hidden = widget.hidden.contains(id);
    final iconSize = math.max(16.0, 36 * u);
    return Container(
      width: labelW,
      height: height,
      decoration: BoxDecoration(
        color: KColors.editorLabel,
        borderRadius: BorderRadius.circular(math.max(8.0, 18 * u)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      padding: EdgeInsets.symmetric(horizontal: math.max(4.0, 10 * u)),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onToggleHidden(id),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: iconSize,
                color: KColors.ink,
              ),
            ),
          ),
          Icon(trackIcon(id), size: iconSize, color: KColors.ink),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                trackName(id),
                maxLines: 1,
                style: TextStyle(
                  fontSize: math.max(11.0, 27 * u),
                  fontWeight: FontWeight.w500,
                  color: KColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final u = width / 941.0;
        final labelLeft = 14 * u;
        final labelW = math.max(84.0, 214 * u);
        final stripLeft = labelLeft + labelW + 5 * u;
        final viewportW = width - stripLeft - 13 * u;
        _pps = (viewportW / 31.2) * _zoom;
        final pps = _pps;

        final rulerH = 128 * u;
        final baseRow = math.max(34.0, 70 * u);
        final pad = math.max(2.0, 2 * u);
        final clipH = baseRow - 2 * pad;
        final stride = clipH + pad;
        final rowGap = math.max(4.0, 10 * u);
        final addH = math.max(30.0, 52 * u);

        final clips = _buildClips();
        final totalMs = widget.lesson.durationMs;
        final contentW = math.max(viewportW, totalMs / 1000 * pps + 60 * u + clipH);

        final rowHeights = <String, double>{};
        for (final id in widget.order) {
          rowHeights[id] = baseRow + (_lanes(clips[id]!) - 1) * stride;
        }
        var rowsTotal = 0.0;
        for (final id in widget.order) {
          rowsTotal += rowHeights[id]! + rowGap;
        }
        final panelH = rulerH + rowsTotal + 12 * u + addH + 10 * u;

        // ---- scroll content (ruler, rows, playhead) ----
        final rows = <Widget>[];
        var top = rulerH;
        for (final id in widget.order) {
          final rowH = rowHeights[id]!;
          final hidden = widget.hidden.contains(id);
          final children = <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _seekFromX(d.localPosition.dx),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KColors.editorStrip,
                    borderRadius: BorderRadius.circular(math.max(8.0, 16 * u)),
                  ),
                ),
              ),
            ),
          ];
          for (final clip in clips[id]!) {
            final x = clip.startMs / 1000 * pps;
            final w = math.max(8.0, (clip.endMs - clip.startMs) / 1000 * pps - 2);
            children.add(Positioned(
              left: x,
              top: pad + clip.lane * stride,
              width: w,
              height: clipH,
              child: _clipView(clip, w, clipH, u),
            ));
          }
          if (id == 'video') {
            children.add(Positioned(
              left: 12 * u,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  'Screen recordings will appear here',
                  style: TextStyle(fontSize: math.max(10.0, 22 * u), color: const Color(0xFF8C80B8)),
                ),
              ),
            ));
          }
          if (id == 'image') {
            children.add(Positioned(
              left: totalMs / 1000 * pps + 6,
              top: pad,
              width: clipH,
              height: clipH,
              child: GestureDetector(
                onTap: widget.onAddScene,
                child: Container(
                  decoration: BoxDecoration(
                    color: KColors.lavender,
                    borderRadius: BorderRadius.circular(math.max(6.0, 14 * u)),
                    border: Border.all(color: KColors.purple, width: 1.2),
                  ),
                  child: const Icon(Icons.add, color: KColors.purple),
                ),
              ),
            ));
          }
          Widget row = SizedBox(width: contentW, height: rowH, child: Stack(children: children));
          if (hidden) row = Opacity(opacity: 0.4, child: row);
          rows.add(Positioned(left: 0, top: top, child: row));
          top += rowH + rowGap;
        }

        final playheadX = widget.player.positionMs / 1000 * pps;
        final pillW = math.max(64.0, 107 * u);
        final pillH = math.max(22.0, 42 * u);
        final lineW = math.max(2.0, 3 * u);

        final content = SizedBox(
          width: contentW,
          height: panelH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: contentW,
                height: rulerH,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _seekFromX(d.localPosition.dx),
                  onScaleStart: (_) => _zoomStart = _zoom,
                  onScaleUpdate: (d) {
                    if (d.pointerCount >= 2) {
                      setState(() => _zoom = (_zoomStart * d.scale).clamp(0.25, 6.0).toDouble());
                    }
                  },
                  child: CustomPaint(painter: _RulerPainter(pps: pps, u: u)),
                ),
              ),
              ...rows,
              Positioned(
                left: playheadX - lineW / 2,
                top: 66 * u,
                width: lineW,
                height: panelH - 66 * u - 6 * u,
                child: IgnorePointer(child: ColoredBox(color: KColors.editorPlayhead)),
              ),
              Positioned(
                left: playheadX - pillW / 2 - 12,
                top: 26 * u,
                width: pillW + 24,
                height: pillH + 10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    final ms = widget.player.positionMs + (d.delta.dx / pps * 1000).round();
                    widget.player.seek(ms);
                  },
                  child: Center(
                    child: Container(
                      width: pillW,
                      height: pillH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KColors.editorPlay,
                        borderRadius: BorderRadius.circular(pillH),
                        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 1))],
                      ),
                      child: Text(
                        _pillText(widget.player.positionMs),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: math.max(10.0, 24 * u),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        // ---- fixed left column ----
        final labels = <Widget>[SizedBox(height: rulerH)];
        for (final id in widget.order) {
          labels.add(_labelChip(id, rowHeights[id]!, u, labelW));
          labels.add(SizedBox(height: rowGap));
        }
        labels.add(SizedBox(height: 12 * u));
        labels.add(
          GestureDetector(
            onTap: widget.onAddTrack,
            child: CustomPaint(
              painter: _DashedBorderPainter(color: const Color(0xFF9A8FC2), radius: math.max(8.0, 16 * u)),
              child: SizedBox(
                width: math.max(labelW - 6 * u, 80),
                height: addH,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: math.max(16.0, 34 * u), color: KColors.ink),
                    const SizedBox(width: 4),
                    Text(
                      'Add Track',
                      style: TextStyle(
                        fontSize: math.max(10.5, 25 * u),
                        fontWeight: FontWeight.w500,
                        color: KColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // ---- fixed menu icons at the right edge of every row ----
        final menus = <Widget>[];
        var menuTop = rulerH;
        for (final id in widget.order) {
          final rowH = rowHeights[id]!;
          menus.add(Positioned(
            right: 6 * u,
            top: menuTop,
            height: baseRow,
            width: math.max(32.0, 60 * u),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTrackMenu(id),
              child: Center(
                child: Icon(Icons.menu, size: math.max(16.0, 34 * u), color: const Color(0xFF5B4A8A)),
              ),
            ),
          ));
          menuTop += rowH + rowGap;
        }

        return SizedBox(
          height: panelH,
          child: Stack(
            children: [
              Positioned(left: labelLeft, top: 0, width: labelW, height: panelH, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: labels)),
              Positioned(
                left: stripLeft,
                right: 13 * u,
                top: 0,
                height: panelH,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: content,
                      ),
                    ),
                    ...menus,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// painters
// ---------------------------------------------------------------------------

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.pps, required this.u});

  final double pps;
  final double u;

  static const List<int> _steps = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600];

  @override
  void paint(Canvas canvas, Size size) {
    var step = _steps.last;
    for (final s in _steps) {
      if (s * pps >= 100 * u) {
        step = s;
        break;
      }
    }
    final minor = step / 5.0;
    final tickPaint = Paint()
      ..color = const Color(0xFF9B93B8)
      ..strokeWidth = math.max(1.0, 2 * u);
    final seconds = size.width / pps;
    final count = (seconds / minor).ceil() + 1;
    for (var i = 0; i < count; i++) {
      final sec = i * minor;
      final x = sec * pps;
      if (x > size.width) break;
      final major = i % 5 == 0;
      final y1 = 73 * u;
      final y2 = major ? 98 * u : 86 * u;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), tickPaint);
      if (major) {
        final total = sec.round();
        final label = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: const Color(0xFF3A3358),
              fontSize: math.max(10.0, 24 * u),
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x - painter.width / 2, 53 * u - painter.height / 2));
        painter.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.pps != pps || oldDelegate.u != u;
}

/// A look-alike waveform. It is drawn from the file name, not from the sound itself.
class _WavePainter extends CustomPainter {
  _WavePainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;
    final mid = size.height / 2;
    final count = (size.width / 5).floor();
    for (var i = 0; i < count; i++) {
      final r = (((i * 2654435761) ^ (seed * 40503)) >> 3) & 0xFF;
      final env = 0.35 + 0.65 * (math.sin(i * 0.23 + (seed & 7)) * 0.5 + 0.5);
      final amp = math.max(2.0, (r / 255.0) * env * (size.height * 0.42));
      final x = 4.0 + i * 5.0;
      canvas.drawLine(Offset(x, mid - amp), Offset(x, mid + amp), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.seed != seed;
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
