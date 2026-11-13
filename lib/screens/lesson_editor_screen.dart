import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../app_state.dart';
import '../editor/add_timeline_sheet.dart';
import '../editor/edit_panel.dart';
import '../editor/editor_history.dart';
import '../editor/editor_tools.dart';
import '../editor/fullscreen_player.dart';
import '../editor/lesson_player.dart';
import '../editor/timeline_panel.dart';
import '../editor/track_visibility.dart';
import '../models.dart';
import '../scene_canvas.dart';
import '../theme.dart';
import '../widgets.dart';
import 'audio_sheet.dart';
import 'editor_sheets.dart';
import 'export_screen.dart';

/// Width and height (as fractions of the slide) for an item with the given
/// picture shape, kept inside the given limits.
(double, double) fitBox(double aspect, {required double maxW, required double maxH}) {
  var w = maxW;
  var h = w * (16 / 9) / aspect;
  if (h > maxH) {
    h = maxH;
    w = h * aspect * (9 / 16);
  }
  return (w, h);
}

/// Size taken from the mockup (941 px wide), scaled to this phone.
double _s(double u, double px, [double min = 0]) => math.max(min, px * u);

class LessonEditorScreen extends StatefulWidget {
  const LessonEditorScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  final String courseId;
  final String lessonId;

