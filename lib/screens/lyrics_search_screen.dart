import 'dart:async';

import 'package:flutter/material.dart';

import '../lyrics_search.dart';

/// Search for the words of a song online. Returns the song the person taps, or null.
class LyricsSearchScreen extends StatefulWidget {
  const LyricsSearchScreen({super.key, required this.initialQuery, required this.audioMs});

  final String initialQuery;
  final int audioMs;

  @override
  State<LyricsSearchScreen> createState() => _LyricsSearchScreenState();
}

class _LyricsSearchScreenState extends State<LyricsSearchScreen> {
  final TextEditingController _query = TextEditingController();
  List<LyricsHit> _hits = [];
  bool _busy = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _query.text.trim();
    if (q.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = '';
      _hits = [];
    });
    List<LyricsHit> hits = [];
    String message = '';
    try {
      hits = await searchLyrics(q, audioMs: widget.audioMs);
      if (hits.isEmpty) {
        message = 'Nothing found. Try the artist and the song name only, or paste the lyrics yourself.';
      }
    } catch (_) {
      message = 'Could not reach the lyrics service. Check the connection and try again.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hits = hits;
      _message = message;
    });
  }

  String _clock(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  String _lengthNote(LyricsHit h) {
    if (widget.audioMs <= 0 || h.durationSec <= 0) return '';
    final diff = (h.durationSec - widget.audioMs / 1000).abs().round();
    return diff <= 3 ? '  -  same length as your song' : '  -  ${diff}s different from your song';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find lyrics')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _run(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Artist and song name',
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _run),
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB5ABD6))),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _hits.length,
              itemBuilder: (_, i) {
                final h = _hits[i];
                return ListTile(
                  title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${h.artist}  -  ${_clock(h.durationSec)}${_lengthNote(h)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(h.hasSynced ? 'Synced' : 'Words only'),
                  ),
                  onTap: () => Navigator.of(context).pop(h),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Lyrics come from LRCLIB, a community service, and may be missing for some songs. '
              'Make sure you may use the words in your video.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8E85B5)),
            ),
          ),
        ],
      ),
    );
  }
}
