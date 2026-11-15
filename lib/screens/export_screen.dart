import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide Layer;
import 'package:flutter/services.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../animation_math.dart';
import '../app_state.dart';
import '../editor/track_visibility.dart';
import '../models.dart';
import '../transition_math.dart';
import '../watermark.dart';
import '../scene_canvas.dart';
import '../hands.dart';
import '../text_reveal.dart';
import '../theme.dart';

const double _kStageW = 1280;
const double _kStageH = 720;
const double _kPad = 12;

class _Cancelled implements Exception {}

/// Exports a whole lesson to one MP4 video.
///
/// Every slide is drawn here with Flutter (so it looks exactly like the editor).
/// Items without animation are baked into the slide picture. From the first
/// animated item upward, every item becomes its own transparent picture that the
/// video encoder animates with the same formulas as the editor preview.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.courseId, required this.lessonId});

  final String courseId;
  final String lessonId;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final GlobalKey _stageKey = GlobalKey();
  Widget? _stageChild;
  double _stageW = _kStageW;
  double _stageH = _kStageH;
  int _stageSerial = 0;

  // Choices made on this screen for this export.
  int _quality = 720; // output height: 480, 720, 1080 or 1440
  int _fps = 30;
  double _mbps = 8;
  final TextEditingController _nameCtl = TextEditingController();
  bool _nameReady = false;
  bool _defaultsReady = false;

  static const Map<int, (int, String, String, double)> _qualities = {
    480: (854, 'SD', 'Smaller file', 3),
    720: (1280, 'HD', 'Recommended', 8),
    1080: (1920, 'Full HD', 'Best for sharing', 12),
    1440: (2560, '2K', 'Sharpest, slow', 20),
  };

  bool _busy = false;
  bool _cancelled = false;
  bool _failed = false;
  int _phase = 0; // 0 drawing, 1 narration, 2 video
  double _progress = 0;
  String _status = '';
  DateTime? _startedAt;
  Timer? _ticker;
  Widget? _thumbCache;
  String? _unsavedVideo;
  String _unsavedName = '';

  @override
  void dispose() {
    _ticker?.cancel();
    _nameCtl.dispose();
    if (_busy) {
      _cancelled = true;
      KainuwaEncoder.cancelExport();
    }
    super.dispose();
  }

  void _set(String message, {bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _failed = failed;
    });
  }

  void _setProgress(int phase, double fraction) {
    if (!mounted) return;
    const starts = [0.0, 0.25, 0.35];
    const spans = [0.25, 0.10, 0.65];
    final value = starts[phase] + spans[phase] * fraction.clamp(0.0, 1.0).toDouble();
    setState(() {
      _phase = phase;
      // The bar only ever moves forward.
      if (value > _progress) _progress = value;
    });
  }

  void _guard() {
    if (_cancelled) throw _Cancelled();
  }

  // ---- Drawing ----

  Future<ui.Image> _capture(Widget child, double w, double h, double pixelRatio) async {
    setState(() {
      _stageW = w;
      _stageH = h;
      _stageSerial++;
      _stageChild = child;
    });
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final object = _stageKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw StateError('The drawing area was not ready.');
    }
    return object.toImage(pixelRatio: pixelRatio);
  }

  Future<void> _savePng(ui.Image image, String path) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Could not store a slide picture.');
    await File(path).writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }

  Future<void> _precache(Scene scene) async {
    final providers = <ImageProvider>[];
    if (scene.bgType == 'asset') {
      providers.add(AssetImage(scene.bgValue));
    } else if (scene.bgType == 'file') {
      providers.add(FileImage(File(scene.bgValue)));
    }
    for (final layer in scene.layers) {
      if (layer.type == 'asset') providers.add(AssetImage(layer.path));
      final hand = handById(layer.hand);
      if (hand != null) providers.add(AssetImage(hand.asset));
      if (layer.type == 'image') providers.add(FileImage(File(layer.path)));
    }
    for (final provider in providers) {
      if (!mounted) return;
      try {
        await precacheImage(provider, context);
      } catch (_) {
        // A missing picture is drawn as a grey box, like in the editor.
      }
    }
  }

  /// The box around a rotated item, with some room for shadows.
  (double, double, Widget) _layerPicture(Layer l, {int? revealMs, double? clip}) {
    final lw = l.w * _kStageW;
    final lh = l.h * _kStageH;
    final c = math.cos(l.rotation).abs();
    final s = math.sin(l.rotation).abs();
    final bw = math.max(2.0, lw * c + lh * s + _kPad * 2);
    final bh = math.max(2.0, lw * s + lh * c + _kPad * 2);
    final widget = SizedBox(
      width: bw,
      height: bh,
      child: Center(
        child: Transform.rotate(
          angle: l.rotation,
          child: SizedBox(width: lw, height: lh, child: LayerContent(layer: l, revealMs: revealMs, clipFraction: clip)),
        ),
      ),
    );
    return (bw, bh, widget);
  }

  // ---- Export ----

  Future<void> _start() async {
    if (_busy) return;
    final state = AppScope.read(context);
    final lesson = state.lessonById(widget.courseId, widget.lessonId);
    if (lesson == null || lesson.scenes.isEmpty) {
      _set('This lesson has no slides to export.', failed: true);
      return;
    }
    final hidden = Set<String>.of(lesson.hiddenTracks);
    final audioOff = hidden.contains('audio');
    final scenes = lesson.scenes.map((s) {
      final v = viewScene(s, hidden);
      return identical(v, s) ? s.duplicate() : v;
    }).toList();
    final outH = _quality;
    final outW = _qualities[_quality]!.$1;
    final fps = _fps;
    final ratio = outW / _kStageW;
    final title = lesson.title;
    final musicPath = audioOff ? '' : lesson.musicPath;
    final clipMaps = <Map<String, Object?>>[];
    if (!audioOff) {
      for (final clip in lesson.audioClips) {
        if (clip.path.isEmpty || !await File(clip.path).exists()) continue;
        clipMaps.add({
          'path': clip.path,
          'startMs': clip.startMs,
          'trimMs': clip.trimMs,
          'durMs': clip.durationMs,
          'volume': clip.volume,
          'fadeInMs': clip.fadeInMs,
          'fadeOutMs': clip.fadeOutMs,
        });
      }
    }
    final musicVolume = lesson.musicVolume;
    final musicFade = lesson.musicFade;

    setState(() {
      _busy = true;
      _cancelled = false;
      _failed = false;
      _unsavedVideo = null;
      _phase = 0;
      _progress = 0;
      _startedAt = DateTime.now();
      _status = 'Drawing slides. Keep this screen open.';
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    final subs = <StreamSubscription<dynamic>>[
      KainuwaEncoder.stage.listen((s) {
        if (s == 'audio') {
          _setProgress(1, 0);
          _set('Preparing the narration. Keep this screen open.');
        } else if (s == 'video') {
          _setProgress(2, 0);
          _set('Creating the video. This can take a while. Keep this screen open.');
        }
      }),
      KainuwaEncoder.audioProgress.listen((p) => _setProgress(1, p / 100)),
      KainuwaEncoder.progress.listen((p) {
        if (_phase == 2) _setProgress(2, p / 100);
      }),
    ];

    Directory? root;
    try {
      final base = await KainuwaEncoder.filesDir();
      root = Directory('$base/export_tmp');
      if (await root.exists()) await root.delete(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final work = Directory('${root.path}/job_$stamp');
      await work.create(recursive: true);

      final specs = <Map<String, Object?>>[];
      final transitions = <Map<String, Object?>>[];
      var missingNarration = 0;
      var offsetMs = 0;
      for (var i = 0; i < scenes.length; i++) {
        _guard();
        _setProgress(0, i / scenes.length);
        final scene = scenes[i];
        final videoOk = scene.hasVideo && await File(scene.videoPath).exists();
        if (!videoOk && scene.hasVideo) {
          scene.videoPath = '';
        }
        if (scene.hasVideo && scene.videoMs > 0) {
          scene.durationMs = math.max(500, math.min(scene.durationMs, scene.videoMs - scene.videoStartMs));
        }
        await _precache(scene);

        final firstAnimated = scene.layers.indexWhere(layerNeedsOverlay);
        final staticLayers =
            firstAnimated < 0 ? scene.layers : scene.layers.sublist(0, firstAnimated);
        final baseScene = Scene(
          id: 'export_base',
          durationMs: scene.durationMs,
          bgType: scene.hasVideo ? 'color' : scene.bgType,
          bgValue: scene.hasVideo ? '0' : scene.bgValue,
          layers: List<Layer>.of(staticLayers),
        );
        final wm = AppScope.read(context).settings.wm;
        final phoneOn = scene.hasVideo && scene.phoneFrame;
        final geo = PhoneGeometry(_kStageW, _kStageH, scene.phoneScale);
        final baseImage = await _capture(
          SizedBox(
            width: _kStageW,
            height: _kStageH,
            child: phoneOn
                ? Stack(children: [
                    // Background and phone body with a see-through screen, so the video shows in it.
                    Positioned.fill(
                      child: ClipPath(
                        clipper: PhoneHoleClipper(geo),
                        child: Stack(children: [
                          Positioned.fill(child: SceneBackground(scene: scene, noVideo: true)),
                          PhoneBody(geo: geo, light: scene.phoneLight),
                        ]),
                      ),
                    ),
                    PhoneNotch(geo: geo),
                    Positioned.fill(child: SceneCanvas(scene: baseScene)),
                    watermarkOverlay(wm, _kStageW, _kStageH),
                  ])
                : Stack(children: [
                    Positioned.fill(child: SceneCanvas(scene: baseScene)),
                    watermarkOverlay(wm, _kStageW, _kStageH),
                  ]),
          ),
          _kStageW,
          _kStageH,
          ratio,
        );
        final basePath = '${work.path}/scene_$i.png';
        await _savePng(baseImage, basePath);

        final overlays = <Map<String, Object?>>[];
        if (scene.hasVideo) {
          // The slide's own items sit on top of the video as a transparent picture.
          overlays.add({
            'path': basePath,
            'cx': 0.5,
            'cy': 0.5,
            'anim': 'none',
            'startMs': 0,
            'durMs': 0,
            'showMs': 0,
            'hideMs': null,
            'outAnim': 'none',
            'outStartMs': 0,
            'outDurMs': 0,
          });
          if (!scene.videoMuted && scene.videoVolume > 0) {
            clipMaps.add({
              'path': scene.videoPath,
              'startMs': offsetMs,
              'trimMs': scene.videoStartMs,
              'durMs': scene.durationMs,
              'volume': scene.videoVolume,
              'fadeInMs': 0,
              'fadeOutMs': 0,
            });
          }
        }
        final handOverlays = <Map<String, Object?>>[];
        if (firstAnimated >= 0) {
          for (var k = firstAnimated; k < scene.layers.length; k++) {
            _guard();
            final layer = scene.layers[k];
            final picture = _layerPicture(layer);
            final handSpec = handById(layer.hand);
            final handAnimated = handSpec != null;
            final textAnimated = !handAnimated && layer.type == 'text' && layer.textAnim != 'none';
            final firstPicture = textAnimated
                ? _layerPicture(layer, revealMs: -1)
                : (handAnimated ? _layerPicture(layer, clip: 0.0) : picture);
            final image = await _capture(firstPicture.$3, firstPicture.$1, firstPicture.$2, ratio);
            final path = '${work.path}/scene_${i}_layer_$k.png';
            await _savePng(image, path);
            // Text animations are a series of pictures, each one showing a bit more text.
            List<Map<String, Object?>>? frames;
            if (textAnimated) {
              final total = textRevealTotalMs(layer);
              final step = math.max(50, (total / 180).ceil());
              final t0 = layer.startMs + layer.animStartMs;
              frames = [
                {'path': path, 'atMs': layer.startMs},
              ];
              var f = 0;
              for (var r = step; ; r += step) {
                _guard();
                final reveal = math.min(r, total);
                final pic = _layerPicture(layer, revealMs: reveal);
                final img = await _capture(pic.$3, pic.$1, pic.$2, ratio);
                final fp = '${work.path}/scene_${i}_layer_${k}_f${f++}.png';
                await _savePng(img, fp);
                frames.add({'path': fp, 'atMs': t0 + reveal});
                if (reveal >= total) break;
              }
            }
            if (handAnimated) {
              // The item is drawn from left to right: a series of pictures, each one
              // showing a bit more. The hand is its own picture that moves along.
              final t0 = layer.startMs + layer.animStartMs;
              final drawMs = math.max(1, layer.handMs);
              final step = math.max(60, (drawMs / 120).ceil());
              frames = [
                {'path': path, 'atMs': layer.startMs},
              ];
              var f = 0;
              for (var u = step; ; u += step) {
                _guard();
                final shown = math.min(u, drawMs);
                final pic = _layerPicture(layer, clip: shown >= drawMs ? null : shown / drawMs);
                final img = await _capture(pic.$3, pic.$1, pic.$2, ratio);
                final fp = '${work.path}/scene_${i}_layer_${k}_f${f++}.png';
                await _savePng(img, fp);
                frames.add({'path': fp, 'atMs': t0 + kHandEnterMs + shown});
                if (shown >= drawMs) break;
              }
              final handW = _kStageW * kHandWidthFrac;
              final handH = handW / handSpec.aspect;
              await precacheImage(AssetImage(handSpec.asset), context);
              final handImage = await _capture(
                SizedBox(
                  width: handW,
                  height: handH,
                  child: Image.asset(handSpec.asset, fit: BoxFit.fill),
                ),
                handW,
                handH,
                ratio,
              );
              final handPath = '${work.path}/scene_${i}_hand_$k.png';
              await _savePng(handImage, handPath);
              final keys = <Map<String, Object?>>[];
              final total = handTotalMs(layer);
              for (var t = 0; ; t += 40) {
                final tt = math.min(t, total);
                final st = handStateAt(layer, tt);
                keys.add({
                  't': t0 + tt,
                  'x': st.tipX + (0.5 - handSpec.tipX) * kHandWidthFrac,
                  'y': st.tipY + (0.5 - handSpec.tipY) * (handH / _kStageH),
                });
                if (tt >= total) break;
              }
              handOverlays.add({
                'path': handPath,
                'cx': 0.5,
                'cy': 0.5,
                'anim': 'none',
                'startMs': 0,
                'durMs': 0,
                'showMs': t0,
                'hideMs': t0 + total + 60,
                'outAnim': 'none',
                'outStartMs': 0,
                'outDurMs': 0,
                'keys': keys,
              });
            }
            final end = layerEndMs(layer, scene.durationMs);
            overlays.add({
              'frames': frames,
              'path': path,
              'cx': layer.cx,
              'cy': layer.cy,
              'anim': layer.animIn,
              'startMs': layer.startMs + layer.animStartMs,
              'durMs': layer.animDurationMs,
              'showMs': layer.startMs,
              'hideMs': end,
              'outAnim': layer.animOut,
              'outStartMs': end - layer.animOutDurationMs,
              'outDurMs': layer.animOutDurationMs,
              'loop': layer.animLoop,
              'loopMs': loopPeriodMs(layer),
            });
          }
          overlays.addAll(handOverlays);
        }

        String? narration;
        if (!audioOff && scene.narrationPath.isNotEmpty) {
          if (await File(scene.narrationPath).exists()) {
            narration = scene.narrationPath;
          } else {
            missingNarration++;
          }
        }
        specs.add({
          'image': basePath,
          'durationMs': scene.durationMs,
          'narration': narration,
          'volume': scene.narrationVolume,
          'clean': scene.narrationClean,
          'overlays': overlays,
          'video': scene.hasVideo ? scene.videoPath : null,
          'videoStartMs': scene.videoStartMs,
          'videoScale': scene.hasVideo && scene.phoneFrame
              ? PhoneGeometry(_kStageW, _kStageH, scene.phoneScale).screenH / _kStageH
              : 1.0,
        });
        offsetMs += scene.durationMs;
        final half = transitionHalfMs(lesson, i);
        if (half > 0) {
          transitions.add({
            'atMs': offsetMs,
            'kind': scene.transKind,
            'dir': scene.transDir,
            'halfMs': half,
          });
        }
      }

      if (mounted) setState(() => _stageChild = null);
      _guard();

      String? music;
      if (musicPath.isNotEmpty && await File(musicPath).exists()) music = musicPath;

      _setProgress(1, 0);
      final output = '${root.path}/lesson_$stamp.mp4';
      await KainuwaEncoder.exportLesson(
        scenes: specs,
        workDir: work.path,
        outputPath: output,
        musicPath: music,
        musicVolume: musicVolume,
        musicFadeMs: musicFade ? 2000 : 0,
        width: outW,
        height: outH,
        fps: fps,
        bitrate: (_mbps * 1000000).round(),
        clips: clipMaps,
        transitions: transitions,
      );
      try {
        await work.delete(recursive: true);
      } catch (_) {}
      _setProgress(2, 1);
      await _save(output, title, missingNarration);
    } on _Cancelled {
      _set('Export cancelled.');
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') {
        _set('Export cancelled.');
      } else {
        _set('Export stopped: ${e.message}', failed: true);
      }
    } catch (e) {
      _set('Export stopped: $e', failed: true);
    } finally {
      _ticker?.cancel();
      _ticker = null;
      for (final s in subs) {
        await s.cancel();
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _stageChild = null;
        });
      }
    }
  }

  String _safeName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'Lesson' : cleaned;
  }

  Future<void> _save(String output, String title, int missingNarration) async {
    final typed = _safeName(_nameCtl.text.trim().isEmpty ? title : _nameCtl.text.trim());
    final name = '$typed.mp4';
    final note = missingNarration > 0
        ? ' $missingNarration slide(s) had a narration file that could not be found and are silent.'
        : '';
    try {
      final saved = await KainuwaEncoder.saveToMovies(path: output, name: name);
      if (mounted) setState(() => _unsavedVideo = null);
      _set('Done. The video was saved to $saved.$note');
      try {
        await File(output).delete();
      } catch (_) {}
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _unsavedVideo = output;
          _unsavedName = name;
        });
      }
      _set('The video was made but not saved yet (${e.message}). Tap Save video to try again.$note',
          failed: true);
    }
  }

  Future<void> _retrySave() async {
    final path = _unsavedVideo;
    if (path == null || _busy) return;
    setState(() => _busy = true);
    try {
      final saved = await KainuwaEncoder.saveToMovies(path: path, name: _unsavedName);
      if (mounted) setState(() => _unsavedVideo = null);
      _set('Done. The video was saved to $saved.');
      try {
        await File(path).delete();
      } catch (_) {}
    } on PlatformException catch (e) {
      _set('Could not save yet (${e.message}). Tap Save video to try again.', failed: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    _cancelled = true;
    _set('Cancelling...');
    try {
      await KainuwaEncoder.cancelExport();
    } catch (_) {}
  }

  // ---- Screen ----

  /// Small pictures of the slides, so the person sees what is being exported.
  Widget _thumbnails(List<Scene> scenes) {
    const w = 96.0;
    const h = 54.0;
    final shown = scenes.take(12).toList();
    final more = scenes.length - shown.length;
    final media = MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling);
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length + (more > 0 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i >= shown.length) {
            return Container(
              width: w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KColors.lavender,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('+$more more', style: const TextStyle(fontSize: 12)),
            );
          }
          final scene = shown[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: w,
              height: h,
              child: IgnorePointer(
                child: MediaQuery(
                  data: media,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _kStageW,
                      height: _kStageH,
                      child: SceneCanvas(scene: scene),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _elapsed() {
    final t = _startedAt;
    if (t == null) return '';
    final sec = DateTime.now().difference(t).inSeconds;
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final r = (sec % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Widget _progressCard() {
    final pct = (_progress * 100).clamp(0, 100).round();
    const steps = ['Slides', 'Sound', 'Video'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KColors.lavender,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$pct%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1)),
              const Spacer(),
              Text('Elapsed ${_elapsed()}', style: const TextStyle(fontSize: 13, color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Color(0x33FFFFFF))),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: _progress.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      builder: (context, v, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v <= 0 ? 0.0 : v,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [KColors.purple, KColors.gold]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Icon(
                  i < _phase
                      ? Icons.check_circle
                      : (i == _phase ? Icons.timelapse : Icons.radio_button_unchecked),
                  size: 16,
                  color: i <= _phase ? KColors.gold : Colors.white38,
                ),
                const SizedBox(width: 4),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == _phase ? FontWeight.w700 : FontWeight.w500,
                    color: i <= _phase ? Colors.white : Colors.white54,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lesson = state.lessonById(widget.courseId, widget.lessonId);
    final media = MediaQuery.of(context);

    final stage = MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Material(
        type: MaterialType.transparency,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: _stageKey,
            child: SizedBox(
              width: _stageW,
              height: _stageH,
              child: KeyedSubtree(
                key: ValueKey<int>(_stageSerial),
                child: _stageChild ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );

    if (!_defaultsReady) {
      _quality = _qualities.containsKey(state.settings.videoHeight) ? state.settings.videoHeight : 720;
      _fps = state.settings.frameRate;
      _mbps = _qualities[_quality]!.$4;
      _defaultsReady = true;
    }
    if (lesson != null && !_nameReady) {
      _nameCtl.text = 'Kainuwa_${_safeName(lesson.title)}';
      _nameReady = true;
    }
    final seconds = lesson == null ? 0 : (lesson.durationMs / 1000);
    final estMb = seconds * _mbps / 8 + seconds * 0.016;

    Widget card(Widget child) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x143B0F8C), blurRadius: 10, offset: Offset(0, 2))],
          ),
          child: child,
        );
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: KColors.accent)),
        );

    final tiles = <Widget>[];
    for (final entry in _qualities.entries) {
      final q = entry.key;
      final info = entry.value;
      final on = q == _quality;
      tiles.add(
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: tiles.isEmpty ? 0 : 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _busy
                  ? null
                  : () => setState(() {
                        _quality = q;
                        _mbps = info.$4;
                      }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? KColors.lavender : KColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: on ? KColors.purple : const Color(0xFF3D3266), width: on ? 2 : 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${q}p', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(info.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${info.$1}x$q', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                    ),
                    const SizedBox(height: 4),
                    Icon(on ? Icons.check_circle : Icons.circle_outlined,
                        size: 16, color: on ? KColors.purple : Colors.white24),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.movie_creation_outlined, color: KColors.purple, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson?.title ?? 'Lesson',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      if (lesson != null)
                        Text('${sceneCountText(lesson.scenes.length)}  -  ${formatClock(lesson.durationMs)}  -  about ${estMb.toStringAsFixed(estMb < 10 ? 1 : 0)} MB'),
                    ],
                  ),
                ),
              ],
            ),
            if (lesson != null && lesson.scenes.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Drawn once and reused, so the progress updates do not redraw the slides.
              _thumbCache ??= RepaintBoundary(child: _thumbnails(lesson.scenes)),
            ],
          ],
        )),
        card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('File name'),
            TextField(
              controller: _nameCtl,
              enabled: !_busy,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                suffixText: '.mp4',
              ),
            ),
          ],
        )),
        card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Quality'),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: tiles),
            ),
            const SizedBox(height: 8),
            Text(
              '${_qualities[_quality]!.$3}${_quality == 720 ? '' : '  (720p is recommended)'}',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        )),
        card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Format'),
            const Text('MP4 (H.264 video, AAC sound)'),
            const SizedBox(height: 14),
            label('Frame rate'),
            DropdownButton<int>(
              value: _fps,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 24, child: Text('24 FPS (Cinematic)')),
                DropdownMenuItem(value: 30, child: Text('30 FPS (Smooth)')),
              ],
              onChanged: _busy ? null : (v) => setState(() => _fps = v ?? 30),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text('Video bitrate', style: TextStyle(fontWeight: FontWeight.w700, color: KColors.accent)),
                ),
                Text('${_mbps.round()} Mbps', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            Slider(
              value: _mbps,
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: _busy ? null : (v) => setState(() => _mbps = v),
            ),
            const Text(
              'Higher bitrate looks sharper and makes a bigger file.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        )),
        card(WatermarkCard(
          wm: state.settings.wm,
          enabled: !_busy,
          onChanged: (w) => state.updateSettings(state.settings.copyWith(wm: w)),
        )),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Keep the app open and the phone awake until the export finishes. '
            'Long lessons take a long time; try a short lesson first.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        if (_busy) ...[
          _progressCard(),
          const SizedBox(height: 12),
        ],
        if (_status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _status,
              style: TextStyle(
                color: _failed ? Theme.of(context).colorScheme.error : KColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (!_busy)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.gold,
              foregroundColor: KColors.onGold,
            ),
            onPressed: lesson == null ? null : _start,
            icon: const Icon(Icons.movie_creation_outlined),
            label: const Text('Export Video'),
          ),
        if (_busy && _phase != 99)
          OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
        if (!_busy) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
        ],
        if (_unsavedVideo != null && !_busy) ...[
          const SizedBox(height: 8),
          FilledButton(onPressed: _retrySave, child: const Text('Save video')),
        ],
      ],
    );

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Export Video')),
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // The drawing area sits behind the screen content.
            Positioned(
              left: 0,
              top: 0,
              width: _stageW,
              height: _stageH,
              child: IgnorePointer(child: stage),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(child: content),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