  @override
  State<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends State<LessonEditorScreen>
    with SingleTickerProviderStateMixin {
  LessonPlayer? _player;
  EditorHistory? _history;

  String? _selectedId;
  String? _selectedAudioId;
  bool _sceneSelected = false;
  int _tab = 0;
  final List<String> _order = List<String>.of(kDefaultTrackOrder);

  @override
  void initState() {
    super.initState();
    final lesson = AppScope.read(context).lessonById(widget.courseId, widget.lessonId);
    if (lesson != null) {
      if (lesson.scenes.isEmpty) {
        lesson.scenes.add(Scene(id: newId()));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) AppScope.read(context).persist();
        });
      }
      _history = EditorHistory(lesson);
      final player = LessonPlayer(vsync: this, lesson: lesson);
      player.addListener(_onPlayer);
      _player = player;
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayer);
    _player?.dispose();
    super.dispose();
  }

  void _onPlayer() {
    if (mounted) setState(() {});
  }

  // ---- small helpers ----

  Lesson? _lesson() => AppScope.read(context).lessonById(widget.courseId, widget.lessonId);

  Scene? _currentScene() {
    final lesson = _lesson();
    final player = _player;
    if (lesson == null || player == null || lesson.scenes.isEmpty) return null;
    return lesson.scenes[sceneAt(lesson, player.positionMs).index];
  }

  Layer? _selectedLayer(Scene? scene) {
    if (scene == null || _selectedId == null) return null;
    for (final layer in scene.layers) {
      if (layer.id == _selectedId) return layer;
    }
    return null;
  }

  void _pause() => _player?.pause();

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _needItem() => _snack('Select an item on the slide or on the timeline first.');

  Future<void> _commit() async {
    final lesson = _lesson();
    if (lesson != null) {
      _history?.record(lesson);
      _player?.clampToLesson();
    }
    if (mounted) setState(() {});
    if (!mounted) return;
    await AppScope.read(context).persist();
  }

  void _selectLayer(String? id) {
    setState(() {
      _selectedId = id;
      _selectedAudioId = null;
      _sceneSelected = false;
    });
  }

  void _seekToScene(Lesson lesson, int index) {
    final player = _player;
    if (player == null) return;
    final spot = sceneAt(lesson, player.positionMs);
    if (spot.index != index) player.seek(sceneStartMs(lesson, index));
  }

  void _selectScene(int index) {
    final lesson = _lesson();
    if (lesson == null || index >= lesson.scenes.length) return;
    _seekToScene(lesson, index);
    setState(() {
      _selectedId = null;
      _selectedAudioId = null;
      _sceneSelected = true;
    });
  }

  void _selectLayerFromTimeline(int sceneIndex, String id) {
    final lesson = _lesson();
    if (lesson == null || sceneIndex >= lesson.scenes.length) return;
    _seekToScene(lesson, sceneIndex);
    setState(() {
      _selectedId = id;
      _selectedAudioId = null;
      _sceneSelected = false;
    });
  }

  // ---- undo, redo, save, export ----

  Future<void> _undo() async {
    final lesson = _lesson();
    final history = _history;
    if (lesson == null || history == null) return;
    _pause();
    if (history.undo(lesson)) {
      _player?.clampToLesson();
      setState(() {
        _selectedId = null;
        _sceneSelected = false;
      });
      await AppScope.read(context).persist();
    }
  }

  Future<void> _redo() async {
    final lesson = _lesson();
    final history = _history;
    if (lesson == null || history == null) return;
    _pause();
    if (history.redo(lesson)) {
      _player?.clampToLesson();
      setState(() {
        _selectedId = null;
        _sceneSelected = false;
      });
      await AppScope.read(context).persist();
    }
  }

  Future<void> _save() async {
    await AppScope.read(context).persist();
    if (mounted) _snack('Saved on this phone.');
  }

  void _export() {
    _pause();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExportScreen(courseId: widget.courseId, lessonId: widget.lessonId),
      ),
    );
  }

  void _fullscreen(Lesson lesson) {
    final player = _player;
    if (player == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenPlayer(lesson: lesson, player: player),
      ),
    );
  }

  // ---- adding things ----

  void _addLayer(Scene scene, Layer layer) {
    scene.layers.add(layer);
    _selectedId = layer.id;
    _sceneSelected = false;
    _commit();
  }

  Future<void> _openAdd() async {
    final choice = await showAddSheet(context);
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'text':
        await _addText();
        break;
      case 'icon':
        await _addIcon();
        break;
      case 'image':
        await _addImage();
        break;
      case 'shape':
        await _addShape();
        break;
    }
  }

  Future<void> _setBackground() async {
    final scene = _currentScene();
    if (scene == null) return;
    final choice = await showBackgroundSheet(context);
    if (choice == null) return;
    scene.bgType = choice.type;
    scene.bgValue = choice.value;
    _commit();
  }

  Future<void> _addText() async {
    final scene = _currentScene();
    if (scene == null) return;
    final text = await promptText(
      context,
      title: 'Add text',
      label: 'Text',
      confirm: 'Add',
      maxLength: 200,
      multiline: true,
    );
    if (text == null || !mounted) return;
    final layer = Layer(
      id: newId(),
      type: 'text',
      text: text,
      color: scene.isDarkBackground ? 0xFFFFFFFF : 0xFF1E1433,
    );
    setLayerTextSizePx(layer, 72);
    if (layer.w > 0.9) {
      final f = 0.9 / layer.w;
      layer.w = 0.9;
      layer.h = layer.h * f;
    }
    _addLayer(scene, layer);
  }

  Future<void> _addSubtitles() async {
    final scene = _currentScene();
    if (scene == null) return;
    final text = await promptText(
      context,
      title: 'Add subtitles',
      label: 'Caption',
      confirm: 'Add',
      maxLength: 200,
      multiline: true,
    );
    if (text == null || !mounted) return;
    final layer = Layer(
      id: newId(),
      type: 'text',
      text: text,
      cy: 0.86,
      color: 0xFFFFFFFF,
      bold: false,
      bgBox: true,
      bgColor: 0xCC000000,
    );
    setLayerTextSizePx(layer, 40);
    if (layer.w > 0.92) {
      final f = 0.92 / layer.w;
      layer.w = 0.92;
      layer.h = layer.h * f;
    }
    _addLayer(scene, layer);
  }

  Future<void> _addIcon() async {
    final scene = _currentScene();
    if (scene == null) return;
    final item = await showAssetSheet(context);
    if (item == null) return;
    final box = fitBox(1.0, maxW: 0.28, maxH: 0.5);
    _addLayer(scene, Layer(id: newId(), type: 'asset', w: box.$1, h: box.$2, path: item.path));
  }

  Future<double> _imageAspect(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 128);
      final frame = await codec.getNextFrame();
      final aspect = frame.image.width / frame.image.height;
      frame.image.dispose();
      codec.dispose();
      return aspect;
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> _addImage() async {
    final scene = _currentScene();
    if (scene == null) return;
    String? path;
    try {
      path = await KainuwaEncoder.pickImage();
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    final aspect = await _imageAspect(path);
    if (!mounted) return;
    final box = fitBox(aspect, maxW: 0.6, maxH: 0.8);
    _addLayer(scene, Layer(id: newId(), type: 'image', w: box.$1, h: box.$2, path: path));
  }

  Future<void> _addShape() async {
    final scene = _currentScene();
    if (scene == null) return;
    final kind = await showShapeSheet(context);
    if (kind == null) return;
    final box = kind == 'circle'
        ? fitBox(1.0, maxW: 0.25, maxH: 0.45)
        : fitBox(1.6, maxW: 0.4, maxH: 0.4);
    _addLayer(
      scene,
      Layer(
        id: newId(),
        type: 'shape',
        shape: kind,
        w: box.$1,
        h: box.$2,
        color: 0xFFF6C101,
      ),
    );
  }

  Future<void> _openAudio() async {
    final lesson = _lesson();
    final scene = _currentScene();
    if (lesson == null || scene == null) return;
    await showAudioSheet(context, lesson: lesson, scene: scene, onChanged: _commit);
    _commit();
  }

  Future<void> _openEdit(String tab) async {
    final scene = _currentScene();
    if (scene == null) return;
    _pause();
    final layer = _selectedLayer(scene);
    if (layer == null) {
      _needItem();
      return;
    }
    await showEditPanel(
      context,
      layer: layer,
      scene: scene,
      initialTab: tab,
      onLive: () {
        if (mounted) setState(() {});
      },
    );
    _commit();
  }

  Future<void> _openAnimate() => _openEdit('animation');

  Future<void> _setDuration() async {
    final scene = _currentScene();
    if (scene == null) return;
    final ms = await showDurationSheet(context, scene.durationMs, minMs: scene.narrationMs);
    if (ms == null) return;
    scene.durationMs = ms;
    _commit();
  }

  // ---- toolbar: Split, Duplicate, Delete, Layer, Adjust, Volume, Speed ----

  void _split() {
    if (_selectedAudioId != null) {
      _splitAudio();
      return;
    }
    final lesson = _lesson();
    final player = _player;
    if (lesson == null || player == null) return;
    _pause();
    final spot = sceneAt(lesson, player.positionMs);
    final scene = lesson.scenes[spot.index];
    final local = spot.localMs;
    if (local < 500 || scene.durationMs - local < 500) {
      _snack('Move the playhead inside a slide, at least half a second from its edges, to split it.');
      return;
    }
    if (scene.narrationPath.isNotEmpty && local < scene.narrationMs) {
      _snack('The narration of this slide runs past this point. Move the playhead after it ends, or remove the narration first.');
      return;
    }
    final second = scene.duplicate();
    second.narrationPath = '';
    second.narrationMs = 0;
    for (final layer in second.layers) {
      layer.animIn = 'none';
    }
    final original = scene.durationMs;
    scene.durationMs = local;
    second.durationMs = original - local;
    lesson.scenes.insert(spot.index + 1, second);
    player.seek(sceneStartMs(lesson, spot.index + 1));
    _selectedId = null;
    _sceneSelected = true;
    _commit();
  }

  void _duplicateSelection() {
    if (_selectedAudioId != null) {
      _duplicateAudio();
      return;
    }
    final lesson = _lesson();
    final scene = _currentScene();
    if (lesson == null || scene == null) return;
    _pause();
    final layer = _selectedLayer(scene);
    if (layer != null) {
      _duplicateLayer(scene, layer);
      return;
    }
    _duplicateScene();
  }

  void _duplicateScene() {
    final lesson = _lesson();
    final scene = _currentScene();
    if (lesson == null || scene == null) return;
    _pause();
    final index = lesson.scenes.indexOf(scene);
    lesson.scenes.insert(index + 1, scene.duplicate());
    _player?.seek(sceneStartMs(lesson, index + 1));
    _selectedId = null;
    _sceneSelected = true;
    _commit();
  }

  void _deleteSelection() {
    if (_selectedAudioId != null) {
      _deleteAudio();
      return;
    }
    final lesson = _lesson();
    final scene = _currentScene();
    if (lesson == null || scene == null) return;
    _pause();
    final layer = _selectedLayer(scene);
    if (layer != null) {
      _deleteLayer(scene, layer);
      return;
    }
    if (lesson.scenes.length <= 1) {
      _snack('A lesson needs at least one slide.');
      return;
    }
    final index = lesson.scenes.indexOf(scene);
    lesson.scenes.removeAt(index);
    _player?.seek(sceneStartMs(lesson, math.min(index, lesson.scenes.length - 1)));
    _selectedId = null;
    _sceneSelected = false;
    _commit();
  }

  void _duplicateLayer(Scene scene, Layer layer) {
    final copy = layer.copy();
    copy.cx = (copy.cx + 0.04).clamp(0.0, 1.0).toDouble();
    copy.cy = (copy.cy + 0.04).clamp(0.0, 1.0).toDouble();
    _addLayer(scene, copy);
  }

  void _deleteLayer(Scene scene, Layer layer) {
    scene.layers.remove(layer);
    _selectedId = null;
    _commit();
  }

  Future<void> _openLayers() async {
    final scene = _currentScene();
    if (scene == null) return;
    _pause();
    await showLayersSheet(
      context,
      scene: scene,
      selectedId: _selectedId,
      onSelect: _selectLayer,
      onChanged: () {
        _commit();
      },
    );
  }

  Future<void> _adjust() async {
    final scene = _currentScene();
    final layer = _selectedLayer(scene);
    await _openEdit(layer != null && layer.type == 'text' ? 'content' : 'style');
  }

  Future<void> _volume() async {
    if (_selectedAudioId != null) {
      await _audioSettings();
      return;
    }
    final lesson = _lesson();
    final scene = _currentScene();
    if (lesson == null || scene == null) return;
    _pause();
    await showVolumeSheet(
      context,
      lesson: lesson,
      scene: scene,
      onLive: () {
        if (mounted) setState(() {});
      },
    );
    _commit();
  }

  Future<void> _speed() async {
    final scene = _currentScene();
    if (scene == null) return;
    _pause();
    final layer = _selectedLayer(scene);
    if (layer == null) {
      _needItem();
      return;
    }
    await showSpeedSheet(
      context,
      layer,
      onLive: () {
        if (mounted) setState(() {});
      },
    );
    _commit();
  }

  // ---- extra audio clips ----

  AudioClip? _selectedAudio() {
    final lesson = _lesson();
    final id = _selectedAudioId;
    if (lesson == null || id == null) return null;
    for (final clip in lesson.audioClips) {
      if (clip.id == id) return clip;
    }
    return null;
  }

  void _selectAudio(String id) {
    setState(() {
      _selectedAudioId = id;
      _selectedId = null;
      _sceneSelected = false;
    });
  }

  Future<void> _openSound() async {
    final choice = await showSoundChooser(context);
    if (choice == null || !mounted) return;
    if (choice == 'narration') {
      await _openAudio();
    } else {
      await _addAudioClip(choice == 'sfx' ? 'sfx' : 'music');
    }
  }

  String _clipName(String path) {
    var name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name.length > 28 ? name.substring(0, 28) : name;
  }

  Future<void> _addAudioClip(String kind) async {
    final lesson = _lesson();
    final player = _player;
    if (lesson == null || player == null) return;
    _pause();
    String? path;
    try {
      path = await KainuwaEncoder.pickAudio();
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    var sourceMs = 0;
    try {
      sourceMs = await KainuwaEncoder.audioDuration(path);
    } catch (_) {
      sourceMs = 0;
    }
    if (!mounted) return;
    if (sourceMs <= 0) {
      _snack('That audio file could not be read.');
      return;
    }
    final total = lesson.durationMs;
    final start = math.min(player.positionMs, math.max(0, total - 1000));
    final clip = AudioClip(
      id: newId(),
      path: path,
      label: _clipName(path),
      kind: kind,
      startMs: start,
      durationMs: math.min(sourceMs, math.max(1000, total - start)),
      sourceMs: sourceMs,
      volume: kind == 'music' ? 0.5 : 1.0,
    );
    lesson.audioClips.add(clip);
    _selectAudio(clip.id);
    _commit();
  }

  void _splitAudio() {
    final lesson = _lesson();
    final clip = _selectedAudio();
    final player = _player;
    if (lesson == null || clip == null || player == null) return;
    _pause();
    final local = player.positionMs - clip.startMs;
    if (local < 300 || clip.durationMs - local < 300) {
      _snack('Move the playhead inside the clip, at least 0.3 seconds from its edges, to split it.');
      return;
    }
    final second = clip.copy();
    second.startMs = clip.startMs + local;
    second.trimMs = clip.trimMs + local;
    second.durationMs = clip.durationMs - local;
    second.fadeInMs = 0;
    clip.durationMs = local;
    clip.fadeOutMs = 0;
    lesson.audioClips.add(second);
    _selectAudio(second.id);
    _commit();
  }

  void _duplicateAudio() {
    final lesson = _lesson();
    final clip = _selectedAudio();
    if (lesson == null || clip == null) return;
    _pause();
    final copy = clip.copy();
    copy.startMs = math.min(clip.endMs, math.max(0, lesson.durationMs - 300));
    lesson.audioClips.add(copy);
    _selectAudio(copy.id);
    _commit();
  }

  void _deleteAudio() {
    final lesson = _lesson();
    final clip = _selectedAudio();
    if (lesson == null || clip == null) return;
    _pause();
    lesson.audioClips.remove(clip);
    setState(() => _selectedAudioId = null);
    _commit();
  }

  Future<void> _audioSettings() async {
    final clip = _selectedAudio();
    if (clip == null) return;
    _pause();
    final action = await showAudioClipSheet(
      context,
      clip: clip,
      onLive: () {
        if (mounted) setState(() {});
      },
    );
    if (!mounted) return;
    if (action == 'duplicate') {
      _duplicateAudio();
    } else if (action == 'delete') {
      _deleteAudio();
    } else {
      _commit();
    }
  }

  // ---- scenes and tracks ----

  void _addScene() {
    final lesson = _lesson();
    final current = _currentScene();
    if (lesson == null || current == null) return;
    _pause();
    final index = lesson.scenes.indexOf(current);
    lesson.scenes.insert(
      index + 1,
      Scene(
        id: newId(),
        durationMs: current.durationMs,
        bgType: current.bgType,
        bgValue: current.bgValue,
      ),
    );
    _player?.seek(sceneStartMs(lesson, index + 1));
    _selectedId = null;
    _sceneSelected = true;
    _commit();
  }

  void _setSceneDuration(int index, int ms) {
    final lesson = _lesson();
    if (lesson == null || index < 0 || index >= lesson.scenes.length) return;
    lesson.scenes[index].durationMs = math.max(500, ms);
    if (mounted) setState(() {});
  }

  Future<void> _sceneMenu(int index) async {
    final lesson = _lesson();
    if (lesson == null || index >= lesson.scenes.length) return;
    _pause();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Duplicate slide'),
              onTap: () => Navigator.of(sheetContext).pop('duplicate'),
            ),
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Move earlier'),
                onTap: () => Navigator.of(sheetContext).pop('earlier'),
              ),
            if (index < lesson.scenes.length - 1)
              ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: const Text('Move later'),
                onTap: () => Navigator.of(sheetContext).pop('later'),
              ),
            if (lesson.scenes.length > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete slide'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    var target = index;
    switch (action) {
      case 'duplicate':
        lesson.scenes.insert(index + 1, lesson.scenes[index].duplicate());
        target = index + 1;
        break;
      case 'earlier':
        {
          final moved = lesson.scenes.removeAt(index);
          lesson.scenes.insert(index - 1, moved);
          target = index - 1;
        }
        break;
      case 'later':
        {
          final moved = lesson.scenes.removeAt(index);
          lesson.scenes.insert(index + 1, moved);
          target = index + 1;
        }
        break;
      case 'delete':
        lesson.scenes.removeAt(index);
        target = math.min(index, lesson.scenes.length - 1);
        break;
    }
    _player?.seek(sceneStartMs(lesson, target));
    _selectedId = null;
    _sceneSelected = action != 'delete';
    _commit();
  }

  Future<void> _addTrack() async {
    _pause();
    final choice = await showAddTimelineSheet(context);
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'slide':
        _addScene();
        break;
      case 'duplicate':
        _duplicateScene();
        break;
      case 'text':
        await _addText();
        break;
      case 'subtitles':
        await _addSubtitles();
        break;
      case 'illustration':
        await _addIcon();
        break;
      case 'image':
        await _addImage();
        break;
      case 'shape':
        await _addShape();
        break;
      case 'audio':
        await _openSound();
        break;
      case 'voice':
        await _openAudio();
        break;
      case 'sfx':
        await _addAudioClip('sfx');
        break;
      case 'video':
      case 'screen':
        _snack('Video clips and screen recordings come in a later batch.');
        break;
      case 'drawing':
      case 'library':
        _snack('This option is planned for a later update.');
        break;
    }
  }

  void _toggleHidden(String id) {
    final lesson = _lesson();
    if (lesson == null) return;
    if (!lesson.hiddenTracks.remove(id)) lesson.hiddenTracks.add(id);
    _player?.muted = lesson.hiddenTracks.contains('audio');
    _commit();
  }

  Future<void> _trackMenu(String id) async {
    final index = _order.indexOf(id);
    if (index < 0) return;
    final hidden = _lesson()?.hiddenTracks.contains(id) ?? false;
    final isAudio = id == 'audio';
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                '${trackName(id)} track',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KColors.ink),
              ),
            ),
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Move up'),
                onTap: () => Navigator.of(sheetContext).pop('up'),
              ),
            if (index < _order.length - 1)
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('Move down'),
                onTap: () => Navigator.of(sheetContext).pop('down'),
              ),
            if (id != 'video')
              ListTile(
                leading: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                title: Text(
                  isAudio
                      ? (hidden ? 'Unmute the track' : 'Mute the track')
                      : (hidden ? 'Show the track' : 'Hide the track'),
                ),
                subtitle: const Text('A hidden or muted track is left out of the preview and of the exported video.'),
                onTap: () => Navigator.of(sheetContext).pop('hide'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    setState(() {
      if (action == 'up') {
        _order.removeAt(index);
        _order.insert(index - 1, id);
      } else if (action == 'down') {
        _order.removeAt(index);
        _order.insert(index + 1, id);
      }
    });
    if (action == 'hide') _toggleHidden(id);
  }

  // ---- screen parts ----

  String _clock(int ms) {
    final total = ms ~/ 1000;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Widget _headerIcon(double u, IconData icon, VoidCallback? onTap, {String? tooltip}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: _s(u, 84, 34), minHeight: 40),
      icon: Icon(
        icon,
        size: _s(u, 46, 22),
        color: onTap == null ? const Color(0x80FFFFFF) : Colors.white,
      ),
    );
  }

  Widget _header(Lesson lesson, double u) {
    final top = MediaQuery.of(context).padding.top;
    final history = _history;
    return Container(
      color: KColors.deepPurple,
      padding: EdgeInsets.only(top: top),
      child: SizedBox(
        height: math.max(52.0, _s(u, 113)),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back, size: _s(u, 50, 24), color: Colors.white),
            ),
            Expanded(
              child: Text(
                lesson.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _s(u, 46, 16),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _headerIcon(u, Icons.undo, (history?.canUndo ?? false) ? _undo : null, tooltip: 'Undo'),
            _headerIcon(u, Icons.redo, (history?.canRedo ?? false) ? _redo : null, tooltip: 'Redo'),
            _headerIcon(u, Icons.save_outlined, _save, tooltip: 'Save'),
            SizedBox(width: _s(u, 12, 4)),
            Material(
              color: KColors.editorExport,
              borderRadius: BorderRadius.circular(_s(u, 18, 10)),
              child: InkWell(
                borderRadius: BorderRadius.circular(_s(u, 18, 10)),
                onTap: _export,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: _s(u, 20, 10), vertical: _s(u, 14, 8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_outlined, size: _s(u, 40, 18), color: Colors.white),
                      SizedBox(width: _s(u, 10, 4)),
                      Text(
                        'Export',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _s(u, 32, 13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: _s(u, 20, 8)),
          ],
        ),
      ),
    );
  }

  Widget _preview(Lesson lesson, Scene scene, SceneSpot spot, double u) {
    final player = _player!;
    final playing = player.playing;
    return Padding(
      padding: EdgeInsets.fromLTRB(_s(u, 28), _s(u, 25), _s(u, 28), 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_s(u, 28, 12)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: SceneCanvas(
            scene: viewScene(scene, lesson.hiddenTracks),
            selectedId: playing ? null : _selectedId,
            interactive: !playing,
            previewMs: playing ? spot.localMs : null,
            ghostAtMs: playing ? null : spot.localMs,
            onSelect: _selectLayer,
            onCommit: _commit,
            onDuplicate: (id) {
              final layer = _selectedLayer(scene);
              if (layer != null && layer.id == id) _duplicateLayer(scene, layer);
            },
            onDelete: (id) {
              final layer = _selectedLayer(scene);
              if (layer != null && layer.id == id) _deleteLayer(scene, layer);
            },
          ),
        ),
      ),
    );
  }

  Widget _roundIcon(double size, IconData icon, VoidCallback onTap, {Color? color, Color? iconColor}) {
    return Material(
      color: color ?? Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.62, color: iconColor ?? KColors.ink),
        ),
      ),
    );
  }

  Widget _transport(Lesson lesson, double u) {
    final player = _player!;
    final side = math.max(44.0, _s(u, 70));
    final playSize = math.max(48.0, _s(u, 84));
    return Padding(
      padding: EdgeInsets.fromLTRB(_s(u, 38), _s(u, 22), _s(u, 32), _s(u, 14)),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: KColors.editorLabel,
                borderRadius: BorderRadius.circular(_s(u, 18, 10)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(_s(u, 18, 10)),
                  onTap: () => _fullscreen(lesson),
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: Icon(Icons.crop_free, size: side * 0.62, color: KColors.ink),
                  ),
                ),
              ),
            ),
          ),
          _roundIcon(side, Icons.skip_previous, player.previous),
          SizedBox(width: _s(u, 20, 6)),
          Material(
            color: KColors.editorPlay,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: player.toggle,
              child: SizedBox(
                width: playSize,
                height: playSize,
                child: Icon(
                  player.playing ? Icons.pause : Icons.play_arrow_rounded,
                  size: playSize * 0.62,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: _s(u, 20, 6)),
          _roundIcon(side, Icons.skip_next, player.next),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_clock(player.positionMs)} / ${_clock(player.totalMs)}',
                  style: TextStyle(
                    fontSize: _s(u, 31, 12),
                    fontWeight: FontWeight.w600,
                    color: KColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolItem(double u, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(_s(u, 18, 8)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: _s(u, 12, 6)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: _s(u, 44, 22), color: KColors.editorToolIcon),
              SizedBox(height: _s(u, 8, 2)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: _s(u, 25, 10),
                    color: KColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolDivider(double u) {
    return Container(width: 1, height: _s(u, 70, 30), color: const Color(0xFFE3DDF3));
  }

  Widget _toolCard(double u) {
    final tools = <(IconData, String, VoidCallback)>[
      (Icons.content_cut, 'Split', _split),
      (Icons.copy_all_outlined, 'Duplicate', _duplicateSelection),
      (Icons.delete_outline, 'Delete', _deleteSelection),
      (Icons.layers_outlined, 'Layer', _openLayers),
      (Icons.tune, 'Adjust', _adjust),
      (Icons.volume_up_outlined, 'Volume', _volume),
      (Icons.speed, 'Speed', _speed),
    ];
    final children = <Widget>[];
    for (var i = 0; i < tools.length; i++) {
      if (i > 0) children.add(_toolDivider(u));
      children.add(_toolItem(u, tools[i].$1, tools[i].$2, tools[i].$3));
    }
    return Container(
      margin: EdgeInsets.fromLTRB(_s(u, 14, 6), _s(u, 12, 4), _s(u, 14, 6), _s(u, 10, 4)),
      height: math.max(62.0, _s(u, 126)),
      decoration: BoxDecoration(
        color: KColors.editorCard,
        borderRadius: BorderRadius.circular(_s(u, 28, 14)),
        boxShadow: const [BoxShadow(color: Color(0x1A3B0F8C), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Row(children: children),
    );
  }

  Future<void> _navTap(int index) async {
    _pause();
    setState(() => _tab = index);
    switch (index) {
      case 1:
        await _setBackground();
        break;
      case 2:
        await _openAdd();
        break;
      case 3:
        await _openSound();
        break;
      case 4:
        await _openAnimate();
        break;
      case 5:
        await _setDuration();
        break;
    }
    if (mounted) setState(() => _tab = 0);
  }

  Widget _bottomNav(double u) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final items = <(IconData, String)>[
      (Icons.movie_outlined, 'Timeline'),
      (Icons.wallpaper, 'Background'),
      (Icons.add_box_outlined, 'Add'),
      (Icons.mic_none, 'Sound'),
      (Icons.auto_awesome_outlined, 'Animate'),
      (Icons.timer_outlined, 'Time'),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(_s(u, 12, 4), _s(u, 14, 4), _s(u, 12, 4), _s(u, 12, 4) + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x143B0F8C), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _navTap(i),
                child: Container(
                  height: math.max(52.0, _s(u, 116)),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: _tab == i ? KColors.editorNav : Colors.transparent,
                    borderRadius: BorderRadius.circular(_s(u, 30, 14)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].$1,
                        size: _s(u, 50, 24),
                        color: _tab == i ? Colors.white : KColors.editorNav,
                      ),
                      SizedBox(height: _s(u, 6, 2)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          items[i].$2,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: _s(u, 26, 10.5),
                            fontWeight: FontWeight.w600,
                            color: _tab == i ? Colors.white : KColors.editorNav,
                          ),
                        ),
                      ),
                    ],
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
    final state = AppScope.of(context);
    final lesson = state.lessonById(widget.courseId, widget.lessonId);
    final player = _player;

    if (lesson == null || player == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This lesson no longer exists.')),
      );
    }
    if (lesson.scenes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(lesson.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    player.muted = lesson.hiddenTracks.contains('audio');
    final spot = sceneAt(lesson, player.positionMs);
    final scene = lesson.scenes[spot.index];
    final width = math.min(MediaQuery.of(context).size.width, 640.0);
    final u = width / 941.0;

    return Scaffold(
      backgroundColor: KColors.editorPanel,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              _header(lesson, u),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _preview(lesson, scene, spot, u),
                      _transport(lesson, u),
                      TimelinePanel(
                        lesson: lesson,
                        player: player,
                        order: _order,
                        hidden: lesson.hiddenTracks,
                        selectedLayerId: _selectedId,
                        selectedAudioId: _selectedAudioId,
                        sceneSelected: _sceneSelected,
                        onSelectScene: _selectScene,
                        onSelectLayer: _selectLayerFromTimeline,
                        onSelectAudio: _selectAudio,
                        onSceneMenu: _sceneMenu,
                        onSceneDuration: _setSceneDuration,
                        onEditEnd: _commit,
                        onLayerTiming: () {
                          if (mounted) setState(() {});
                        },
                        onAudioChanged: () {
                          if (mounted) setState(() {});
                        },
                        onTrackMenu: _trackMenu,
                        onToggleHidden: _toggleHidden,
                        onAddTrack: _addTrack,
                        onAddScene: _addScene,
                      ),
                      SizedBox(height: _s(u, 16, 8)),
                    ],
                  ),
                ),
              ),
              _toolCard(u),
              _bottomNav(u),
            ],
          ),
        ),
      ),
    );
  }
}
