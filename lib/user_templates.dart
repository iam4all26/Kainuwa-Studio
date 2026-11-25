import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import 'models.dart';

/// A look the owner saved from one of their own music or lyrics videos. It keeps only the look
/// (fonts, colours, effects, layout), never the cover, song or words.
class UserTemplate {
  UserTemplate({required this.id, required this.name, required this.kind, required this.form, required this.createdAt});

  final String id;
  String name;

  /// 'music' or 'lyrics'
  final String kind;
  final Map<String, dynamic> form;
  final int createdAt;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind, 'form': form, 'createdAt': createdAt};

  factory UserTemplate.fromJson(Map<String, dynamic> j) => UserTemplate(
        id: j['id'] is String ? j['id'] as String : newId(),
        name: j['name'] is String ? j['name'] as String : 'My template',
        kind: j['kind'] == 'music' ? 'music' : 'lyrics',
        form: j['form'] is Map ? Map<String, dynamic>.from(j['form'] as Map) : <String, dynamic>{},
        createdAt: j['createdAt'] is num ? (j['createdAt'] as num).toInt() : 0,
      );
}

const List<String> _kLyricsLookKeys = [
  'look', 'anim', 'font', 'bg', 'palette', 'stars', 'streaks', 'embers', 'sparkle', 'snow', 'more',
  'karaoke', 'player', 'centerViz', 'shape', 'byWord', 'layout', 'viz',
];
const List<String> _kMusicLookKeys = ['shape', 'viz', 'player', 'fx', 'accent', 'layout', 'titleFont', 'artistFont', 'template', 'aspect'];

/// The look part of a setup form: everything personal (cover, song, words, timing, titles) is left out.
Map<String, dynamic> templateFormFrom(String kind, Map<String, dynamic> form) {
  final keys = kind == 'music' ? _kMusicLookKeys : _kLyricsLookKeys;
  return {
    for (final k in keys)
      if (form.containsKey(k)) k: form[k],
  };
}

/// The owner's saved templates, kept in one small JSON file in the app's private storage.
class UserTemplates extends ChangeNotifier {
  UserTemplates._();
  static final UserTemplates instance = UserTemplates._();

  final List<UserTemplate> items = [];
  bool _loaded = false;

  Future<File> _file() async {
    final base = await KainuwaEncoder.filesDir();
    final dir = Directory('$base/kainuwa_data');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/user_templates.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString());
      if (data is Map && data['items'] is List) {
        items.clear();
        for (final e in data['items'] as List) {
          if (e is Map<String, dynamic>) items.add(UserTemplate.fromJson(e));
        }
        notifyListeners();
      }
    } catch (_) {
      // An unreadable file simply means no saved templates.
    }
  }

  Future<void> _save() async {
    final f = await _file();
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(jsonEncode({'items': [for (final t in items) t.toJson()]}), flush: true);
    await temp.rename(f.path);
  }

  Future<void> add(String kind, String name, Map<String, dynamic> form) async {
    await load();
    items.insert(0, UserTemplate(id: newId(), name: name, kind: kind, form: templateFormFrom(kind, form), createdAt: DateTime.now().millisecondsSinceEpoch));
    notifyListeners();
    await _save();
  }

  Future<void> rename(String id, String name) async {
    for (final t in items) {
      if (t.id == id) t.name = name;
    }
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    items.removeWhere((t) => t.id == id);
    notifyListeners();
    await _save();
  }
}
