import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Short name of a layer, shown on the timeline and in the layer list.
String layerLabel(Layer layer) {
  switch (layer.type) {
    case 'text':
      final first = layer.text.split('\n').first.trim();
      if (first.isEmpty) return 'Text';
      return first.length > 22 ? '${first.substring(0, 22)}...' : first;
    case 'asset':
      return 'Icon';
    case 'image':
      return 'Photo';
    case 'shape':
      switch (layer.shape) {
        case 'circle':
          return 'Circle';
        case 'round':
          return 'Rounded box';
        default:
          return 'Box';
      }
    default:
      return 'Item';
  }
}

IconData layerIcon(Layer layer) {
  switch (layer.type) {
    case 'text':
      return Icons.title;
    case 'asset':
      return Icons.emoji_objects_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'shape':
      return layer.shape == 'circle' ? Icons.circle_outlined : Icons.crop_square;
    default:
      return Icons.layers_outlined;
  }
}

Widget _sheetTitle(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KColors.ink),
    ),
  );
}

// ---------------------------------------------------------------------------
// Volume: narration of this scene and music of the lesson
// ---------------------------------------------------------------------------

Future<void> showVolumeSheet(
  BuildContext context, {
  required Lesson lesson,
  required Scene scene,
  required VoidCallback onLive,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _VolumeSheet(lesson: lesson, scene: scene, onLive: onLive),
  );
}

class _VolumeSheet extends StatefulWidget {
  const _VolumeSheet({required this.lesson, required this.scene, required this.onLive});

  final Lesson lesson;
  final Scene scene;
  final VoidCallback onLive;

  @override
  State<_VolumeSheet> createState() => _VolumeSheetState();
}

class _VolumeSheetState extends State<_VolumeSheet> {
  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final lesson = widget.lesson;
    final hasNarration = scene.narrationPath.isNotEmpty;
    final hasMusic = lesson.musicPath.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetTitle('Volume'),
            Text(
              hasNarration
                  ? 'Narration of this scene ${(scene.narrationVolume * 100).round()}%'
                  : 'This scene has no narration yet. Use Sound to record or import one.',
            ),
            Slider(
              value: scene.narrationVolume.clamp(0.0, 1.0).toDouble(),
              divisions: 20,
              onChanged: hasNarration
                  ? (v) {
                      setState(() => scene.narrationVolume = v);
                      widget.onLive();
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              hasMusic
                  ? 'Music of the lesson ${(lesson.musicVolume * 100).round()}%'
                  : 'This lesson has no music yet. Use Sound to add some.',
            ),
            Slider(
              value: lesson.musicVolume.clamp(0.0, 1.0).toDouble(),
              divisions: 20,
              onChanged: hasMusic
                  ? (v) {
                      setState(() => lesson.musicVolume = v);
                      widget.onLive();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Speed: how fast the entrance animation of the selected item plays
// ---------------------------------------------------------------------------

const int _normalAnimMs = 800;
const List<double> _speeds = [0.5, 0.75, 1.0, 1.5, 2.0];

Future<void> showSpeedSheet(
  BuildContext context,
  Layer layer, {
  required VoidCallback onLive,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _SpeedSheet(layer: layer, onLive: onLive),
  );
}

class _SpeedSheet extends StatefulWidget {
  const _SpeedSheet({required this.layer, required this.onLive});

  final Layer layer;
  final VoidCallback onLive;

  @override
  State<_SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<_SpeedSheet> {
  bool _isSelected(double speed) {
    final ms = (_normalAnimMs / speed).round();
    return (widget.layer.animDurationMs - ms).abs() < 40;
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetTitle('Speed'),
            Text(
              layer.animIn == 'none'
                  ? 'This item has no entrance animation yet. Use Animate to choose one, then set its speed here.'
                  : 'How fast the entrance animation of this item plays.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final speed in _speeds)
                  ChoiceChip(
                    label: Text('${speed == speed.roundToDouble() ? speed.toInt() : speed}x'),
                    selected: _isSelected(speed),
                    onSelected: (_) {
                      setState(() => layer.animDurationMs = (_normalAnimMs / speed).round());
                      widget.onLive();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layer: order of the items on the slide
// ---------------------------------------------------------------------------

Future<void> showLayersSheet(
  BuildContext context, {
  required Scene scene,
  required String? selectedId,
  required ValueChanged<String> onSelect,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LayersSheet(
      scene: scene,
      selectedId: selectedId,
      onSelect: onSelect,
      onChanged: onChanged,
    ),
  );
}

class _LayersSheet extends StatefulWidget {
  const _LayersSheet({
    required this.scene,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
  });

  final Scene scene;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onChanged;

  @override
  State<_LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<_LayersSheet> {
  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final shown = widget.scene.layers.reversed.toList();
    final item = shown.removeAt(oldIndex);
    shown.insert(newIndex, item);
    widget.scene.layers
      ..clear()
      ..addAll(shown.reversed);
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.scene.layers.reversed.toList();
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetTitle('Layers on this slide'),
            const Text('The top of the list is in front. Press and hold an item, then drag it to change the order. Tap an item to select it.'),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('There is nothing on this slide yet. Use Add to put text, icons or pictures on it.'),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: shown.length,
                  onReorder: _reorder,
                  itemBuilder: (context, index) {
                    final layer = shown[index];
                    final selected = layer.id == widget.selectedId;
                    return ListTile(
                      key: ValueKey(layer.id),
                      contentPadding: EdgeInsets.zero,
                      selected: selected,
                      selectedTileColor: KColors.lavender,
                      leading: Icon(layerIcon(layer), color: KColors.purple),
                      title: Text(layerLabel(layer), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        widget.onSelect(layer.id);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
