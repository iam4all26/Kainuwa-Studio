import 'package:flutter/material.dart';

import '../app_state.dart';
import '../lyrics_project.dart';
import '../music_project.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lesson_editor_screen.dart';
import 'lessons_screen.dart';
import 'lyrics_setup_screen.dart';
import 'music_setup_screen.dart';
import 'video_setup_dialog.dart';

/// The "Create video" sheet and everything it starts. Used by the Projects tab and by the
/// All projects page.
Widget _choiceTile(BuildContext context, IconData icon, String title, String subtitle, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).pop(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KColors.lavender,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: KColors.selected,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFFB5ABD6))),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


Future<void> createProject(BuildContext context) async {
  final state = AppScope.read(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create video', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            _choiceTile(sheetContext, Icons.movie_creation_outlined, 'Video',
                'Open the canvas and start right away', 'video'),
            _choiceTile(sheetContext, Icons.album_outlined, 'Music video',
                'Cover art, a turning record and an audio picture', 'music'),
            _choiceTile(sheetContext, Icons.lyrics_outlined, 'Lyrics video',
                'Words glowing in time with the song', 'lyrics'),
            _choiceTile(sheetContext, Icons.school_outlined, 'Course',
                'A set of lessons, each one a video', 'course'),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'lyrics') {
    final lyrics = await Navigator.of(context).push<LyricsSetup>(
      MaterialPageRoute<LyricsSetup>(builder: (_) => const LyricsSetupScreen()),
    );
    if (lyrics == null || !context.mounted) return;
    final title = lyrics.title.trim().isEmpty ? 'Lyrics video' : lyrics.title.trim();
    final ids = await state.addVideo(title: title, aspectW: lyrics.aspectW, aspectH: lyrics.aspectH);
    final lesson = state.lessonById(ids.$1, ids.$2);
    if (lesson != null) {
      buildLyricsProject(lesson, lyrics);
      await state.saveNow();
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonEditorScreen(courseId: ids.$1, lessonId: ids.$2),
      ),
    );
    return;
  }
  if (choice == 'music') {
    final music = await Navigator.of(context).push<MusicSetup>(
      MaterialPageRoute<MusicSetup>(builder: (_) => const MusicSetupScreen()),
    );
    if (music == null || !context.mounted) return;
    final title = music.title.trim().isEmpty ? 'Music video' : music.title.trim();
    final ids = await state.addVideo(title: title, aspectW: music.aspectW, aspectH: music.aspectH);
    final lesson = state.lessonById(ids.$1, ids.$2);
    if (lesson != null) {
      buildMusicProject(lesson, music);
      await state.saveNow();
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonEditorScreen(courseId: ids.$1, lessonId: ids.$2),
      ),
    );
    return;
  }
  if (choice == 'video') {
    final setup = await showVideoSetup(context);
    if (setup == null || !context.mounted) return;
    final ids = await state.addVideo(title: setup.name, aspectW: setup.aspectW, aspectH: setup.aspectH);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonEditorScreen(courseId: ids.$1, lessonId: ids.$2),
      ),
    );
    return;
  }
  final title = await promptText(
    context,
    title: 'New course',
    label: 'Course title',
    confirm: 'Create',
  );
  if (title == null || !context.mounted) return;
  final id = await state.addCourse(title);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LessonsScreen(courseId: id)),
  );
}

