import 'package:flutter/material.dart';

import '../animation_math.dart' show animLabel;
import '../app_state.dart';
import '../lyrics_project.dart';
import '../music_project.dart';
import '../music_templates.dart';
import '../project_templates.dart';
import '../scene_canvas.dart';
import '../models.dart';
import '../stage_shape.dart';
import '../visualizer.dart';
import 'lesson_editor_screen.dart';
import 'lyrics_setup_screen.dart';
import 'music_setup_screen.dart';

/// One ready template with its picture.
class _Card {
  _Card({required this.name, required this.note, required this.scene, required this.w, required this.h, required this.onUse});

  final String name;
  final String note;
  final Scene scene;
  final double w;
  final double h;
  final VoidCallback onUse;
}

/// Ready-made music and lyrics videos. The picture of each card is drawn by the same code that builds
/// the real video. A tap asks only for the cover, song and words; fonts, colours and animations stay.
class TemplatesTab extends StatefulWidget {
  const TemplatesTab({super.key});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  List<_Card> _music = [];
  List<_Card> _lyrics = [];

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    final music = <_Card>[];
    Stage.use(16, 9);
    for (final t in kMusicTemplates) {
      final scene = buildMusicScene(MusicSetup(
        cover: '',
        coverAspect: 1.0,
        audio: '',
        audioMs: 0,
        title: 'Song title',
        artist: 'Artist name',
        aspectW: 16,
        aspectH: 9,
        vizKind: t.viz,
        accent: t.accent,
        layout: t.layout,
        titleFont: t.titleFont,
        artistFont: t.artistFont,
      ));
      final viz = kVizKinds.where((k) => k.id == t.viz).map((k) => k.name).join();
      music.add(_Card(
        name: t.name,
        note: viz,
        scene: scene,
        w: Stage.w,
        h: Stage.h,
        onUse: () => _useMusic(t),
      ));
    }
    final lyrics = <_Card>[];
    Stage.use(9, 16);
    for (final l in kLyricsLooks) {
      final scene = buildLyricsScene(
        LyricsSetup(
          audio: '',
          audioMs: 2000,
          cues: const [LyricCue(0, 1000, 'Feel it')],
          aspectW: 9,
          aspectH: 16,
          palette: l.palette,
          font: l.font,
          bg: l.bg,
          fx: l.fx,
          byWord: true,
          anim: l.anim,
        ),
        sampleOnly: true,
      );
      lyrics.add(_Card(
        name: l.name,
        note: 'One word at a time, ${animLabel(l.anim).toLowerCase()}',
        scene: scene,
        w: Stage.w,
        h: Stage.h,
        onUse: () => _useLyrics(l),
      ));
    }
    Stage.reset();
    _music = music;
    _lyrics = lyrics;
  }

  Future<void> _open(Lesson? lesson, (String, String) ids) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LessonEditorScreen(courseId: ids.$1, lessonId: ids.$2)),
    );
  }

  Future<void> _useMusic(MusicTemplate t) async {
    final state = AppScope.read(context);
    final music = await Navigator.of(context).push<MusicSetup>(
      MaterialPageRoute<MusicSetup>(
        builder: (_) => MusicSetupScreen(initial: musicTemplateForm(t), simple: true, templateName: t.name),
      ),
    );
    if (music == null || !mounted) return;
    final title = music.title.trim().isEmpty ? 'Music video' : music.title.trim();
    final ids = await state.addVideo(title: title, aspectW: music.aspectW, aspectH: music.aspectH);
    final lesson = state.lessonById(ids.$1, ids.$2);
    if (lesson != null) {
      buildMusicProject(lesson, music);
      await state.saveNow();
    }
    await _open(lesson, (ids.$1, ids.$2));
  }

  Future<void> _useLyrics(LyricsLook l) async {
    final state = AppScope.read(context);
    final lyrics = await Navigator.of(context).push<LyricsSetup>(
      MaterialPageRoute<LyricsSetup>(
        builder: (_) => LyricsSetupScreen(initial: lyricsTemplateForm(l), simple: true, templateName: l.name),
      ),
    );
    if (lyrics == null || !mounted) return;
    final title = lyrics.title.trim().isEmpty ? 'Lyrics video' : lyrics.title.trim();
    final ids = await state.addVideo(title: title, aspectW: lyrics.aspectW, aspectH: lyrics.aspectH);
    final lesson = state.lessonById(ids.$1, ids.$2);
    if (lesson != null) {
      buildLyricsProject(lesson, lyrics);
      await state.saveNow();
    }
    await _open(lesson, (ids.$1, ids.$2));
  }

  Widget _card(_Card c, double width) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: c.onUse,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: c.w / c.h,
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(width: c.w, height: c.h, child: SceneCanvas(scene: c.scene)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(c.note, style: const TextStyle(fontSize: 12, color: Color(0xFFB5ABD6))),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String hint, List<_Card> cards, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFFB5ABD6))),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 16, children: [for (final c in cards) _card(c, width)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final inner = box.maxWidth - 32;
          final half = (inner - 12) / 2;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text('Templates', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'Pick a look, then add your own cover art, song and words. Fonts, colours and animations are ready. '
                'You can still change everything.',
                style: TextStyle(color: Color(0xFFB5ABD6)),
              ),
              _section('Music videos', 'Cover art, a turning record and an audio picture', _music, half),
              _section('Lyrics videos', 'Words in time with the song', _lyrics, half),
            ],
          );
        },
      ),
    );
  }
}
