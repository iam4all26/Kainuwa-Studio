import 'dart:convert';

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../models.dart';
import '../scene_canvas.dart';
import '../svg/svg_raster.dart';
import '../stage_shape.dart';
import 'ai_client.dart';
import 'ai_catalog.dart';
import 'ai_config.dart';

class PlanSlide {
  PlanSlide({
    this.heading = '',
    List<String>? points,
    this.narration = '',
    this.seconds = 8,
    this.layout = 'bullets',
    List<String>? icons,
    this.bg,
  })  : points = points ?? <String>[],
        icons = icons ?? <String>[];

  String layout;
  List<String> icons;

  /// Optional background id for this slide only.
  String? bg;
  String heading;
  List<String> points;
  String narration;
  int seconds;

  Map<String, dynamic> toJson() => {
        'layout': layout,
        'heading': heading,
        'points': points,
        'icons': icons,
        'bg': bg,
        'narration': narration,
        'seconds': seconds,
      };

  factory PlanSlide.fromJson(Map<String, dynamic> j) => PlanSlide(
        heading: (j['heading'] ?? '').toString(),
        points: [if (j['points'] is List) for (final e in j['points'] as List) e.toString()],
        narration: (j['narration'] ?? '').toString(),
        seconds: j['seconds'] is num ? (j['seconds'] as num).toInt() : 8,
        layout: (j['layout'] ?? 'bullets').toString(),
        icons: [if (j['icons'] is List) for (final e in j['icons'] as List) e.toString()],
        bg: j['bg'] is String ? j['bg'] as String : null,
      );
}

class LessonPlan {
  LessonPlan({this.title = '', List<PlanSlide>? slides}) : slides = slides ?? <PlanSlide>[];

  String title;
  String mood = '';

  /// The picture-list code the AI copied from the prompt. Empty when the answer carries none.
  String catalogCode = '';
  String? bg;
  int? bgColor;
  int? accent;
  int? ink;

  /// Font family for headings and for the other text. Empty means the app's default.
  String font = '';
  String bodyFont = '';
  final List<PlanSlide> slides;

  Map<String, dynamic> toJson() => {
        'title': title,
        'mood': mood,
        'catalog': catalogCode,
        'bg': bg,
        'bgColor': bgColor,
        'accent': accent,
        'ink': ink,
        'font': font,
        'bodyFont': bodyFont,
        'slides': [for (final s in slides) s.toJson()],
      };

