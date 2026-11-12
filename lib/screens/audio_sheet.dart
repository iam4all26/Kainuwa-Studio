import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../models.dart';
import '../theme.dart';

/// Narration for the current scene and music for the whole lesson.
Future<void> showAudioSheet(
  BuildContext context, {
  required Lesson lesson,
  required Scene scene,
  required Future<void> Function() onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _AudioSheet(lesson: lesson, scene: scene, onChanged: onChanged),
    ),
  );
}

class _AudioSheet extends StatefulWidget {
  const _AudioSheet({required this.lesson, required this.scene, required this.onChanged});

  final Lesson lesson;
  final Scene scene;
  final Future<void> Function() onChanged;

  @override
  State<_AudioSheet> createState() => _AudioSheetState();
}

class _AudioSheetState extends State<_AudioSheet> {
  bool _recording = false;
  bool _reduceNoise = true;
  bool _playing = false;
  int _elapsedMs = 0;
  double _level = 0;
  String? _recordingPath;
  String? _message;
  Timer? _timer;
  StreamSubscription<void>? _doneSub;

  @override
  void initState() {
    super.initState();
    _doneSub = KainuwaEncoder.playbackDone.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _doneSub?.cancel();
    if (_recording) {
      KainuwaEncoder.stopRecording().then((_) {}, onError: (_) {});
    }
    KainuwaEncoder.stopAudio().then((_) {}, onError: (_) {});
    super.dispose();
  }

  String _shortName(String path) {
    final name = path.split('/').last;
    return name.replaceFirst(RegExp(r'^\d+_'), '');
  }

  void _say(String message) {
    if (mounted) setState(() => _message = message);
  }

  Future<void> _attachNarration(String path, int ms) async {
    final scene = widget.scene;
    scene.narrationPath = path;
    scene.narrationMs = ms;
    scene.durationMs = math.max(1000, ms);
    await widget.onChanged();
    if (mounted) setState(() => _message = null);
  }

