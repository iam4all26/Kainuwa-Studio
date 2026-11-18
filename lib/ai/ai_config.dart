import 'dart:convert';
import 'dart:io';

import 'package:kainuwa_encoder/kainuwa_encoder.dart';

enum AiKind { openai, anthropic, gemini }

extension AiKindInfo on AiKind {
  String get label {
    switch (this) {
      case AiKind.openai:
        return 'OpenAI style';
      case AiKind.anthropic:
        return 'Claude';
      case AiKind.gemini:
        return 'Gemini';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiKind.openai:
        return 'gpt-4o-mini';
      case AiKind.anthropic:
        return 'claude-sonnet-5-5';
      case AiKind.gemini:
        return 'gemini-2.5-flash';
    }
  }
}

/// The chosen AI service. The key itself is kept in the phone's secure storage,
/// never in the project files and never in an exported .kainuwa file.
class AiConfig {
  AiConfig({
    this.kind = AiKind.openai,
    this.openaiBase = 'https://api.openai.com/v1',
    Map<String, String>? models,
    this.key = '',
  }) : models = models ?? <String, String>{};

  AiKind kind;
  String openaiBase;
  final Map<String, String> models;
  String key;

  String get model {
    final saved = (models[kind.name] ?? '').trim();
    return saved.isEmpty ? kind.defaultModel : saved;
  }

  bool get ready => key.trim().isNotEmpty && model.isNotEmpty;

  static const String _file = 'ai_config.json';

  static Future<File> _fileRef() async {
    final base = await KainuwaEncoder.filesDir();
    final dir = Directory('$base/kainuwa_data');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$_file');
  }

  static Future<AiConfig> load() async {
    final config = AiConfig();
    try {
      final file = await _fileRef();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is Map<String, dynamic>) {
          final k = data['kind'];
          config.kind = AiKind.values.firstWhere((e) => e.name == k, orElse: () => AiKind.openai);
          final base = data['openaiBase'];
          if (base is String && base.trim().isNotEmpty) config.openaiBase = base.trim();
          final models = data['models'];
          if (models is Map) {
            models.forEach((key, value) {
              if (value is String) config.models[key.toString()] = value;
            });
          }
        }
      }
    } catch (_) {}
    try {
      config.key = await KainuwaEncoder.secureGet('ai_key_${config.kind.name}');
    } catch (_) {}
    return config;
  }

  /// Loads the key that belongs to another provider when the user switches.
  Future<void> loadKeyFor(AiKind next) async {
    kind = next;
    try {
      key = await KainuwaEncoder.secureGet('ai_key_${next.name}');
    } catch (_) {
      key = '';
    }
  }

  Future<void> save() async {
    final file = await _fileRef();
    await file.writeAsString(jsonEncode({
      'kind': kind.name,
      'openaiBase': openaiBase,
      'models': models,
    }));
    await KainuwaEncoder.secureSet('ai_key_${kind.name}', key.trim());
  }

  Future<void> removeKey() async {
    key = '';
    await KainuwaEncoder.secureSet('ai_key_${kind.name}', '');
  }
}
