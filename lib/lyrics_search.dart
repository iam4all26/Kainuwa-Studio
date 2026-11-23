import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'lyrics_project.dart';

/// One song found by the lyrics search.
class LyricsHit {
  const LyricsHit({
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSec,
    required this.plain,
    required this.synced,
  });

  final String title;
  final String artist;
  final String album;
  final int durationSec;

  /// The words, one line per line (may be empty).
  final String plain;

  /// The words with a start time on every line (LRC format; may be empty).
  final String synced;

  bool get hasSynced => synced.trim().isNotEmpty;

  /// The words to put in the lyrics box.
  String get words => plain.trim().isNotEmpty ? plain.trim() : stripLrc(synced);
}

final RegExp _lrcTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final RegExp _lrcMeta = RegExp(r'^\[[A-Za-z]+:.*\]$');

/// The words of an LRC text, without the times.
String stripLrc(String raw) {
  final lines = <String>[];
  for (final line in raw.replaceAll('\r', '').split('\n')) {
    final t = line.replaceAll(_lrcTag, '').trim();
    if (t.isEmpty || _lrcMeta.hasMatch(t)) continue;
    lines.add(t);
  }
  return lines.join('\n');
}

/// Cues from LRC text: each line starts at its time and runs to the next line. A line is kept at most
/// 8 seconds, so a long music-only part is left empty. By word, a line's time is shared between its words.
List<LyricCue> cuesFromLrc(String raw, int totalMs, bool byWord) {
  final stamps = <(int, String)>[];
  for (final line in raw.replaceAll('\r', '').split('\n')) {
    final tags = _lrcTag.allMatches(line).toList();
    if (tags.isEmpty) continue;
    final text = line.replaceAll(_lrcTag, '').trim();
    for (final m in tags) {
      final minutes = int.tryParse(m.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(m.group(2) ?? '') ?? 0;
      final frac = m.group(3) ?? '';
      final ms = frac.isEmpty ? 0 : (int.tryParse(frac.padRight(3, '0').substring(0, 3)) ?? 0);
      stamps.add((minutes * 60000 + seconds * 1000 + ms, text));
    }
  }
  stamps.sort((a, b) => a.$1.compareTo(b.$1));
  final out = <LyricCue>[];
  for (var i = 0; i < stamps.length; i++) {
    final text = stamps[i].$2;
    if (text.isEmpty) continue;
    final start = stamps[i].$1;
    if (start >= totalMs) break;
    var end = i + 1 < stamps.length ? stamps[i + 1].$1 : totalMs;
    end = math.min(end, start + 8000);
    end = math.min(end, totalMs);
    if (end < start + 200) end = math.min(totalMs, start + 200);
    if (end <= start) continue;
    if (byWord) {
      out.addAll(spreadCues(lyricUnits(text, true), start, end));
    } else {
      out.add(LyricCue(start, end, text));
    }
  }
  return out;
}

/// Searches the LRCLIB community lyrics service. Songs with timed lyrics come first, then the ones
/// whose length is closest to the song ([audioMs]). Throws when the service cannot be reached.
Future<List<LyricsHit>> searchLyrics(String query, {int audioMs = 0}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(Uri.https('lrclib.net', '/api/search', {'q': q}));
    request.headers.set(HttpHeaders.userAgentHeader, 'KainuwaStudio/1.0');
    final response = await request.close().timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw HttpException('The lyrics service answered with code ${response.statusCode}.');
    }
    final text = await response.transform(utf8.decoder).join();
    final data = jsonDecode(text);
    final hits = <LyricsHit>[];
    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        String str(String key) => item[key] is String ? item[key] as String : '';
        if (item['instrumental'] == true) continue;
        final hit = LyricsHit(
          title: str('trackName'),
          artist: str('artistName'),
          album: str('albumName'),
          durationSec: item['duration'] is num ? (item['duration'] as num).round() : 0,
          plain: str('plainLyrics'),
          synced: str('syncedLyrics'),
        );
        if (hit.plain.trim().isEmpty && !hit.hasSynced) continue;
        hits.add(hit);
      }
    }
    final songSec = audioMs / 1000;
    int gap(LyricsHit h) => audioMs > 0 && h.durationSec > 0 ? (h.durationSec - songSec).abs().round() : 0;
    hits.sort((a, b) {
      if (a.hasSynced != b.hasSynced) return a.hasSynced ? -1 : 1;
      return gap(a).compareTo(gap(b));
    });
    return hits.take(25).toList();
  } finally {
    client.close(force: true);
  }
}
