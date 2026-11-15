import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'storage.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);

  final StorageService _storage;

  List<Course> courses = <Course>[];
  AppSettings settings = const AppSettings();
  bool loaded = false;
  String? loadError;

  Future<void> load() async {
    try {
      courses = await _storage.loadCourses();
      settings = await _storage.loadSettings();
    } catch (e) {
      loadError = e.toString();
    }
    loaded = true;
    applyOrientation();
    notifyListeners();
  }

  /// True while the lesson editor is open and the user chose landscape.
  static bool editorLandscape = false;

  /// The app itself stays in portrait; only the editor can turn to landscape.
  void applyOrientation() {
    setOrientation(landscape: editorLandscape);
  }

  static void setOrientation({required bool landscape}) {
    SystemChrome.setPreferredOrientations(landscape
        ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : const [DeviceOrientation.portraitUp]);
  }

  Course? courseById(String id) {
    for (final course in courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  String _newId() => newId();

  Lesson? lessonById(String courseId, String lessonId) {
    final course = courseById(courseId);
    if (course == null) return null;
    for (final lesson in course.lessons) {
      if (lesson.id == lessonId) return lesson;
    }
    return null;
  }

  Future<void> importCourse(Course course) {
    courses.insert(0, course);
    return _saveCourses();
  }

  /// Saves everything after an edit made directly on a course, lesson or scene.
  Future<void> persist() => _saveCourses();

  Future<void> _saveCourses() async {
    notifyListeners();
    try {
      await _storage.saveCourses(courses);
    } catch (e) {
      loadError = 'Could not save: $e';
      notifyListeners();
    }
  }

  Future<String> addCourse(String title) async {
    final id = _newId();
    courses.insert(
      0,
      Course(
        id: id,
        title: title,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _saveCourses();
    return id;
  }

  /// A single video with no course around it. Returns the ids to open the editor with.
  Future<(String, String)> addVideo() async {
    final courseId = _newId();
    final lessonId = _newId();
    const title = 'Untitled video';
    courses.insert(
      0,
      Course(
        id: courseId,
        title: title,
        isVideo: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        lessons: [Lesson(id: lessonId, title: title)],
      ),
    );
    await _saveCourses();
    return (courseId, lessonId);
  }

  Future<void> renameCourse(String id, String title) {
    final course = courseById(id);
    if (course != null) {
      course.title = title;
      if (course.isVideo && course.lessons.isNotEmpty) course.lessons.first.title = title;
    }
    return _saveCourses();
  }

  Future<void> deleteCourse(String id) {
    courses.removeWhere((c) => c.id == id);
    return _saveCourses();
  }

  Future<void> addLesson(String courseId, String title) {
    final course = courseById(courseId);
    if (course != null) {
      course.lessons.add(Lesson(id: _newId(), title: title));
    }
    return _saveCourses();
  }

  Future<void> renameLesson(String courseId, String lessonId, String title) {
    final course = courseById(courseId);
    if (course != null) {
      for (final lesson in course.lessons) {
        if (lesson.id == lessonId) lesson.title = title;
      }
    }
    return _saveCourses();
  }

  Future<void> deleteLesson(String courseId, String lessonId) {
    courseById(courseId)?.lessons.removeWhere((l) => l.id == lessonId);
    return _saveCourses();
  }

  Future<void> reorderLessons(String courseId, int oldIndex, int newIndex) {
    final course = courseById(courseId);
    if (course != null) {
      if (newIndex > oldIndex) newIndex -= 1;
      final lesson = course.lessons.removeAt(oldIndex);
      course.lessons.insert(newIndex, lesson);
    }
    return _saveCourses();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    applyOrientation();
    notifyListeners();
    try {
      await _storage.saveSettings(next);
    } catch (_) {}
  }
}

/// Gives every screen access to the app state.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  /// Use inside build(): the screen rebuilds when the state changes.
  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }

  /// Use inside event handlers: no rebuild is requested.
  static AppState read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }
}
