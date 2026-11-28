import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../media/media_library.dart';
import '../models.dart';

/// Cuts one long voice-over into one piece for each scene. Returns true when pieces were put on scenes.
Future<bool> showDocCut(BuildContext context, Lesson lesson, VoidCallback onChanged) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => _DocCutPage(lesson: lesson, onChanged: onChanged)),
  );
  return result ?? false;
}

String _sceneTitle(Scene s, int index) {
  final first = s.note.split('\n').first.trim();
  final t = first.isEmpty || first.startsWith('[') || first.startsWith('(') ? 'Slide ${index + 1}' : first;
  return t.replaceFirst(RegExp(r'^\d+\.\s*'), '');
}

String _clock(int ms) {
  final total = (ms / 1000).floor();
  final m = total ~/ 60;
  final s = total % 60;
  final t = ((ms % 1000) / 100).floor();
  return '$m:${s.toString().padLeft(2, '0')}.$t';
}

class _DocCutPage extends StatefulWidget {
  const _DocCutPage({required this.lesson, required this.onChanged});

  final Lesson lesson;
  final VoidCallback onChanged;

  @override
  State<_DocCutPage> createState() => _DocCutPageState();
}

class _DocCutPageState extends State<_DocCutPage> {
  static const _playerId = 'doccut';

  String _path = '';
  int _totalMs = 0;
  int _posMs = 0;
  bool _playing = false;
  double _speed = 1.0;
  int _playFromMs = 0;
  final Stopwatch _clockWatch = Stopwatch();
  Timer? _timer;

  // The first piece starts at _origin. Each cut ends one piece and starts the next.
  int _origin = 0;
  final List<int> _cuts = [];
  int _startScene = 0;
  bool _busy = false;

  List<Scene> get _scenes => widget.lesson.scenes;

  @override
  void initState() {
    super.initState();
    final first = _scenes.indexWhere((s) => s.narrationPath.isEmpty);
    _startScene = first < 0 ? 0 : first;
  }

  @override
  void dispose() {
    _timer?.cancel();
    KainuwaEncoder.stopClip(_playerId);
    super.dispose();
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick() async {
    await _stop();
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
      _say('That file could not be read as audio.');
      return;
    }
    setState(() {
      _path = path!;
      _totalMs = ms;
      _posMs = 0;
      _origin = 0;
      _cuts.clear();
    });
  }

  Future<void> _play() async {
    if (_path.isEmpty) return;
    _playFromMs = _posMs;
    _clockWatch
      ..reset()
      ..start();
    try {
      await KainuwaEncoder.playClip(_playerId, _path, seekMs: _posMs, speed: _speed);
    } catch (_) {
      _say('The sound could not be played.');
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final now = _playFromMs + (_clockWatch.elapsedMilliseconds * _speed).round();
      if (now >= _totalMs) {
        _stop();
        return;
      }
      if (mounted) setState(() => _posMs = now);
    });
    if (mounted) setState(() => _playing = true);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _clockWatch.stop();
    try {
      await KainuwaEncoder.stopClip(_playerId);
    } catch (_) {
      // nothing to do
    }
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _seek(int ms) async {
    final target = ms.clamp(0, _totalMs).toInt();
    final was = _playing;
    if (was) await _stop();
    if (mounted) setState(() => _posMs = target);
    if (was) await _play();
  }

  int get _lastEdge => _cuts.isEmpty ? _origin : _cuts.last;

  int get _nextScene => _startScene + _cuts.length;

  void _cutHere() {
    if (_nextScene >= _scenes.length) {
      _say('Every scene has a piece already.');
      return;
    }
    if (_posMs < _lastEdge + 500) {
      _say('Go forward first. A piece must be at least half a second.');
      return;
    }
    setState(() => _cuts.add(_posMs));
  }

  void _undo() {
    if (_cuts.isEmpty) return;
    final removed = _cuts.removeLast();
    setState(() => _posMs = _lastEdge > 0 ? _lastEdge : 0);
    _say('Removed the cut at ${_clock(removed)}.');
    if (_playing) _seek(_posMs);
  }

  void _nudge(int deltaMs) {
    if (_cuts.isEmpty) return;
    final prev = _cuts.length >= 2 ? _cuts[_cuts.length - 2] : _origin;
    final moved = (_cuts.last + deltaMs).clamp(prev + 500, _totalMs).toInt();
    setState(() => _cuts[_cuts.length - 1] = moved);
  }

  void _startHere() {
    if (_cuts.isNotEmpty) {
      _say('Remove the cuts first, or apply them. The start can only be moved before the first cut.');
      return;
    }
    setState(() => _origin = _posMs);
  }

  void _finishWithEnd() {
    if (_nextScene >= _scenes.length) return;
    if (_totalMs - _lastEdge < 500) return;
    setState(() => _cuts.add(_totalMs));
  }

