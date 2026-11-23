import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../lyrics_project.dart';

/// Plays the song and shows the words at the times they were given, so the timing can be checked
/// before the video is made.
class LyricsReplayScreen extends StatefulWidget {
  const LyricsReplayScreen({super.key, required this.audio, required this.audioMs, required this.cues});

  final String audio;
  final int audioMs;
  final List<LyricCue> cues;

  @override
  State<LyricsReplayScreen> createState() => _LyricsReplayScreenState();
}

class _LyricsReplayScreenState extends State<LyricsReplayScreen> {
  final Stopwatch _clock = Stopwatch();
  Timer? _tick;
  bool _running = false;

  @override
  void dispose() {
    _tick?.cancel();
    if (_running) KainuwaEncoder.stopAudio();
    super.dispose();
  }

  Future<void> _begin() async {
    _clock
      ..reset()
      ..start();
    setState(() => _running = true);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      if (_clock.elapsedMilliseconds > widget.audioMs + 300) {
        _stop();
      } else {
        setState(() {});
      }
    });
    try {
      await KainuwaEncoder.playAudio(widget.audio);
    } catch (_) {}
  }

  Future<void> _stop() async {
    _tick?.cancel();
    _clock.stop();
    try {
      await KainuwaEncoder.stopAudio();
    } catch (_) {}
    if (mounted) setState(() => _running = false);
  }

  String _time(int ms) => '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = _clock.elapsedMilliseconds;
    final cues = widget.cues;
    var current = -1;
    var next = cues.length;
    for (var i = 0; i < cues.length; i++) {
      if (cues[i].startMs <= now && now < cues[i].endMs) {
        current = i;
      }
      if (cues[i].startMs > now) {
        next = i;
        break;
      }
    }
    final shown = current >= 0 ? cues[current].text : (_running ? 'Music only' : 'Press Play');
    final previous = (current >= 0 ? current : next) - 1;
    final upcoming = current >= 0 ? current + 1 : next;
    final progress = widget.audioMs <= 0 ? 0.0 : (now / widget.audioMs).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Replay the timing')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'The words appear at the times they will have in the video.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Text(
                previous >= 0 && previous < cues.length ? cues[previous].text : '',
                style: const TextStyle(fontSize: 18, color: Colors.white38),
              ),
              const SizedBox(height: 10),
              Text(
                shown,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  color: current >= 0 ? Colors.white : Colors.white54,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                upcoming >= 0 && upcoming < cues.length ? cues[upcoming].text : '',
                style: const TextStyle(fontSize: 18, color: Colors.white54),
              ),
              const Spacer(),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text('${_time(now)} / ${_time(widget.audioMs)}'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _running ? _stop : _begin,
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_running ? 'Stop' : 'Play'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
