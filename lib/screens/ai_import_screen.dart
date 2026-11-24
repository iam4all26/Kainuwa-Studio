import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai/ai_catalog.dart';
import '../ai/ai_client.dart';
import '../ai/ai_config.dart';
import '../ai/lesson_plan.dart';
import '../ai/lesson_voice.dart';
import '../media/media_library.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';
import '../app_state.dart';
import '../theme.dart';
import 'ai_settings_screen.dart';
import 'lesson_editor_screen.dart';

const int _kMaxChars = 40000;

class AiImportScreen extends StatefulWidget {
  const AiImportScreen({super.key});

  @override
  State<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends State<AiImportScreen> {
  final TextEditingController _lesson = TextEditingController();
  final TextEditingController _name = TextEditingController();
  AiConfig? _config;
  int _language = 0;
  int _length = 1;
  int _shape = 0;
  bool _busy = false;
  String _busyMsg = '';
  int _voice = 0;
  String _voicePath = '';
  int _voiceMs = 0;
  String _error = '';
  LessonPlan? _plan;
  AiCatalog? _catalog;
  List<TextEditingController> _headings = [];
  List<TextEditingController> _points = [];

  static const List<(String, int, int)> _shapes = [
    ('16:9', 16, 9),
    ('9:16', 9, 16),
    ('1:1', 1, 1),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _lesson.dispose();
    _name.dispose();
    for (final c in _headings) {
      c.dispose();
    }
    for (final c in _points) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final c = await AiConfig.load();
    if (mounted) setState(() => _config = c);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()));
    await _loadConfig();
  }

  Future<void> _generate() async {
    final c = _config;
    final text = _lesson.text.trim();
    if (c == null || !c.ready || text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final catalog = _catalog ??= await AiCatalog.load();
      final plan = await generatePlan(
        c,
        lesson: text.length > _kMaxChars ? text.substring(0, _kMaxChars) : text,
        language: kPlanLanguages[_language],
        slides: kPlanLengths[_length].$2,
        catalog: catalog,
      );
      if (!mounted) return;
      _setPlan(plan);
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyPrompt() async {
    // With no lesson pasted yet, the prompt is copied with a marker the person replaces in the AI app.
    final typed = _lesson.text.trim();
    final blank = typed.isEmpty;
    final text = blank ? '[PASTE YOUR LESSON HERE]' : typed;
    final catalog = _catalog ??= await AiCatalog.load();
    final prompt = buildExternalPrompt(
      lesson: text.length > _kMaxChars ? text.substring(0, _kMaxChars) : text,
      language: kPlanLanguages[_language],
      slides: kPlanLengths[_length].$2,
      catalog: catalog,
    );
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    setState(() => _error = '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(blank
            ? 'Prompt copied. In your AI app, replace [PASTE YOUR LESSON HERE] with your lesson, then come back and paste the answer.'
            : 'Prompt copied. Paste it in your AI app, then come back and paste the answer.'),
      ),
    );
  }

  Future<void> _pasteAnswer() async {
    final catalog = _catalog ??= await AiCatalog.load();
    if (!mounted) return;
    final controller = TextEditingController();
    var message = '';
    final plan = await showDialog<LessonPlan>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          scrollable: true,
          title: const Text("Paste the AI's answer"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste here'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) controller.text = data!.text!;
                  },
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste from clipboard'),
                ),
                if (message.isNotEmpty)
                  Text(message, style: const TextStyle(color: Color(0xFFFF8A80))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                try {
                  Navigator.of(c).pop(parsePlan(controller.text, catalog));
                } on AiException catch (e) {
                  setD(() => message = e.message);
                }
              },
              child: const Text('Read answer'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (plan == null || !mounted) return;
    _setPlan(plan);
  }

  Future<void> _chooseVoiceFile() async {
    String? path;
    try {
      path = await pickMedia(context, MediaKind.audio);
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;
    var ms = 0;
    try {
      ms = await KainuwaEncoder.audioDuration(path);
    } catch (_) {
      ms = 0;
    }
    if (!mounted) return;
    if (ms <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That sound file could not be read.')));
      return;
    }
    setState(() {
      _voicePath = path!;
      _voiceMs = ms;
    });
  }

  void _setPlan(LessonPlan plan) {
    for (final c in _headings) {
      c.dispose();
    }
    for (final c in _points) {
      c.dispose();
    }
    _headings = [for (final s in plan.slides) TextEditingController(text: s.heading)];
    _points = [for (final s in plan.slides) TextEditingController(text: s.points.join('\n'))];
    if (_name.text.trim().isEmpty) _name.text = plan.title;
    setState(() => _plan = plan);
  }

  void _removeSlide(int i) {
    final plan = _plan;
    if (plan == null || plan.slides.length <= 1) return;
    plan.slides.removeAt(i);
    _headings.removeAt(i).dispose();
    _points.removeAt(i).dispose();
    setState(() {});
  }

  void _applyEdits() {
    final plan = _plan!;
    for (var i = 0; i < plan.slides.length; i++) {
      plan.slides[i].heading = _headings[i].text.trim();
      plan.slides[i].points = _points[i]
          .text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  Future<void> _create() async {
    final plan = _plan;
    if (plan == null) return;
    if (_voice == 2 && _voicePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose your voice-over file first.')));
      return;
    }
    _applyEdits();
    final state = AppScope.read(context);
    final shape = _shapes[_shape];
    final title = _name.text.trim().isEmpty ? plan.title : _name.text.trim();
    final ids = await state.addVideo(title: title, aspectW: shape.$2, aspectH: shape.$3);
    final lesson = state.lessonById(ids.$1, ids.$2);
    if (lesson != null) {
      await buildScenes(lesson, plan, _catalog ?? await AiCatalog.load());
      if (_voice == 1) {
        setState(() {
          _busy = true;
          _busyMsg = 'Making voices...';
        });
        final failed = await applyTtsVoices(
          lesson,
          plan,
          lang: const ['', 'en', 'ha'][_language],
          onProgress: (d, t) {
            if (mounted) setState(() => _busyMsg = 'Making voice $d of $t');
          },
        );
        if (mounted) {
          setState(() => _busy = false);
          if (failed > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$failed slide(s) got no voice. The phone voice may not support this language.')),
            );
          }
        }
      } else if (_voice == 2) {
        applyOwnVoice(lesson, plan, _voicePath, _voiceMs);
      }
      await state.saveNow();
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => LessonEditorScreen(courseId: ids.$1, lessonId: ids.$2)),
    );
  }

  Widget _chips(List<String> labels, int value, ValueChanged<int> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: value == i ? KColors.selected : const Color(0xFF2A2250),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(labels[i], style: TextStyle(fontWeight: value == i ? FontWeight.w500 : FontWeight.w400)),
            ),
          ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFFB5ABD6))),
      );

  Widget _inputStep() {
    final c = _config;
    final needsKey = c != null && !c.ready;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (needsKey)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFF1E1938), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.key_outlined),
                const SizedBox(width: 12),
                const Expanded(child: Text('Add your AI key to start.')),
                FilledButton(onPressed: _openSettings, child: const Text('Set up')),
              ],
            ),
          ),
        TextField(
          controller: _lesson,
          minLines: 10,
          maxLines: 14,
          maxLength: _kMaxChars,
          decoration: const InputDecoration(hintText: 'Paste your lesson here'),
        ),
        _label('Language'),
        _chips(kPlanLanguages, _language, (i) => setState(() => _language = i)),
        _label('Length'),
        _chips([for (final l in kPlanLengths) '${l.$1}  ${l.$2}'], _length, (i) => setState(() => _length = i)),
        _label('Video shape'),
        _chips([for (final s in _shapes) s.$1], _shape, (i) => setState(() => _shape = i)),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error, style: const TextStyle(color: Color(0xFFFF8A80))),
          ),
        const SizedBox(height: 20),
        const SizedBox(height: 28),
        const Divider(),
        _label('No AI key? Use any AI you like (ChatGPT, Claude, Gemini...)'),
        const Text(
          '1. Copy the prompt.  2. Paste it in your AI app.  3. Copy the answer and paste it here.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _copyPrompt,
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy prompt for AI'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pasteAnswer,
          icon: const Icon(Icons.content_paste),
          label: const Text("Paste the AI's answer"),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: (_busy || needsKey || c == null) ? null : _generate,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_busy ? 'Working, this can take a minute' : 'Create slides'),
        ),
      ],
    );
  }

  Widget _slideCard(int i) {
    final slide = _plan!.slides[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1938), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: KColors.selected.withValues(alpha: 0.3),
                child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _headings[i],
                  decoration: const InputDecoration(hintText: 'Heading', isDense: true),
                ),
              ),
              IconButton(
                tooltip: 'Remove slide',
                onPressed: _plan!.slides.length > 1 ? () => _removeSlide(i) : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final l in kLayouts)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(l.replaceAll('_', ' ')),
                      selected: slide.layout == l,
                      onSelected: (_) => setState(() => slide.layout = l),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _points[i],
            minLines: 1,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'One point per line', isDense: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18),
              const SizedBox(width: 6),
              Text('${slide.seconds} s', style: const TextStyle(fontSize: 13)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: slide.seconds > 3 ? () => setState(() => slide.seconds -= 1) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: slide.seconds < 30 ? () => setState(() => slide.seconds += 1) : null,
                icon: const Icon(Icons.add_circle_outline, size: 20),
              ),
            ],
          ),
          if (slide.narration.isNotEmpty)
            Text(slide.narration, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6))),
        ],
      ),
    );
  }

  Widget _voiceBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1938), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Voice', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _chips(const ['No voice', 'Phone voice', 'My voice-over'], _voice, (i) => setState(() => _voice = i)),
          if (_voice == 1)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'The phone reads each slide\'s narration (no internet needed) and the slide lasts as long as the voice.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6)),
              ),
            ),
          if (_voice == 2) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Tap Copy narration, read it into your recorder, then choose the file. The slides are timed to your '
                'recording by how many words each one has. You can fine tune the times in the editor.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _chooseVoiceFile,
              icon: const Icon(Icons.audiotrack_outlined),
              label: Text(_voicePath.isEmpty
                  ? 'Choose my voice-over file'
                  : '${_voicePath.split('/').last}  (${(_voiceMs / 1000).toStringAsFixed(0)} s)'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewStep() {
    final plan = _plan!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Video name'),
              ),
              if (_catalog != null && themeSummary(plan, _catalog!).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Design chosen by AI: ${themeSummary(plan, _catalog!)}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFB5ABD6))),
                ),
              const SizedBox(height: 14),
              _voiceBox(),
              for (var i = 0; i < plan.slides.length; i++) _slideCard(i),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      _applyEdits();
                      await Clipboard.setData(ClipboardData(text: plan.narrationScript));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Narration copied.')));
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy narration'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _create,
                    child: Text(_busy ? _busyMsg : 'Create video'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final review = _plan != null;
    return PopScope(
      canPop: !review,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && review) setState(() => _plan = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(review ? 'Review slides' : 'Create with AI'),
          actions: [
            if (!review)
              IconButton(tooltip: 'AI settings', onPressed: _openSettings, icon: const Icon(Icons.tune)),
          ],
        ),
        body: review ? _reviewStep() : _inputStep(),
      ),
    );
  }
}
