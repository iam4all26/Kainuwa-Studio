import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand colors taken from the Kainuwa Studio mockup.
class KColors {
  KColors._();

  static const Color deepPurple = Color(0xFF3B0F8C);
  static const Color purple = Color(0xFF6D28D9);
  static const Color lavender = Color(0xFFEDE7FF);
  static const Color background = Color(0xFFF7F4FF);
  static const Color gold = Color(0xFFF6C101);
  static const Color ink = Color(0xFF1E1433);
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
