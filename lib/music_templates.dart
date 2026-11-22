/// A ready-made look for a music video: visualizer style, colour, record place and fonts.
/// Only fonts every Android phone has are used, so a template always looks the same.
class MusicTemplate {
  const MusicTemplate({
    required this.id,
    required this.name,
    required this.viz,
    required this.accent,
    this.layout = 0,
    this.titleFont = '',
    this.artistFont = '',
  });

  final String id;
  final String name;
  final String viz;
  final int accent;

  /// 0 centre, 1 left, 2 right (left and right only apply to the wide video shape).
  final int layout;
  final String titleFont;
  final String artistFont;
}

const List<MusicTemplate> kMusicTemplates = [
  MusicTemplate(id: 'vinyl', name: 'Vinyl Night', viz: 'circle', accent: 0xFFFF9F1C, layout: 1, titleFont: 'sans-serif-black', artistFont: 'sans-serif-medium'),
  MusicTemplate(id: 'neon', name: 'Neon Club', viz: 'bars', accent: 0xFFFF4D6D, titleFont: 'sans-serif-black', artistFont: 'sans-serif-condensed'),
  MusicTemplate(id: 'lofi', name: 'Lo-fi Warm', viz: 'blocks', accent: 0xFFFFD54F, layout: 2, titleFont: 'casual', artistFont: 'casual'),
  MusicTemplate(id: 'clean', name: 'Clean White', viz: 'wave', accent: 0xFFFFFFFF, titleFont: 'sans-serif-medium', artistFont: ''),
  MusicTemplate(id: 'gold', name: 'Gospel Gold', viz: 'pulse', accent: 0xFFFFD54F, titleFont: 'serif', artistFont: 'serif'),
  MusicTemplate(id: 'radio', name: 'Radio Classic', viz: 'rise', accent: 0xFF4DD0E1, layout: 2, titleFont: 'monospace', artistFont: 'monospace'),
  MusicTemplate(id: 'mint', name: 'Fresh Mint', viz: 'dots', accent: 0xFF69F0AE, titleFont: 'sans-serif-condensed', artistFont: 'sans-serif-condensed'),
  MusicTemplate(id: 'dream', name: 'Dreamy', viz: 'circle', accent: 0xFFB9A0FF, layout: 2, titleFont: 'cursive', artistFont: 'sans-serif-medium'),
];
