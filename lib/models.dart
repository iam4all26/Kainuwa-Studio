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
    this.opacity = 1.0,
    this.startMs = 0,
    this.endMs = -1,
    this.animOut = 'none',
    this.animOutDurationMs = 500,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontFamily = '',
    this.letterSpacing = 0,
    this.lineHeight = 1.15,
    this.align = 'center',
    this.bgBox = false,
    this.bgColor = 0xCC000000,
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

  /// Entrance animation. animStartMs is a delay after the item appears.
  String animIn;
  int animStartMs;
  int animDurationMs;

  /// 0 (invisible) to 1 (solid).
  double opacity;

  /// The item is on screen from startMs until endMs (milliseconds into the
  /// slide). endMs -1 means until the end of the slide.
  int startMs;
  int endMs;

  /// Exit animation, played just before the item leaves.
  String animOut;
  int animOutDurationMs;

  // Text style
  bool italic;
  bool underline;
  bool strike;

  /// Empty means the default font.
  String fontFamily;

  /// In pixels of a 72 px text.
  double letterSpacing;
  double lineHeight;

  /// left, center, right or justify
  String align;
  bool bgBox;
  int bgColor;

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
        'opacity': opacity,
        'startMs': startMs,
        'endMs': endMs,
        'animOut': animOut,
        'animOutDurationMs': animOutDurationMs,
        'italic': italic,
        'underline': underline,
        'strike': strike,
        'fontFamily': fontFamily,
        'letterSpacing': letterSpacing,
        'lineHeight': lineHeight,
        'align': align,
        'bgBox': bgBox,
        'bgColor': bgColor,
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
        opacity: _num(json['opacity'], 1.0).clamp(0.0, 1.0).toDouble(),
        startMs: _int(json['startMs'], 0),
        endMs: _int(json['endMs'], -1),
        animOut: _str(json['animOut'], 'none'),
        animOutDurationMs: _int(json['animOutDurationMs'], 500),
        italic: json['italic'] is bool ? json['italic'] as bool : false,
        underline: json['underline'] is bool ? json['underline'] as bool : false,
        strike: json['strike'] is bool ? json['strike'] as bool : false,
        fontFamily: _str(json['fontFamily'], ''),
        letterSpacing: _num(json['letterSpacing'], 0),
        lineHeight: _num(json['lineHeight'], 1.15),
        align: _str(json['align'], 'center'),
        bgBox: json['bgBox'] is bool ? json['bgBox'] as bool : false,
        bgColor: _int(json['bgColor'], 0xCC000000),
      );
}

/// One slide of a lesson.
class Scene {
  Scene({
    required this.id,
    this.durationMs = 5000,
    this.bgType = 'color',
    this.bgValue = '4294967295',
    this.narrationPath = '',
    this.narrationMs = 0,
    this.narrationVolume = 1.0,
    this.narrationClean = true,
    this.videoPath = '',
    this.videoStartMs = 0,
    this.videoMs = 0,
    this.videoVolume = 1.0,
    this.videoMuted = false,
    List<Layer>? layers,
  }) : layers = layers ?? <Layer>[];

  final String id;
  int durationMs;

  /// color (bgValue is the ARGB number), asset (an asset path) or file (a photo path)
  String bgType;
  String bgValue;

  /// Voice recording or imported audio for this scene. Empty means none.
  String narrationPath;
  int narrationMs;
  double narrationVolume;

  /// Clean the voice (cut rumble, quiet the gaps) when the lesson is exported.
  bool narrationClean;
  final List<Layer> layers;

  /// A video clip that plays as this slide's background. Empty means none.
  String videoPath;
  int videoStartMs;
  int videoMs;
  double videoVolume;
  bool videoMuted;

