import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/animated_icons.dart';
import '../models.dart';
import '../scene_canvas.dart';
import '../theme.dart';

/// A grid of the animated icons, each one playing on a loop. [onPick] is called with the icon that was tapped.
class AnimatedIconGrid extends StatelessWidget {
  const AnimatedIconGrid({super.key, required this.onPick});

  final ValueChanged<AnimIconPreset> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: kAnimatedIcons.length,
      itemBuilder: (context, index) {
        final preset = kAnimatedIcons[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onPick(preset),
          child: Container(
            decoration: BoxDecoration(
              color: KColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KColors.lavender),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Expanded(child: AnimatedIconPreview(preset: preset)),
                const SizedBox(height: 6),
                Text(preset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Plays one animated icon again and again on a dark square.
class AnimatedIconPreview extends StatefulWidget {
  const AnimatedIconPreview({super.key, required this.preset});

  final AnimIconPreset preset;

  @override
  State<AnimatedIconPreview> createState() => _AnimatedIconPreviewState();
}

class _AnimatedIconPreviewState extends State<AnimatedIconPreview> with SingleTickerProviderStateMixin {
  Scene? _scene;
  Ticker? _ticker;
  final ValueNotifier<int> _ms = ValueNotifier<int>(0);
  int _loopMs = 3000;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final preset = widget.preset;
    // A square picture, so the icon is drawn with a size that fills most of it.
    final layers = await buildAnimatedIcon(preset, aspect: 1.0, size: (preset.size * 2.6).clamp(0.4, 0.8).toDouble());
    if (!mounted || layers.isEmpty) return;
    _loopMs = preset.totalMs + 1800;
    final scene = Scene(
      id: newId(),
      durationMs: _loopMs + 500,
      bgType: 'color',
      bgValue: 0xFF1E1938.toString(),
      layers: layers,
    );
    _ticker = createTicker((elapsed) => _ms.value = elapsed.inMilliseconds % _loopMs)..start();
    setState(() => _scene = scene);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1,
        child: scene == null
            ? const ColoredBox(color: Color(0xFF1E1938))
            : FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 400,
                  height: 400,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _ms,
                    builder: (context, ms, _) => SceneCanvas(scene: scene, previewMs: ms),
                  ),
                ),
              ),
      ),
    );
  }
}