  factory LessonPlan.fromJson(Map<String, dynamic> j) {
    final plan = LessonPlan(
      title: (j['title'] ?? '').toString(),
      slides: [
        if (j['slides'] is List)
          for (final e in j['slides'] as List)
            if (e is Map) PlanSlide.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
    plan.mood = (j['mood'] ?? '').toString();
    plan.catalogCode = (j['catalog'] ?? '').toString();
    plan.bg = j['bg'] is String ? j['bg'] as String : null;
    plan.bgColor = j['bgColor'] is num ? (j['bgColor'] as num).toInt() : null;
    plan.accent = j['accent'] is num ? (j['accent'] as num).toInt() : null;
    plan.ink = j['ink'] is num ? (j['ink'] as num).toInt() : null;
    plan.font = (j['font'] ?? '').toString();
    plan.bodyFont = (j['bodyFont'] ?? '').toString();
    return plan;
  }

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
const List<String> kLayouts = [
  'title',
  'bullets',
  'statement',
  'icon_grid',
  'steps',
  'two_column',
  'quote',
  'recap',
];

String _systemPrompt(AiCatalog cat) {
  final bgs = cat.bgs.map((b) => '${b.id}=${b.name} (${b.dark ? 'dark' : 'light'}${b.hint.isEmpty ? '' : ', ${b.hint}'})').join('; ');
  String picHint(String h) {
    final parts = h.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).take(3).toList();
    return parts.isEmpty ? '' : ' (${parts.join(', ')})';
  }

  final pics = cat.pics.map((p) => '${p.id}=${p.name}${picHint(p.item.hint)}').join('; ');
  final fonts = cat.fonts.map((f) => '${f.id}=${f.name} (${f.category})').join('; ');
  return '''
You are a video designer. You turn a lesson into a designed slide plan for a short teaching video.
Reply with one JSON object only. No markdown, no code fences, no comments.
Schema:
{"catalog": string, "title": string, "mood": string,
 "theme": {"bg": string, "accent": "#RRGGBB", "text": "#RRGGBB", "font": string or null, "bodyFont": string or null},
 "slides": [{"layout": string, "heading": string, "points": [string], "icons": [string], "bg": string or null, "narration": string, "seconds": number}]}
Design rules:
- First decide the mood of this lesson (for example calm, serious, playful, technical, spiritual, business) and pick a theme that fits the subject and the audience. Do not reuse one fixed look. Different lessons must look different.
- theme.bg is either a background id from the list below or a solid colour like "#0B3C5D". Prefer a solid colour or a plain background when the text is long. Use a picture background only when it really fits the topic.
- theme.accent is the highlight colour for headings. theme.text is the main text colour and must contrast strongly with the background.
- theme.font is the font for headings and theme.bodyFont the font for all other text. Each is an id from the Fonts list below, or null for the default font. Choose fonts that fit the mood and the audience (for example a clean modern font for technical lessons, a serif for serious or spiritual ones, a friendly rounded font for playful ones). Use at most two fonts. Never use a decorative or handwriting font for bodyFont, because it must stay easy to read. Every letter of the lesson language must be supported (Hausa needs the hooked letters), so when unsure use null.
- slide.bg is optional: null keeps the theme background, or give another background id or colour for one special slide, such as the title or recap.
- catalog: copy this exact text without change: ${cat.code}
- layout is one of: title, bullets, statement, icon_grid, steps, two_column, quote, recap.
  title: opening slide only (heading = video title, points = one short subtitle).
  bullets: a heading with 2 to 5 short points.
  statement: one big sentence in heading, optional one short point under it. Use for a key idea.
  icon_grid: 2 to 4 short points, each with its own icon in icons (same order). Use for sets of items or features.
  steps: 2 to 5 ordered steps. Use for procedures and how-to.
  two_column: 2 to 6 points split in two groups. Use for comparisons or pros and cons.
  quote: one sentence in points[0], who or what it is from in heading.
  recap: last slide, 2 to 5 key takeaways.
- Use a good mix of layouts. Never use the same layout more than twice in a row.
- icons: 0 to 4 ids from the picture list that match the meaning of the slide. Use [] when nothing fits. Never invent ids. The list has real app and company logos (for example WhatsApp, Google Play, Telegram, PayPal) and everyday icons (phone, calculator, camera, settings, clock). When the lesson names an app, brand or everyday device, use its own icon.
- heading: at most 8 words. points: each at most 10 words, no bullet symbols, no numbering.
- narration: the words the teacher says over the slide, natural and spoken, matching the lesson.
- seconds: between 4 and 20, about 2.5 spoken words per second of narration.
- Keep every fact, name, number and step from the lesson correct. Never invent facts.
- Write all text in the requested language.
Backgrounds: $bgs
Pictures: $pics
Fonts: $fonts
''';
}

String _userPrompt(String lesson, String language, int slides) {
  final lang = language == 'Same as the lesson'
      ? 'the same language as the lesson'
      : language;
  return 'Language: $lang\nTarget number of slides: about $slides\n\nLESSON:\n$lesson';
}

/// The whole instruction as one text, to paste into any AI app (ChatGPT, Claude, Gemini...).
/// The answer can be pasted back and read with [parsePlan].
String buildExternalPrompt({
  required String lesson,
  required String language,
  required int slides,
  required AiCatalog catalog,
}) {
  return 'Follow these instructions exactly. Your whole answer must be the JSON object and nothing else, '
      'because I will paste it into my video app.\n\n'
      '${_systemPrompt(catalog)}\n${_userPrompt(lesson, language, slides)}\n\n'
      'Now reply with the JSON object only.';
}

Future<LessonPlan> generatePlan(
  AiConfig config, {
  required String lesson,
  required String language,
  required int slides,
  required AiCatalog catalog,
}) async {
  final raw = await AiClient.complete(
    config,
    system: _systemPrompt(catalog),
    user: _userPrompt(lesson, language, slides),
    maxTokens: 8000,
  );
  return parsePlan(raw, catalog);
}

int? _hex(dynamic v) {
  if (v is! String) return null;
  var s = v.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  if (s.length != 6) return null;
  final n = int.tryParse(s, radix: 16);
  return n == null ? null : 0xFF000000 | n;
}

LessonPlan parsePlan(String raw, AiCatalog cat) {
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
    // Chat apps often paste JSON with markdown escapes such as \[ \] \_ \*.
    // Drop a backslash that is not a valid JSON escape and try once more.
    final cleaned = text.replaceAllMapped(
      RegExp(r'\\\\|\\([^"\\/bfnrtu])'),
      (m) => m.group(1) ?? m.group(0)!,
    );
    try {
      data = jsonDecode(cleaned);
    } catch (_) {
      throw AiException('The AI answer was cut off or broken. Try a shorter lesson or a larger model.');
    }
  }
  if (data is! Map || data['slides'] is! List) {
    throw AiException('The AI did not return slides. Try again.');
  }
  final plan = LessonPlan(title: (data['title'] ?? '').toString().trim());
  plan.mood = (data['mood'] ?? '').toString().trim();
  plan.catalogCode = (data['catalog'] ?? '').toString().trim();
  final theme = data['theme'];
  if (theme is Map) {
    final bg = (theme['bg'] ?? '').toString().trim();
    if (cat.bg(bg) != null) {
      plan.bg = bg;
    } else {
      plan.bgColor = _hex(bg);
    }
    plan.accent = _hex(theme['accent']);
    plan.ink = _hex(theme['text']);
    plan.font = cat.font(theme['font']?.toString())?.family ?? '';
    plan.bodyFont = cat.font(theme['bodyFont']?.toString())?.family ?? '';
  }
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
    final icons = <String>[];
    final rawIcons = item['icons'];
    if (rawIcons is List) {
      for (final p in rawIcons) {
        final s = p.toString().trim();
        if (cat.pic(s) != null) icons.add(s);
      }
    }
    var seconds = 8;
    final sec = item['seconds'];
    if (sec is num) seconds = sec.round();
    var layout = (item['layout'] ?? 'bullets').toString().trim();
    if (!kLayouts.contains(layout)) layout = 'bullets';
    final bgRaw = (item['bg'] ?? '').toString().trim();
    String? slideBg;
    if (cat.bg(bgRaw) != null) {
      slideBg = bgRaw;
    } else if (_hex(bgRaw) != null) {
      slideBg = bgRaw;
    }
    plan.slides.add(PlanSlide(
      heading: (item['heading'] ?? '').toString().trim(),
      points: points.take(6).toList(),
      narration: (item['narration'] ?? '').toString().trim(),
      seconds: seconds.clamp(3, 30).toInt(),
      layout: layout,
      icons: icons.take(4).toList(),
      bg: slideBg,
    ));
  }
  if (plan.slides.isEmpty) {
    throw AiException('The AI returned no slides. Try again.');
  }
  plan.slides.first.layout = 'title';
  if (plan.title.isEmpty) plan.title = plan.slides.first.heading;
  return plan;
}

