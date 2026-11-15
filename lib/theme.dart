import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand colors taken from the Kainuwa Studio mockup.
class KColors {
  KColors._();

  static const Color deepPurple = Color(0xFF41038B);
  static const Color purple = Color(0xFF6D28D9);
  static const Color lavender = Color(0xFF2B2152);
  static const Color background = Color(0xFF0F0B1E);
  static const Color surface = Color(0xFF1A1431);
  static const Color accent = Color(0xFFB9A0FF);
  static const Color onGold = Color(0xFF1E1433);
  static const Color gold = Color(0xFFF6C101);
  static const Color ink = Color(0xFFEFEAFF);

  /// Background of anything that is selected (tabs, chips, options). Text on it is white.
  static const Color selected = Color(0xFF7351FF);

  // Lesson editor (multitrack timeline) colors, sampled from the mockup.
  static const Color editorPanel = Color(0xFF13102A);
  static const Color editorStrip = Color(0xFF241C48);
  static const Color editorLabel = Color(0xFF1C1638);
  static const Color editorCard = Color(0xFF1C1638);
  static const Color editorNav = Color(0xFF6B10D1);
  static const Color editorNavIcon = Color(0xFFB794F6);
  static const Color editorPlay = Color(0xFF7514DF);
  static const Color editorPlayhead = Color(0xFF8E1BDC);
  static const Color editorToolIcon = Color(0xFFD8CCFF);
  static const Color editorExport = Color(0xFFFCBE12);
  static const Color clipText = Color(0xFFFDC018);
  static const Color clipAudio = Color(0xFF03A845);
  static const Color clipMusic = Color(0xFF0B8F6A);
  static const Color clipVideo = Color(0xFF382BC8);
  static const Color clipPicture = Color(0xFF7C4DDB);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KColors.purple,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF8B5CF6),
    onPrimary: Colors.white,
    secondary: KColors.gold,
    onSecondary: KColors.onGold,
    surface: KColors.surface,
    onSurface: KColors.ink,
    primaryContainer: KColors.lavender,
    onPrimaryContainer: KColors.accent,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: KColors.background,
    canvasColor: KColors.surface,
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: KColors.surface),
    appBarTheme: const AppBarTheme(
      backgroundColor: KColors.deepPurple,
      foregroundColor: Colors.white,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KColors.surface,
      indicatorColor: KColors.selected,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : KColors.accent),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? Colors.white : KColors.accent,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      backgroundColor: KColors.lavender,
      selectedColor: KColors.selected,
      disabledColor: KColors.lavender,
      side: BorderSide.none,
      labelStyle: WidgetStateTextStyle.resolveWith(
        (s) => TextStyle(
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? Colors.white : KColors.ink,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? KColors.selected : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : KColors.ink,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
  );
}
