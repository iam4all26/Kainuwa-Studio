import 'dart:io';

import 'package:flutter/material.dart';

import '../export_history.dart';
import '../theme.dart';

/// The page shown right after an export finishes: the new video, quick actions
/// and the list of this project's exported videos.
class ExportSuccessView extends StatelessWidget {
  const ExportSuccessView({
    super.key,
    required this.latest,
    required this.history,
    required this.onPlay,
    required this.onShare,
    required this.onOpenWith,
    required this.onMore,
    required this.onRemove,
  });

  final ExportEntry latest;
  final List<ExportEntry> history;
  final void Function(ExportEntry) onPlay;
  final void Function(ExportEntry) onShare;
  final void Function(ExportEntry) onOpenWith;
  final VoidCallback onMore;
  final void Function(ExportEntry) onRemove;

  static const Color _soft = Color(0xFFB9B0D8);

  @override
  Widget build(BuildContext context) {
    final list = history.isEmpty ? [latest] : history;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1465), Color(0xFF160F33), KColors.background],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const SizedBox(height: 8),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.5, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                  child: const _CheckBadge(),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Project Successfully Exported',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your video has been exported and saved\nin your device storage.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: _soft, height: 1.35),
              ),
              const SizedBox(height: 22),
              _latestCard(),
              const SizedBox(height: 14),
              _actions(),
              const SizedBox(height: 22),
              const Divider(height: 1, color: Color(0x26FFFFFF)),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.layers_outlined, color: Colors.white, size: 26),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Project Exports',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x4D6D28D9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: Text(
                      '${list.length} ${list.length == 1 ? 'Video' : 'Videos'}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final e in list) ...[
                _row(context, e),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _latestCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x66231A48),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x40B9A0FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 11,
            child: _Thumb(entry: latest, radius: 16, badgeSize: 13, aspect: 16 / 10),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  latest.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x666D28D9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('MP4',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: KColors.accent)),
                    ),
                    Text(latest.resolution, style: const TextStyle(fontSize: 14, color: _soft)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 20, color: _soft),
                    const SizedBox(width: 8),
                    Text(latest.sizeText, style: const TextStyle(fontSize: 15, color: _soft)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    Widget tile(IconData icon, String label, VoidCallback tap, {bool primary = false, int flex = 11}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              height: 76,
              decoration: BoxDecoration(
                gradient: primary
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B6CFF), Color(0xFF6D28D9)],
                      )
                    : null,
                color: primary ? null : const Color(0x33231A48),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary ? const Color(0x80D6C8FF) : const Color(0x33B9A0FF)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: tap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 30, color: Colors.white),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(Icons.play_arrow_rounded, 'Play', () => onPlay(latest), primary: true),
        tile(Icons.share_outlined, 'Share', () => onShare(latest)),
        tile(Icons.folder_open_outlined, 'Open File', () => onOpenWith(latest)),
        tile(Icons.more_vert, 'More', onMore, flex: 10),
      ],
    );
  }

  Widget _row(BuildContext context, ExportEntry e) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0x4D231A48),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x33B9A0FF)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onPlay(e),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(width: 112, child: _Thumb(entry: e, radius: 12, badgeSize: 11, aspect: 16 / 9.4)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _meta(Icons.movie_outlined, 'MP4'),
                          _meta(null, e.shortResolution),
                          _meta(Icons.insert_drive_file_outlined, e.sizeText),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: KColors.editorCard,
                  onSelected: (v) {
                    if (v == 'play') onPlay(e);
                    if (v == 'share') onShare(e);
                    if (v == 'open') onOpenWith(e);
                    if (v == 'remove') onRemove(e);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'play', child: Text('Play')),
                    PopupMenuItem(value: 'share', child: Text('Share')),
                    PopupMenuItem(value: 'open', child: Text('Open with')),
                    PopupMenuItem(value: 'remove', child: Text('Remove from list')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData? icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: _soft),
            const SizedBox(width: 5),
          ],
          Text(text, style: const TextStyle(fontSize: 13, color: _soft)),
        ],
      );
}

/// Picture of the video with the play icon and length in the corner.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.entry, required this.radius, required this.badgeSize, required this.aspect});

  final ExportEntry entry;
  final double radius;
  final double badgeSize;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    Widget picture;
    if (entry.thumbPath.isNotEmpty && File(entry.thumbPath).existsSync()) {
      picture = Image.file(File(entry.thumbPath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback());
    } else {
      picture = _fallback();
    }
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: badgeSize + 2, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(entry.clock,
                        style: TextStyle(fontSize: badgeSize, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF41038B), Color(0xFF7351FF), KColors.gold],
          ),
        ),
        child: Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white70, size: 30)),
      );
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _ConfettiPainter())),
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
              ),
              boxShadow: [BoxShadow(color: Color(0x6622C55E), blurRadius: 28, spreadRadius: 2)],
            ),
            child: const Icon(Icons.check_rounded, size: 76, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    void bar(double dx, double dy, double angle, Color color, double w, double h) {
      canvas.save();
      canvas.translate(c.dx + dx, c.dy + dy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(h / 2)),
        Paint()..color = color,
      );
      canvas.restore();
    }

    const gold = KColors.gold;
    const purple = Color(0xFF7351FF);
    const teal = Color(0xFF2DD4BF);
    const red = Color(0xFFFB5A5A);
    bar(-86, -42, -0.7, gold, 20, 7);
    bar(-114, -6, 0, red, 7, 7);
    bar(-92, 36, -0.8, teal, 13, 6);
    bar(88, -44, 0.7, gold, 20, 7);
    bar(106, -10, -0.15, purple, 24, 6);
    bar(92, 36, 0.8, teal, 13, 6);
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
