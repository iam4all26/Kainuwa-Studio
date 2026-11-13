import 'package:flutter/material.dart';

import '../theme.dart';

/// "Add to Timeline" sheet. Returns one of: slide, duplicate, image,
/// illustration, shape, text, subtitles, drawing, audio, video, screen, voice,
/// sfx, library. Returns null when closed.
Future<String?> showAddTimelineSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => const _AddTimelineSheet(),
  );
}

class _AddTimelineSheet extends StatelessWidget {
  const _AddTimelineSheet();

  Widget _section(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 16, 5),
          decoration: BoxDecoration(
            color: const Color(0x33B9A8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: KColors.purple),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: KColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required String value,
    bool compact = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Color.alphaBlend(accent.withAlpha(28), const Color(0xFFF7F3FF)),
          borderRadius: BorderRadius.circular(16),
          elevation: 0.5,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).pop(value),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 10 : 12),
              child: Row(
                children: [
                  Icon(icon, size: compact ? 28 : 32, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: KColors.ink),
                        ),
                        Text(
                          subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF4F4968), height: 1.2),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: KColors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _small(BuildContext context, IconData icon, String title, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: const Color(0xFFF7F3FF),
          borderRadius: BorderRadius.circular(14),
          elevation: 0.5,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).pop(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 26, color: KColors.purple),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KColors.ink)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F1FF), Color(0xFFE6DCFA)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: const Color(0xFFB9AEDB), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [KColors.purple, Color(0xFF8B3DF0)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.movie_creation_outlined, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add to Timeline',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: KColors.ink),
                          ),
                          Text(
                            'Choose what to add to your video at the current position.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF4F4968)),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                _section(Icons.layers_outlined, 'Scene'),
                Row(
                  children: [
                    _tile(context, icon: Icons.add_box_outlined, accent: KColors.purple, title: 'New Slide', subtitle: 'Add a new scene after the current one', value: 'slide'),
                    _tile(context, icon: Icons.copy_all_outlined, accent: KColors.purple, title: 'Duplicate Slide', subtitle: 'Create a copy of the current scene', value: 'duplicate'),
                  ],
                ),
                _section(Icons.image_outlined, 'Visual Elements'),
                Row(
                  children: [
                    _tile(context, icon: Icons.image, accent: const Color(0xFF2F80ED), title: 'Add Image', subtitle: 'Insert a photo from your device', value: 'image', compact: true),
                    _tile(context, icon: Icons.emoji_objects, accent: KColors.purple, title: 'Add Illustration', subtitle: 'Use icons, graphics or illustrations', value: 'illustration', compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _tile(context, icon: Icons.crop_square, accent: const Color(0xFFF2994A), title: 'Add Shape', subtitle: 'Insert a shape (box, circle, etc.)', value: 'shape', compact: true),
                    _tile(context, icon: Icons.title, accent: KColors.purple, title: 'Add Text', subtitle: 'Insert a text box (title, caption, etc.)', value: 'text', compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _tile(context, icon: Icons.closed_caption_outlined, accent: const Color(0xFF2F80ED), title: 'Add Subtitles', subtitle: 'Insert a caption at the bottom of the slide', value: 'subtitles', compact: true),
                    _tile(context, icon: Icons.draw_outlined, accent: const Color(0xFFE0407B), title: 'Add Drawing', subtitle: 'Draw or highlight on the slide', value: 'drawing', compact: true),
                  ],
                ),
                _section(Icons.play_circle_outline, 'Media'),
                Row(
                  children: [
                    _tile(context, icon: Icons.headphones, accent: const Color(0xFF1FA463), title: 'Add Audio', subtitle: 'Record narration, add music or sound effect', value: 'audio'),
                    _tile(context, icon: Icons.videocam, accent: const Color(0xFFE5532D), title: 'Add Video', subtitle: 'Insert a video clip (MP4, MOV, etc.)', value: 'video'),
                  ],
                ),
                _section(Icons.settings_outlined, 'More Options'),
                Row(
                  children: [
                    _small(context, Icons.videocam_outlined, 'Screen Recording', 'screen'),
                    _small(context, Icons.mic_none, 'Record Voice', 'voice'),
                    _small(context, Icons.graphic_eq, 'Add Sound Effect', 'sfx'),
                    _small(context, Icons.folder_open, 'From Library', 'library'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
