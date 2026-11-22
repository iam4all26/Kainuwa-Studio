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
import '../theme.dart';
import '../visualizer.dart';
import 'lesson_editor_screen.dart';
import 'lyrics_setup_screen.dart';
import 'music_setup_screen.dart';

/// One ready template with its picture.
class _Card {
  _Card({required this.name, required this.note, required this.badge, required this.scene, required this.w, required this.h, required this.onUse});

  final String name;
  final String note;
  final String badge;
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
  List<_Card> _record = [];

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
        note: '$viz  -  ${t.titleFont.isEmpty ? 'Default font' : t.titleFont}',
        badge: 'Music',
        scene: scene,
        w: Stage.w,
        h: Stage.h,
        onUse: () => _useMusic(t),
      ));
    }
    final lyrics = <_Card>[];
    final record = <_Card>[];
    for (final l in kLyricsLooks) {
      // A look with the record is drawn wide, the others tall.
      if (l.layout != 0) {
        Stage.use(16, 9);
      } else {
        Stage.use(9, 16);
      }
      final scene = buildLyricsScene(
        LyricsSetup(
          audio: '',
          audioMs: 2000,
          cues: const [LyricCue(0, 1000, 'Feel it')],
          aspectW: l.layout != 0 ? 16 : 9,
          aspectH: l.layout != 0 ? 9 : 16,
          palette: l.palette,
          font: l.font,
          bg: l.bg,
          fx: l.fx,
          byWord: l.byWord,
          anim: l.anim,
          layout: l.layout,
          vizKind: l.viz,
          title: 'Song title',
          artist: 'Artist name',
        ),
        sampleOnly: true,
      );
      (l.layout != 0 ? record : lyrics).add(_Card(
        name: l.name,
        note: '${animLabel(l.anim)}  -  ${l.font}',
        badge: l.byWord ? 'Words' : 'Lines',
        scene: scene,
        w: Stage.w,
        h: Stage.h,
        onUse: () => _useLyrics(l),
      ));
    }
    Stage.reset();
    _music = music;
    _lyrics = lyrics;
    _record = record;
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
      child: Material(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: c.onUse,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: c.w / c.h,
                      child: IgnorePointer(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(width: c.w, height: c.h, child: SceneCanvas(scene: c.scene)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xAA000000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(c.badge, style: const TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(c.note, style: const TextStyle(fontSize: 12, color: Color(0xFFB5ABD6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _page(String hint, List<_Card> cards, double width) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(hint, style: const TextStyle(fontSize: 13, color: Color(0xFFB5ABD6))),
        ),
        Wrap(spacing: 12, runSpacing: 14, children: [for (final c in cards) _card(c, width)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final half = (box.maxWidth - 32 - 12) / 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Templates', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text('Pick a look, add your cover, song and words. The rest is ready.', style: TextStyle(color: Color(0xFFB5ABD6))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: KColors.surface, borderRadius: BorderRadius.circular(26)),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(color: KColors.selected, borderRadius: BorderRadius.circular(22)),
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xFFB5ABD6),
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      labelPadding: EdgeInsets.zero,
                      tabs: [
                        Tab(height: 40, text: 'Music (${_music.length})'),
                        Tab(height: 40, text: 'Lyrics (${_lyrics.length})'),
                        Tab(height: 40, text: 'Record (${_record.length})'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _page('Cover art, a turning record and an audio picture.', _music, half),
                      _page('Words in time with the song, centred on the screen.', _lyrics, half),
                      _page('Cover and record on one side, the lyrics on the other, with the audio picture and the song name under the cover.', _record, half),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