  Future<void> _startRecording() async {
    setState(() => _message = null);
    try {
      final base = await KainuwaEncoder.filesDir();
      final path = '$base/media/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await KainuwaEncoder.startRecording(path: path, reduceNoise: _reduceNoise);
      await KainuwaEncoder.stopAudio();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _playing = false;
        _elapsedMs = 0;
        _level = 0;
        _recordingPath = path;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        int level = 0;
        try {
          level = await KainuwaEncoder.recordingLevel();
        } catch (_) {}
        if (!mounted || !_recording) return;
        setState(() {
          _elapsedMs += 100;
          _level = (level / 20000).clamp(0.0, 1.0).toDouble();
        });
      });
    } on PlatformException catch (e) {
      _say(e.code == 'permission_denied'
          ? 'Recording needs the microphone permission. Allow it and try again.'
          : 'Could not start recording: ${e.message}');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = _recordingPath;
    setState(() => _recording = false);
    try {
      final ms = await KainuwaEncoder.stopRecording();
      if (path != null && ms > 0) {
        await _attachNarration(path, ms);
      } else {
        _say('The recording was empty. Please try again.');
      }
    } on PlatformException catch (e) {
      _say(e.code == 'too_short'
          ? 'The recording was too short. Hold on a little longer.'
          : 'Could not save the recording: ${e.message}');
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    setState(() => _recording = false);
    try {
      await KainuwaEncoder.stopRecording();
    } catch (_) {}
  }

  Future<void> _importNarration() async {
    try {
      final path = await KainuwaEncoder.pickAudio();
      if (path == null) return;
      final ms = await KainuwaEncoder.audioDuration(path);
      if (ms <= 0) {
        _say('That file could not be read as audio.');
        return;
      }
      await _attachNarration(path, ms);
    } on PlatformException catch (e) {
      _say('Could not import the file: ${e.message}');
    }
  }

  Future<void> _removeNarration() async {
    await KainuwaEncoder.stopAudio();
    final scene = widget.scene;
    scene.narrationPath = '';
    scene.narrationMs = 0;
    await widget.onChanged();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _togglePlay() async {
    final scene = widget.scene;
    if (_playing) {
      await KainuwaEncoder.stopAudio();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await KainuwaEncoder.playAudio(scene.narrationPath, volume: scene.narrationVolume);
      if (mounted) setState(() => _playing = true);
    } on PlatformException catch (e) {
      _say('Could not play the audio: ${e.message}');
    }
  }

  Future<void> _chooseMusic() async {
    try {
      final path = await KainuwaEncoder.pickAudio();
      if (path == null) return;
      widget.lesson.musicPath = path;
      await widget.onChanged();
      if (mounted) setState(() => _message = null);
    } on PlatformException catch (e) {
      _say('Could not choose the music: ${e.message}');
    }
  }

  Future<void> _removeMusic() async {
    widget.lesson.musicPath = '';
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  String _clock(int ms) => formatClock(ms);

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final lesson = widget.lesson;
    final hasNarration = scene.narrationPath.isNotEmpty;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Sound', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text(
            'Narration for this scene',
            style: TextStyle(fontWeight: FontWeight.w700, color: KColors.deepPurple),
          ),
          const SizedBox(height: 8),
          if (_recording) ...[
            Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Text('Recording ${_clock(_elapsedMs)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _level, minHeight: 8),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop and keep'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _cancelRecording, child: const Text('Cancel')),
              ],
            ),
          ] else if (!hasNarration) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('Record'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importNarration,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce background noise while recording'),
              subtitle: const Text(
                'Uses the phone\'s own noise suppression, if it has one.',
                style: TextStyle(fontSize: 12),
              ),
              value: _reduceNoise,
              onChanged: (v) => setState(() => _reduceNoise = v),
            ),
          ] else ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.graphic_eq, color: KColors.purple),
                title: Text(_shortName(scene.narrationPath), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Length ${_clock(scene.narrationMs)}. The scene is as long as the narration.'),
                trailing: IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(_playing ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Narration volume ${(scene.narrationVolume * 100).round()}%'),
            Slider(
              value: scene.narrationVolume.clamp(0.0, 1.0).toDouble(),
              divisions: 20,
              onChanged: (v) => setState(() => scene.narrationVolume = v),
              onChangeEnd: (_) => widget.onChanged(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Clean the voice when exporting'),
              subtitle: const Text(
                'Cuts low rumble and quiets the gaps between words. It is applied when the lesson is exported.',
                style: TextStyle(fontSize: 12),
              ),
              value: scene.narrationClean,
              onChanged: (v) {
                setState(() => scene.narrationClean = v);
                widget.onChanged();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('Record again'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _removeNarration, child: const Text('Remove')),
              ],
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const Divider(height: 32),
          const Text(
            'Music for the whole lesson',
            style: TextStyle(fontWeight: FontWeight.w700, color: KColors.deepPurple),
          ),
          const SizedBox(height: 8),
          if (lesson.musicPath.isEmpty)
            OutlinedButton.icon(
              onPressed: _chooseMusic,
              icon: const Icon(Icons.music_note),
              label: const Text('Choose music'),
            )
          else ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.music_note, color: KColors.purple),
                title: Text(_shortName(lesson.musicPath), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: TextButton(onPressed: _removeMusic, child: const Text('Remove')),
              ),
            ),
            const SizedBox(height: 8),
            Text('Music volume ${(lesson.musicVolume * 100).round()}%'),
            Slider(
              value: lesson.musicVolume.clamp(0.0, 1.0).toDouble(),
              divisions: 20,
              onChanged: (v) => setState(() => lesson.musicVolume = v),
              onChangeEnd: (_) => widget.onChanged(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fade in and fade out'),
              value: lesson.musicFade,
              onChanged: (v) {
                setState(() => lesson.musicFade = v);
                widget.onChanged();
              },
            ),
            const Text(
              'The music plays under the whole lesson. If it is shorter than the lesson it will stop when it ends.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
