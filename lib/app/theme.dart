import 'package:flutter/material.dart';

const kFont = 'Poppins';

/// A full color palette for the app chrome (not the blocks themselves —
/// those come from `game/skins.dart`, purchased separately).
class AppTheme {
  const AppTheme({
    required this.name,
    required this.background,
    required this.surface,
    required this.line,
    required this.text,
    required this.subtext,
    required this.accent,
    required this.danger,
    required this.gold,
    required this.checkerA,
    required this.checkerB,
    this.dark = false,
    this.price = 0,
  });

  final String name;
  final Color background;
  final Color surface;
  final Color line;
  final Color text;
  final Color subtext;
  final Color accent;
  final Color danger;
  final Color gold;

  /// The faint two-tone checker painted behind empty board cells.
  final Color checkerA;
  final Color checkerB;

  final bool dark;

  /// Coins to unlock in the shop (0 = free/default).
  final int price;

  TextStyle title(double size, {Color? color, FontWeight? weight}) => TextStyle(
        fontFamily: kFont,
        fontSize: size,
        height: 1.1,
        fontWeight: weight ?? FontWeight.w700,
        letterSpacing: -.02 * size,
        color: color ?? text,
      );

  TextStyle body(double size, {Color? color, FontWeight? weight}) => TextStyle(
        fontFamily: kFont,
        fontSize: size,
        height: 1.35,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? subtext,
      );

  static const paper = AppTheme(
    name: 'Paper',
    background: Color(0xFFFAFAF8),
    surface: Colors.white,
    line: Color(0xFFEAEAE6),
    text: Color(0xFF15171C),
    subtext: Color(0xFF8B9099),
    accent: Color(0xFF2F6BFF),
    danger: Color(0xFFEF4444),
    gold: Color(0xFFCA8A04),
    checkerA: Color(0xFFF3F3F0),
    checkerB: Color(0xFFFFFFFF),
  );

  static const ink = AppTheme(
    name: 'Ink',
    background: Color(0xFF15171C),
    surface: Color(0xFF1D2027),
    line: Color(0xFF2C3039),
    text: Color(0xFFF2F2EF),
    subtext: Color(0xFFA3A8B6),
    accent: Color(0xFF7EA3FF),
    danger: Color(0xFFF87171),
    gold: Color(0xFFFFD873),
    checkerA: Color(0xFF20232B),
    checkerB: Color(0xFF262A33),
    dark: true,
  );

  static const meadow = AppTheme(
    name: 'Meadow',
    background: Color(0xFFF3FAF1),
    surface: Colors.white,
    line: Color(0xFFDCEBD8),
    text: Color(0xFF142417),
    subtext: Color(0xFF6B8A70),
    accent: Color(0xFF1FA34A),
    danger: Color(0xFFEF4444),
    gold: Color(0xFFCA8A04),
    checkerA: Color(0xFFE9F5E6),
    checkerB: Color(0xFFFFFFFF),
    price: 400,
  );

  static const midnight = AppTheme(
    name: 'Midnight',
    background: Color(0xFF0B0F2A),
    surface: Color(0xFF131A3C),
    line: Color(0xFF232B57),
    text: Color(0xFFEDEFFF),
    subtext: Color(0xFF9AA3D9),
    accent: Color(0xFF8B9BFF),
    danger: Color(0xFFFF7A7A),
    gold: Color(0xFFFFD873),
    checkerA: Color(0xFF111736),
    checkerB: Color(0xFF161D42),
    dark: true,
    price: 400,
  );

  static const all = [paper, ink, meadow, midnight];

  static AppTheme byName(String name) =>
      all.firstWhere((t) => t.name == name, orElse: () => paper);
}