  Future<void> _apply() async {
    if (_cuts.isEmpty || _busy) return;
    await _stop();
    final replaced = <int>[
      for (var k = 0; k < _cuts.length; k++)
        if (_scenes[_startScene + k].narrationPath.isNotEmpty) _startScene + k + 1,
    ];
    if (replaced.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace voices?'),
          content: Text('${replaced.length} of these scenes already have a voice and it will be replaced '
              '(scenes ${replaced.take(8).join(', ')}${replaced.length > 8 ? ' ...' : ''}).'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Replace')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final dir = '${await KainuwaEncoder.filesDir()}/voice_cuts';
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final starts = <int>[];
      final ends = <int>[];
      final outs = <String>[];
      for (var k = 0; k < _cuts.length; k++) {
        starts.add(k == 0 ? _origin : _cuts[k - 1]);
        ends.add(_cuts[k]);
        outs.add('$dir/cut_${stamp}_${_startScene + k + 1}.wav');
      }
      await KainuwaEncoder.cutAudio(_path, starts, ends, outs);
      var tooLong = 0;
      for (var k = 0; k < _cuts.length; k++) {
        final s = _scenes[_startScene + k];
        final ms = ends[k] - starts[k];
        s.narrationPath = outs[k];
        s.narrationMs = ms;
        s.narrationSpeed = 1.0;
        if (!s.hasVideo) {
          s.durationMs = ms + 500;
        } else if (ms > s.videoMs - s.videoStartMs + 300) {
          tooLong++;
        }
      }
      widget.onChanged();
      if (!mounted) return;
      final n = _cuts.length;
      final msg = tooLong > 0
          ? 'Done: $n scenes got their voice. $tooLong of them are longer than their clip, so the end of the voice will be cut. They are marked in the Scenes list.'
          : 'Done: $n scenes got their voice.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 6)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _say('Cutting failed: $e');
      }
    }
  }

  Widget _pieceRow(int k) {
    final start = k == 0 ? _origin : _cuts[k - 1];
    final end = _cuts[k];
    final idx = _startScene + k;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${idx + 1}. ${_sceneTitle(_scenes[idx], idx)}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${_clock(start)} to ${_clock(end)}   (${((end - start) / 1000).toStringAsFixed(1)} s)'),
      trailing: IconButton(
        tooltip: 'Play this piece',
        icon: const Icon(Icons.play_arrow),
        onPressed: () => _seek(start).then((_) {
          if (!_playing) _play();
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenes = _scenes;
    final next = _nextScene;
    final done = next >= scenes.length;
    final current = done ? null : scenes[next];
    return Scaffold(
      appBar: AppBar(title: const Text('Cut the voice-over')),
      body: _busy
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Cutting the pieces...')],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_path.isEmpty) ...[
                  const Text(
                    'Pick the one long recording. Then play it and tap "Cut here" at the end of each scene. '
                    'Each piece becomes the voice of one scene, in order.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('First scene to fill: '),
                      IconButton(onPressed: _startScene > 0 ? () => setState(() => _startScene--) : null, icon: const Icon(Icons.remove_circle_outline)),
                      Text('${_startScene + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(onPressed: _startScene < scenes.length - 1 ? () => setState(() => _startScene++) : null, icon: const Icon(Icons.add_circle_outline)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: _pick, icon: const Icon(Icons.audiotrack), label: const Text('Pick the voice-over')),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(done ? 'Every scene has a piece.' : 'Now cutting scene ${next + 1} of ${scenes.length}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (current != null) ...[
                            const SizedBox(height: 4),
                            Text(_sceneTitle(current, next)),
                            if (current.narrationText.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(current.narrationText, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            ],
                            if (next + 1 < scenes.length && scenes[next + 1].narrationText.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Next scene starts: ${scenes[next + 1].narrationText}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(_clock(_posMs)),
                      Expanded(
                        child: Slider(
                          value: _posMs.clamp(0, _totalMs).toDouble(),
                          max: _totalMs.toDouble(),
                          onChanged: (v) => setState(() => _posMs = v.round()),
                          onChangeEnd: (v) => _seek(v.round()),
                        ),
                      ),
                      Text(_clock(_totalMs)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: () => _seek(_posMs - 5000), icon: const Icon(Icons.replay_5)),
                      IconButton(onPressed: () => _seek(_posMs - 1000), icon: const Icon(Icons.fast_rewind)),
                      IconButton.filled(
                        iconSize: 36,
                        onPressed: _playing ? _stop : _play,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      ),
                      IconButton(onPressed: () => _seek(_posMs + 1000), icon: const Icon(Icons.fast_forward)),
                      IconButton(onPressed: () => _seek(_posMs + 5000), icon: const Icon(Icons.forward_5)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final sp in const [1.0, 1.5, 2.0])
                        ChoiceChip(
                          label: Text('${sp}x'),
                          selected: _speed == sp,
                          onSelected: (_) async {
                            final was = _playing;
                            if (was) await _stop();
                            setState(() => _speed = sp);
                            if (was) await _play();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: done ? null : _cutHere,
                    icon: const Icon(Icons.content_cut),
                    label: Text(done ? 'No scene left' : 'Cut here: end of scene ${next + 1}'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(onPressed: _cuts.isEmpty ? null : _undo, child: const Text('Undo last cut')),
                      OutlinedButton(onPressed: _cuts.isEmpty ? null : () => _nudge(-200), child: const Text('Last cut -0.2 s')),
                      OutlinedButton(onPressed: _cuts.isEmpty ? null : () => _nudge(200), child: const Text('Last cut +0.2 s')),
                      OutlinedButton(onPressed: _cuts.isEmpty ? _startHere : null, child: const Text('Start of piece 1 here')),
                      OutlinedButton(onPressed: done ? null : _finishWithEnd, child: const Text('Last piece to the end')),
                    ],
                  ),
                  if (_origin > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('The first piece starts at ${_clock(_origin)}.', style: const TextStyle(fontSize: 12)),
                    ),
                  const SizedBox(height: 12),
                  Text('Pieces: ${_cuts.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (var k = _cuts.length - 1; k >= 0; k--) _pieceRow(k),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _cuts.isEmpty ? null : _apply,
                    icon: const Icon(Icons.check),
                    label: Text('Put ${_cuts.length} pieces on the scenes'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'You can stop at any scene, put the pieces on, and come back later: pick the same recording, '
                    'move to where you stopped and tap "Start of piece 1 here".',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                  TextButton(onPressed: _pick, child: const Text('Pick another recording')),
                ],
              ],
            ),
    );
  }
}
