import 'package:flutter/material.dart';

const kFont = 'Poppins';

/// A full color palette for the app chrome and the board (not the blocks
/// themselves — those come from `game/skins.dart`, purchased separately).
///
/// Every theme is a dark, saturated arcade palette: a vertical background
/// gradient ([backgroundTop] → [background]), a deep recessed board
/// ([boardFrame] around [boardCell] slots) and bright chrome on top.
class AppTheme {
  const AppTheme({
    required this.name,
    required this.backgroundTop,
    required this.background,
    required this.surface,
    required this.line,
    required this.text,
    required this.subtext,
    required this.accent,
    required this.danger,
    required this.gold,
    required this.boardFrame,
    required this.boardCell,
    required this.boardCellEdge,
    this.dark = true,
    this.price = 0,
  });

  final String name;

  /// Top and bottom of the screen background gradient.
  final Color backgroundTop;
  final Color background;

  /// Cards, sheets and the bottom bar.
  final Color surface;
  final Color line;
  final Color text;
  final Color subtext;

  /// Primary call-to-action color (the big Play button).
  final Color accent;
  final Color danger;
  final Color gold;

  /// The board's outer tray, the empty cell slots inside it, and the darker
  /// rim that makes each empty slot look sunk into the board.
  final Color boardFrame;
  final Color boardCell;
  final Color boardCellEdge;

  final bool dark;

  /// Coins to unlock in the shop (0 = free/default).
  final int price;

  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundTop, background],
      );

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

  static const indigo = AppTheme(
    name: 'Indigo',
    backgroundTop: Color(0xFF4146B8),
    background: Color(0xFF1B1C5A),
    surface: Color(0xFF282A7E),
    line: Color(0xFF3B3E9E),
    text: Colors.white,
    subtext: Color(0xFFB7BBF0),
    accent: Color(0xFF34C86A),
    danger: Color(0xFFFF5C6C),
    gold: Color(0xFFFFC93C),
    boardFrame: Color(0xFF15164C),
    boardCell: Color(0xFF22246E),
    boardCellEdge: Color(0xFF1A1C5C),
  );

  static const ocean = AppTheme(
    name: 'Ocean',
    backgroundTop: Color(0xFF1C7CC9),
    background: Color(0xFF0A2C5A),
    surface: Color(0xFF123F78),
    line: Color(0xFF1E5592),
    text: Colors.white,
    subtext: Color(0xFFA9D2F5),
    accent: Color(0xFF34C86A),
    danger: Color(0xFFFF5C6C),
    gold: Color(0xFFFFC93C),
    boardFrame: Color(0xFF08214A),
    boardCell: Color(0xFF0F3165),
    boardCellEdge: Color(0xFF0A2756),
    price: 400,
  );

  static const grape = AppTheme(
    name: 'Grape',
    backgroundTop: Color(0xFF8A36B8),
    background: Color(0xFF2C0D4E),
    surface: Color(0xFF45186E),
    line: Color(0xFF5E2690),
    text: Colors.white,
    subtext: Color(0xFFDDB8F5),
    accent: Color(0xFF34C86A),
    danger: Color(0xFFFF5C6C),
    gold: Color(0xFFFFC93C),
    boardFrame: Color(0xFF240A42),
    boardCell: Color(0xFF371460),
    boardCellEdge: Color(0xFF2C0F50),
    price: 400,
  );

  static const night = AppTheme(
    name: 'Night',
    backgroundTop: Color(0xFF2E3442),
    background: Color(0xFF0D0F15),
    surface: Color(0xFF1D212B),
    line: Color(0xFF2E3340),
    text: Colors.white,
    subtext: Color(0xFFA3A9B8),
    accent: Color(0xFF34C86A),
    danger: Color(0xFFFF5C6C),
    gold: Color(0xFFFFC93C),
    boardFrame: Color(0xFF0A0C11),
    boardCell: Color(0xFF181B24),
    boardCellEdge: Color(0xFF12141B),
    price: 400,
  );

  static const sunset = AppTheme(
    name: 'Sunset',
    backgroundTop: Color(0xFFFF8A5B),
    background: Color(0xFF5A1846),
    surface: Color(0xFF7A2456),
    line: Color(0xFF9A3466),
    text: Colors.white,
    subtext: Color(0xFFFFD2C2),
    accent: Color(0xFF34C86A),
    danger: Color(0xFFFF5C6C),
    gold: Color(0xFFFFC93C),
    boardFrame: Color(0xFF3D0F31),
    boardCell: Color(0xFF5C1A47),
    boardCellEdge: Color(0xFF4A143A),
    price: 500,
  );

  static const forest = AppTheme(
    name: 'Forest',
    backgroundTop: Color(0xFF2F9E6A),
    background: Color(0xFF0B3326),
    surface: Color(0xFF14513B),
    line: Color(0xFF1E6A4D),
    text: Colors.white,
    subtext: Color(0xFFB9EBD2),
    accent: Color(0xFFFF9F1C),
    danger: Color(0xFFFF5C6C),
    gold: Color(0xFFFFC93C),
    boardFrame: Color(0xFF08261C),
    boardCell: Color(0xFF0F3B2C),
    boardCellEdge: Color(0xFF0A2F23),
    price: 500,
  );

  static const candy = AppTheme(
    name: 'Bubblegum',
    backgroundTop: Color(0xFFFF7EC8),
    background: Color(0xFF6A2C9E),
    surface: Color(0xFF8A3BB8),
    line: Color(0xFFA34FCF),
    text: Colors.white,
    subtext: Color(0xFFFFD6F2),
    accent: Color(0xFF34C86A),
    danger: Color(0xFFFF5C6C),
    gold: Color(0xFFFFC93C),
    boardFrame: Color(0xFF4A1A75),
    boardCell: Color(0xFF61268F),
    boardCellEdge: Color(0xFF521F7D),
    price: 600,
  );

  static const all = [indigo, ocean, grape, night, sunset, forest, candy];

  static AppTheme byName(String name) =>
      all.firstWhere((t) => t.name == name, orElse: () => indigo);
}
