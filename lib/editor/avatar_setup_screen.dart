
import 'dart:async';
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
  final AvatarSpec spec;
}

/// Pick a photo, mark the mouth, then give a sound file or type text for the phone to speak.
class AvatarSetupScreen extends StatefulWidget {
  const AvatarSetupScreen({
    super.key,
    this.initialPhoto,
    this.initialAspect = 1.0,
    this.initialSpec,
  });

  final String? initialPhoto;
  final double initialAspect;
  final AvatarSpec? initialSpec;

  @override
  State<AvatarSetupScreen> createState() => _AvatarSetupScreenState();
}

class _AvatarSetupScreenState extends State<AvatarSetupScreen> {
  String _photo = '';
  double _aspect = 1.0;
  AvatarSpec _spec = const AvatarSpec();
  double _test = 0;
  double _step = 0.004;
  Timer? _repeat;
  bool _editing = false;

  bool _useText = false;
  final TextEditingController _text = TextEditingController();
  String _audio = '';
  int _audioMs = 0;
  bool _busy = false;
  bool _playing = false;
  String _message = '';

  @override
  void initState() {
    super.initState();

    final p = widget.initialPhoto;

    if (p != null && p.isNotEmpty) {
      _editing = true;
      _photo = p;
      _aspect = widget.initialAspect;
      _spec = widget.initialSpec ?? const AvatarSpec();
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _text.dispose();

    if (_playing) {
      KainuwaEncoder.stopAudio();
    }

    super.dispose();
  }

  Future<double> _imageAspect(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 128,
      );
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
      setState(() {
        _message = 'Please choose a photo (JPG or PNG), not an SVG.';
      });
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
      setState(() {
        _message = 'That sound file could not be read.';
      });
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
      setState(() {
        _message = 'Type what the picture should say.';
      });
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

      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      await KainuwaEncoder.ttsToFile(text, path);

      final ms = await KainuwaEncoder.audioDuration(path);

      if (!mounted) return;

      if (ms <= 0) {
        setState(() {
          _busy = false;
          _message =
              'The voice could not be made on this phone. Try a sound file instead.';
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

    return (s.startsWith('PlatformException') && i > 0)
        ? s.substring(i + 1).replaceAll(')', '').trim()
        : s;
  }

  Future<void> _togglePlay() async {
    if (_audio.isEmpty) return;

    if (_playing) {
      await KainuwaEncoder.stopAudio();

      if (mounted) {
        setState(() => _playing = false);
      }

      return;
    }

    setState(() => _playing = true);

    try {
      await KainuwaEncoder.playAudio(_audio);
    } catch (_) {}

    Future<void>.delayed(
      Duration(milliseconds: _audioMs + 300),
      () {
        if (mounted) {
          setState(() => _playing = false);
        }
      },
    );
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

  void _nudge(double dx, double dy) {
    setState(() {
      _spec = _spec.copyWith(
        x: (_spec.x + dx * _step).clamp(0.0, 1.0).toDouble(),
        y: (_spec.y + dy * _step).clamp(0.0, 1.0).toDouble(),
      );
    });
  }

  void _startRepeat(double dx, double dy) {
    _repeat?.cancel();
    _nudge(dx, dy);

    _repeat = Timer.periodic(
      const Duration(milliseconds: 70),
      (_) => _nudge(dx, dy),
    );
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  Widget _arrow(IconData icon, double dx, double dy) {
    return GestureDetector(
      onTapDown: (_) => _startRepeat(dx, dy),
      onTapUp: (_) => _stopRepeat(),
      onTapCancel: _stopRepeat,
      onPanEnd: (_) => _stopRepeat(),
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0x33808080),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 32),
      ),
    );
  }

  Widget _pad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrow(Icons.keyboard_arrow_up, 0, -1),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrow(Icons.keyboard_arrow_left, -1, 0),
            const SizedBox(width: 56, height: 56),
            _arrow(Icons.keyboard_arrow_right, 1, 0),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrow(Icons.keyboard_arrow_down, 0, 1),
          ],
        ),
      ],
    );
  }

  void _done() {
    Navigator.of(context).pop(
      AvatarSetupResult(
        photo: _photo,
        aspect: _aspect,
        audio: _audio,
        sourceMs: _audioMs,
        spec: _spec,
      ),
    );
  }

  String _seconds(int ms) => '${(ms / 1000).toStringAsFixed(1)} s';

  @override
  Widget build(BuildContext context) {
    final ready = _photo.isNotEmpty && (_editing || _audio.isNotEmpty) && !_busy;

    final width = MediaQuery.of(context).size.width - 32;
    final ph = math.min(340.0, width / math.max(0.2, _aspect));
    final pw = ph * _aspect;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Talking picture'),
      ),
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

            const Text(
              '1. Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _photo.isEmpty ? 'Choose a photo' : 'Choose another photo',
              ),
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
                    onTapDown: (d) => _place(
                      d.localPosition,
                      Size(pw, ph),
                    ),
                    onPanUpdate: (d) => _place(
                      d.localPosition,
                      Size(pw, ph),
                    ),
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
              const SizedBox(height: 4),

              const Text('Move the mouth (hold a button to keep moving):'),

              const SizedBox(height: 4),

              _pad(),

              _slider(
                'Move speed',
                _step,
                0.001,
                0.02,
                (v) => setState(() => _step = v),
              ),

              _slider(
                'Mouth width',
                _spec.w,
                0.06,
                0.5,
                (v) => setState(() => _spec = _spec.copyWith(w: v)),
              ),

              _slider(
                'Mouth movement',
                _spec.jaw,
                0.3,
                2.0,
                (v) => setState(() => _spec = _spec.copyWith(jaw: v)),
              ),

              _slider(
                'Test: open the mouth',
                _test,
                0,
                4,
                (v) => setState(() => _test = v),
              ),
            ],

            if (!_editing) ...[
              const SizedBox(height: 16),

              const Text(
                '2. Voice',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('My sound file'),
                    icon: Icon(Icons.audiotrack_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Type text'),
                    icon: Icon(Icons.record_voice_over_outlined),
                  ),
                ],
                selected: {_useText},
                onSelectionChanged: (s) {
                  setState(() => _useText = s.first);
                },
              ),

              const SizedBox(height: 12),

              if (!_useText)
                OutlinedButton.icon(
                  onPressed: _pickSound,
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    _audio.isEmpty
                        ? 'Choose a sound file'
                        : 'Choose another sound file',
                  ),
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
                  label: const Text(
                    "Make the voice (uses this phone's voice, no internet)",
                  ),
                ),
              ],

              if (_audio.isNotEmpty) ...[
                const SizedBox(height: 8),

                Row(
                  children: [
                    IconButton(
                      onPressed: _togglePlay,
                      icon: Icon(
                        _playing
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                      ),
                    ),

                    Expanded(
                      child: Text(
                        '${_audio.split('/').last} (${_seconds(_audioMs)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],

            if (_message.isNotEmpty) ...[
              const SizedBox(height: 8),

              Text(
                _message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],

            const SizedBox(height: 20),

            FilledButton(
              onPressed: ready ? _done : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _editing ? 'Save changes' : 'Add to slide',
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'The mouth opens and closes with the loudness of the voice. '
              'It starts at the playhead. If you move or cut the sound later, '
              'move the picture to match.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
