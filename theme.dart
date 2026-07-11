import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// WorkLink design tokens.
/// Copper = trust (Zambia's copper heritage), deep green = growth.
class WL {
  static const bg = Color(0xFFF4F5F0);
  static const card = Colors.white;
  static const ink = Color(0xFF152119);
  static const inkSoft = Color(0xFF4C5A50);
  static const green = Color(0xFF1E5631);
  static const greenDeep = Color(0xFF123A21);
  static const copper = Color(0xFFB06F35);
  static const copperLight = Color(0xFFE8D3BC);
  static const line = Color(0xFFDDE1D8);
  static const red = Color(0xFFB3402A);
}

ThemeData worklinkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: WL.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: WL.green,
      primary: WL.green,
      secondary: WL.copper,
      surface: WL.card,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.archivoTextTheme(base.textTheme).apply(
      bodyColor: WL.ink,
      displayColor: WL.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: WL.greenDeep,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: WL.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    cardTheme: CardTheme(
      color: WL.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: WL.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WL.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: WL.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: WL.line),
      ),
    ),
  );
}
