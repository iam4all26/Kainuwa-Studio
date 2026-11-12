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

  /// Private folder of the app where data is kept permanently (not cleared like the cache).
  static Future<String> filesDir() async {
    _init();
    final result = await _channel.invokeMethod<String>('filesDir');
    return result ?? '';
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

  /// One scene: an image shown for the length of the narration, optional
  /// background music with volume and fades, and an optional animated text label.
  ///
  /// overlayAnimation is one of: fade, slide, pop, zoom.
  static Future<String> exportScene({
    required String imagePath,
    required String narrationPath,
    required String outputPath,
    String? musicPath,
    double narrationVolume = 1.0,
    double musicVolume = 0.3,
    int musicFadeInMs = 0,
    int musicFadeOutMs = 0,
    String? overlayText,
    int overlayStartMs = 1000,
    int overlayDurationMs = 800,
    String overlayAnimation = 'fade',
    int width = 1280,
    int height = 720,
  }) async {
    _init();
    final result = await _channel.invokeMethod<String>('exportScene', {
      'image': imagePath,
      'narration': narrationPath,
      'music': musicPath,
      'output': outputPath,
      'narrationVolume': narrationVolume,
      'musicVolume': musicVolume,
      'musicFadeInMs': musicFadeInMs,
      'musicFadeOutMs': musicFadeOutMs,
      'overlayText': overlayText,
      'overlayStartMs': overlayStartMs,
      'overlayDurationMs': overlayDurationMs,
      'overlayAnimation': overlayAnimation,
      'width': width,
      'height': height,
    });
    return result ?? outputPath;
  }

  static Future<void> cancelExport() async {
    _init();
    await _channel.invokeMethod<void>('cancel');
  }

  /// Saves a finished video. On Android 10 and newer it goes to Movies/Kainuwa Studio;
  /// on older versions a save dialog opens.
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
