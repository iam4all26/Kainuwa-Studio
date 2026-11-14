import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../app_state.dart';
import '../models.dart';
import '../project_package.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lessons_screen.dart';

class CoursesTab extends StatelessWidget {
  const CoursesTab({
    super.key,
    required this.onOpenSettings,
    required this.onOpenTemplates,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenTemplates;

  Future<void> _create(BuildContext context) async {
    final state = AppScope.read(context);
    final title = await promptText(
      context,
      title: 'New course',
      label: 'Course title',
      confirm: 'Create',
    );
    if (title != null) {
      await state.addCourse(title);
    }
  }

  void _busy(BuildContext context, String text) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(text)),
          ]),
        ),
      ),
    );
  }

  void _say(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export(BuildContext context, Course course) async {
    final nav = Navigator.of(context, rootNavigator: true);
    _busy(context, 'Packing "${course.title}" with all its media...');
    var closed = false;
    void close() {
      if (!closed) {
        closed = true;
        nav.pop();
      }
    }

    String? temp;
    try {
      final base = await KainuwaEncoder.filesDir();
      final dir = Directory('$base/export_tmp');
      await dir.create(recursive: true);
      final safe = course.title.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final name = '${safe.isEmpty ? 'course' : safe}.kainuwa';
      temp = '${dir.path}/$name';
      await ProjectPackage.exportTo(course, temp);
      close();
      final where = await KainuwaEncoder.saveFile(path: temp, name: name);
      if (context.mounted) _say(context, 'Saved to $where');
    } catch (e) {
      close();
      if (context.mounted) {
        final text = e.toString();
        _say(context, text.contains('save_cancelled') ? 'Export cancelled.' : 'Could not export: $text');
      }
    } finally {
      close();
      if (temp != null) {
        try {
          await File(temp).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final state = AppScope.read(context);
    String? picked;
    try {
      picked = await KainuwaEncoder.pickAnyFile();
    } catch (_) {
      picked = null;
    }
    if (picked == null || !context.mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    _busy(context, 'Opening the project...');
    var closed = false;
    void close() {
      if (!closed) {
        closed = true;
        nav.pop();
      }
    }

    try {
      final course = await ProjectPackage.importFrom(picked);
      await state.importCourse(course);
      close();
      if (context.mounted) _say(context, 'Imported "${course.title}".');
    } catch (e) {
      close();
      if (context.mounted) {
        _say(context, e is FormatException ? e.message : 'Could not import: $e');
      }
    } finally {
      close();
      try {
        await File(picked).delete();
      } catch (_) {}
    }
  }

  Future<void> _rename(BuildContext context, Course course) async {
    final state = AppScope.read(context);
    final title = await promptText(
      context,
      title: 'Rename course',
      label: 'Course title',
      initial: course.title,
    );
    if (title != null) {
      await state.renameCourse(course.id, title);
    }
  }

  Future<void> _delete(BuildContext context, Course course) async {
    final state = AppScope.read(context);
    final ok = await confirmDialog(
      context,
      title: 'Delete course',
      message: 'Delete "${course.title}" and all of its lessons from this phone?',
    );
    if (ok) {
      await state.deleteCourse(course.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = AppScope.of(context).courses;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Image.asset('assets/icon/app_icon.png', height: 40),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Kainuwa Studio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: KColors.accent,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Import project',
                  onPressed: () => _import(context),
                  icon: const Icon(Icons.file_download_outlined, color: KColors.accent),
                ),
                IconButton(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings, color: KColors.accent),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: KColors.gold,
                      foregroundColor: KColors.onGold,
                    ),
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Course'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onOpenTemplates,
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: const Text('Templates'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'My Courses (${courses.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: courses.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No courses yet. Tap Create Course to start your first one.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                          leading: const CourseCover(),
                          title: Text(
                            course.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${lessonCountText(course.lessons.length)} - ${minutesText(course.totalMs)}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LessonsScreen(courseId: course.id),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'rename') _rename(context, course);
                              if (value == 'export') _export(context, course);
                              if (value == 'delete') _delete(context, course);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('Rename')),
                              PopupMenuItem(value: 'export', child: Text('Export (.kainuwa)')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
