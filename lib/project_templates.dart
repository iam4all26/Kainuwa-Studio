import 'lyrics_project.dart';
import 'music_templates.dart';

/// The saved-choices map a setup screen starts from for a ready template. The person only adds
/// the cover, song and words; the look of the template stays.
Map<String, dynamic> musicTemplateForm(MusicTemplate t) => {
      'viz': t.viz,
      'accent': t.accent,
      'layout': t.layout,
      'titleFont': t.titleFont,
      'artistFont': t.artistFont,
      'template': t.id,
      'shape': 0,
    };

Map<String, dynamic> lyricsTemplateForm(LyricsLook l) => {
      'look': l.id,
      'anim': l.anim,
      'font': l.font,
      'bg': l.bg,
      'palette': l.palette,
      'stars': l.fx.contains('stars'),
      'streaks': l.fx.contains('streaks'),
      'embers': l.fx.contains('embers'),
      'sparkle': l.fx.contains('sparkle'),
      'shape': l.layout != 0 ? 0 : 1,
      'byWord': l.byWord,
      'layout': l.layout,
    };
