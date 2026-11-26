import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../data/asset_catalog.dart';
import '../editor/edit_panel.dart' show fontEntries;
import '../store/store_service.dart';

class AiBg {
  AiBg(this.id, this.item, this.lum);
  final String id;
  final CatalogItem item;

  /// Average brightness of the picture, 0 (black) to 1 (white).
  final double lum;

  bool get dark => lum < 0.45;
  String get name => item.name;
  String get hint => item.hint;
}

class AiFont {
  AiFont(this.id, this.family, this.name, this.category);
  final String id;

  /// The font family name set on text.
  final String family;
  final String name;
  final String category;
}

class AiPic {
  AiPic(this.id, this.item);
  final String id;
  final CatalogItem item;
  String get name => item.name;
}

/// The backgrounds and pictures the AI may choose from.
class AiCatalog {
  AiCatalog(this.bgs, this.pics, [this.fonts = const []]);
  final List<AiBg> bgs;
  final List<AiPic> pics;
  final List<AiFont> fonts;

  /// A short code for the picture list. It changes whenever a picture is added, removed or moved,
  /// so an answer made from an older prompt can be told apart from one made from this list.
  String get code {
    var h = 0x811C9DC5;
    for (final p in pics) {
      for (final u in '${p.id}:${p.name}|'.codeUnits) {
        h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
      }
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  AiFont? font(String? id) {
    if (id == null) return null;
    final key = id.trim();
    if (key.isEmpty) return null;
    for (final f in fonts) {
      if (f.id == key) return f;
    }
    // The AI sometimes writes the font name instead of its id.
    for (final f in fonts) {
      if (f.name.toLowerCase() == key.toLowerCase() || f.family.toLowerCase() == key.toLowerCase()) return f;
    }
    return null;
  }

  AiBg? bg(String? id) {
    if (id == null) return null;
    for (final b in bgs) {
      if (b.id == id.trim()) return b;
    }
    return null;
  }

  AiPic? pic(String? id) {
    if (id == null) return null;
    for (final p in pics) {
      if (p.id == id.trim()) return p;
    }
    return null;
  }

  static Future<Uint8List?> _bytes(CatalogItem item) async {
    try {
      if (item.isFile) return await File(item.path).readAsBytes();
      final data = await rootBundle.load(item.path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Width divided by height of a picture.
  static Future<double> aspectOf(CatalogItem item) async {
    final bytes = await _bytes(item);
    if (bytes == null) return 1.0;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 48);
      final frame = await codec.getNextFrame();
      final a = frame.image.width / frame.image.height;
      frame.image.dispose();
      codec.dispose();
      return a <= 0 ? 1.0 : a;
    } catch (_) {
      return 1.0;
    }
  }

  /// Average brightness of any catalog picture, 0 (black) to 1 (white).
  static Future<double> luminanceOf(CatalogItem item) => _luminance(item);

  static Future<double> _luminance(CatalogItem item) async {
    final bytes = await _bytes(item);
    if (bytes == null) return 0.5;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 12);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return 0.5;
      var sum = 0.0;
      var n = 0;
      for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
        final r = data.getUint8(i) / 255.0;
        final g = data.getUint8(i + 1) / 255.0;
        final b = data.getUint8(i + 2) / 255.0;
        sum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
        n++;
      }
      return n == 0 ? 0.5 : sum / n;
    } catch (_) {
      return 0.5;
    }
  }

  static Future<AiCatalog> load() async {
    final bgs = <AiBg>[];
    final all = allBackgrounds();
    for (var i = 0; i < all.length; i++) {
      bgs.add(AiBg('b${i + 1}', all[i], await _luminance(all[i])));
    }
    final pics = <AiPic>[];
    final items = <CatalogItem>[
      ...kIcons,
      ...kIllustrations,
    ].where((e) => !e.isFile && e.path.toLowerCase().endsWith('.png')).toList();
    // Built-in brand logos (WhatsApp, Google Play and so on) and everyday icons (phone, calculator
    // and so on). They are SVG, drawn into pictures when the lesson is built.
    items.addAll([
      ...kSocialIcons,
      ...kAppIcons,
      ...kPaymentIcons,
      ...kNigerianSymbols,
      ...kNigerianIcons,
      ...kDeveloperIcons,
      ...kLanguageIcons,
      ...kUiIcons,
    ]);
    for (var i = 0; i < items.length; i++) {
      pics.add(AiPic('p${i + 1}', items[i]));
    }
    // Icons installed from the store (SVG, recoloured to the slide accent).
    // Sorted by id so the numbers stay the same until the owner installs or
    // removes an icon.
    final store = StoreService.instance
        .ofType('icon')
        .where((e) => e.path.toLowerCase().endsWith('.svg'))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (var i = 0; i < store.length; i++) {
      pics.add(AiPic('p${items.length + i + 1}', CatalogItem(store[i].path, store[i].name, tint: true)));
    }
    final fonts = <AiFont>[];
    final seen = <String>{};
    for (final e in fontEntries()) {
      if (e.$1.isEmpty || !seen.add(e.$1)) continue;
      fonts.add(AiFont('f${fonts.length + 1}', e.$1, e.$2, e.$3));
    }
    return AiCatalog(bgs, pics, fonts);
  }
}
