import '../models.dart';

/// A copy of the slide without what the hidden tracks switch off. Layers are
/// shared with the real slide, so editing the copy edits the real slide.
Scene viewScene(Scene scene, Set<String> hidden) {
  final hideImage = hidden.contains('image');
  final hideText = hidden.contains('text');
  if (!hideImage && !hideText) return scene;
  return Scene(
    id: scene.id,
    durationMs: scene.durationMs,
    bgType: hideImage ? 'color' : scene.bgType,
    bgValue: hideImage ? (0xFFE5E1F3).toString() : scene.bgValue,
    narrationPath: scene.narrationPath,
    narrationMs: scene.narrationMs,
    narrationVolume: scene.narrationVolume,
    narrationClean: scene.narrationClean,
    layers: scene.layers.where((l) => l.type == 'text' ? !hideText : !hideImage).toList(),
  );
}
