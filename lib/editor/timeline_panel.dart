import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animation_math.dart';
import '../models.dart';
import '../scene_canvas.dart';
import '../theme.dart';
import 'editor_tools.dart';
import 'lesson_player.dart';
import 'peaks_cache.dart';

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
    this.audio,
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
  final AudioClip? audio;
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
    required this.selectedAudioId,
    required this.sceneSelected,
    required this.selectedSound,
    required this.onSelectSound,
    required this.onSelectScene,
    required this.onSelectLayer,
    this.multiIds = const <String>{},
    required this.onSelectAudio,
    required this.onSceneMenu,
    required this.onSceneDuration,
    required this.onEditEnd,
    required this.onLayerTiming,
    required this.onAudioChanged,
    required this.onTrackMenu,
    required this.onToggleHidden,
    required this.onAddTrack,
    required this.onAddScene,
    required this.onTransition,
    this.maxUnit = double.infinity,
  });

  /// Upper limit for the size unit, so a wide landscape screen does not make the tracks huge.
  final double maxUnit;
  final Lesson lesson;
  final LessonPlayer player;
  final List<String> order;
  final Set<String> hidden;
  final String? selectedLayerId;
  final String? selectedAudioId;
  final bool sceneSelected;

  /// 'music' or 'narration:<scene index>' when a sound strip is selected.
  final String? selectedSound;
  final void Function(String kind, int sceneIndex) onSelectSound;
  final ValueChanged<int> onSelectScene;
  final void Function(int sceneIndex, String layerId) onSelectLayer;

  /// Items chosen with "Select many": they are drawn as selected.
  final Set<String> multiIds;
  final ValueChanged<String> onSelectAudio;
  final ValueChanged<int> onSceneMenu;

  /// Live change of a scene length while a handle is dragged.
  final void Function(int sceneIndex, int ms) onSceneDuration;

  /// Called when a handle drag ends, so the change can be saved.
  final VoidCallback onEditEnd;

  /// An item's start or end was changed on the timeline (live, not yet saved).
  final VoidCallback onLayerTiming;

  /// An extra audio clip was moved or trimmed (live, not yet saved).
  final VoidCallback onAudioChanged;
  final ValueChanged<String> onTrackMenu;
  final ValueChanged<String> onToggleHidden;
  final VoidCallback onAddTrack;
  final VoidCallback onAddScene;

  /// Opens the transition settings for the join after the slide with this index.
  final ValueChanged<int> onTransition;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  final ScrollController _scroll = ScrollController();
  double _zoom = 1.0;
  double _zoomStart = 1.0;

  // While the user touches or scrolls the timeline, the view does not follow the playhead.
  DateTime _followHoldUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Offset? _tapDown;
  DateTime _tapTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _holdFollow(int ms) {
    _followHoldUntil = DateTime.now().add(Duration(milliseconds: ms));
  }
  double _pps = 22;

  // handle drag
  double _dragAccum = 0;
  int _dragStartThis = 0;
  int _dragStartPrev = 0;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_follow);
    PeaksCache.instance.addListener(_peaksReady);
  }

  void _peaksReady() {
    if (mounted) setState(() {});
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
    PeaksCache.instance.removeListener(_peaksReady);
    _edgeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the playhead on screen while the lesson plays.
  void _follow() {
    if (!widget.player.playing || !_scroll.hasClients) return;
    if (DateTime.now().isBefore(_followHoldUntil)) return;
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
    final video = <_Clip>[];
    var start = 0;
    var anyNarration = false;
    for (var i = 0; i < lesson.scenes.length; i++) {
      final scene = lesson.scenes[i];
      final end = start + scene.durationMs;
      if (scene.hasVideo) {
        video.add(_Clip(
          kind: 'scene',
          startMs: start,
          endMs: end,
          lane: 0,
          sceneIndex: i,
          scene: scene,
          label: 'Video',
        ));
      }
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
      final textLaneEnds = <int>[];
      for (final layer in scene.layers) {
        final dur = scene.durationMs;
        final from = layer.startMs.clamp(0, math.max(0, dur - 200)).toInt();
        final to = math.max(from + 200, layerEndMs(layer, dur));
        if (layer.type == 'text') {
          text.add(_Clip(
            kind: 'layer',
            startMs: start + from,
            endMs: start + math.min(to, dur),
            lane: lesson.setupKind == 'lyrics'
                ? _packLane(textLaneEnds, start + from, start + math.min(to, dur))
                : textLane++,
            sceneIndex: i,
            layer: layer,
            label: layerLabel(layer),
          ));
        } else {
          image.add(_Clip(
            kind: 'layer',
            startMs: start + from,
            endMs: start + math.min(to, dur),
            lane: imageLane++,
            sceneIndex: i,
            layer: layer,
            label: layerLabel(layer),
          ));
        }
      }
      if (scene.narrationPath.isNotEmpty) {
        anyNarration = true;
        final length = scene.narrationMs > 0 ? math.min(scene.narrationLenMs, scene.durationMs) : scene.durationMs;
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
    // extra clips of the Audio track, packed into lanes below the rest
    final firstLane = (anyNarration ? 1 : 0) + (lesson.musicPath.isNotEmpty ? 1 : 0);
    final laneEnds = <int>[];
    final sorted = List<AudioClip>.of(lesson.audioClips)..sort((a, b) => a.startMs.compareTo(b.startMs));
    for (final ac in sorted) {
      var lane = laneEnds.indexWhere((end) => end <= ac.startMs);
      if (lane < 0) {
        laneEnds.add(ac.endMs);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = ac.endMs;
      }
      audio.add(_Clip(
        kind: 'audioclip',
        startMs: ac.startMs,
        endMs: math.max(ac.startMs + 200, ac.endMs),
        lane: firstLane + lane,
        sceneIndex: 0,
        audio: ac,
        label: ac.label,
        seed: ac.path.hashCode,
      ));
    }
    return {'image': image, 'text': text, 'audio': audio, 'video': video};
  }

  /// Puts a clip on the first row where it does not overlap another one. Lyrics use this so
  /// the words follow each other on one row instead of every word having its own row.
  int _packLane(List<int> ends, int startMs, int endMs) {
    final lane = ends.indexWhere((end) => end <= startMs);
    if (lane < 0) {
      ends.add(endMs);
      return ends.length - 1;
    }
    ends[lane] = endMs;
    return lane;
  }

  int _lanes(List<_Clip> clips) {
    var lanes = 1;
    for (final c in clips) {
      lanes = math.max(lanes, c.lane + 1);
    }
    return lanes;
  }

  // ---- handles on the selected slide clip ----

  /// Touch width of a drag handle: enough for a thumb, but never more than a quarter of a short clip.
  double _handleWidth(double u, double clipW) =>
      math.min(math.max(24.0, 30 * u), math.max(14.0, clipW * 0.25));

  /// The end handle of a selected clip: a thin white strip on the outer edge with a dark bar.
  /// The touch area is wider than the white strip, so the clip itself stays visible.
  Widget _handleBox(bool left, double u, {bool plain = false}) {
    if (plain) return const SizedBox.shrink();
    final r = Radius.circular(math.max(4.0, 6 * u));
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        heightFactor: 1.0,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: left
                ? BorderRadius.only(topLeft: r, bottomLeft: r)
                : BorderRadius.only(topRight: r, bottomRight: r),
          ),
          child: Container(
            width: 2.5,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF5B21B6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

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

  void _applySceneHandle(int index, bool left) {
    final lesson = widget.lesson;
    final scene = lesson.scenes[index];
    var deltaMs = ((_dragAccum + _scrolled()) / _pps * 1000);
    deltaMs = (deltaMs / 100).round() * 100.0;
    if (!left) {
      final minMs = math.max(500, scene.narrationLenMs);
      final ms = math.max(minMs, _dragStartThis + deltaMs.round());
      widget.onSceneDuration(index, ms);
    } else if (index > 0) {
      final prev = lesson.scenes[index - 1];
      final minPrev = math.max(500, prev.narrationLenMs);
      final minThis = math.max(500, scene.narrationLenMs);
      final low = (minPrev - _dragStartPrev).toDouble();
      final high = (_dragStartThis - minThis).toDouble();
      if (high >= low) {
        final delta = deltaMs.clamp(low, high).round();
        widget.onSceneDuration(index - 1, _dragStartPrev + delta);
        widget.onSceneDuration(index, _dragStartThis - delta);
      }
    }
  }

  Widget _handle({required bool left, required int index, required double u, double cw = 200}) {
    final lesson = widget.lesson;
    final scene = lesson.scenes[index];
    final width = _handleWidth(u, cw);
    return Positioned(
      left: left ? 0.0 : null,
      right: left ? null : 0.0,
      top: 0,
      bottom: 0,
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          _dragAccum = 0;
          _dragStartThis = scene.durationMs;
          _dragStartPrev = index > 0 ? lesson.scenes[index - 1].durationMs : 0;
          _beginEdgeDrag(d.globalPosition.dx, () => _applySceneHandle(index, left));
        },
        onHorizontalDragUpdate: (d) {
          _dragAccum += d.delta.dx;
          _fingerGx = d.globalPosition.dx;
          _applySceneHandle(index, left);
        },
        onHorizontalDragEnd: (_) {
          _endEdgeDrag();
          widget.onEditEnd();
        },
        onHorizontalDragCancel: () {
          _endEdgeDrag();
          widget.onEditEnd();
        },
        child: _handleBox(left, u, plain: left && index == 0),
      ),
    );
  }

  // ---- handles and moving of a selected item ----

  int _layerStartA = 0;
  bool _movingLayer = false;
  int? _dropScene;
  int _layerStartB = 0;

  // Moving an item to another slide: the slide under the FINGER is the target.
  int _moveFrom = 0;
  double _pressAbsMs = 0;
  double _pressInItemMs = 0;
  double _scrollAtPress = 0;
  double _fingerDx = 0;
  double _fingerGx = 0;
  Timer? _edgeTimer;

  // Any drag on a handle or on the playhead: the view scrolls by itself when the finger is near an edge.
  double _scrollBase = 0;
  bool _dragging = false;
  VoidCallback? _reapply;
  int _headGrab = 0;

  void _beginEdgeDrag(double gx, VoidCallback reapply) {
    _scrollBase = _scroll.hasClients ? _scroll.offset : 0;
    _fingerGx = gx;
    _dragging = true;
    _reapply = reapply;
    _holdFollow(5000);
    _startEdgeScroll();
  }

  void _endEdgeDrag() {
    _dragging = false;
    _reapply = null;
    if (!_movingLayer && !_extending) _edgeTimer?.cancel();
  }

  /// The lesson time (ms) under a finger at the global x, counting the scroll of the timeline.
  int _fingerMs(double gx) {
    if (!_scroll.hasClients) return 0;
    final box = _scroll.position.context.storageContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    final x = box.globalToLocal(Offset(gx, 0)).dx + _scroll.offset;
    return (x / _pps * 1000).round();
  }

  void _seekToFinger() {
    widget.player.seek(math.max(0, _fingerMs(_fingerGx) + _headGrab));
  }

  /// Lesson time (ms) under the finger now, counting any scrolling done since the press.
  double _fingerAbsMs() {
    final scrolled = _scroll.hasClients ? _scroll.offset - _scrollAtPress : 0.0;
    return _pressAbsMs + (_fingerDx + scrolled) / _pps * 1000;
  }

  void _refreshTarget() {
    final total = widget.lesson.durationMs;
    final raw = _extending ? _extBaseEndAbs + (_fingerDx + _scrolledSincePress()) / _pps * 1000 - 1 : _fingerAbsMs();
    final abs = raw.round().clamp(0, math.max(0, total - 1)).toInt();
    final target = sceneAt(widget.lesson, abs).index;
    if (target != _dropScene) {
      HapticFeedback.selectionClick();
      setState(() => _dropScene = target);
    }
  }

  /// Scrolls the timeline while the finger is near its left or right edge, so far slides can be reached.
  void _startEdgeScroll() {
    _edgeTimer?.cancel();
    _edgeTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !(_movingLayer || _extending || _dragging) || !_scroll.hasClients) return;
      final box = _scroll.position.context.storageContext.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final left = box.localToGlobal(Offset.zero).dx;
      final right = left + box.size.width;
      const edge = 72.0;
      var v = 0.0;
      if (_fingerGx > right - edge) {
        v = (_fingerGx - (right - edge)) / edge;
      } else if (_fingerGx < left + edge) {
        v = -((left + edge) - _fingerGx) / edge;
      }
      if (v == 0) return;
      final pos = _scroll.position;
      final next = (pos.pixels + v.clamp(-1.0, 1.0) * 30).clamp(0.0, pos.maxScrollExtent).toDouble();
      if (next != pos.pixels) {
        _scroll.jumpTo(next);
        _holdFollow(3000);
        if (_movingLayer || _extending) _refreshTarget();
        _reapply?.call();
      }
    });
  }

  void _layerDragStart(Layer layer, int sceneMs) {
    _dragAccum = 0;
    _layerStartA = layer.startMs;
    _layerStartB = layerEndMs(layer, sceneMs);
    _scrollBase = _scroll.hasClients ? _scroll.offset : 0;
    _collectSnaps(layer, sceneMs);
  }

  // ---- snapping: an item edge is pulled to the slide edges, the playhead and the other items ----

  List<int> _snapPts = <int>[];
  int _lastSnapped = -1;

  void _collectSnaps(Layer layer, int sceneMs) {
    final lesson = widget.lesson;
    _snapPts = <int>[0, sceneMs];
    _lastSnapped = -1;
    for (var i = 0; i < lesson.scenes.length; i++) {
      final scene = lesson.scenes[i];
      if (!scene.layers.contains(layer)) continue;
      final head = widget.player.positionMs - sceneStartMs(lesson, i);
      if (head > 0 && head < sceneMs) _snapPts.add(head);
      for (final other in scene.layers) {
        if (identical(other, layer)) continue;
        _snapPts.add(other.startMs);
        _snapPts.add(layerEndMs(other, scene.durationMs));
      }
      break;
    }
  }

  /// The snap point within a few pixels of [ms], or null.
  int? _nearest(int ms) {
    final tol = (8 / _pps * 1000).round();
    int? best;
    var bestD = tol + 1;
    for (final p in _snapPts) {
      final d = (p - ms).abs();
      if (d < bestD) {
        best = p;
        bestD = d;
      }
    }
    return best;
  }

  void _buzz(int? point) {
    if (point == null) {
      _lastSnapped = -1;
    } else if (point != _lastSnapped) {
      _lastSnapped = point;
      HapticFeedback.selectionClick();
    }
  }

  /// Zooms the timeline and keeps the playhead in the middle of the view.
  void _zoomTo(double value) {
    setState(() => _zoom = value.clamp(0.1, 30.0).toDouble());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final x = widget.player.positionMs / 1000 * _pps - pos.viewportDimension / 2;
      _scroll.jumpTo(x.clamp(0.0, pos.maxScrollExtent).toDouble());
    });
  }

  Widget _zoomButton(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: KColors.editorLabel,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      ),
    );
  }

  /// How far the timeline has scrolled since the current drag began. The edge auto-scroll adds this,
  /// so an item keeps following the finger while the view moves under it.
  double _scrolled() => _scroll.hasClients ? _scroll.offset - _scrollBase : 0.0;

  double _roundedDelta() => (((_dragAccum + _scrolled()) / _pps * 1000) / 100).round() * 100.0;

  void _layerTrim(Layer layer, int sceneMs, {required bool left}) {
    final delta = _roundedDelta().round();
    if (left) {
      final snap = _nearest(_layerStartA + delta);
      _buzz(snap);
      layer.startMs = (snap ?? _layerStartA + delta).clamp(0, math.max(0, _layerStartB - 200)).toInt();
    } else {
      final snap = _nearest(_layerStartB + delta);
      _buzz(snap);
      final end = (snap ?? _layerStartB + delta).clamp(_layerStartA + 200, sceneMs).toInt();
      layer.endMs = end >= sceneMs ? -1 : end;
    }
    widget.onLayerTiming();
  }

  void _layerMove(Layer layer, int sceneMs) {
    var delta = _roundedDelta().round();
    // Either end of the item may snap; the nearer one wins.
    final a = _layerStartA + delta;
    final b = _layerStartB + delta;
    final sa = _nearest(a);
    final sb = _nearest(b);
    if (sa != null && (sb == null || (sa - a).abs() <= (sb - b).abs())) {
      delta += sa - a;
      _buzz(sa);
    } else if (sb != null) {
      delta += sb - b;
      _buzz(sb);
    } else {
      _buzz(null);
    }
    delta = delta.clamp(-_layerStartA, sceneMs - _layerStartB).toInt();
    layer.startMs = _layerStartA + delta;
    final end = _layerStartB + delta;
    layer.endMs = end >= sceneMs ? -1 : end;
    widget.onLayerTiming();
  }

  // ---- an item that continues over several slides (drag the grip at its right end) ----

  bool _extending = false;
  double _extBaseEndAbs = 0;

  double _scrolledSincePress() => _scroll.hasClients ? _scroll.offset - _scrollAtPress : 0.0;

  void _extendStart(Layer layer, int pieceScene, int sceneMs, double gx) {
    _layerDragStart(layer, sceneMs);
    _extBaseEndAbs = (sceneStartMs(widget.lesson, pieceScene) + _layerStartB).toDouble();
    _scrollAtPress = _scroll.hasClients ? _scroll.offset : 0;
    _fingerDx = 0;
    _fingerGx = gx;
    _extending = true;
    setState(() => _dropScene = pieceScene);
    _reapply = () => _layerTrim(layer, sceneMs, left: false);
    _startEdgeScroll();
  }

  void _extendUpdate(Layer layer, int sceneMs, double gx) {
    _fingerDx = _dragAccum;
    _fingerGx = gx;
    _layerTrim(layer, sceneMs, left: false);
    _refreshTarget();
  }

  void _extendEnd(Layer piece, int pieceScene) {
    _edgeTimer?.cancel();
    if (!_extending) return;
    var endAbs = _extBaseEndAbs + (_fingerDx + _scrolledSincePress()) / _pps * 1000;
    endAbs = ((endAbs / 100).round() * 100).toDouble();
    setState(() {
      _extending = false;
      _dropScene = null;
    });
    _applyChain(piece, pieceScene, endAbs.round());
  }

  /// Makes the item (and its continuation pieces) end at the lesson time [endAbs].
  /// Beyond the end of its slide the item gets a copy on each following slide, with no new
  /// entrance animation, so it looks like one item that just carries on.
  void _applyChain(Layer piece, int pieceScene, int endAbs) {
    final lesson = widget.lesson;
    final total = lesson.durationMs;
    // The first piece of the chain.
    Layer head = piece;
    var headScene = pieceScene;
    if (piece.linkId.isNotEmpty) {
      var found = false;
      for (var i = 0; i < lesson.scenes.length && !found; i++) {
        for (final l in lesson.scenes[i].layers) {
          if (l.linkId == piece.linkId) {
            head = l;
            headScene = i;
            found = true;
            break;
          }
        }
      }
    }
    // The last piece holds the exit animation; remember it, then remove the continuation pieces.
    var outAnim = head.animOut;
    var outDur = head.animOutDurationMs;
    if (head.linkId.isNotEmpty) {
      for (var i = headScene + 1; i < lesson.scenes.length; i++) {
        final gone = lesson.scenes[i].layers.where((l) => l.linkId == head.linkId).toList();
        for (final l in gone) {
          outAnim = l.animOut;
          outDur = l.animOutDurationMs;
          lesson.scenes[i].layers.remove(l);
        }
      }
    }
    final headStart = sceneStartMs(lesson, headScene);
    final headMs = lesson.scenes[headScene].durationMs;
    final minEnd = headStart + head.startMs + 200;
    final end = endAbs.clamp(minEnd, math.max(minEnd, total)).toInt();
    if (end <= headStart + headMs) {
      // Fits inside its own slide: a normal item again.
      final local = end - headStart;
      head.endMs = local >= headMs ? -1 : local;
      head.animOut = outAnim;
      head.animOutDurationMs = outDur;
      head.linkId = '';
    } else {
      final link = head.linkId.isNotEmpty ? head.linkId : newId();
      head.linkId = link;
      head.endMs = -1;
      head.animOut = 'none';
      final order = lesson.scenes[headScene].layers.indexOf(head);
      for (var k = headScene + 1; k < lesson.scenes.length; k++) {
        final s0 = sceneStartMs(lesson, k);
        if (s0 >= end) break;
        final dur = lesson.scenes[k].durationMs;
        final isLast = end <= s0 + dur;
        final p = head.copy();
        p.linkId = link;
        p.startMs = 0;
        p.animIn = 'none';
        p.animStartMs = 0;
        p.textAnim = 'none';
        p.hand = '';
        p.endMs = isLast ? ((end - s0) >= dur ? -1 : end - s0) : -1;
        p.animOut = isLast ? outAnim : 'none';
        p.animOutDurationMs = outDur;
        final list = lesson.scenes[k].layers;
        list.insert(math.min(math.max(order, 0), list.length), p);
      }
    }
    widget.onSelectLayer(headScene, head.id);
  }

  Widget _layerHandle({required bool left, required Layer layer, required int sceneIndex, required int sceneMs, required double u, double cw = 200}) {
    final width = _handleWidth(u, cw);
    return Positioned(
      left: left ? 0.0 : null,
      right: left ? null : 0.0,
      top: 0,
      bottom: 0,
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          if (left) {
            _layerDragStart(layer, sceneMs);
            _beginEdgeDrag(d.globalPosition.dx, () => _layerTrim(layer, sceneMs, left: true));
          } else {
            _extendStart(layer, sceneIndex, sceneMs, d.globalPosition.dx);
          }
        },
        onHorizontalDragUpdate: (d) {
          _dragAccum += d.delta.dx;
          _fingerGx = d.globalPosition.dx;
          if (left) {
            _layerTrim(layer, sceneMs, left: true);
          } else {
            _extendUpdate(layer, sceneMs, d.globalPosition.dx);
          }
        },
        onHorizontalDragEnd: (_) {
          if (!left) _extendEnd(layer, sceneIndex);
          _endEdgeDrag();
          widget.onEditEnd();
        },
        onHorizontalDragCancel: () {
          if (!left) _extendEnd(layer, sceneIndex);
          _endEdgeDrag();
          widget.onEditEnd();
        },
        child: _handleBox(left, u),
      ),
    );
  }

  // ---- extra audio clips: move and trim ----

  int _aStart = 0;
  int _aTrim = 0;
  int _aDur = 0;

  void _audioDragStart(AudioClip ac) {
    _dragAccum = 0;
    _scrollBase = _scroll.hasClients ? _scroll.offset : 0;
    _aStart = ac.startMs;
    _aTrim = ac.trimMs;
    _aDur = ac.durationMs;
  }

  void _audioMove(AudioClip ac) {
    final total = widget.lesson.durationMs;
    ac.startMs = (_aStart + _roundedDelta().round()).clamp(0, math.max(0, total - 300)).toInt();
    widget.onAudioChanged();
  }

  void _audioTrim(AudioClip ac, {required bool left}) {
    final delta = _roundedDelta().round();
    if (left) {
      final low = math.max(-_aTrim, -_aStart);
      final high = _aDur - 300;
      if (high >= low) {
        final applied = delta.clamp(low, high).toInt();
        ac.trimMs = _aTrim + applied;
        ac.startMs = _aStart + applied;
        ac.durationMs = _aDur - applied;
      }
    } else {
      final high = math.max(300, ac.sourceMs - ac.trimMs);
      ac.durationMs = (_aDur + delta).clamp(300, high).toInt();
    }
    final half = ac.durationMs ~/ 2;
    if (ac.fadeInMs > half) ac.fadeInMs = half;
    if (ac.fadeOutMs > half) ac.fadeOutMs = half;
    widget.onAudioChanged();
  }

  Widget _audioHandle({required bool left, required AudioClip ac, required double u, double cw = 200}) {
    final width = _handleWidth(u, cw);
    return Positioned(
      left: left ? 0.0 : null,
      right: left ? null : 0.0,
      top: 0,
      bottom: 0,
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          _audioDragStart(ac);
          _beginEdgeDrag(d.globalPosition.dx, () => _audioTrim(ac, left: left));
        },
        onHorizontalDragUpdate: (d) {
          _dragAccum += d.delta.dx;
          _fingerGx = d.globalPosition.dx;
          _audioTrim(ac, left: left);
        },
        onHorizontalDragEnd: (_) {
          _endEdgeDrag();
          widget.onEditEnd();
        },
        onHorizontalDragCancel: () {
          _endEdgeDrag();
          widget.onEditEnd();
        },
        child: _handleBox(left, u),
      ),
    );
  }

  // ---- one clip ----

  Widget _clipView(_Clip clip, double w, double h, double u) {
    final radius = BorderRadius.circular(math.max(4.0, 8 * u));
    final fontSize = math.max(10.5, 26 * u);
    Widget body;
    bool selected = false;
    VoidCallback? onTap;
    VoidCallback? onLong;
    // Moving an item needs a press and hold first, so a plain swipe always scrolls the timeline.
    void Function(Offset local, double gx)? moveStart;
    void Function(double dx, double gx)? moveUpdate;
    VoidCallback? moveEnd;

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
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 4)],
                ),
              ),
            ),
          ],
        );
        break;
      case 'layer':
        final layer = clip.layer!;
        selected = (!widget.sceneSelected && widget.selectedLayerId == layer.id) || widget.multiIds.contains(layer.id);
        onTap = () => widget.onSelectLayer(clip.sceneIndex, layer.id);
        {
          final fromScene = clip.sceneIndex;
          final sceneMs = widget.lesson.scenes[fromScene].durationMs;
          moveStart = (local, gx) {
            if (!selected) widget.onSelectLayer(fromScene, layer.id);
            _layerDragStart(layer, sceneMs);
            // The slide is chosen by where the FINGER is, not by where the item bar is.
            _pressInItemMs = local.dx / _pps * 1000;
            _pressAbsMs = clip.startMs + _pressInItemMs;
            _scrollAtPress = _scroll.hasClients ? _scroll.offset : 0;
            _fingerDx = 0;
            _fingerGx = gx;
            _moveFrom = fromScene;
            setState(() {
              _movingLayer = true;
              _dropScene = fromScene;
            });
            HapticFeedback.mediumImpact();
            _reapply = () => _layerMove(layer, sceneMs);
            _startEdgeScroll();
          };
          moveUpdate = (dx, gx) {
            if (!_movingLayer) return;
            _dragAccum = dx;
            _fingerDx = dx;
            _fingerGx = gx;
            _layerMove(layer, sceneMs);
            _refreshTarget();
          };
          moveEnd = () {
            if (!_movingLayer) return;
            _reapply = null;
            _edgeTimer?.cancel();
            _refreshTarget();
            final to = _dropScene ?? fromScene;
            final fingerAbs = _fingerAbsMs();
            setState(() {
              _movingLayer = false;
              _dropScene = null;
            });
            if (to != fromScene) {
              // Dropped on another slide: the item goes there, starting where the finger let go.
              final lesson = widget.lesson;
              final toMs = lesson.scenes[to].durationMs;
              final dur = _layerStartB - _layerStartA;
              final raw = (fingerAbs - _pressInItemMs - sceneStartMs(lesson, to)).round();
              final local = ((raw / 100).round() * 100).clamp(0, math.max(0, toMs - 300)).toInt();
              final end = local + dur;
              layer.startMs = local;
              layer.endMs = end >= toMs ? -1 : end;
              lesson.scenes[fromScene].layers.remove(layer);
              lesson.scenes[to].layers.add(layer);
              widget.onSelectLayer(to, layer.id);
            }
            widget.onEditEnd();
          };
        }
        final isText = layer.type == 'text';
        final fg = isText ? KColors.onGold : Colors.white;
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
                  style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
        break;
      case 'audioclip':
        {
          final ac = clip.audio!;
          selected = widget.selectedAudioId == ac.id;
          onTap = () => widget.onSelectAudio(ac.id);
          final color = ac.kind == 'sfx'
              ? const Color(0xFFD9822B)
              : (ac.kind == 'voice' ? KColors.clipAudio : KColors.clipMusic);
          final from = ac.sourceMs <= 0 ? 0.0 : ac.trimMs / ac.sourceMs;
          final to = ac.sourceMs <= 0 ? 1.0 : (ac.trimMs + ac.durationMs) / ac.sourceMs;
          body = Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: color),
              CustomPaint(
                painter: _WavePainter(
                  seed: clip.seed,
                  peaks: PeaksCache.instance.peaksFor(ac.path),
                  from: from,
                  to: to,
                ),
              ),
              Positioned(
                left: 6,
                top: 2,
                right: 6,
                child: Text(
                  clip.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: math.max(9.5, 20 * u),
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 3)],
                  ),
                ),
              ),
            ],
          );
          moveStart = (local, gx) {
            if (!selected) widget.onSelectAudio(ac.id);
            _audioDragStart(ac);
            _beginEdgeDrag(gx, () => _audioMove(ac));
          };
          moveUpdate = (dx, gx) {
            _dragAccum = dx;
            _fingerGx = gx;
            _audioMove(ac);
          };
          moveEnd = () {
            _endEdgeDrag();
            widget.onEditEnd();
          };
        }
        break;
      default:
        final music = clip.kind == 'music';
        final soundKey = music ? 'music' : 'narration:${clip.sceneIndex}';
        selected = widget.selectedSound == soundKey;
        onTap = () {
          widget.onSelectSound(music ? 'music' : 'narration', clip.sceneIndex);
        };
        final path = music ? widget.lesson.musicPath : (clip.scene?.narrationPath ?? '');
        body = Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: music ? KColors.clipMusic : KColors.clipAudio),
            CustomPaint(painter: _WavePainter(seed: clip.seed, peaks: PeaksCache.instance.peaksFor(path))),
          ],
        );
    }

    Widget view = ClipRRect(borderRadius: radius, child: body);
    final dropHere = clip.kind == 'scene' && _movingLayer && _dropScene == clip.sceneIndex;
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
              _handle(left: true, index: clip.sceneIndex, u: u, cw: w),
              _handle(left: false, index: clip.sceneIndex, u: u, cw: w),
            ],
            if (clip.kind == 'audioclip') ...[
              _audioHandle(left: true, ac: clip.audio!, u: u, cw: w),
              _audioHandle(left: false, ac: clip.audio!, u: u, cw: w),
            ],
            if (clip.kind == 'layer') ...[
              _layerHandle(left: true, layer: clip.layer!, sceneIndex: clip.sceneIndex, sceneMs: widget.lesson.scenes[clip.sceneIndex].durationMs, u: u, cw: w),
              _layerHandle(left: false, layer: clip.layer!, sceneIndex: clip.sceneIndex, sceneMs: widget.lesson.scenes[clip.sceneIndex].durationMs, u: u, cw: w),
            ],
          ],
        ),
      );
    }
    if (dropHere) {
      view = Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: const Color(0xFFFFC21A), width: 3),
        ),
        child: view,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLong,
      onLongPressStart: moveStart == null ? null : (d) => moveStart!(d.localPosition, d.globalPosition.dx),
      onLongPressMoveUpdate: moveUpdate == null ? null : (d) => moveUpdate!(d.offsetFromOrigin.dx, d.globalPosition.dx),
      onLongPressEnd: moveEnd == null ? null : (_) => moveEnd!(),
      onLongPressCancel: moveEnd,
      child: view,
    );
  }

  int get sceneIndexNow => sceneAt(widget.lesson, widget.player.positionMs).index;

  // ---- label column ----

  Widget _labelChip(String id, double height, double u, double labelW) {
    final hidden = widget.hidden.contains(id);
    final iconSize = math.max(15.0, 30 * u);
    return Tooltip(
      message: trackName(id),
      child: Container(
        width: labelW,
        height: height,
        decoration: BoxDecoration(
          color: KColors.editorLabel,
          borderRadius: BorderRadius.circular(math.max(5.0, 8 * u)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onToggleHidden(id),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: iconSize,
                  color: hidden ? const Color(0xFF8A7BD6) : KColors.ink,
                ),
              ),
            ),
            Icon(trackIcon(id), size: iconSize, color: KColors.ink),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final u = math.min(width / 941.0, widget.maxUnit);
        final labelLeft = 14 * u;
        final labelW = math.max(84.0, 110 * u);
        final stripLeft = labelLeft + labelW + 5 * u;
        final viewportW = width - stripLeft - 13 * u;
        // About 9 seconds fill the view, and never less than 30 px per second, so every second can be read.
        _pps = math.max(30.0, viewportW / 9.0) * _zoom;
        final pps = _pps;

        final rulerH = 128 * u;
        final baseRow = math.max(30.0, 58 * u);
        final pad = math.max(2.0, 2 * u);
        final clipH = baseRow - 2 * pad;
        final stride = clipH + pad;
        final rowGap = math.max(3.0, 6 * u);
        final addH = math.max(28.0, 40 * u);
        // Transition button: small, and the room kept free on each side of it.
        final tBtn = math.max(20.0, math.min(clipH * 0.8, 28.0));
        final tGap = tBtn / 2 + 4;

        final clips = _buildClips();
        // While the video plays, the timeline is redrawn on every frame. With many slides that is too much,
        // so only the bars near the visible part are built. They are all built again when playing stops.
        final playingNow = widget.player.playing;
        final scrolledTo = _scroll.hasClients ? _scroll.offset : 0.0;
        final visFrom = scrolledTo - 600.0;
        final visTo = scrolledTo + viewportW + 600.0;
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
                    borderRadius: BorderRadius.circular(math.max(5.0, 8 * u)),
                  ),
                ),
              ),
            ),
          ];
          for (final clip in clips[id]!) {
            var x = clip.startMs / 1000 * pps;
            var w = math.max(8.0, (clip.endMs - clip.startMs) / 1000 * pps - 2);
            if (clip.kind == 'scene') {
              // Leave a clear gap beside every join so the transition button never touches a slide.
              final lastIndex = widget.lesson.scenes.length - 1;
              if (clip.sceneIndex > 0) {
                x += tGap;
                w -= tGap;
              }
              if (clip.sceneIndex < lastIndex) w -= tGap;
              w = math.max(8.0, w);
            }
            if (playingNow && (x + w < visFrom || x > visTo)) continue;
            children.add(Positioned(
              left: x,
              top: pad + clip.lane * stride,
              width: w,
              height: clipH,
              child: _clipView(clip, w, clipH, u),
            ));
          }
          if (id == 'video' && clips[id]!.isEmpty) {
            children.add(Positioned(
              left: 12 * u,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  'Screen recordings will appear here',
                  style: TextStyle(fontSize: math.max(10.0, 22 * u), color: const Color(0xFFA89DD0)),
                ),
              ),
            ));
          }
          if (id == 'image') {
            final btn = tBtn;
            for (var i = 0; i < widget.lesson.scenes.length - 1; i++) {
              final boundaryMs = sceneStartMs(widget.lesson, i + 1);
              final on = widget.lesson.scenes[i].transKind != 'none';
              final buttonX = boundaryMs / 1000 * pps;
              if (playingNow && (buttonX + btn < visFrom || buttonX - btn > visTo)) continue;
              children.add(Positioned(
                left: buttonX - btn / 2,
                top: pad + (clipH - btn) / 2,
                width: btn,
                height: btn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onTransition(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: on ? const Color(0xFF7351FF) : const Color(0xFF2E2658),
                      borderRadius: BorderRadius.circular(btn * 0.3),
                      border: Border.all(color: on ? Colors.white : const Color(0xFF8A7BD6), width: on ? 1.5 : 1),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
                    ),
                    child: Icon(Icons.compare_arrows, size: btn * 0.7, color: Colors.white),
                  ),
                ),
              ));
            }
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

        final content = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _holdFollow(3000);
            _tapDown = e.localPosition;
            _tapTime = DateTime.now();
          },
          onPointerMove: (_) => _holdFollow(3000),
          onPointerUp: (e) {
            _holdFollow(2500);
            final down = _tapDown;
            _tapDown = null;
            // A quick tap anywhere on the timeline moves the playhead there.
            if (down != null &&
                (e.localPosition - down).distance < 10 &&
                DateTime.now().difference(_tapTime).inMilliseconds < 400) {
              _seekFromX(e.localPosition.dx);
            }
          },
          child: SizedBox(
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
                      setState(() => _zoom = (_zoomStart * d.scale).clamp(0.1, 30.0).toDouble());
                    }
                  },
                  child: CustomPaint(painter: _RulerPainter(pps: pps, u: u, bookmarks: List<int>.of(widget.lesson.bookmarks))),
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
                  // Touching the time adds a red bookmark here; touching it again removes it.
                  onTap: () {
                    final ms = widget.player.positionMs;
                    final tol = (12 / pps * 1000).round() + 50;
                    final list = widget.lesson.bookmarks;
                    final near = list.indexWhere((b) => (b - ms).abs() <= tol);
                    setState(() {
                      if (near >= 0) {
                        list.removeAt(near);
                      } else {
                        list.add(ms);
                        list.sort();
                      }
                    });
                    widget.onEditEnd();
                  },
                  onHorizontalDragStart: (d) {
                    _headGrab = widget.player.positionMs - _fingerMs(d.globalPosition.dx);
                    _beginEdgeDrag(d.globalPosition.dx, _seekToFinger);
                  },
                  onHorizontalDragUpdate: (d) {
                    _fingerGx = d.globalPosition.dx;
                    _seekToFinger();
                  },
                  onHorizontalDragEnd: (_) => _endEdgeDrag(),
                  onHorizontalDragCancel: _endEdgeDrag,
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));

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
              painter: _DashedBorderPainter(color: const Color(0xFF6F63A6), radius: math.max(8.0, 16 * u)),
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
                        fontWeight: FontWeight.w400,
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
                child: Icon(Icons.menu, size: math.max(16.0, 34 * u), color: const Color(0xFF9C8FD0)),
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
                left: labelLeft,
                top: 8 * u,
                width: labelW,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _zoomButton(Icons.zoom_out, 'Zoom out', () => _zoomTo(_zoom / 1.6)),
                    const SizedBox(width: 2),
                    _zoomButton(Icons.zoom_in, 'Zoom in', () => _zoomTo(_zoom * 1.6)),
                    const SizedBox(width: 2),
                    _zoomButton(
                      _zoom > 8 ? Icons.fit_screen : Icons.unfold_more,
                      _zoom > 8 ? 'Back to normal width' : 'Wide: see tenths of a second',
                      () => _zoomTo(_zoom > 8 ? 1 : 24),
                    ),
                  ],
                ),
              ),
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
              if ((_movingLayer || _extending) && _dropScene != null)
                Positioned(
                  left: stripLeft,
                  right: 13 * u,
                  top: 4 * u,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC21A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _extending
                              ? 'Shows until slide ${_dropScene! + 1}'
                              : (_dropScene == _moveFrom
                                  ? 'Stays on slide ${_dropScene! + 1}'
                                  : 'Drop on slide ${_dropScene! + 1}'),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
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
  _RulerPainter({required this.pps, required this.u, required this.bookmarks});

  final double pps;
  final double u;
  final List<int> bookmarks;

  static const List<double> _steps = [0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600];

  @override
  void paint(Canvas canvas, Size size) {
    var step = _steps.last;
    for (final s in _steps) {
      if (s * pps >= math.max(30.0, 70 * u)) {
        step = s;
        break;
      }
    }
    final minor = step / 5.0;
    final tickPaint = Paint()
      ..color = const Color(0xFF8E84B8)
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
        String label;
        if (step < 1) {
          final tenths = (sec * 10).round();
          final whole = tenths ~/ 10;
          label = '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}.${tenths % 10}';
        } else {
          final total = sec.round();
          label = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
        }
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: const Color(0xFFB5ABD6),
              fontSize: math.max(10.0, 24 * u),
              fontWeight: FontWeight.w400,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x - painter.width / 2, 53 * u - painter.height / 2));
        painter.dispose();
      }
    }
    // Red bookmarks
    final red = Paint()..color = const Color(0xFFFF3B3B);
    for (final ms in bookmarks) {
      final x = ms / 1000 * pps;
      if (x < 0 || x > size.width) continue;
      canvas.drawRect(Rect.fromLTWH(x - math.max(1.0, u), 36 * u, math.max(2.0, 2 * u), 64 * u), red);
      final flag = Path()
        ..moveTo(x, 36 * u)
        ..lineTo(x + 20 * u, 45 * u)
        ..lineTo(x, 54 * u)
        ..close();
      canvas.drawPath(flag, red);
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.pps != pps || oldDelegate.u != u || oldDelegate.bookmarks.join(',') != bookmarks.join(',');
}

