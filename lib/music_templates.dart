/// A ready-made look for a music video: visualizer style, colour, record place and fonts.
/// Fonts are names from the app's built-in font list (lib/data/font_catalog.dart), so they are always available.
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
  MusicTemplate(id: 'vinyl', name: 'Vinyl Night', viz: 'circle', accent: 0xFFFF9F1C, layout: 1, titleFont: 'Bebas Neue', artistFont: 'Montserrat'),
  MusicTemplate(id: 'neon', name: 'Neon Club', viz: 'bars', accent: 0xFFFF4D6D, titleFont: 'Orbitron', artistFont: 'Exo 2'),
  MusicTemplate(id: 'lofi', name: 'Lo-fi Warm', viz: 'blocks', accent: 0xFFFFD54F, layout: 2, titleFont: 'Caveat', artistFont: 'Quicksand'),
  MusicTemplate(id: 'clean', name: 'Clean White', viz: 'wave', accent: 0xFFFFFFFF, titleFont: 'Montserrat', artistFont: 'Lato'),
  MusicTemplate(id: 'gold', name: 'Gospel Gold', viz: 'pulse', accent: 0xFFFFD54F, titleFont: 'Playfair Display', artistFont: 'Cormorant Garamond'),
  MusicTemplate(id: 'radio', name: 'Radio Classic', viz: 'rise', accent: 0xFF4DD0E1, layout: 2, titleFont: 'Space Mono', artistFont: 'Space Mono'),
  MusicTemplate(id: 'mint', name: 'Fresh Mint', viz: 'dots', accent: 0xFF69F0AE, titleFont: 'Poppins', artistFont: 'Nunito'),
  MusicTemplate(id: 'dream', name: 'Dreamy', viz: 'circle', accent: 0xFFB9A0FF, layout: 2, titleFont: 'Great Vibes', artistFont: 'Raleway'),
  MusicTemplate(id: 'arcade', name: 'Retro Arcade', viz: 'blocks', accent: 0xFF69F0AE, titleFont: 'Press Start 2P', artistFont: 'VT323'),
  MusicTemplate(id: 'party', name: 'Party', viz: 'bars', accent: 0xFFFF4D6D, layout: 1, titleFont: 'Bungee', artistFont: 'Righteous'),
  MusicTemplate(id: 'sunset', name: 'Sunset Drive', viz: 'wave', accent: 0xFFFF7043, layout: 1, titleFont: 'Pacifico', artistFont: 'Quicksand'),
  MusicTemplate(id: 'midnight', name: 'Midnight Blue', viz: 'rise', accent: 0xFF82B1FF, layout: 2, titleFont: 'Raleway', artistFont: 'Raleway'),
  MusicTemplate(id: 'rose', name: 'Rose Gold', viz: 'circle', accent: 0xFFFF80AB, layout: 1, titleFont: 'Great Vibes', artistFont: 'Lato'),
  MusicTemplate(id: 'bold', name: 'Bold Beat', viz: 'bars', accent: 0xFFFFEB3B, titleFont: 'Bebas Neue', artistFont: 'Bebas Neue'),
  MusicTemplate(id: 'forest', name: 'Forest', viz: 'pulse', accent: 0xFF81C784, layout: 2, titleFont: 'Playfair Display', artistFont: 'Lato'),
  MusicTemplate(id: 'cyber', name: 'Cyber', viz: 'blocks', accent: 0xFF00E5FF, layout: 1, titleFont: 'Orbitron', artistFont: 'Space Mono'),
  MusicTemplate(id: 'script', name: 'Soft Script', viz: 'wave', accent: 0xFFFFFFFF, titleFont: 'Dancing Script', artistFont: 'Lato'),
];
