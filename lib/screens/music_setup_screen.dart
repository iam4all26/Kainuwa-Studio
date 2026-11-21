import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../media/media_library.dart';
import '../music_project.dart';
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

  @override
  void dispose() {
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

  void _create() {
    final s = _shapes[_shape];
    Navigator.of(context).pop(
      MusicSetup(
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
      ),
    );
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
                child: Text('${_audio.split('/').last}  (${_seconds(_audioMs)})', overflow: TextOverflow.ellipsis),
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
            const Text('Audio picture', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final k in kVizKinds)
                  ChoiceChip(
                    label: Text(k.name),
                    selected: _viz == k.id,
                    onSelected: (_) => setState(() => _viz = k.id),
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
                    onTap: () => setState(() => _accent = c),
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
    );
  }
}