  bool get hasVideo => videoPath.isNotEmpty;

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
        narrationPath: narrationPath,
        narrationMs: narrationMs,
        narrationVolume: narrationVolume,
        narrationClean: narrationClean,
        videoPath: videoPath,
        videoStartMs: videoStartMs,
        videoMs: videoMs,
        videoVolume: videoVolume,
        videoMuted: videoMuted,
        layers: layers.map((l) => l.copy()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'durationMs': durationMs,
        'bgType': bgType,
        'bgValue': bgValue,
        'narrationPath': narrationPath,
        'narrationMs': narrationMs,
        'narrationVolume': narrationVolume,
        'narrationClean': narrationClean,
        'videoPath': videoPath,
        'videoStartMs': videoStartMs,
        'videoMs': videoMs,
        'videoVolume': videoVolume,
        'videoMuted': videoMuted,
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
      narrationPath: _str(json['narrationPath'], ''),
      narrationMs: _int(json['narrationMs'], 0),
      narrationVolume: _num(json['narrationVolume'], 1.0),
      narrationClean: json['narrationClean'] is bool ? json['narrationClean'] as bool : true,
      videoPath: _str(json['videoPath'], ''),
      videoStartMs: _int(json['videoStartMs'], 0),
      videoMs: _int(json['videoMs'], 0),
      videoVolume: _num(json['videoVolume'], 1.0),
      videoMuted: json['videoMuted'] is bool ? json['videoMuted'] as bool : false,
      layers: layers,
    );
  }
}

/// A sound placed on the lesson timeline: music, a sound effect or a voice clip.
class AudioClip {
  AudioClip({
    required this.id,
    required this.path,
    this.label = '',
    this.kind = 'music',
    this.startMs = 0,
    this.trimMs = 0,
    this.durationMs = 1000,
    this.sourceMs = 1000,
    this.volume = 1.0,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
  });

  final String id;
  String path;
  String label;

  /// music, sfx or voice
  String kind;

  /// Where the clip starts on the lesson timeline.
  int startMs;

  /// How far into the file the clip starts playing (trimmed from the start).
  int trimMs;

  /// How long the clip plays.
  int durationMs;

  /// Length of the whole file.
  int sourceMs;
  double volume;
  int fadeInMs;
  int fadeOutMs;

  int get endMs => startMs + durationMs;

  AudioClip copy() => AudioClip.fromJson({...toJson(), 'id': newId()});

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'label': label,
        'kind': kind,
        'startMs': startMs,
        'trimMs': trimMs,
        'durationMs': durationMs,
        'sourceMs': sourceMs,
        'volume': volume,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
      };

  factory AudioClip.fromJson(Map<String, dynamic> json) => AudioClip(
        id: _str(json['id'], newId()),
        path: _str(json['path'], ''),
        label: _str(json['label'], ''),
        kind: _str(json['kind'], 'music'),
        startMs: _int(json['startMs'], 0),
        trimMs: _int(json['trimMs'], 0),
        durationMs: _int(json['durationMs'], 1000),
        sourceMs: _int(json['sourceMs'], 1000),
        volume: _num(json['volume'], 1.0).clamp(0.0, 1.0).toDouble(),
        fadeInMs: _int(json['fadeInMs'], 0),
        fadeOutMs: _int(json['fadeOutMs'], 0),
      );
}

class Lesson {
  Lesson({
    required this.id,
    required this.title,
    List<Scene>? scenes,
    this.musicPath = '',
    this.musicVolume = 0.3,
    this.musicFade = true,
    Set<String>? hiddenTracks,
    List<AudioClip>? audioClips,
  })  : scenes = scenes ?? <Scene>[],
        hiddenTracks = hiddenTracks ?? <String>{},
        audioClips = audioClips ?? <AudioClip>[];

  final String id;
  String title;
  final List<Scene> scenes;

  /// Background music for the whole lesson. Empty means none.
  String musicPath;
  double musicVolume;
  bool musicFade;

  /// Tracks switched off with the eye icon (image, text, audio). They are left
  /// out of the preview and of the exported video.
  final Set<String> hiddenTracks;

  /// Extra sounds on the Audio track, besides the narration of each slide and
  /// the lesson music.
  final List<AudioClip> audioClips;

  int get durationMs => scenes.fold<int>(0, (sum, s) => sum + s.durationMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'musicPath': musicPath,
        'musicVolume': musicVolume,
        'musicFade': musicFade,
        'hiddenTracks': hiddenTracks.toList(),
        'audioClips': audioClips.map((c) => c.toJson()).toList(),
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
      musicPath: _str(json['musicPath'], ''),
      musicVolume: _num(json['musicVolume'], 0.3),
      musicFade: json['musicFade'] is bool ? json['musicFade'] as bool : true,
      hiddenTracks: json['hiddenTracks'] is List
          ? (json['hiddenTracks'] as List).whereType<String>().toSet()
          : <String>{},
      audioClips: [
        if (json['audioClips'] is List)
          for (final item in json['audioClips'] as List)
            if (item is Map<String, dynamic>) AudioClip.fromJson(item),
      ],
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
