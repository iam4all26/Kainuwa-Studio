import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../animation_math.dart' show animLabel;
import '../editor/edit_panel.dart' show fontEntries;
import '../lyrics_project.dart';
import '../media/media_library.dart';
import '../scene_canvas.dart';
import '../stage_shape.dart';
import '../effects.dart' show kFxKinds;
import '../visualizer.dart';
import 'lyrics_tap_screen.dart';

/// Setup of a lyrics video: the song, the words, how they are timed, and the look.
class LyricsSetupScreen extends StatefulWidget {
  const LyricsSetupScreen({super.key, this.initial, this.simple = false, this.templateName});

  /// True when opened from a ready template: only the song, words, timing and shape are asked; the look stays.
  final bool simple;
  final String? templateName;

  /// The saved choices of an existing video, to correct them. Null for a new video.
  final Map<String, dynamic>? initial;

  @override
  State<LyricsSetupScreen> createState() => _LyricsSetupScreenState();
}

class _LyricsSetupScreenState extends State<LyricsSetupScreen> {
  String _audio = '';
  int _audioMs = 0;
  final TextEditingController _lyrics = TextEditingController();
  bool _byWord = true;

  /// 0 spread evenly, 1 tapped by the person, 2 from an .srt file
  int _timing = 0;
  List<int> _starts = [];
  List<int> _ends = [];
  // Where the singing starts and how much music-only time is left at the end (spread evenly).
  int _leadMs = 0;
  int _tailMs = 0;
  List<LyricCue> _srt = [];
  String _look = 'neon';
  String _anim = 'jump';
  String _cover = '';
  double _coverAspect = 1.0;
  int _layout = 0;
  String _viz = 'bars';
  final TextEditingController _songTitle = TextEditingController();
  final TextEditingController _artist = TextEditingController();
  String _font = 'Sacramento';
  int _bg = 0xFF03040B;
  List<int> _palette = kLyricsLooks.first.palette;
  bool _stars = true;
  bool _streaks = true;
  bool _embers = false;
  bool _sparkle = false;
  bool _snow = false;
  bool _player = false;
  Set<String> _more = {};
  int _shape = 1;
  String _message = '';

  static const List<(String, int, int)> _shapes = [
    ('Wide 16:9', 16, 9),
    ('Tall 9:16', 9, 16),
    ('Square 1:1', 1, 1),
  ];

  bool get _editing => widget.initial != null && !widget.simple;
  bool _showLook = true;

  @override
  void initState() {
    super.initState();
    _showLook = !widget.simple;
    _applyLook(kLyricsLooks.first);
    final f = widget.initial;
    if (f == null) return;
    String str(String k, String d) => f[k] is String ? f[k] as String : d;
    int iv(String k, int d) => f[k] is num ? (f[k] as num).round() : d;
    bool flag(String k, bool d) => f[k] is bool ? f[k] as bool : d;
    _audio = str('audio', '');
    _audioMs = iv('audioMs', 0);
    _lyrics.text = str('lyrics', '');
    _byWord = flag('byWord', true);
    _timing = iv('timing', 0);
    _starts = [if (f['starts'] is List) for (final v in f['starts'] as List) if (v is num) v.round()];
    _ends = [if (f['ends'] is List) for (final v in f['ends'] as List) if (v is num) v.round()];
    _leadMs = iv('lead', 0);
    _tailMs = iv('tail', 0);
    _srt = [
      if (f['srt'] is List)
        for (final v in f['srt'] as List)
          if (v is List && v.length == 3 && v[0] is num && v[1] is num && v[2] is String)
            LyricCue((v[0] as num).round(), (v[1] as num).round(), v[2] as String),
    ];
    _look = str('look', 'neon');
    _anim = str('anim', _anim);
    _cover = str('cover', '');
    _coverAspect = f['coverAspect'] is num ? (f['coverAspect'] as num).toDouble() : 1.0;
    _layout = iv('layout', _layout);
    _viz = str('viz', _viz);
    _songTitle.text = str('songTitle', '');
    _artist.text = str('artist', '');
    _font = str('font', _font);
    _bg = iv('bg', _bg);
    if (f['palette'] is List) {
      final p = [for (final v in f['palette'] as List) if (v is num) v.round()];
      if (p.isNotEmpty) _palette = p;
    }
    _stars = flag('stars', _stars);
    _streaks = flag('streaks', _streaks);
    _embers = flag('embers', _embers);
    _sparkle = flag('sparkle', _sparkle);
    _snow = flag('snow', _snow);
    _player = flag('player', _player);
    if (f['more'] is List) _more = {for (final v in f['more'] as List) if (v is String) v};
    _shape = iv('shape', 1).clamp(0, _shapes.length - 1).toInt();
  }

