import 'dart:convert';

import '../models.dart';
import '../scene_canvas.dart';
import '../stage_shape.dart';
import 'ai_client.dart';
import 'ai_config.dart';

class PlanSlide {
  PlanSlide({
    this.heading = '',
    List<String>? points,
    this.narration = '',
    this.seconds = 8,
  }) : points = points ?? <String>[];

  String heading;
  List<String> points;
  String narration;
  int seconds;
}

class LessonPlan {
  LessonPlan({this.title = '', List<PlanSlide>? slides}) : slides = slides ?? <PlanSlide>[];

  String title;
  final List<PlanSlide> slides;

  String get narrationScript {
    final b = StringBuffer();
    for (var i = 0; i < slides.length; i++) {
      final n = slides[i].narration.trim();
      if (n.isEmpty) continue;
      b.writeln('Slide ${i + 1}');
      b.writeln(n);
      b.writeln();
    }
    return b.toString().trim();
  }
}

const List<String> kPlanLanguages = ['Same as the lesson', 'English', 'Hausa'];
const List<(String, int)> kPlanLengths = [('Short', 6), ('Medium', 10), ('Long', 16)];

String _systemPrompt() => '''
You turn a lesson into a slide plan for a short teaching video.
Reply with one JSON object only. No markdown, no code fences, no comments.
Schema:
{"title": string, "slides": [{"heading": string, "points": [string], "narration": string, "seconds": number}]}
Rules:
- The first slide is the title slide: heading is the video title, points has one short subtitle.
- The last slide is a short recap.
- heading: at most 8 words.
- points: 0 to 5 items, each at most 10 words, no bullet symbols, no numbering.
- narration: the words the teacher says over this slide, natural and spoken, matching the lesson.
- seconds: between 4 and 20, about 2.5 spoken words per second of narration.
- Keep every fact, name, number and step from the lesson correct. Never invent facts.
- Write all text in the requested language.
''';

String _userPrompt(String lesson, String language, int slides) {
  final lang = language == 'Same as the lesson'
      ? 'the same language as the lesson'
      : language;
  return 'Language: $lang\nTarget number of slides: about $slides\n\nLESSON:\n$lesson';
}

Future<LessonPlan> generatePlan(
  AiConfig config, {
  required String lesson,
  required String language,
  required int slides,
}) async {
  final raw = await AiClient.complete(
    config,
    system: _systemPrompt(),
    user: _userPrompt(lesson, language, slides),
  );
  return parsePlan(raw);
}

LessonPlan parsePlan(String raw) {
  var text = raw.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw AiException('The AI did not return slides. Try again.');
  }
  text = text.substring(start, end + 1);
  dynamic data;
  try {
    data = jsonDecode(text);
  } catch (_) {
    throw AiException('The AI answer was cut off or broken. Try a shorter lesson or a larger model.');
  }
  if (data is! Map || data['slides'] is! List) {
    throw AiException('The AI did not return slides. Try again.');
  }
  final plan = LessonPlan(title: (data['title'] ?? '').toString().trim());
  for (final item in data['slides'] as List) {
    if (item is! Map) continue;
    final points = <String>[];
    final rawPoints = item['points'];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        final s = p.toString().trim();
        if (s.isNotEmpty) points.add(s);
      }
    }
    var seconds = 8;
    final sec = item['seconds'];
    if (sec is num) seconds = sec.round();
    plan.slides.add(PlanSlide(
      heading: (item['heading'] ?? '').toString().trim(),
      points: points.take(6).toList(),
      narration: (item['narration'] ?? '').toString().trim(),
      seconds: seconds.clamp(3, 30).toInt(),
    ));
  }
  if (plan.slides.isEmpty) {
    throw AiException('The AI returned no slides. Try again.');
  }
  if (plan.title.isEmpty) plan.title = plan.slides.first.heading;
  return plan;
}

const int _kBackground = 0xFF120B2E;
const int _kGold = 0xFFF6C101;
const int _kWhite = 0xFFFFFFFF;

/// Fills the lesson with one slide per plan slide. Items appear one after
/// another so the viewer can follow the teacher.
void buildScenes(Lesson lesson, LessonPlan plan) {
  Stage.use(lesson.aspectW, lesson.aspectH);
  final f = (Stage.w / 1280.0).clamp(0.8, 1.0).toDouble();
  lesson.scenes.clear();

  Layer textLayer(String text, double px, int color, bool bold, double cy, {double maxW = 0.88}) {
    final layer = Layer(
      id: newId(),
      type: 'text',
      text: text,
      color: color,
      bold: bold,
      cx: 0.5,
      cy: cy,
    );
    var size = px;
    setLayerTextSizePx(layer, size);
    while (layer.w > maxW && size > 26) {
      size -= 4;
      setLayerTextSizePx(layer, size);
    }
    layer.cx = 0.5;
    layer.cy = cy;
    return layer;
  }

  for (var i = 0; i < plan.slides.length; i++) {
    final slide = plan.slides[i];
    final durationMs = (slide.seconds * 1000).clamp(3000, 30000).toInt();
    final scene = Scene(
      id: newId(),
      durationMs: durationMs,
      bgType: 'color',
      bgValue: _kBackground.toString(),
      transKind: i == 0 ? 'none' : 'fade',
      transMs: 600,
    );
    if (i == 0) {
      final title = textLayer(slide.heading, 104 * f, _kWhite, true, 0.42);
      title.animIn = 'pop';
      title.animDurationMs = 700;
      scene.layers.add(title);
      if (slide.points.isNotEmpty) {
        final sub = textLayer(slide.points.first, 52 * f, _kGold, false, 0.6);
        sub.animIn = 'fade';
        sub.animDurationMs = 700;
        sub.startMs = 700;
        scene.layers.add(sub);
      }
    } else {
      final heading = textLayer(slide.heading, 64 * f, _kGold, true, 0.15);
      heading.animIn = 'fade';
      heading.animDurationMs = 500;
      scene.layers.add(heading);
      final n = slide.points.length;
      if (n > 0) {
        final step = (0.58 / n).clamp(0.08, 0.15).toDouble();
        final top = 0.3 + (0.58 - step * n) / 2;
        final span = (durationMs - 1800).clamp(600, 60000).toInt();
        for (var p = 0; p < n; p++) {
          final layer = textLayer(slide.points[p], 48 * f, _kWhite, false, top + step * (p + 0.5));
          layer.animIn = 'fade';
          layer.animDurationMs = 500;
          layer.startMs = 700 + (span * p ~/ n);
          scene.layers.add(layer);
        }
      }
    }
    lesson.scenes.add(scene);
  }
  Stage.reset();
}
