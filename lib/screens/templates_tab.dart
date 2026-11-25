import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
import '../user_templates.dart';
import '../visualizer.dart';
import 'lesson_editor_screen.dart';
import 'lyrics_setup_screen.dart';
import 'music_setup_screen.dart';

/// One ready template with its picture.
class _Card {
  _Card({
    required this.name,
    required this.note,
    required this.badge,
    required this.scene,
    required this.w,
    required this.h,
    required this.onUse,
    this.loopMs = 4000,
    this.onMenu,
  });

  final String name;
  final String note;
  final String badge;
  final Scene scene;
  final double w;
  final double h;
  final VoidCallback onUse;

  /// How long the animated preview runs before it starts again.
  final int loopMs;

  /// A menu button on the card (rename, delete) for the owner's own templates.
  final VoidCallback? onMenu;
}

/// Ready-made music and lyrics videos. The picture of each card is drawn by the same code that builds
/// the real video. A tap asks only for the cover, song and words; fonts, colours and animations stay.
class TemplatesTab extends StatefulWidget {
  const TemplatesTab({super.key});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> with SingleTickerProviderStateMixin {
  List<_Card> _music = [];
  List<_Card> _lyrics = [];
  List<_Card> _record = [];
  List<_Card> _mine = [];

  /// The time of the animated previews, in milliseconds; it steps ten times a second to keep the phone cool.
  final ValueNotifier<int> _clock = ValueNotifier<int>(0);
  late final Ticker _ticker;
  bool _animate = true;

  @override
  void initState() {
    super.initState();
    _build();
    _ticker = createTicker((d) {
      final step = (d.inMilliseconds ~/ 100) * 100;
      if (step != _clock.value) _clock.value = step;
    })
      ..start();
    UserTemplates.instance.addListener(_mineChanged);
    UserTemplates.instance.load();
  }

  @override
  void dispose() {
    UserTemplates.instance.removeListener(_mineChanged);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _mineChanged() {
    if (!mounted) return;
    setState(_buildMine);
  }

  static String _s(dynamic v, String d) => v is String ? v : d;
  static int _i(dynamic v, int d) => v is num ? v.toInt() : d;
  static bool _b(dynamic v, bool d) => v is bool ? v : d;

  /// The picture cards of the owner's saved templates, drawn by the same code as the ready ones.
  void _buildMine() {
    // The editor may be open on top of this tab: put the stage size back exactly as it was.
    final keepW = Stage.w;
    final keepH = Stage.h;
    final mine = <_Card>[];
    for (final t in UserTemplates.instance.items) {
      final f = t.form;
      if (t.kind == 'music') {
        Stage.use(16, 9);
        final scene = buildMusicScene(MusicSetup(
          cover: '',
          coverAspect: 1.0,
          audio: '',
          audioMs: 0,
          title: 'Song title',
          artist: 'Artist name',
          aspectW: 16,
          aspectH: 9,
          vizKind: _s(f['viz'], 'bars'),
          accent: _i(f['accent'], 0xFFFFC107),
          layout: _i(f['layout'], 0),
          player: _b(f['player'], false),
          fx: f['fx'] is List ? (f['fx'] as List).whereType<String>().toList() : const <String>[],
          titleFont: _s(f['titleFont'], ''),
          artistFont: _s(f['artistFont'], ''),
        ));
        mine.add(_Card(
          name: t.name,
          note: 'Music  -  ${_s(f['titleFont'], '').isEmpty ? 'Default font' : _s(f['titleFont'], '')}',
          badge: 'Mine',
          scene: scene,
          w: Stage.w,
          h: Stage.h,
          onUse: () => _useMusicForm(f, t.name),
          onMenu: () => _mineMenu(t),
        ));
      } else {
        final layout = _i(f['layout'], 0);
        if (layout != 0) {
          Stage.use(16, 9);
        } else {
          Stage.use(9, 16);
        }
        final fx = <String>[
          for (final k in const ['stars', 'streaks', 'embers', 'sparkle', 'snow'])
            if (_b(f[k], false)) k,
          if (f['more'] is List) ...(f['more'] as List).whereType<String>(),
        ];
        final palette = f['palette'] is List && (f['palette'] as List).isNotEmpty
            ? (f['palette'] as List).whereType<num>().map((e) => e.toInt()).toList()
            : kLyricsLooks.first.palette;
        final scene = buildLyricsScene(
          LyricsSetup(
            audio: '',
            audioMs: 4000,
            cues: const [LyricCue(0, 4000, 'Feel it')],
            aspectW: layout != 0 ? 16 : 9,
            aspectH: layout != 0 ? 9 : 16,
            palette: palette,
            font: _s(f['font'], kLyricsLooks.first.font),
            bg: _i(f['bg'], kLyricsLooks.first.bg),
            fx: fx,
            byWord: _b(f['byWord'], false),
            anim: _s(f['anim'], 'pop'),
            layout: layout,
            vizKind: _s(f['viz'], 'bars'),
            player: _b(f['player'], false),
            centerViz: _b(f['centerViz'], false),
            karaoke: _b(f['karaoke'], false),
            title: 'Song title',
            artist: 'Artist name',
          ),
          sampleOnly: true,
        );
        mine.add(_Card(
          name: t.name,
          note: 'Lyrics  -  ${animLabel(_s(f['anim'], 'pop'))}  -  ${_s(f['font'], '')}',
          badge: 'Mine',
          scene: scene,
          w: Stage.w,
          h: Stage.h,
          loopMs: 4000,
          onUse: () => _useLyricsForm(f, t.name),
          onMenu: () => _mineMenu(t),
        ));
      }
    }
    Stage.w = keepW;
    Stage.h = keepH;
    _mine = mine;
  }

  Future<void> _mineMenu(UserTemplate t) async {
    final pick = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Rename'), onTap: () => Navigator.of(c).pop(0)),
            ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () => Navigator.of(c).pop(1)),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == 0) {
      final controller = TextEditingController(text: t.name);
      final name = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: const Text('Rename template'),
          content: TextField(controller: controller, autofocus: true, maxLength: 40),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(c).pop(controller.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      controller.dispose();
      if (name != null && name.isNotEmpty) await UserTemplates.instance.rename(t.id, name);
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this template?'),
          content: Text('"${t.name}" is removed from Templates. Videos made from it are not changed.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
          ],
        ),
      );
      if (ok == true) await UserTemplates.instance.remove(t.id);
    }
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
          audioMs: 4000,
          cues: const [LyricCue(0, 4000, 'Feel it')],
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

