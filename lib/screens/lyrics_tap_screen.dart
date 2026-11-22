import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

/// Play the song and tap once for every word (or line) as it is sung. Returns the start time of each
/// tapped unit in milliseconds, or null when closed without finishing.
class LyricsTapScreen extends StatefulWidget {
  const LyricsTapScreen({super.key, required this.audio, required this.audioMs, required this.units});

  final String audio;
  final int audioMs;
  final List<String> units;

  @override
  State<LyricsTapScreen> createState() => _LyricsTapScreenState();
}

class _LyricsTapScreenState extends State<LyricsTapScreen> {
  final Stopwatch _clock = Stopwatch();
  final List<int> _starts = [];
  bool _running = false;

  @override
  void dispose() {
    if (_running) KainuwaEncoder.stopAudio();
    super.dispose();
  }

  Future<void> _begin() async {
    _starts.clear();
    _clock
      ..reset()
      ..start();
    setState(() => _running = true);
    try {
      await KainuwaEncoder.playAudio(widget.audio);
    } catch (_) {}
    Future<void>.delayed(Duration(milliseconds: widget.audioMs + 300), () {
      if (mounted && _running) _stop();
    });
  }

  Future<void> _stop() async {
    _clock.stop();
    try {
      await KainuwaEncoder.stopAudio();
    } catch (_) {}
    if (mounted) setState(() => _running = false);
  }

  void _tap() {
    if (_starts.length >= widget.units.length) return;
    setState(() => _starts.add(_clock.elapsedMilliseconds));
    if (_starts.length >= widget.units.length) _stop();
  }

  void _undo() {
    if (_starts.isEmpty) return;
    setState(() => _starts.removeLast());
  }

  String _unit(int i) => i >= 0 && i < widget.units.length ? widget.units[i] : '';

  @override
  Widget build(BuildContext context) {
    final at = _starts.length;
    final done = at >= widget.units.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Tap along')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _running
                    ? 'Tap the big button each time the next word starts.'
                    : (done ? 'All words timed.' : 'Press Start. The song plays and you tap for every word.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text('${_unit(at - 1)}', style: const TextStyle(fontSize: 18, color: Colors.white54)),
              const SizedBox(height: 8),
              Text(
                done ? 'Done' : _unit(at),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(_unit(at + 1), style: const TextStyle(fontSize: 18, color: Colors.white54)),
              const SizedBox(height: 8),
              Text('$at of ${widget.units.length}'),
              const Spacer(),
              if (!_running && !done)
                FilledButton.icon(
                  onPressed: _begin,
                  icon: const Icon(Icons.play_arrow),
                  label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Start')),
                )
              else if (_running)
                SizedBox(
                  width: double.infinity,
                  height: 150,
                  child: FilledButton(
                    onPressed: _tap,
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    child: const Text('TAP', style: TextStyle(fontSize: 34)),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: _starts.isEmpty ? null : _undo, child: const Text('Undo last')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _running || _starts.isNotEmpty ? () async {
                        await _stop();
                        if (mounted) setState(_starts.clear);
                      } : null,
                      child: const Text('Start again'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _starts.isEmpty
                    ? null
                    : () async {
                        await _stop();
                        if (mounted) Navigator.of(context).pop(List<int>.of(_starts));
                      },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Use these times'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
