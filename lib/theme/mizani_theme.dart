import 'package:flutter/material.dart';

/// Brand palette lifted from the web prototype (shared/mizani.css) so the
/// Flutter app reads as the same product, not a different one.
class MizaniColors {
  static const brand = Color(0xFF0E7C72);
  static const brandDark = Color(0xFF123F5A);
  static const ok = Color(0xFF1F7A4A);
  static const okSoft = Color(0xFFE4F3EA);
  static const warn = Color(0xFFA16207);
  static const warnSoft = Color(0xFFFCF1DC);
  static const bad = Color(0xFFB4322A);
  static const badSoft = Color(0xFFFBE7E5);
  static const info = Color(0xFF2858A8);
  static const infoSoft = Color(0xFFE5EDFA);
  static const ink = Color(0xFF0F1E1A);
  static const muted = Color(0xFF66756F);
  static const surface = Color(0xFFF6F8F7);
}

ThemeData buildMizaniTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MizaniColors.brand,
      primary: MizaniColors.brand,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: MizaniColors.surface,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: MizaniColors.surface,
      foregroundColor: MizaniColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MizaniColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFFD3DCD8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD3DCD8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD3DCD8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MizaniColors.brand, width: 1.6),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8E5)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: const Color(0xFFE2E8E5),
  );
}
