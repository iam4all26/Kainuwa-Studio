import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide Layer;
import 'package:flutter/services.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../app_state.dart';
import '../models.dart';
import '../scene_canvas.dart';
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

  bool _busy = false;
  bool _cancelled = false;
  bool _failed = false;
  int _phase = 0; // 0 drawing, 1 narration, 2 video
  double _progress = 0;
  String _status = '';
  String? _unsavedVideo;
  String _unsavedName = '';

  @override
  void dispose() {
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
    const starts = [0.0, 0.2, 0.35];
    const spans = [0.2, 0.15, 0.65];
    setState(() {
      _phase = phase;
      _progress = starts[phase] + spans[phase] * fraction.clamp(0.0, 1.0).toDouble();
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
  (double, double, Widget) _layerPicture(Layer l) {
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
          child: SizedBox(width: lw, height: lh, child: LayerContent(layer: l)),
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
    final scenes = List<Scene>.of(lesson.scenes);
    final settings = state.settings;
    final outW = settings.videoWidth;
    final outH = settings.videoHeight;
    final fps = settings.frameRate;
    final ratio = outW / _kStageW;
    final title = lesson.title;
    final musicPath = lesson.musicPath;
    final musicVolume = lesson.musicVolume;
    final musicFade = lesson.musicFade;

    setState(() {
      _busy = true;
      _cancelled = false;
      _failed = false;
      _unsavedVideo = null;
      _phase = 0;
      _progress = 0;
      _status = 'Drawing slides. Keep this screen open.';
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
      var missingNarration = 0;
      for (var i = 0; i < scenes.length; i++) {
        _guard();
        _setProgress(0, i / scenes.length);
        final scene = scenes[i];
        await _precache(scene);

        final firstAnimated = scene.layers.indexWhere((l) => l.animIn != 'none');
        final staticLayers =
            firstAnimated < 0 ? scene.layers : scene.layers.sublist(0, firstAnimated);
        final baseScene = Scene(
          id: 'export_base',
          durationMs: scene.durationMs,
          bgType: scene.bgType,
          bgValue: scene.bgValue,
          layers: List<Layer>.of(staticLayers),
        );
        final baseImage = await _capture(
          SizedBox(
            width: _kStageW,
            height: _kStageH,
            child: SceneCanvas(scene: baseScene),
          ),
          _kStageW,
          _kStageH,
          ratio,
        );
        final basePath = '${work.path}/scene_$i.png';
        await _savePng(baseImage, basePath);

        final overlays = <Map<String, Object?>>[];
        if (firstAnimated >= 0) {
          for (var k = firstAnimated; k < scene.layers.length; k++) {
            _guard();
            final layer = scene.layers[k];
            final picture = _layerPicture(layer);
            final image = await _capture(picture.$3, picture.$1, picture.$2, ratio);
            final path = '${work.path}/scene_${i}_layer_$k.png';
            await _savePng(image, path);
            overlays.add({
              'path': path,
              'cx': layer.cx,
              'cy': layer.cy,
              'anim': layer.animIn,
              'startMs': layer.animStartMs,
              'durMs': layer.animDurationMs,
            });
          }
        }

        String? narration;
        if (scene.narrationPath.isNotEmpty) {
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
        });
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
    final name = 'Kainuwa_${_safeName(title)}.mp4';
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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lesson = state.lessonById(widget.courseId, widget.lessonId);
    final settings = state.settings;
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

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          lesson?.title ?? 'Lesson',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        if (lesson != null)
          Text('${sceneCountText(lesson.scenes.length)} - ${formatClock(lesson.durationMs)}'),
        const SizedBox(height: 12),
        Text(
          'Video: ${settings.videoWidth} x ${settings.videoHeight}, ${settings.frameRate} frames per second. '
          'Change this in Settings.',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep the app open and the phone awake until the export finishes. '
          'Long lessons take a long time; try a short lesson first.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 20),
        if (_busy) ...[
          LinearProgressIndicator(value: _progress <= 0 ? null : _progress, minHeight: 8),
          const SizedBox(height: 6),
          Text('${(_progress * 100).round()} percent'),
          const SizedBox(height: 12),
        ],
        if (_status.isNotEmpty)
          Text(
            _status,
            style: TextStyle(
              color: _failed ? Theme.of(context).colorScheme.error : KColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 16),
        if (!_busy)
          FilledButton.icon(
            onPressed: lesson == null ? null : _start,
            icon: const Icon(Icons.movie_creation_outlined),
            label: const Text('Export video'),
          ),
        if (_busy && _phase != 99)
          OutlinedButton(onPressed: _cancel, child: const Text('Cancel export')),
        if (_unsavedVideo != null && !_busy) ...[
          const SizedBox(height: 8),
          FilledButton(onPressed: _retrySave, child: const Text('Save video')),
        ],
      ],
    );

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Export lesson')),
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