/// A waveform. It uses the real loudness of the file when it is known, and a
/// look-alike drawn from the file name while it is still being read.
class _WavePainter extends CustomPainter {
  _WavePainter({required this.seed, this.peaks, this.from = 0, this.to = 1});

  final int seed;
  final List<double>? peaks;
  final double from;
  final double to;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;
    final mid = size.height / 2;
    final count = (size.width / 5).floor();
    final data = peaks;
    for (var i = 0; i < count; i++) {
      double amp;
      if (data != null && data.isNotEmpty) {
        final f = count <= 1 ? from : from + (to - from) * (i / (count - 1));
        final index = (f * (data.length - 1)).round().clamp(0, data.length - 1).toInt();
        amp = math.max(2.0, math.sqrt(data[index]) * size.height * 0.46);
      } else {
        final r = (((i * 2654435761) ^ (seed * 40503)) >> 3) & 0xFF;
        final env = 0.35 + 0.65 * (math.sin(i * 0.23 + (seed & 7)) * 0.5 + 0.5);
        amp = math.max(2.0, (r / 255.0) * env * (size.height * 0.42));
      }
      final x = 4.0 + i * 5.0;
      canvas.drawLine(Offset(x, mid - amp), Offset(x, mid + amp), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.peaks != peaks ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
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
