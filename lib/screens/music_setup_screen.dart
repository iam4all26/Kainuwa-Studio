import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../editor/edit_panel.dart' show fontEntries;
import '../media/media_library.dart';
import '../models.dart';
import '../music_project.dart';
import '../music_templates.dart';
import '../scene_canvas.dart';
import '../stage_shape.dart';
import '../visualizer.dart';

/// Pick the cover art and the song, write the title, choose the audio picture. Returns a [MusicSetup].
class MusicSetupScreen extends StatefulWidget {
  const MusicSetupScreen({super.key});

  @override
  State<MusicSetupScreen> createState() => _MusicSetupScreenState();
}

class _MusicSetupScreenState extends State<MusicSetupScreen> {
  String _cover = '';
  double _aspect = 1.0;
  String _audio = '';
  int _audioMs = 0;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _artist = TextEditingController();
  int _shape = 0;
  String _viz = 'bars';
  int _accent = 0xFFFF9F1C;
  String _message = '';
  int _layout = 0;
  String _titleFont = '';
  String _artistFont = '';
  bool _playing = false;
  String _template = '';

  static const List<(String, int, int)> _shapes = [
    ('Wide 16:9', 16, 9),
    ('Tall 9:16', 9, 16),
    ('Square 1:1', 1, 1),
  ];
  static const List<int> _accents = [
    0xFFFF9F1C,
    0xFFFFD54F,
    0xFF4DD0E1,
    0xFF69F0AE,
    0xFFFF4D6D,
    0xFFB9A0FF,
    0xFFFFFFFF,
  ];

  void _applyTemplate(MusicTemplate t) {
    setState(() {
      _template = t.id;
      _viz = t.viz;
      _accent = t.accent;
      _layout = t.layout;
      _titleFont = t.titleFont;
      _artistFont = t.artistFont;
    });
  }

  /// Any change by hand after picking a template turns the template off, so the person sees it is now custom.
  void _custom() => _template = '';

  Widget _templateRow() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final t in kMusicTemplates)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: CircleAvatar(backgroundColor: Color(t.accent), radius: 7),
                label: Text(t.name),
                selected: _template == t.id,
                onSelected: (_) => _applyTemplate(t),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_playing) KainuwaEncoder.stopAudio();
    Stage.reset();
    _title.dispose();
    _artist.dispose();
    super.dispose();
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

  String _nameOf(String path) {
    var name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name;
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
      _aspect = a;
      _message = '';
    });
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
      _message = '';
      if (_title.text.trim().isEmpty) _title.text = _nameOf(path);
    });
  }

  MusicSetup _setup() {
    final s = _shapes[_shape];
    return MusicSetup(
      cover: _cover,
      coverAspect: _aspect,
      audio: _audio,
      audioMs: _audioMs,
      title: _title.text,
      artist: _artist.text,
      aspectW: s.$2,
      aspectH: s.$3,
      vizKind: _viz,
      accent: _accent,
      layout: _shape == 0 ? _layout : 0,
      titleFont: _titleFont,
      artistFont: _artistFont,
    );
  }

  void _create() => Navigator.of(context).pop(_setup());

  Future<void> _togglePlay() async {
    if (_audio.isEmpty) return;
    if (_playing) {
      await KainuwaEncoder.stopAudio();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      await KainuwaEncoder.playAudio(_audio);
    } catch (_) {}
    Future<void>.delayed(Duration(milliseconds: _audioMs + 300), () {
      if (mounted) setState(() => _playing = false);
    });
  }

  /// How the video will look, drawn with the same code as the real video.
  Widget _preview() {
    if (_cover.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(color: const Color(0x22808080), borderRadius: BorderRadius.circular(12)),
        child: const Text('Choose the cover art to see the preview'),
      );
    }
    final shape = _shapes[_shape];
    Stage.use(shape.$2, shape.$3);
    final scene = buildMusicScene(_setup());
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

  /// A list of fonts, each name written in its own font. Returns the family, or null when closed.
  Future<String?> _pickFont(String current) {
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
                _title.text.trim().isEmpty ? e.$2 : '${_title.text.trim()}  -  ${e.$2}',
                style: TextStyle(fontFamily: e.$1.isEmpty ? null : e.$1, fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(e.$3, style: const TextStyle(fontSize: 11)),
              trailing: e.$1 == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(c).pop(e.$1),
            );
          },
        ),
      ),
    );
  }

  String _fontName(String family) {
    for (final e in fontEntries()) {
      if (e.$1 == family) return e.$2;
    }
    return family.isEmpty ? 'Default' : family;
  }

  String _seconds(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ready = _cover.isNotEmpty && _audio.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Music video')),
      body: SafeArea(
        child: Column(
          children: [
            _preview(),
            Expanded(
              child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                if (_cover.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_cover), width: 72, height: 72, fit: BoxFit.cover),
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
            OutlinedButton.icon(
              onPressed: _pickSong,
              icon: const Icon(Icons.library_music_outlined),
              label: Text(_audio.isEmpty ? 'Choose the song' : 'Choose another song'),
            ),
            if (_audio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _togglePlay,
                      icon: Icon(_playing ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                    ),
                    Expanded(
                      child: Text('${_audio.split('/').last}  (${_seconds(_audioMs)})', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Song title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artist,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Artist (optional)'),
            ),
            const SizedBox(height: 16),
            const Text('Template', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _templateRow(),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            const Text('Place the record and cover', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final o in const [(0, 'Centre'), (1, 'Left'), (2, 'Right')])
                  ChoiceChip(
                    label: Text(o.$2),
                    selected: (_shape == 0 ? _layout : 0) == o.$1,
                    onSelected: _shape == 0 ? (_) => setState(() { _custom(); _layout = o.$1; }) : null,
                  ),
              ],
            ),
            if (_shape != 0)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Left and right need the wide video shape. The other shapes have no room.', style: TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 16),
            const Text('Fonts', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final f = await _pickFont(_titleFont);
                if (f != null) setState(() { _custom(); _titleFont = f; });
              },
              child: Text('Title font: ${_fontName(_titleFont)}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final f = await _pickFont(_artistFont);
                if (f != null) setState(() { _custom(); _artistFont = f; });
              },
              child: Text('Artist font: ${_fontName(_artistFont)}'),
            ),
            const SizedBox(height: 16),
            const Text('Audio picture', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final k in kVizKinds)
                  ChoiceChip(
                    label: Text(k.name),
                    selected: _viz == k.id,
                    onSelected: (_) => setState(() { _custom(); _viz = k.id; }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Colour', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (final c in _accents)
                  GestureDetector(
                    onTap: () => setState(() { _custom(); _accent = c; }),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: _accent == c ? Colors.white : Colors.white24, width: _accent == c ? 3 : 1),
                      ),
                    ),
                  ),
              ],
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: ready ? _create : null,
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Create the video')),
            ),
            const SizedBox(height: 8),
            const Text(
              'The cover is added with a record turning behind it, and the audio picture moves with the real sound. '
              'Only use music and pictures you have the right to use.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
            ),
          ],
        ),
      ),
    );
  }
}
