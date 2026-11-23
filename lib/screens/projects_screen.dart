import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'create_project.dart';
import 'lesson_editor_screen.dart';
import 'lessons_screen.dart';
import 'project_export.dart';

enum _Sort { newest, oldest, nameAz, nameZa, longest }

enum _When { any, today, week, month }

const List<String> _tabKeys = ['all', 'video', 'music', 'lyrics', 'course'];
const List<String> _tabNames = ['All', 'Videos', 'Music', 'Lyrics', 'Courses'];
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// video, music, lyrics or course.
String projectCategory(Course c) {
  if (!c.isVideo) return 'course';
  if (c.lessons.isNotEmpty) {
    final kind = c.lessons.first.setupKind;
    if (kind == 'music') return 'music';
    if (kind == 'lyrics') return 'lyrics';
  }
  return 'video';
}

String _dateText(int ms) {
  if (ms <= 0) return 'No date';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// The full list of projects: tabs, search, sort, date filter and multi-select delete.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  _Sort _sort = _Sort.newest;
  _When _when = _When.any;
  final Set<String> _picked = <String>{};

  bool get _selecting => _picked.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabKeys.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  List<Course> _base(List<Course> all) {
    final q = _query.trim().toLowerCase();
    final now = DateTime.now();
    int? since;
    if (_when == _When.today) {
      since = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    } else if (_when == _When.week) {
      since = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    } else if (_when == _When.month) {
      since = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    }
    return all.where((c) {
      if (q.isNotEmpty && !c.title.toLowerCase().contains(q)) return false;
      if (since != null && c.createdAt < since) return false;
      return true;
    }).toList();
  }

  void _sortList(List<Course> list) {
    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _Sort.nameAz:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _Sort.nameZa:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case _Sort.longest:
        list.sort((a, b) => b.totalMs.compareTo(a.totalMs));
    }
  }

  String _sortName(_Sort s) {
    switch (s) {
      case _Sort.newest:
        return 'Newest first';
      case _Sort.oldest:
        return 'Oldest first';
      case _Sort.nameAz:
        return 'Name A to Z';
      case _Sort.nameZa:
        return 'Name Z to A';
      case _Sort.longest:
        return 'Longest first';
    }
  }

  String _whenName(_When w) {
    switch (w) {
      case _When.any:
        return 'Any time';
      case _When.today:
        return 'Today';
      case _When.week:
        return '7 days';
      case _When.month:
        return '30 days';
    }
  }

  void _open(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => course.isVideo && course.lessons.isNotEmpty
            ? LessonEditorScreen(courseId: course.id, lessonId: course.lessons.first.id)
            : LessonsScreen(courseId: course.id),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (!_picked.remove(id)) _picked.add(id);
    });
  }

  Future<void> _rename(Course course) async {
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

  Future<void> _deleteOne(Course course) async {
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

  Future<void> _deleteSelected() async {
    final state = AppScope.read(context);
    final count = _picked.length;
    final ok = await confirmDialog(
      context,
      title: count == 1 ? 'Delete 1 project' : 'Delete $count projects',
      message: count == 1
          ? 'Delete the selected project from this phone?'
          : 'Delete the $count selected projects from this phone? This cannot be undone.',
    );
    if (!ok || !mounted) return;
    final ids = Set<String>.of(_picked);
    setState(_picked.clear);
    await state.deleteCourses(ids);
  }

  Widget _card(Course course) {
    final category = projectCategory(course);
    final picked = _picked.contains(course.id);
    final IconData icon;
    final String label;
    switch (category) {
      case 'music':
        icon = Icons.album_outlined;
        label = 'Music video';
      case 'lyrics':
        icon = Icons.lyrics_outlined;
        label = 'Lyrics video';
      case 'course':
        icon = Icons.school_outlined;
        label = 'Course';
      default:
        icon = Icons.videocam_outlined;
        label = 'Video';
    }
    final meta = course.isVideo
        ? formatClock(course.totalMs)
        : '${lessonCountText(course.lessons.length)} - ${minutesText(course.totalMs)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _selecting ? _toggle(course.id) : _open(course),
        onLongPress: () {
          FocusScope.of(context).unfocus();
          _toggle(course.id);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          decoration: BoxDecoration(
            color: picked ? const Color(0xFF2A2250) : const Color(0xFF1E1938),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: picked ? KColors.gold : Colors.transparent,
              width: 2,
            ),
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
                        Icon(icon, size: 14, color: const Color(0xFFB5ABD6)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$label  -  $meta',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateText(course.createdAt),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF8E85B5)),
                    ),
                  ],
                ),
              ),
              if (_selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    picked ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: picked ? KColors.gold : Colors.white54,
                  ),
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (value) {
                    if (value == 'rename') _rename(course);
                    if (value == 'duplicate') AppScope.read(context).duplicateCourse(course.id);
                    if (value == 'export') exportProjectFile(context, course);
                    if (value == 'delete') _deleteOne(course);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(value: 'export', child: Text('Export (.kainuwa)')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(int total, List<Course> shown) {
    if (_selecting) {
      final allPicked = shown.isNotEmpty && shown.every((c) => _picked.contains(c.id));
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel selection',
          onPressed: () => setState(_picked.clear),
        ),
        title: Text('${_picked.length} selected'),
        actions: [
          IconButton(
            icon: Icon(allPicked ? Icons.deselect : Icons.select_all),
            tooltip: allPicked ? 'Clear selection' : 'Select all shown',
            onPressed: () => setState(() {
              if (allPicked) {
                _picked.clear();
              } else {
                _picked.addAll(shown.map((c) => c.id));
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete selected',
            onPressed: _deleteSelected,
          ),
        ],
      );
    }
    return AppBar(title: Text('All projects  ($total)'));
  }

  @override
  Widget build(BuildContext context) {
    final all = AppScope.of(context).courses;
    _picked.removeWhere((id) => !all.any((c) => c.id == id));

    final base = _base(all);
    final counts = <String, int>{for (final key in _tabKeys) key: 0};
    counts['all'] = base.length;
    for (final c in base) {
      final key = projectCategory(c);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final tabKey = _tabKeys[_tabs.index];
    final shown = tabKey == 'all'
        ? List<Course>.of(base)
        : base.where((c) => projectCategory(c) == tabKey).toList();
    _sortList(shown);

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(_picked.clear);
      },
      child: Scaffold(
        appBar: _appBar(all.length, shown),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton(
                heroTag: 'all_projects_create_fab',
                backgroundColor: KColors.gold,
                foregroundColor: KColors.onGold,
                tooltip: 'New project',
                onPressed: () => createProject(context),
                child: const Icon(Icons.add, size: 32),
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search by title',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: const Color(0xFF1E1938),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<_Sort>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => [
                      for (final s in _Sort.values)
                        PopupMenuItem<_Sort>(value: s, child: Text(_sortName(s))),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFFB5ABD6),
              indicatorColor: KColors.gold,
              onTap: (_) => setState(() {}),
              tabs: [
                for (var i = 0; i < _tabKeys.length; i++)
                  Tab(text: '${_tabNames[i]} (${counts[_tabKeys[i]] ?? 0})'),
              ],
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final w in _When.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_whenName(w)),
                        selected: _when == w,
                        onSelected: (_) => setState(() => _when = w),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          all.isEmpty
                              ? 'Nothing here yet.'
                              : 'No project matches. Try another search, tab or date.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB5ABD6)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: shown.length,
                      itemBuilder: (_, index) => _card(shown[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