  @override
  void dispose() {
    // No Stage.reset() here: this screen closes after the editor may already have opened, and a reset then
    // would break the editor's layout. The editor sets its own stage size on every build.
    _lyrics.dispose();
    _songTitle.dispose();
    _artist.dispose();
    super.dispose();
  }

  void _applyLook(LyricsLook l) {
    _look = l.id;
    _anim = l.anim;
    _layout = l.layout;
    _byWord = l.byWord;
    _viz = l.viz;
    _font = l.font;
    _bg = l.bg;
    _palette = l.palette;
    _stars = l.fx.contains('stars');
    _streaks = l.fx.contains('streaks');
    _embers = l.fx.contains('embers');
    _sparkle = l.fx.contains('sparkle');
    _snow = l.fx.contains('snow');
    _more = l.fx.where(_extraFx.contains).toSet();
  }

  List<String> get _fx => [
        if (_stars) 'stars',
        if (_streaks) 'streaks',
        if (_embers) 'embers',
        if (_sparkle) 'sparkle',
        if (_snow) 'snow',
        ..._more,
      ];

  /// The effects that are not one of the five switches above.
  static const Set<String> _extraFx = {'spotlight', 'smoke', 'fairies', 'fireflies', 'bokeh', 'hearts', 'meteors'};

  List<String> get _units => lyricUnits(_lyrics.text, _byWord);

  String _nameOf(String path) {
    var name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name;
  }

  String _fontName(String family) {
    if (family.isEmpty) return 'Default';
    for (final e in fontEntries()) {
      if (e.$1 == family) return e.$2;
    }
    return family;
  }