/// Short text for the review screen, such as "Calm, picture background".
String themeSummary(LessonPlan plan, AiCatalog cat) {
  final parts = <String>[];
  if (plan.mood.isNotEmpty) parts.add(plan.mood);
  final b = cat.bg(plan.bg);
  final hf = cat.fonts.where((f) => f.family == plan.font).toList();
  if (hf.isNotEmpty) parts.add('${hf.first.name} font');
  if (b != null) {
    parts.add(b.name);
  } else if (plan.bgColor != null) {
    parts.add('solid colour');
  }
  return parts.join(', ');
}

const int _kWhite = 0xFFFFFFFF;
const int _kNearBlack = 0xFF111111;
const int _kFallbackBg = 0xFF1F2933;

double _lumOf(int c) => ui.Color(c).computeLuminance();

double _contrast(double a, double b) {
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

int _bestOn(double lum) =>
    _contrast(lum, 1.0) >= _contrast(lum, 0.0) ? _kWhite : _kNearBlack;

/// What one slide looks like: background, scrim, text and highlight colours.
class _Look {
  _Look({
    required this.bgType,
    required this.bgValue,
    required this.ink,
    required this.accent,
    required this.onAccent,
    this.scrim,
  });
  final String bgType;
  final String bgValue;
  final int ink;
  final int accent;
  final int onAccent;
  final int? scrim;
}

_Look _lookFor(LessonPlan plan, PlanSlide slide, AiCatalog cat) {
  final id = slide.bg ?? plan.bg;
  AiBg? pic = cat.bg(id);
  int? solid;
  if (pic == null) {
    solid = _hex(slide.bg) ?? plan.bgColor ?? _kFallbackBg;
  }
  late String bgType;
  late String bgValue;
  late double lum;
  late int ink;
  int? scrim;
  if (pic != null) {
    bgType = pic.item.isFile ? 'file' : 'asset';
    bgValue = pic.item.path;
    if (pic.lum < 0.5) {
      ink = _kWhite;
      scrim = 0xFF000000;
      lum = pic.lum * 0.5;
    } else {
      ink = _kNearBlack;
      scrim = _kWhite;
      lum = pic.lum * 0.45 + 0.55;
    }
  } else {
    bgType = 'color';
    bgValue = solid!.toString();
    lum = _lumOf(solid);
    ink = _bestOn(lum);
    final wanted = plan.ink;
    if (wanted != null && _contrast(lum, _lumOf(wanted)) >= 4.5) ink = wanted;
  }
  var accent = plan.accent ?? ink;
  if (_contrast(lum, _lumOf(accent)) < 3.0) accent = ink;
  return _Look(
    bgType: bgType,
    bgValue: bgValue,
    ink: ink,
    accent: accent,
    onAccent: _bestOn(_lumOf(accent)),
    scrim: scrim,
  );
}

/// Fills the lesson with one designed slide per plan slide. The AI chose the
/// theme, layout and pictures; the geometry here is fixed so nothing overlaps.
Future<void> buildScenes(Lesson lesson, LessonPlan plan, AiCatalog cat) async {
  final aspects = <String, double>{};
  // Store icons are SVG files: draw each once into a PNG and use that picture.
  final rasters = <String, SvgRaster>{};
  for (final s in plan.slides) {
    for (final id in s.icons) {
      if (aspects.containsKey(id)) continue;
      final p = cat.pic(id);
      if (p == null) continue;
      if (p.item.path.toLowerCase().endsWith('.svg')) {
        final r = p.item.isFile
            ? await rasterizeSvg(p.item.path, longSide: 512)
            : await rasterizeSvgAsset(p.item.path, longSide: 512);
        if (r != null) {
          rasters[id] = r;
          aspects[id] = r.aspect;
        }
      } else {
        aspects[id] = await AiCatalog.aspectOf(p.item);
      }
    }
  }
  var tintColor = 0xFFFFFFFF;

  Stage.use(lesson.aspectW, lesson.aspectH);
  try {
    final W = Stage.w;
    final H = Stage.h;
    final f = (W / 1280.0).clamp(0.8, 1.0).toDouble();
    final portrait = H > W;
    lesson.scenes.clear();

    Layer text(
      String t,
      double px,
      int color, {
      bool bold = false,
      bool italic = false,
      double cx = 0.5,
      double cy = 0.5,
      double maxW = 0.88,
      double maxH = 1.0,
      double? left,
      bool head = false,
    }) {
      final l = Layer(
        id: newId(),
        type: 'text',
        text: t,
        color: color,
        bold: bold,
        italic: italic,
      );
      l.fontFamily = head ? plan.font : plan.bodyFont;
      var size = px;
      setLayerTextSizePx(l, size);
      while (l.w > maxW && size > px * 0.72) {
        size -= 4;
        setLayerTextSizePx(l, size);
      }
      if (l.w > maxW && t.contains(' ')) {
        final mid = t.length ~/ 2;
        var cut = -1;
        for (var d = 0; d < t.length; d++) {
          if (mid - d >= 0 && t[mid - d] == ' ') {
            cut = mid - d;
            break;
          }
          if (mid + d < t.length && t[mid + d] == ' ') {
            cut = mid + d;
            break;
          }
        }
        if (cut > 0) {
          l.text = '${t.substring(0, cut)}\n${t.substring(cut + 1)}';
          size = px * 0.8;
          setLayerTextSizePx(l, size);
        }
      }
      while ((l.w > maxW || l.h > maxH) && size > 22) {
        size -= 4;
        setLayerTextSizePx(l, size);
      }
      l.cy = cy;
      if (left != null) {
        l.align = 'left';
        l.cx = left + l.w / 2;
      } else {
        l.cx = cx;
      }
      return l;
    }

    Layer shape(String kind, int color, double cx, double cy, double wPx, double hPx,
        {double opacity = 1.0}) {
      return Layer(
        id: newId(),
        type: 'shape',
        shape: kind,
        color: color,
        cx: cx,
        cy: cy,
        w: wPx / W,
        h: hPx / H,
        opacity: opacity,
      );
    }

    Layer? picture(String id, double cx, double cy, double boxPx) {
      final p = cat.pic(id);
      if (p == null) return null;
      final a = aspects[id] ?? 1.0;
      final wPx = a >= 1 ? boxPx : boxPx * a;
      final hPx = a >= 1 ? boxPx / a : boxPx;
      final raster = rasters[id];
      if (raster != null) {
        // Brand logos keep their own colour; the other SVG icons take the slide's accent colour.
        return Layer(
          id: newId(),
          type: 'image',
          shape: p.item.tint ? 'tint' : 'rect',
          color: tintColor,
          path: raster.path,
          cx: cx,
          cy: cy,
          w: wPx / W,
          h: hPx / H,
        );
      }
      if (p.item.isFile) return null;
      return Layer(
        id: newId(),
        type: 'asset',
        path: p.item.path,
        cx: cx,
        cy: cy,
        w: wPx / W,
        h: hPx / H,
      );
    }

    Layer anim(Layer l, String kind, int startMs, [int dur = 500]) {
      l.animIn = kind;
      l.animDurationMs = dur;
      l.startMs = startMs;
      return l;
    }

    for (var i = 0; i < plan.slides.length; i++) {
      final slide = plan.slides[i];
      final look = _lookFor(plan, slide, cat);
      tintColor = look.accent;
      final durationMs = (slide.seconds * 1000).clamp(3000, 30000).toInt();
      final scene = Scene(
        id: newId(),
        durationMs: durationMs,
        bgType: look.bgType,
        bgValue: look.bgValue,
        transKind: i == 0 ? 'none' : 'fade',
        transMs: 600,
        narrationText: slide.narration.trim(),
      );
      final out = scene.layers;
      if (look.scrim != null) {
        out.add(shape('rect', look.scrim!, 0.5, 0.5, W, H, opacity: look.scrim == _kWhite ? 0.55 : 0.5));
      }
      final span = (durationMs - 1800).clamp(600, 60000).toInt();
      final n = slide.points.length;
      var layout = slide.layout;
      if (i == 0) layout = 'title';
      if (layout == 'icon_grid' && (slide.icons.length < 2 || n < 1)) layout = 'bullets';
      if ((layout == 'bullets' || layout == 'steps' || layout == 'recap' || layout == 'two_column') && n == 0) {
        layout = 'statement';
      }
      if (layout == 'two_column' && n < 2) layout = 'bullets';

      void heading() {
        final hy = portrait ? 0.1 : 0.13;
        final h = text(slide.heading, 64 * f, look.accent, bold: true, head: true, cy: hy, maxW: 0.9, maxH: 0.16);
        out.add(anim(h, 'fade', 0));
        out.add(anim(shape('rect', look.accent, 0.5, hy + h.h / 2 + 0.025, 140, 6), 'fade', 200));
      }

      switch (layout) {
        case 'title':
          {
            final hasPic = slide.icons.isNotEmpty;
            final titleY = hasPic ? 0.56 : 0.42;
            if (hasPic) {
              final p = picture(slide.icons.first, 0.5, 0.27, H * 0.3);
              if (p != null) out.add(anim(p, 'pop', 0, 700));
            }
            final t = text(slide.heading, 100 * f, look.ink, bold: true, head: true, cy: titleY, maxW: 0.86, maxH: 0.3);
            out.add(anim(t, 'pop', hasPic ? 200 : 0, 700));
            if (n > 0) {
              final barY = t.cy + t.h / 2 + 0.035;
              out.add(anim(shape('rect', look.accent, 0.5, barY, 160, 6), 'fade', 700));
              final sub = text(slide.points.first, 50 * f, look.accent, cy: barY + 0.08, maxW: 0.84, maxH: 0.16);
              out.add(anim(sub, 'fade', 900, 700));
            }
          }
          break;
        case 'statement':
          {
            out.add(anim(shape('rect', look.accent, 0.5, 0.25, 120, 8), 'fade', 0));
            final t = text(slide.heading, 84 * f, look.ink, bold: true, head: true, cy: n > 0 ? 0.46 : 0.5, maxW: 0.84, maxH: 0.4);
            out.add(anim(t, 'fade', 200, 700));
            if (n > 0) {
              final sub = text(slide.points.first, 44 * f, look.accent, cy: 0.74, maxW: 0.8, maxH: 0.16);
              out.add(anim(sub, 'fade', 1200, 600));
            }
          }
          break;
        case 'quote':
          {
            final body = n > 0 ? slide.points.first : slide.heading;
            final mark = text('“', 220 * f, look.accent, bold: true, head: true, cy: 0.2, maxW: 0.3, maxH: 0.4);
            out.add(anim(mark, 'pop', 0, 600));
            final q = text(body, 58 * f, look.ink, italic: true, cy: 0.5, maxW: 0.8, maxH: 0.4);
            out.add(anim(q, 'fade', 400, 700));
            if (n > 0 && slide.heading.isNotEmpty) {
              final by = text('— ${slide.heading}', 40 * f, look.accent, cy: 0.82, maxW: 0.8, maxH: 0.12);
              out.add(anim(by, 'fade', 1400, 600));
            }
          }
          break;
        case 'icon_grid':
          {
            heading();
            final cnt = math.min(slide.icons.length, 4);
            final cols = portrait ? 2 : cnt;
            final rows = portrait ? (cnt + 1) ~/ 2 : 1;
            final areaTop = 0.28;
            final areaH = 0.64;
            final cellW = W * 0.86 / cols;
            final rowH = areaH * H / rows;
            final box = math.min(cellW * 0.55, rowH * 0.5);
            for (var k = 0; k < cnt; k++) {
              final c = k % cols;
              final r = k ~/ cols;
              final cx = (0.07 * W + cellW * (c + 0.5)) / W;
              final rc = (areaTop * H + rowH * (r + 0.5)) / H;
              final start = 500 + span * k ~/ cnt;
              out.add(anim(shape('round', look.ink, cx, rc, cellW * 0.92, rowH * 0.9, opacity: 0.1), 'fade', start));
              final p = picture(slide.icons[k], cx, rc - rowH * 0.12 / H, box);
              if (p != null) out.add(anim(p, 'pop', start, 500));
              if (k < n) {
                final lab = text(slide.points[k], 36 * f, look.ink,
                    bold: true,
                    cx: cx,
                    cy: rc + (box * 0.5 + rowH * 0.2) / H,
                    maxW: cellW * 0.86 / W,
                    maxH: rowH * 0.3 / H);
                out.add(anim(lab, 'fade', start + 150));
              }
            }
          }
          break;
        case 'two_column':
          {
            heading();
            final split = (n + 1) ~/ 2;
            final groups = [slide.points.sublist(0, split), slide.points.sublist(split)];
            final hasPics = slide.icons.length >= 2 && !portrait;
            for (var g = 0; g < 2; g++) {
              final cardW = portrait ? W * 0.86 : W * 0.43;
              final cardH = portrait ? H * 0.33 : H * 0.6;
              final cx = portrait ? 0.5 : (g == 0 ? 0.27 : 0.73);
              final cy = portrait ? (g == 0 ? 0.44 : 0.8) : 0.62;
              final start = 400 + span * g ~/ 2;
              out.add(anim(shape('round', look.ink, cx, cy, cardW, cardH, opacity: 0.1), 'fade', start));
              var top = cy * H - cardH / 2 + 24;
              if (hasPics) {
                final p = picture(slide.icons[g], cx, (top + H * 0.08) / H, H * 0.16);
                if (p != null) out.add(anim(p, 'pop', start, 500));
                top += H * 0.17;
              }
              final items = groups[g];
              if (items.isEmpty) continue;
              final avail = cy * H + cardH / 2 - 24 - top;
              final step = math.min(avail / items.length, H * 0.14);
              final left = cx * W - cardW / 2 + 28;
              for (var k = 0; k < items.length; k++) {
                final t = text(items[k], 38 * f, look.ink,
                    cy: (top + step * (k + 0.5)) / H,
                    maxW: (cardW - 56) / W,
                    maxH: step * 0.95 / H,
                    left: left / W);
                out.add(anim(t, 'fade', start + 200 + 300 * k));
              }
            }
          }
          break;
        default:
          {
            // bullets, steps and recap share one list layout
            heading();
            final steps = layout == 'steps';
            final recap = layout == 'recap';
            final sideIcon = !portrait && !steps && !recap && slide.icons.isNotEmpty;
            final left = 0.08 * W;
            final markW = steps ? 56.0 : 20.0;
            final textLeft = left + markW + 28;
            final textMaxW = (sideIcon ? 0.58 * W : 0.9 * W - left) - markW - 28;
            final areaTop = 0.3 * H;
            final areaH = 0.62 * H;
            final step = math.min(areaH / n, H * 0.17);
            final top = areaTop + (areaH - step * n) / 2;
            for (var k = 0; k < n; k++) {
              final cy = (top + step * (k + 0.5)) / H;
              final start = 600 + span * k ~/ n;
              if (steps && n >= 5) {
                // Many steps: the number and its badge are one item, so the video exporter
                // (which draws at most 15 animated items at once) keeps every step.
                final num = text('${k + 1}', 30 * f, look.onAccent, bold: true, cx: (left + markW / 2) / W, cy: cy);
                num.bgBox = true;
                num.bgColor = look.accent;
                out.add(anim(num, 'pop', start, 400));
              } else if (steps) {
                out.add(anim(shape('circle', look.accent, (left + markW / 2) / W, cy, markW, markW), 'pop', start, 400));
                final num = text('${k + 1}', 30 * f, look.onAccent, bold: true, cx: (left + markW / 2) / W, cy: cy);
                out.add(anim(num, 'pop', start, 400));
              } else {
                out.add(anim(shape('circle', look.accent, (left + markW / 2) / W, cy, markW, markW), 'pop', start, 400));
              }
              final t = text(slide.points[k], 46 * f, look.ink,
                  bold: recap,
                  cy: cy,
                  maxW: textMaxW / W,
                  maxH: step * 0.95 / H,
                  left: textLeft / W);
              out.add(anim(t, 'fade', start, 500));
            }
            if (sideIcon) {
              final p = picture(slide.icons.first, 0.8, 0.58, H * 0.44);
              if (p != null) out.add(anim(p, 'pop', 400, 700));
            }
          }
      }
      lesson.scenes.add(scene);
    }
  } finally {
    Stage.reset();
  }
}
