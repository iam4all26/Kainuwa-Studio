import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand colors taken from the Kainuwa Studio mockup.
class KColors {
  KColors._();

  static const Color deepPurple = Color(0xFF41038B);
  static const Color purple = Color(0xFF6D28D9);
  static const Color lavender = Color(0xFFEDE7FF);
  static const Color background = Color(0xFFF7F4FF);
  static const Color gold = Color(0xFFF6C101);
  static const Color ink = Color(0xFF1E1433);

  // Lesson editor (multitrack timeline) colors, sampled from the mockup.
  static const Color editorPanel = Color(0xFFF6F4FD);
  static const Color editorStrip = Color(0xFFE0D9F7);
  static const Color editorLabel = Color(0xFFF8F7FE);
  static const Color editorCard = Color(0xFFFAF8FE);
  static const Color editorNav = Color(0xFF6B10D1);
  static const Color editorPlay = Color(0xFF7514DF);
  static const Color editorPlayhead = Color(0xFF8E1BDC);
  static const Color editorToolIcon = Color(0xFF3B2F6E);
  static const Color editorExport = Color(0xFFFCBE12);
  static const Color clipText = Color(0xFFFDC018);
  static const Color clipAudio = Color(0xFF03A845);
  static const Color clipMusic = Color(0xFF0B8F6A);
  static const Color clipVideo = Color(0xFF382BC8);
  static const Color clipPicture = Color(0xFF7C4DDB);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: KColors.purple).copyWith(
    primary: KColors.purple,
    onPrimary: Colors.white,
    secondary: KColors.gold,
    onSecondary: KColors.ink,
    primaryContainer: KColors.lavender,
    onPrimaryContainer: KColors.deepPurple,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: KColors.deepPurple,
      foregroundColor: Colors.white,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: KColors.lavender,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
