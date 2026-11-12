import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../app_state.dart';
import '../models.dart';
import '../scene_canvas.dart';
import '../theme.dart';
import '../widgets.dart';
import 'editor_sheets.dart';

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

class _LessonEditorScreenState extends State<LessonEditorScreen> {
  int _sceneIndex = 0;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.read(context);
      final lesson = state.lessonById(widget.courseId, widget.lessonId);
      if (lesson != null && lesson.scenes.isEmpty) {
        lesson.scenes.add(Scene(id: newId()));
        state.persist();
      }
    });
  }

  Lesson? _lesson() => AppScope.read(context).lessonById(widget.courseId, widget.lessonId);

  Scene? _currentScene() {
    final lesson = _lesson();
    if (lesson == null || lesson.scenes.isEmpty) return null;
    if (_sceneIndex >= lesson.scenes.length) _sceneIndex = lesson.scenes.length - 1;
    return lesson.scenes[_sceneIndex];
  }

  Future<void> _commit() async {
    if (mounted) setState(() {});
    final state = AppScope.read(context);
    await state.persist();
  }

  void _addLayer(Scene scene, Layer layer) {
    scene.layers.add(layer);
    _selectedId = layer.id;
    _commit();
  }

  // ---- text measuring ----

  TextPainter _measure(String text) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 100, fontWeight: FontWeight.w800, height: 1.15),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
  }

  double _textAspect(String text) {
    final painter = _measure(text);
    final aspect = painter.width / (painter.height == 0 ? 1 : painter.height);
    painter.dispose();
    return aspect <= 0 ? 1 : aspect;
  }

  (double, double) _textBox(String text) {
    final painter = _measure(text);
    final lines = painter.computeLineMetrics().length;
    final aspect = painter.width / (painter.height == 0 ? 1 : painter.height);
    painter.dispose();
    var h = (0.12 * lines).clamp(0.12, 0.7).toDouble();
    var w = h * (aspect <= 0 ? 1 : aspect) * (9 / 16);
    if (w > 0.9) {
      w = 0.9;
      h = w * (16 / 9) / (aspect <= 0 ? 1 : aspect);
    }
    return (w, h);
  }

  // ---- adding things ----

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
    final box = _textBox(text);
    _addLayer(
      scene,
      Layer(
        id: newId(),
        type: 'text',
        w: box.$1,
        h: box.$2,
        text: text,
        color: scene.isDarkBackground ? 0xFFFFFFFF : 0xFF1E1433,
      ),
    );
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

  Future<void> _setDuration() async {
    final scene = _currentScene();
    if (scene == null) return;
    final ms = await showDurationSheet(context, scene.durationMs);
    if (ms == null) return;
    scene.durationMs = ms;
    _commit();
  }

  // ---- actions on the selected item ----

  Future<void> _editText(Layer layer) async {
    final text = await promptText(
      context,
      title: 'Edit text',
      label: 'Text',
      initial: layer.text,
      maxLength: 200,
      multiline: true,
    );
    if (text == null || !mounted) return;
    layer.text = text;
    layer.h = (layer.w * (16 / 9) / _textAspect(text)).clamp(0.03, 1.6).toDouble();
    _commit();
  }

  Future<void> _changeColor(Layer layer) async {
    final value = await pickColor(context);
    if (value == null) return;
    layer.color = value;
    _commit();
  }

  void _resize(Layer layer, double factor) {
    layer.w = (layer.w * factor).clamp(0.03, 1.6).toDouble();
    layer.h = (layer.h * factor).clamp(0.03, 1.6).toDouble();
    _commit();
  }

  void _rotate(Layer layer) {
    layer.rotation += math.pi / 12;
    _commit();
  }

  void _move(Scene scene, Layer layer, int delta) {
    final index = scene.layers.indexOf(layer);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= scene.layers.length) return;
    scene.layers.removeAt(index);
    scene.layers.insert(target, layer);
    _commit();
  }

  void _duplicate(Scene scene, Layer layer) {
    final copy = layer.copy();
    copy.cx = (copy.cx + 0.04).clamp(0.0, 1.0).toDouble();
    copy.cy = (copy.cy + 0.04).clamp(0.0, 1.0).toDouble();
    _addLayer(scene, copy);
  }

  void _delete(Scene scene, Layer layer) {
    scene.layers.remove(layer);
    _selectedId = null;
    _commit();
  }

  // ---- scenes ----

  void _addScene(Lesson lesson, Scene current) {
    final scene = Scene(
      id: newId(),
      durationMs: current.durationMs,
      bgType: current.bgType,
      bgValue: current.bgValue,
    );
    lesson.scenes.insert(_sceneIndex + 1, scene);
    _sceneIndex += 1;
    _selectedId = null;
    _commit();
  }

  Future<void> _sceneMenu(Lesson lesson, int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Duplicate scene'),
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
                title: const Text('Delete scene'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'duplicate':
        lesson.scenes.insert(index + 1, lesson.scenes[index].duplicate());
        _sceneIndex = index + 1;
        break;
      case 'earlier':
        {
          final moved = lesson.scenes.removeAt(index);
          lesson.scenes.insert(index - 1, moved);
          _sceneIndex = index - 1;
        }
        break;
      case 'later':
        {
          final moved = lesson.scenes.removeAt(index);
          lesson.scenes.insert(index + 1, moved);
          _sceneIndex = index + 1;
        }
        break;
      case 'delete':
        lesson.scenes.removeAt(index);
        _sceneIndex = math.min(_sceneIndex, lesson.scenes.length - 1);
        break;
    }
    _selectedId = null;
    _commit();
  }

  // ---- screen ----

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: KColors.purple),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionBar(Scene scene, Layer? selected) {
    if (selected == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Text(
          'Tap an item on the slide to select it. Drag to move it. Pinch with two fingers to resize and turn it.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }
    final layer = selected;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          if (layer.type == 'text') _chip(Icons.edit_outlined, 'Edit', () => _editText(layer)),
          if (layer.type == 'text' || layer.type == 'shape')
            _chip(Icons.palette_outlined, 'Color', () => _changeColor(layer)),
          _chip(Icons.zoom_in, 'Bigger', () => _resize(layer, 1.15)),
          _chip(Icons.zoom_out, 'Smaller', () => _resize(layer, 1 / 1.15)),
          _chip(Icons.rotate_right, 'Rotate', () => _rotate(layer)),
          _chip(Icons.flip_to_front, 'Forward', () => _move(scene, layer, 1)),
          _chip(Icons.flip_to_back, 'Back', () => _move(scene, layer, -1)),
          _chip(Icons.content_copy, 'Duplicate', () => _duplicate(scene, layer)),
          _chip(Icons.delete_outline, 'Delete', () => _delete(scene, layer)),
        ],
      ),
    );
  }

  Widget _sceneStrip(Lesson lesson) {
    final current = lesson.scenes[_sceneIndex];
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: lesson.scenes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == lesson.scenes.length) {
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _addScene(lesson, current),
              child: Container(
                width: 63,
                height: 63,
                decoration: BoxDecoration(
                  color: KColors.lavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: KColors.deepPurple),
              ),
            );
          }
          final scene = lesson.scenes[index];
          final selected = index == _sceneIndex;
          return GestureDetector(
            onTap: () => setState(() {
              _sceneIndex = index;
              _selectedId = null;
            }),
            onLongPress: () => _sceneMenu(lesson, index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 63,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? KColors.gold : KColors.lavender,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: IgnorePointer(child: SceneCanvas(scene: scene)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${index + 1} - ${(scene.durationMs / 1000).toStringAsFixed(1)} s',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lesson = state.lessonById(widget.courseId, widget.lessonId);

    if (lesson == null) {
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
    if (_sceneIndex >= lesson.scenes.length) _sceneIndex = lesson.scenes.length - 1;
    final scene = lesson.scenes[_sceneIndex];
    Layer? selected;
    for (final layer in scene.layers) {
      if (layer.id == _selectedId) selected = layer;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(formatClock(lesson.durationMs)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: SceneCanvas(
                  scene: scene,
                  selectedId: _selectedId,
                  interactive: true,
                  onSelect: (id) => setState(() => _selectedId = id),
                  onCommit: _commit,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _selectionBar(scene, selected),
                  _sceneStrip(lesson),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Text(
                      'Tap a scene to edit it. Press and hold a scene to duplicate, move or delete it.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          child: Row(
            children: [
              _tool(Icons.wallpaper, 'Background', _setBackground),
              _tool(Icons.title, 'Text', _addText),
              _tool(Icons.star_outline, 'Icon', _addIcon),
              _tool(Icons.image_outlined, 'Image', _addImage),
              _tool(Icons.category_outlined, 'Shape', _addShape),
              _tool(Icons.timer_outlined, 'Time', _setDuration),
            ],
          ),
        ),
      ),
    );
  }
}