  Future<void> _pickSong() async {
    String? path;
    try {
      path = await pickMedia(context, MediaKind.audio);
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    var ms = 0;
    try {
      ms = await KainuwaEncoder.audioDuration(path);
    } catch (_) {
      ms = 0;
    }
    if (!mounted) return;
    if (ms <= 0) {
      setState(() => _message = 'That sound file could not be read.');
      return;
    }
    setState(() {
      _audio = path!;
      _audioMs = ms;
      _leadMs = 0;
      _tailMs = 0;
      _message = '';
      _starts = [];
      _ends = [];
      if (_songTitle.text.trim().isEmpty) _songTitle.text = _nameOf(path);
    });
  }

  Future<double> _imageAspect(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 128);
      final frame = await codec.getNextFrame();
      final a = frame.image.width / frame.image.height;
      frame.image.dispose();
      codec.dispose();
      return a;
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> _pickCover() async {
    String? path;
    try {
      path = await pickMedia(context, MediaKind.image);
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    if (path.toLowerCase().endsWith('.svg')) {
      setState(() => _message = 'Please choose a JPG or PNG picture for the cover.');
      return;
    }
    final a = await _imageAspect(path);
    if (!mounted) return;
    setState(() {
      _cover = path!;
      _coverAspect = a;
      _message = '';
    });
  }

  Future<void> _loadSrt() async {
    String? picked;
    try {
      picked = await KainuwaEncoder.pickAnyFile();
    } catch (_) {
      picked = null;
    }
    if (picked == null || !mounted) return;
    List<LyricCue> cues;
    try {
      cues = cuesFromSrt(await File(picked).readAsString(), _byWord);
    } catch (_) {
      cues = [];
    }
    try {
      await File(picked).delete();
    } catch (_) {}
    if (!mounted) return;
    if (cues.isEmpty) {
      setState(() => _message = 'No captions were found in that file.');
      return;
    }
    setState(() {
      _srt = cues;
      _timing = 2;
      _message = '';
    });
  }

  Future<void> _tapAlong() async {
    final units = _units;
    if (_audio.isEmpty || units.isEmpty) {
      setState(() => _message = 'Choose the song and type the words first.');
      return;
    }
    final result = await Navigator.of(context).push<List<List<int>>>(
      MaterialPageRoute<List<List<int>>>(
        builder: (_) => LyricsTapScreen(audio: _audio, audioMs: _audioMs, units: units),
      ),
    );
    if (result == null || result.length < 2 || !mounted) return;
    setState(() {
      _starts = result[0];
      _ends = result[1];
      _timing = 1;
      _message = '';
    });
  }

  String _clock(int ms) => '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';

  List<LyricCue> _cues() {
    if (_timing == 2 && _srt.isNotEmpty) return _srt;
    final units = _units;
    if (_timing == 1 && _starts.isNotEmpty) return cuesFromStarts(units, _starts, _audioMs, _ends);
    final lead = _leadMs.clamp(0, math.max(0, _audioMs - 1000)).toInt();
    final end = (_audioMs - _tailMs).clamp(lead + 1000, math.max(lead + 1000, _audioMs)).toInt();
    return spreadCues(units, lead, end);
  }

  LyricsSetup _setup() {
    final shape = _shapes[_shape];
    return LyricsSetup(
      audio: _audio,
      audioMs: _audioMs,
      cues: _audio.isEmpty ? const [] : _cues(),
      aspectW: shape.$2,
      aspectH: shape.$3,
      palette: _palette,
      font: _font,
      bg: _bg,
      fx: _fx,
      byWord: _byWord,
      anim: _anim,
      cover: _cover,
      coverAspect: _coverAspect,
      layout: _layout,
      vizKind: _viz,
      player: _player,
      artist: _artist.text,
      title: _songTitle.text.trim().isEmpty ? _nameOf(_audio) : _songTitle.text.trim(),
      form: {
        'audio': _audio,
        'audioMs': _audioMs,
        'lyrics': _lyrics.text,
        'byWord': _byWord,
        'timing': _timing,
        'starts': _starts,
        'ends': _ends,
        'lead': _leadMs,
        'tail': _tailMs,
        'srt': [for (final c in _srt) [c.startMs, c.endMs, c.text]],
        'look': _look,
        'anim': _anim,
        'cover': _cover,
        'coverAspect': _coverAspect,
        'layout': _layout,
        'viz': _viz,
        'songTitle': _songTitle.text,
        'artist': _artist.text,
        'font': _font,
        'bg': _bg,
        'palette': _palette,
        'stars': _stars,
        'streaks': _streaks,
        'embers': _embers,
        'sparkle': _sparkle,
        'snow': _snow,
        'more': _more.toList(),
        'player': _player,
        'shape': _shape,
      },
    );
  }

  bool get _ready => _audio.isNotEmpty && (_timing == 2 ? _srt.isNotEmpty : _units.isNotEmpty);

  Widget _preview() {
    final shape = _shapes[_shape];
    Stage.use(shape.$2, shape.$3);
    final scene = buildLyricsScene(_setup(), sampleOnly: true);
    final w = Stage.w;
    final h = Stage.h;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 230),
          child: AspectRatio(
            aspectRatio: w / h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(width: w, height: h, child: SceneCanvas(scene: scene)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _pickFont() {
    final entries = fontEntries();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.7,
        child: ListView.builder(
          itemCount: entries.length,
          itemBuilder: (c, i) {
            final e = entries[i];
            return ListTile(
              dense: true,
              title: Text(
                'Lyrics  -  ${e.$2}',
                style: TextStyle(fontFamily: e.$1.isEmpty ? null : e.$1, fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(e.$3, style: const TextStyle(fontSize: 11)),
              trailing: e.$1 == _font ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(c).pop(e.$1),
            );
          },
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(label: Text(label), selected: value, onSelected: (v) => setState(() => onChanged(v)));
  }

  @override
  Widget build(BuildContext context) {
    final units = _units;
    final stale = _timing == 1 && _starts.isNotEmpty && _starts.length != units.length;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Lyrics video setup' : (widget.templateName ?? 'Lyrics video'))),
      body: Column(
        children: [
          _preview(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                  onPressed: _pickSong,
                  icon: const Icon(Icons.library_music_outlined),
                  label: Text(_audio.isEmpty ? 'Choose the song' : 'Song: ${_nameOf(_audio)}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lyrics,
                  minLines: 4,
                  maxLines: 10,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Lyrics (one line per line)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (_showLook) ...[
                  const Text('Layout', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final o in const [(0, 'Lyrics in the middle'), (1, 'Record left'), (2, 'Record right')])
                        ChoiceChip(
                          label: Text(o.$2),
                          selected: _layout == o.$1,
                          onSelected: (_) => setState(() => _layout = o.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (_layout != 0) ...[
                  Row(
                    children: [
                      if (_cover.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_cover), width: 56, height: 56, fit: BoxFit.cover),
                          ),
                        ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickCover,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(_cover.isEmpty ? 'Choose the cover art' : 'Choose another cover'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _songTitle,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Song name (shown under the cover)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _artist,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Artist (shown under the song name)'),
                  ),
                  if (_showLook) ...[
                    const SizedBox(height: 12),
                    const Text('Audio picture under the cover', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final k in kVizKinds)
                          if (k.id != 'circle')
                            ChoiceChip(
                              label: Text(k.name),
                              selected: _viz == k.id,
                              onSelected: (_) => setState(() => _viz = k.id),
                            ),
                        ChoiceChip(
                          label: const Text('None'),
                          selected: _viz == 'none',
                          onSelected: (_) => setState(() => _viz = 'none'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                const Text('Show', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('One word at a time'),
                      selected: _byWord,
                      onSelected: (_) => setState(() {
                        _byWord = true;
                        _starts = [];
                        _ends = [];
                        _srt = [];
                        if (_timing != 0) _timing = 0;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('One line at a time'),
                      selected: !_byWord,
                      onSelected: (_) => setState(() {
                        _byWord = false;
                        _starts = [];
                        _ends = [];
                        _srt = [];
                        if (_timing != 0) _timing = 0;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Timing', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Spread evenly'),
                      selected: _timing == 0,
                      onSelected: (_) => setState(() => _timing = 0),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.touch_app_outlined, size: 18),
                      label: Text(_timing == 1 && _starts.isNotEmpty ? 'Tap along (done)' : 'Tap along'),
                      onPressed: _tapAlong,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.subtitles_outlined, size: 18),
                      label: Text(_timing == 2 ? 'SRT file (loaded)' : 'Load an SRT file'),
                      onPressed: _loadSrt,
                    ),
                  ],
                ),
                if (_timing == 0 && _audio.isNotEmpty && _audioMs > 4000) ...[
                  const SizedBox(height: 8),
                  Text('Lyrics start at ${_clock(_leadMs)}'),
                  Slider(
                    value: _leadMs.clamp(0, _audioMs ~/ 2).toDouble(),
                    min: 0,
                    max: (_audioMs ~/ 2).toDouble(),
                    onChanged: (v) => setState(() => _leadMs = (v / 500).round() * 500),
                  ),
                  Text('Music only at the end: ${_clock(_tailMs)}'),
                  Slider(
                    value: _tailMs.clamp(0, _audioMs ~/ 2).toDouble(),
                    min: 0,
                    max: (_audioMs ~/ 2).toDouble(),
                    onChanged: (v) => setState(() => _tailMs = (v / 500).round() * 500),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _timing == 0
                        ? 'The words are spread between the two times above, a longer word a little longer. For music-only parts in the middle, use Tap along.'
                        : _timing == 1
                            ? (stale
                                ? 'The words changed after you tapped. Tap along again for exact timing. Until then the rest is spread evenly.'
                                : 'Your tapped times are used.')
                            : 'The times from the SRT file are used. The lyrics box is not needed.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (_showLook) ...[
                const SizedBox(height: 16),
                const Text('Look', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final l in kLyricsLooks)
                      ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: Color(l.palette.first), radius: 7),
                        label: Text(l.name),
                        selected: _look == l.id,
                        onSelected: (_) => setState(() {
                          final was = _byWord;
                          _applyLook(l);
                          if (_byWord != was) {
                            _starts = [];
                            _ends = [];
                            _srt = [];
                            _timing = 0;
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final f = await _pickFont();
                    if (f != null) setState(() => _font = f);
                  },
                  child: Text('Font: ${_fontName(_font)}'),
                ),
                const SizedBox(height: 12),
                const Text('Word animation', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final a in kLyricAnims)
                      ChoiceChip(
                        label: Text(animLabel(a)),
                        selected: _anim == a,
                        onSelected: (_) => setState(() => _anim = a),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Background', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final c in const [0xFF000000, 0xFF03040B, 0xFF02091A, 0xFF12051C, 0xFF110404, 0xFF04120A])
                      GestureDetector(
                        onTap: () => setState(() => _bg = c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg == c ? Colors.white : Colors.white24, width: _bg == c ? 3 : 1),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _toggle('Starfield', _stars, (v) => _stars = v),
                    _toggle('Light streaks', _streaks, (v) => _streaks = v),
                    _toggle('Fire sparks', _embers, (v) => _embers = v),
                    _toggle('Sparkles', _sparkle, (v) => _sparkle = v),
                    _toggle('Snow', _snow, (v) => _snow = v),
                    for (final k in kFxKinds)
                      if (_extraFx.contains(k.id))
                        _toggle(k.name, _more.contains(k.id), (v) {
                          if (v) {
                            _more.add(k.id);
                          } else {
                            _more.remove(k.id);
                          }
                        }),
                  ],
                ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Player buttons and moving bar'),
                  subtitle: const Text('Back, pause and forward icons with the song time'),
                  value: _player,
                  onChanged: (v) => setState(() => _player = v),
                ),
                const SizedBox(height: 8),
                const Text('Video shape', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _shapes.length; i++)
                      ChoiceChip(
                        label: Text(_shapes[i].$1),
                        selected: _shape == i,
                        onSelected: (_) => setState(() => _shape = i),
                      ),
                  ],
                ),
                if (!_showLook) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showLook = true),
                    icon: const Icon(Icons.tune),
                    label: const Text('Customize the look'),
                  ),
                ],
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _ready ? () => Navigator.of(context).pop(_setup()) : null,
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_editing ? 'Save and rebuild the video' : 'Create the video')),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Each word gets its own glow colour from the look. You can change everything in the editor afterwards. '
                  'Only use songs you have the right to use.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
