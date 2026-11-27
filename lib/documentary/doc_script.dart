import '../models.dart';

/// One scene found in a script or in a production plan.
class DocScene {
  DocScene({required this.title, required this.narration, this.kind = '', this.note = '', this.clips = 0});

  final String title;
  final String narration;

  /// FLOW, PRESENTER, MIXED... as written in the plan. Empty for a plain script.
  final String kind;

  /// Everything else the plan says about the scene (what is on screen, prompts, sound, editing).
  final String note;

  /// How many Google Flow prompts the scene has, which is how many clips it needs.
  final int clips;
}

final RegExp _sceneHead = RegExp(r'^#{2,4}\s*Scene\s+(\d+)\s*[—–-]?\s*(.*)$', multiLine: true);
final RegExp _label = RegExp(
  r'^(Narration|Visual|Visual direction|Google Flow prompts?|Sound|Editing|Music|Camera|Note|Notes|Transition|One historical production note)[^:\n]{0,40}:',
);

String _unquote(String s) {
  var t = s.trim();
  const quotes = ['"', '“', '”'];
  while (t.isNotEmpty && quotes.contains(t[0])) {
    t = t.substring(1).trimLeft();
  }
  while (t.isNotEmpty && quotes.contains(t[t.length - 1])) {
    t = t.substring(0, t.length - 1).trimRight();
  }
  return t;
}

/// Reads a script. A production plan (with "### Scene 1 - title" headings and "Narration:" lines) gives one
/// scene per heading. A plain script gives one scene per paragraph.
List<DocScene> parseDocScript(String text) {
  final clean = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (_sceneHead.hasMatch(clean)) return _parsePlan(clean);
  return _parseParagraphs(clean);
}

List<DocScene> _parsePlan(String text) {
  final lines = text.split('\n');
  final out = <DocScene>[];
  var i = 0;
  while (i < lines.length) {
    final m = _sceneHead.firstMatch(lines[i]);
    if (m == null) {
      i++;
      continue;
    }
    final number = m.group(1)!;
    final name = (m.group(2) ?? '').trim();
    i++;
    final block = <String>[];
    while (i < lines.length && !lines[i].startsWith('### ') && !lines[i].startsWith('## ')) {
      block.add(lines[i]);
      i++;
    }
    var kind = '';
    final narration = <String>[];
    final note = <String>[];
    var inNarration = false;
    var inCode = false;
    var codeBlocks = 0;
    for (final raw in block) {
      final line = raw.trimRight();
      if (line.trim().startsWith('```')) {
        if (!inCode) codeBlocks++;
        inCode = !inCode;
        inNarration = false;
        note.add(line);
        continue;
      }
      if (inCode) {
        note.add(line);
        continue;
      }
      if (line.trim().startsWith('![')) continue;
      final trimmed = line.trim();
      if (trimmed.isEmpty && note.isEmpty && narration.isEmpty) continue;
      if (kind.isEmpty && trimmed.isNotEmpty && RegExp(r'^[A-Z][A-Z +/]{3,}$').hasMatch(trimmed) && narration.isEmpty && note.isEmpty) {
        kind = trimmed;
        continue;
      }
      if (trimmed.startsWith('Narration:')) {
        inNarration = true;
        final rest = trimmed.substring('Narration:'.length).trim();
        if (rest.isNotEmpty) narration.add(_unquote(rest));
        continue;
      }
      if (_label.hasMatch(trimmed)) {
        inNarration = false;
        note.add(line);
        continue;
      }
      if (inNarration) {
        if (trimmed.isNotEmpty) narration.add(_unquote(trimmed));
        continue;
      }
      note.add(line);
    }
    out.add(DocScene(
      title: name.isEmpty ? 'Scene $number' : '$number. $name',
      narration: narration.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      kind: kind,
      note: note.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim(),
      clips: codeBlocks,
    ));
  }
  return out;
}

bool _isHeading(String line) {
  final t = line.trim();
  if (t.isEmpty || t.length > 60) return false;
  if (RegExp(r'^(SASHE|SECTION|PART|CHAPTER)\b', caseSensitive: false).hasMatch(t)) return true;
  final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
  return letters.length >= 4 && letters == letters.toUpperCase();
}

bool _isShortTitle(String line) {
  final t = line.trim();
  if (t.isEmpty || t.length > 70) return false;
  return !RegExp(r'[.?!:;,"“”]$').hasMatch(t);
}

List<DocScene> _parseParagraphs(String text) {
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.split('\n').where((l) => !l.trim().startsWith('![')).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final out = <DocScene>[];
  var section = '';
  for (var i = 0; i < paragraphs.length; i++) {
    final p = paragraphs[i];
    if (_isHeading(p)) {
      section = p;
      // A short line right after a heading belongs to it (for example the part's name).
      while (i + 1 < paragraphs.length && _isShortTitle(paragraphs[i + 1]) && !_isHeading(paragraphs[i + 1])) {
        section = '$section: ${paragraphs[i + 1]}';
        i++;
        break;
      }
      continue;
    }
    final words = p.split(' ');
    final title = words.length <= 6 ? p : '${words.take(6).join(' ')}...';
    out.add(DocScene(title: '${out.length + 1}. $title', narration: p, note: section));
  }
  return out;
}

/// Slide length from the number of characters of Hausa or English narration (about 13 characters a second).
int guessDurationMs(String narration) {
  final ms = narration.length * 75;
  if (ms < 3000) return 3000;
  if (ms > 25000) return 25000;
  return ms;
}

/// Replaces the slides of [lesson] with one black slide per scene. The words and notes are kept on each slide.
void buildDocumentary(Lesson lesson, List<DocScene> scenes) {
  lesson.scenes
    ..clear()
    ..addAll([
      for (final s in scenes)
        Scene(
          id: newId(),
          durationMs: guessDurationMs(s.narration),
          bgType: 'color',
          bgValue: '4278190080',
          narrationText: s.narration,
          note: [
            s.title,
            if (s.kind.isNotEmpty) '[${s.kind}]',
            if (s.clips > 0) '(${s.clips} clip${s.clips == 1 ? '' : 's'} planned)',
            if (s.note.isNotEmpty) s.note,
          ].join('\n'),
        ),
    ]);
}
