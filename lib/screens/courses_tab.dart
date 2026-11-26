import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../app_state.dart';
import '../models.dart';
import '../project_package.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lesson_editor_screen.dart';
import 'ai_import_screen.dart';
import 'lessons_screen.dart';
import 'create_project.dart';
import 'project_export.dart';
import 'projects_screen.dart';

class CoursesTab extends StatelessWidget {
  const CoursesTab({
    super.key,
    required this.onOpenSettings,
    required this.onOpenTemplates,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenTemplates;

  /// How many projects the home tab shows before "See all".
  static const int _homeLimit = 5;

  void _openAll(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
    );
  }

  Future<void> _create(BuildContext context) => createProject(context);

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

  Future<void> _export(BuildContext context, Course course) => exportProjectFile(context, course);

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
      title: course.isVideo ? 'Rename video' : 'Rename course',
      label: course.isVideo ? 'Video title' : 'Course title',
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
      title: course.isVideo ? 'Delete video' : 'Delete course',
      message: course.isVideo
          ? 'Delete "${course.title}" from this phone?'
          : 'Delete "${course.title}" and all of its lessons from this phone?',
    );
    if (ok) {
      await state.deleteCourse(course.id);
    }
  }

  Widget _roundButton(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF241D45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _quickCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1938),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: KColors.selected.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFFB5ABD6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectCard(BuildContext context, Course course) {
    final meta = course.isVideo
        ? formatClock(course.totalMs)
        : '${lessonCountText(course.lessons.length)} - ${minutesText(course.totalMs)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => course.isVideo && course.lessons.isNotEmpty
                ? LessonEditorScreen(courseId: course.id, lessonId: course.lessons.first.id)
                : LessonsScreen(courseId: course.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1938),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              course.isVideo ? const VideoCover(size: 60) : const CourseCover(size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(course.isVideo ? Icons.videocam_outlined : Icons.school_outlined,
                            size: 14, color: const Color(0xFFB5ABD6)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${course.isVideo ? 'Video' : 'Course'}  -  $meta',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onSelected: (value) {
                  if (value == 'rename') _rename(context, course);
                  if (value == 'duplicate') AppScope.read(context).duplicateCourse(course.id);
                  if (value == 'export') _export(context, course);
                  if (value == 'ai') openAiPlan(context, course);
                  if (value == 'delete') _delete(context, course);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'export', child: Text('Export (.kainuwa)')),
                  if (hasAiPlan(course)) const PopupMenuItem(value: 'ai', child: Text('Open in AI screen')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = AppScope.of(context).courses;

    return Stack(children: [
      Positioned.fill(child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/icon/app_icon.png', height: 44, width: 44),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kainuwa Studio', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
                    Text('Make videos, even offline',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6))),
                  ],
                ),
              ),
              _roundButton(Icons.settings_outlined, 'Settings', onOpenSettings),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: () => _create(context),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Create a new video',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Name it, then open the canvas and start.',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(color: KColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: KColors.onGold, size: 30),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _quickCard(Icons.dashboard_customize_outlined, 'Templates', 'Start from a design', onOpenTemplates),
              const SizedBox(width: 12),
              _quickCard(Icons.file_download_outlined, 'Import', 'Open a .kainuwa file', () => _import(context)),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AiImportScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1938),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: KColors.selected.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 21),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create with AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        SizedBox(height: 2),
                        Text('Paste a lesson, get slides', style: TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'My projects  (${courses.length})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              if (courses.length > _homeLimit)
                TextButton(
                  onPressed: () => _openAll(context),
                  child: Text('See all (${courses.length})'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.movie_creation_outlined, size: 54, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    'Nothing here yet.\nTap the purple card to make your first video.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFB5ABD6)),
                  ),
                ],
              ),
            )
          else
            for (final course in courses.take(_homeLimit)) _projectCard(context, course),
          if (courses.length > _homeLimit)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: OutlinedButton(
                onPressed: () => _openAll(context),
                child: Text('See all ${courses.length} projects'),
              ),
            ),
        ],
      ),
    )),
      Positioned(
        right: 18,
        bottom: 18,
        child: FloatingActionButton(
          heroTag: 'create_video_fab',
          backgroundColor: KColors.gold,
          foregroundColor: KColors.onGold,
          tooltip: 'Create video',
          onPressed: () => _create(context),
          child: const Icon(Icons.add, size: 32),
        ),
      ),
    ]);
  }
}
