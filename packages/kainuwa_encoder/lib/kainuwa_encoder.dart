import 'dart:async';

import 'package:flutter/services.dart';

/// Dart side of the local Android plugin.
class KainuwaEncoder {
  KainuwaEncoder._();

  static const MethodChannel _channel = MethodChannel('kainuwa_encoder');
  static final StreamController<int> _progress =
      StreamController<int>.broadcast();
  static bool _ready = false;

  static void _init() {
    if (_ready) return;
    _ready = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        final value = call.arguments;
        if (value is int) _progress.add(value);
      }
      return null;
    });
  }

  /// Export progress from 0 to 100.
  static Stream<int> get progress {
    _init();
    return _progress.stream;
  }

  /// Opens the system file picker for images. Returns a local copy path, or null if cancelled.
  static Future<String?> pickImage() {
    _init();
    return _channel.invokeMethod<String>('pick', {'mime': 'image/*'});
  }

  /// Opens the system file picker for audio. Returns a local copy path, or null if cancelled.
  static Future<String?> pickAudio() {
    _init();
    return _channel.invokeMethod<String>('pick', {'mime': 'audio/*'});
  }

  /// Shows one image for the full length of the audio and writes an MP4.
  static Future<String> exportImageWithAudio({
    required String imagePath,
    required String audioPath,
    required String outputPath,
    int width = 1280,
    int height = 720,
  }) async {
    _init();
    final result = await _channel.invokeMethod<String>('export', {
      'image': imagePath,
      'audio': audioPath,
      'output': outputPath,
      'width': width,
      'height': height,
    });
    return result ?? outputPath;
  }

  static Future<void> cancelExport() async {
    _init();
    await _channel.invokeMethod<void>('cancel');
  }

  /// Copies a finished video into Movies/Kainuwa Studio so it shows in the gallery.
  static Future<String> saveToMovies({
    required String path,
    required String name,
  }) async {
    _init();
    final result = await _channel.invokeMethod<String>('saveToMovies', {
      'path': path,
      'name': name,
    });
    return result ?? name;
  }
}
