import 'dart:ui' show Color;

import 'data/asset_catalog.dart';

int _idCounter = 0;

/// A new unique id.
String newId() {
  _idCounter++;
  return '${DateTime.now().microsecondsSinceEpoch}$_idCounter';
}

double _num(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;
int _int(dynamic v, int fallback) => v is num ? v.toInt() : fallback;
String _str(dynamic v, String fallback) => v is String ? v : fallback;

/// One item placed on a scene: text, an icon or illustration, a photo, or a shape.
/// Position and size are fractions of the slide (0 to 1).
class Layer {
  Layer({
    required this.id,
    required this.type,
    this.cx = 0.5,
    this.cy = 0.5,
    this.w = 0.3,
    this.h = 0.3,
    this.rotation = 0,
    this.text = '',
    this.path = '',
    this.shape = 'rect',
    this.color = 0xFFFFFFFF,
    this.bold = true,
    this.animIn = 'none',
    this.animStartMs = 0,
    this.animDurationMs = 800,
  });

  final String id;

  /// text, asset, image or shape
  final String type;
  double cx;
  double cy;
  double w;
  double h;
  double rotation;
  String text;
  String path;

  /// rect, round or circle
  String shape;
  int color;
  bool bold;

  // Stored now, used when animation is added to the editor.
  String animIn;
  int animStartMs;
  int animDurationMs;

  Layer copy() => Layer.fromJson({...toJson(), 'id': newId()});

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'cx': cx,
        'cy': cy,
        'w': w,
        'h': h,
        'rotation': rotation,
        'text': text,
        'path': path,
        'shape': shape,
        'color': color,
        'bold': bold,
        'animIn': animIn,
        'animStartMs': animStartMs,
        'animDurationMs': animDurationMs,
      };

  factory Layer.fromJson(Map<String, dynamic> json) => Layer(
        id: _str(json['id'], newId()),
        type: _str(json['type'], 'shape'),
        cx: _num(json['cx'], 0.5),
        cy: _num(json['cy'], 0.5),
        w: _num(json['w'], 0.3),
        h: _num(json['h'], 0.3),
        rotation: _num(json['rotation'], 0),
        text: _str(json['text'], ''),
        path: _str(json['path'], ''),
        shape: _str(json['shape'], 'rect'),
        color: _int(json['color'], 0xFFFFFFFF),
        bold: json['bold'] is bool ? json['bold'] as bool : true,
        animIn: _str(json['animIn'], 'none'),
        animStartMs: _int(json['animStartMs'], 0),
        animDurationMs: _int(json['animDurationMs'], 800),
      );
}

/// One slide of a lesson.
class Scene {
  Scene({
    required this.id,
    this.durationMs = 5000,
    this.bgType = 'color',
    this.bgValue = '4294967295',
    List<Layer>? layers,
  }) : layers = layers ?? <Layer>[];

  final String id;
  int durationMs;

  /// color (bgValue is the ARGB number), asset (an asset path) or file (a photo path)
  String bgType;
  String bgValue;
  final List<Layer> layers;

  bool get isDarkBackground {
    switch (bgType) {
      case 'color':
        return Color(int.tryParse(bgValue) ?? 0xFFFFFFFF).computeLuminance() < 0.45;
      case 'asset':
        return kDarkBackgrounds.contains(bgValue);
      default:
        return true;
    }
  }

  Scene duplicate() => Scene(
        id: newId(),
        durationMs: durationMs,
        bgType: bgType,
        bgValue: bgValue,
        layers: layers.map((l) => l.copy()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'durationMs': durationMs,
        'bgType': bgType,
        'bgValue': bgValue,
        'layers': layers.map((l) => l.toJson()).toList(),
      };

  factory Scene.fromJson(Map<String, dynamic> json) {
    final layers = <Layer>[];
    final raw = json['layers'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) layers.add(Layer.fromJson(item));
      }
    }
    return Scene(
      id: _str(json['id'], newId()),
      durationMs: _int(json['durationMs'], 5000),
      bgType: _str(json['bgType'], 'color'),
      bgValue: _str(json['bgValue'], '4294967295'),
      layers: layers,
    );
  }
}

class Lesson {
  Lesson({required this.id, required this.title, List<Scene>? scenes})
      : scenes = scenes ?? <Scene>[];

  final String id;
  String title;
  final List<Scene> scenes;

  int get durationMs => scenes.fold<int>(0, (sum, s) => sum + s.durationMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'scenes': scenes.map((s) => s.toJson()).toList(),
      };

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final scenes = <Scene>[];
    final raw = json['scenes'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) scenes.add(Scene.fromJson(item));
      }
    }
    return Lesson(
      id: _str(json['id'], newId()),
      title: _str(json['title'], 'Untitled lesson'),
      scenes: scenes,
    );
  }
}

class Course {
  Course({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    List<Lesson>? lessons,
  }) : lessons = lessons ?? <Lesson>[];

  final String id;
  String title;
  String description;
  final int createdAt;
  final List<Lesson> lessons;

  int get totalMs => lessons.fold<int>(0, (sum, lesson) => sum + lesson.durationMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'createdAt': createdAt,
        'lessons': lessons.map((l) => l.toJson()).toList(),
      };

  factory Course.fromJson(Map<String, dynamic> json) {
    final lessons = <Lesson>[];
    final raw = json['lessons'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) lessons.add(Lesson.fromJson(item));
      }
    }
    return Course(
      id: _str(json['id'], newId()),
      title: _str(json['title'], 'Untitled course'),
      description: _str(json['description'], ''),
      createdAt: _int(json['createdAt'], 0),
      lessons: lessons,
    );
  }
}

class AppSettings {
  const AppSettings({this.videoHeight = 720, this.frameRate = 30});

  final int videoHeight;
  final int frameRate;

  int get videoWidth => videoHeight == 1080 ? 1920 : 1280;

  AppSettings copyWith({int? videoHeight, int? frameRate}) => AppSettings(
        videoHeight: videoHeight ?? this.videoHeight,
        frameRate: frameRate ?? this.frameRate,
      );

  Map<String, dynamic> toJson() => {
        'videoHeight': videoHeight,
        'frameRate': frameRate,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        videoHeight: _int(json['videoHeight'], 720) == 1080 ? 1080 : 720,
        frameRate: _int(json['frameRate'], 30) == 24 ? 24 : 30,
      );
}

String formatClock(int ms) {
  final totalSeconds = (ms / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String lessonCountText(int count) => '$count ${count == 1 ? 'Lesson' : 'Lessons'}';

String sceneCountText(int count) => '$count ${count == 1 ? 'scene' : 'scenes'}';

String minutesText(int ms) => '${(ms / 60000).round()} min';
