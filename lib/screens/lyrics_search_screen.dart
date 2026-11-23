import 'dart:async';

import 'package:flutter/material.dart';
import 'web_page_screen.dart';

import '../lyrics_search.dart';

/// Search for the words of a song online. Returns the song the person taps, or null.
class LyricsSearchScreen extends StatefulWidget {
  const LyricsSearchScreen({
    super.key,
    required this.initialTitle,
    required this.initialArtist,
    required this.audioMs,
  });

  final String initialTitle;
  final String initialArtist;
  final int audioMs;

  @override
  State<LyricsSearchScreen> createState() => _LyricsSearchScreenState();
}

class _LyricsSearchScreenState extends State<LyricsSearchScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _artist = TextEditingController();
  List<LyricsHit> _hits = [];
  bool _busy = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle;
    _artist.text = widget.initialArtist;
    if (widget.initialTitle.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final title = _title.text.trim();
    final artist = _artist.text.trim();
    if (title.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = '';
      _hits = [];
    });
    List<LyricsHit> hits = [];
    String message = '';
    try {
      hits = await searchLyrics('$artist $title', audioMs: widget.audioMs, title: title, artist: artist);
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

  /// Where the words start and end, so a wrong version shows up at once.
  String _edgesNote(LyricsHit h) {
    if (!h.hasSynced) return '';
    final first = firstLrcLine(h.synced);
    final last = lastLrcLine(h.synced);
    if (first == null || last == null) return '';
    return '\nFirst line at ${_clock(first.ms ~/ 1000)}, last line at ${_clock(last.ms ~/ 1000)}';
  }

  /// Opens Google inside the app. Long press the words on a page to copy them, press back, and paste
  /// them in the lyrics box.
  Future<void> _google() async {
    final q = Uri.encodeQueryComponent('${_artist.text.trim()} ${_title.text.trim()} lyrics'.trim());
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WebPageScreen(url: 'https://www.google.com/search?q=$q', title: 'Google'),
      ),
    );
  }

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
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Song name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _artist,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _run(),
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Artist (helps to find the exact song)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(onPressed: _run, icon: const Icon(Icons.search), label: const Text('Search')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _google,
                        icon: const Icon(Icons.public),
                        label: const Text('Google'),
                      ),
                    ),
                  ],
                ),
              ],
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
                    '${h.artist}  -  ${_clock(h.durationSec)}${_lengthNote(h)}${_edgesNote(h)}',
                    maxLines: 3,
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
