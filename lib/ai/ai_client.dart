import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_config.dart';

class AiException implements Exception {
  AiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks straight from the phone to the AI service the user chose.
class AiClient {
  AiClient._();

  static Future<String> complete(
    AiConfig config, {
    required String system,
    required String user,
    int maxTokens = 8000,
    double temperature = 0.4,
  }) async {
    if (!config.ready) {
      throw AiException('Add your AI key in Settings first.');
    }
    switch (config.kind) {
      case AiKind.openai:
        return _openai(config, system, user, temperature);
      case AiKind.anthropic:
        return _anthropic(config, system, user, maxTokens, temperature);
      case AiKind.gemini:
        return _gemini(config, system, user, temperature);
    }
  }

  static Future<dynamic> _post(Uri uri, Map<String, String> headers, Map<String, dynamic> body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 25));
      request.headers.set('content-type', 'application/json; charset=utf-8');
      headers.forEach(request.headers.set);
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(const Duration(seconds: 25));
      final text = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 180));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiException(_explain(response.statusCode, text));
      }
      try {
        return jsonDecode(text);
      } catch (_) {
        throw AiException('The AI service sent an answer the app could not read.');
      }
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw AiException('The AI service took too long. Check your internet and try again.');
    } on SocketException {
      throw AiException('No internet connection, or the address is wrong.');
    } on HandshakeException {
      throw AiException('Could not make a secure connection to the AI service.');
    } on FormatException {
      throw AiException('The address is not valid. Check the base URL.');
    } finally {
      client.close(force: true);
    }
  }

  static String _explain(int code, String body) {
    String detail = '';
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final err = data['error'];
        if (err is Map && err['message'] is String) {
          detail = err['message'] as String;
        } else if (err is String) {
          detail = err;
        } else if (data['message'] is String) {
          detail = data['message'] as String;
        }
      }
    } catch (_) {}
    if (detail.length > 200) detail = '${detail.substring(0, 200)}...';
    if (code == 401 || code == 403) {
      return 'The key was not accepted. Check it and the provider.${detail.isEmpty ? '' : '\n$detail'}';
    }
    if (code == 404) {
      return 'Not found. Check the model name and the base URL.${detail.isEmpty ? '' : '\n$detail'}';
    }
    if (code == 429) {
      return 'Too many requests or no credit left on this key.${detail.isEmpty ? '' : '\n$detail'}';
    }
    return 'The AI service replied with error $code.${detail.isEmpty ? '' : '\n$detail'}';
  }

  static Future<String> _openai(AiConfig c, String system, String user, double temperature) async {
    var base = c.openaiBase.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final data = await _post(
      Uri.parse('$base/chat/completions'),
      {'authorization': 'Bearer ${c.key.trim()}'},
      {
        'model': c.model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      },
    );
    try {
      final content = data['choices'][0]['message']['content'];
      if (content is String && content.trim().isNotEmpty) return content;
    } catch (_) {}
    throw AiException('The AI service returned an empty answer.');
  }

  static Future<String> _anthropic(AiConfig c, String system, String user, int maxTokens, double temperature) async {
    final data = await _post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      {'x-api-key': c.key.trim(), 'anthropic-version': '2023-06-01'},
      {
        'model': c.model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      },
    );
    try {
      final parts = data['content'] as List;
      final text = parts.where((p) => p is Map && p['type'] == 'text').map((p) => p['text'].toString()).join();
      if (text.trim().isNotEmpty) return text;
    } catch (_) {}
    throw AiException('The AI service returned an empty answer.');
  }

  static Future<String> _gemini(AiConfig c, String system, String user, double temperature) async {
    final model = c.model.startsWith('models/') ? c.model.substring(7) : c.model;
    final data = await _post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
      {'x-goog-api-key': c.key.trim()},
      {
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': user},
            ],
          },
        ],
        'generationConfig': {'temperature': temperature},
      },
    );
    try {
      final parts = data['candidates'][0]['content']['parts'] as List;
      final text = parts.map((p) => p['text']?.toString() ?? '').join();
      if (text.trim().isNotEmpty) return text;
    } catch (_) {}
    throw AiException('The AI service returned an empty answer.');
  }
}
