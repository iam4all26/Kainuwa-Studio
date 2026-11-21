import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../avatar.dart';
import '../media/media_library.dart';

/// What the Avatar screen hands back to the editor.
class AvatarSetupResult {
  const AvatarSetupResult({
    required this.photo,
    required this.aspect,
    required this.audio,
    required this.sourceMs,
    required this.spec,
  });

  final String photo;
  final double aspect;
  final String audio;
  final int sourceMs;

  /// Mouth place and size (the sound fields are filled in by the editor).
  final AvatarSpec spec;
}

/// Pick a photo, mark the mouth, then give a sound file or type text for the phone to speak.
class AvatarSetupScreen extends StatefulWidget {
  const AvatarSetupScreen({super.key});

  @override
  State<AvatarSetupScreen> createState() => _AvatarSetupScreenState();
}

class _AvatarSetupScreenState extends State<AvatarSetupScreen> {
  String _photo = '';
  double _aspect = 1.0;
  AvatarSpec _spec = const AvatarSpec();
  double _test = 0;

  bool _useText = false;
  final TextEditingController _text = TextEditingController();
  String _audio = '';
  int _audioMs = 0;
  bool _busy = false;
  bool _playing = false;
  String _message = '';

  @override
  void dispose() {
    _text.dispose();
    if (_playing) {
      KainuwaEncoder.stopAudio();
    }
    super.dispose();
  }

  Future<double> _imageAspect(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 128);
      final frame = await codec.getNextFrame();
      final aspect = frame.image.width / frame.image.height;
      frame.image.dispose();
      codec.dispose();
      return aspect;
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> _pickPhoto() async {
    String? path;
    try {
      path = await pickMedia(context, MediaKind.image);
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    if (path.toLowerCase().endsWith('.svg')) {
      setState(() => _message = 'Please choose a photo (JPG or PNG), not an SVG.');
      return;
    }
    final aspect = await _imageAspect(path);
    if (!mounted) return;
    setState(() {
      _photo = path!;
      _aspect = aspect;
      _message = '';
    });
  }

  Future<void> _pickSound() async {
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
    });
  }

  Future<void> _makeVoice() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _message = 'Type what the picture should say.');
      return;
    }
    setState(() {
      _busy = true;
      _message = 'Making the voice...';
    });
    try {
      final base = await KainuwaEncoder.filesDir();
      final dir = Directory('$base/kainuwa_data/avatar');
      await dir.create(recursive: true);
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await KainuwaEncoder.ttsToFile(text, path);
      final ms = await KainuwaEncoder.audioDuration(path);
      if (!mounted) return;
      if (ms <= 0) {
        setState(() {
          _busy = false;
          _message = 'The voice could not be made on this phone. Try a sound file instead.';
        });
        return;
      }
      setState(() {
        _audio = path;
        _audioMs = ms;
        _busy = false;
        _message = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'The voice could not be made: ${_clean(e)}';
      });
    }
  }

  String _clean(Object e) {
    final s = e.toString();
    final i = s.indexOf(',');
    return (s.startsWith('PlatformException') && i > 0) ? s.substring(i + 1).replaceAll(')', '').trim() : s;
  }

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

  void _place(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    setState(() {
      _spec = _spec.copyWith(
        x: (local.dx / size.width).clamp(0.02, 0.98).toDouble(),
        y: (local.dy / size.height).clamp(0.02, 0.98).toDouble(),
      );
    });
  }

  void _done() {
    Navigator.of(context).pop(
      AvatarSetupResult(photo: _photo, aspect: _aspect, audio: _audio, sourceMs: _audioMs, spec: _spec),
    );
  }

  String _seconds(int ms) => '${(ms / 1000).toStringAsFixed(1)} s';

  @override
  Widget build(BuildContext context) {
    final ready = _photo.isNotEmpty && _audio.isNotEmpty && !_busy;
    final width = MediaQuery.of(context).size.width - 32;
    final ph = math.min(340.0, width / math.max(0.2, _aspect));
    final pw = ph * _aspect;
    return Scaffold(
      appBar: AppBar(title: const Text('Talking picture')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1A808080),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Only use your own photo, or a photo you have permission to use. '
                'Do not use it to copy or mislead people.',
              ),
            ),
            const SizedBox(height: 16),
            const Text('1. Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.image_outlined),
              label: Text(_photo.isEmpty ? 'Choose a photo' : 'Choose another photo'),
            ),
            if (_photo.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Tap or drag on the mouth to place it.'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: pw,
                  height: ph,
                  child: GestureDetector(
                    onTapDown: (d) => _place(d.localPosition, Size(pw, ph)),
                    onPanUpdate: (d) => _place(d.localPosition, Size(pw, ph)),
                    child: AvatarPicture(
                      path: _photo,
                      aspect: _aspect,
                      spec: _spec,
                      level: _test.round(),
                      showMarker: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _slider('Mouth width', _spec.w, 0.06, 0.5, (v) => setState(() => _spec = _spec.copyWith(w: v))),
              _slider('Mouth movement', _spec.jaw, 0.3, 2.0, (v) => setState(() => _spec = _spec.copyWith(jaw: v))),
              _slider('Test: open the mouth', _test, 0, 4, (v) => setState(() => _test = v)),
            ],
            const SizedBox(height: 16),
            const Text('2. Voice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('My sound file'), icon: Icon(Icons.audiotrack_outlined)),
                ButtonSegment(value: true, label: Text('Type text'), icon: Icon(Icons.record_voice_over_outlined)),
              ],
              selected: {_useText},
              onSelectionChanged: (s) => setState(() => _useText = s.first),
            ),
            const SizedBox(height: 12),
            if (!_useText)
              OutlinedButton.icon(
                onPressed: _pickSound,
                icon: const Icon(Icons.folder_open),
                label: Text(_audio.isEmpty ? 'Choose a sound file' : 'Choose another sound file'),
              )
            else ...[
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'What should the picture say?',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _makeVoice,
                icon: const Icon(Icons.graphic_eq),
                label: const Text("Make the voice (uses this phone's voice, no internet)"),
              ),
            ],
            if (_audio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _togglePlay,
                    icon: Icon(_playing ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      '${_audio.split('/').last}  (${_seconds(_audioMs)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: ready ? _done : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Add to slide'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The mouth opens and closes with the loudness of the voice. It starts at the playhead. '
              'If you move or cut the sound later, move the picture to match.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(
          child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
