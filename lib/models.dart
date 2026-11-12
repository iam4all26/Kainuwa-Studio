class Lesson {
  Lesson({required this.id, required this.title, this.durationMs = 0});

  final String id;
  String title;
  int durationMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'durationMs': durationMs,
      };

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? 'Untitled lesson',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      );
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
    final rawLessons = json['lessons'];
    final lessons = <Lesson>[];
    if (rawLessons is List) {
      for (final item in rawLessons) {
        if (item is Map<String, dynamic>) {
          lessons.add(Lesson.fromJson(item));
        }
      }
    }
    return Course(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Untitled course',
      description: (json['description'] as String?) ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
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
        videoHeight: (json['videoHeight'] as num?)?.toInt() == 1080 ? 1080 : 720,
        frameRate: (json['frameRate'] as num?)?.toInt() == 24 ? 24 : 30,
      );
}

String formatClock(int ms) {
  final totalSeconds = (ms / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String lessonCountText(int count) => '$count ${count == 1 ? 'Lesson' : 'Lessons'}';

String minutesText(int ms) => '${(ms / 60000).round()} min';