  Future<void> _useMusic(MusicTemplate t) => _useMusicForm(musicTemplateForm(t), t.name);

  Future<void> _useMusicForm(Map<String, dynamic> form, String name) async {
    final state = AppScope.read(context);
    final music = await Navigator.of(context).push<MusicSetup>(
      MaterialPageRoute<MusicSetup>(
        builder: (_) => MusicSetupScreen(initial: form, simple: true, templateName: name),
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

  Future<void> _useLyrics(LyricsLook l) => _useLyricsForm(lyricsTemplateForm(l), l.name);

  Future<void> _useLyricsForm(Map<String, dynamic> form, String name) async {
    final state = AppScope.read(context);
    final lyrics = await Navigator.of(context).push<LyricsSetup>(
      MaterialPageRoute<LyricsSetup>(
        builder: (_) => LyricsSetupScreen(initial: form, simple: true, templateName: name),
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
                          child: SizedBox(
                            width: c.w,
                            height: c.h,
                            child: _animate
                                ? ValueListenableBuilder<int>(
                                    valueListenable: _clock,
                                    builder: (context, ms, _) => SceneCanvas(scene: c.scene, previewMs: ms % math.max(1000, math.min(c.loopMs, c.scene.durationMs))),
                                  )
                                : SceneCanvas(scene: c.scene),
                          ),
                        ),
                      ),
                    ),
                    if (c.onMenu != null)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Material(
                          color: const Color(0xAA000000),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: c.onMenu,
                            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.more_vert, size: 18, color: Colors.white)),
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
        if (cards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nothing here yet.', style: TextStyle(color: Color(0xFFB5ABD6))),
          ),
        Wrap(spacing: 12, runSpacing: 14, children: [for (final c in cards) _card(c, width)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Animated previews', style: TextStyle(fontSize: 13, color: Color(0xFFB5ABD6)))),
                      Switch(value: _animate, onChanged: (v) => setState(() => _animate = v)),
                    ],
                  ),
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
                        Tab(height: 40, text: 'Mine (${_mine.length})'),
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
                      _page('Your own looks. Open a music or lyrics video, tap Setup, then choose Save this look as a template.', _mine, half),
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
