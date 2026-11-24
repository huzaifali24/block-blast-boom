import 'package:flutter/material.dart';

import 'shapes.dart';

/// A purchasable coat of paint for the blocks: one [Color] per [PieceColor],
/// in enum order (amber, pink, cyan, mint, violet, coral, blue). The engine
/// never looks at this — it only ever deals in [PieceColor] — so adding a
/// skin never touches game logic.
/// How a skin's blocks are drawn (see `BlockArt` in board_painter.dart).
enum BlockStyle {
  /// Glossy candy: bevels, curved shine, sparkle.
  gloss,

  /// Dark glass with a glowing colored rim.
  neon,

  /// Carved wood with grain, tinted by the color.
  wood,
}

class BlockSkin {
  const BlockSkin({
    required this.id,
    required this.name,
    required this.colors,
    this.priceCoins = 0,
    this.style = BlockStyle.gloss,
  });

  final String id;
  final String name;
  final List<Color> colors;
  final BlockStyle style;

  /// Coins to unlock in the shop. 0 = free/default.
  final int priceCoins;

  Color forPiece(PieceColor c) => colors[c.index];
  Color forIndex(int i) => colors[i % colors.length];
}

class Skins {
  Skins._();

  /// Bright, saturated "candy" blocks — the default look.
  static const classic = BlockSkin(
    id: 'classic',
    name: 'Candy',
    colors: [
      Color(0xFFFFC02E), // amber / yellow
      Color(0xFFF23F5B), // pink / red
      Color(0xFF26C6F0), // cyan
      Color(0xFF3FD16B), // mint / green
      Color(0xFF9B5BF5), // violet
      Color(0xFFFF8A26), // coral / orange
      Color(0xFF3D6CF2), // blue
    ],
  );

  static const neon = BlockSkin(
    id: 'neon',
    name: 'Electric',
    priceCoins: 600,
    colors: [
      Color(0xFFFFE600),
      Color(0xFFFF1F7A),
      Color(0xFF00F0FF),
      Color(0xFF39FF14),
      Color(0xFFB026FF),
      Color(0xFFFF6A00),
      Color(0xFF2E5BFF),
    ],
  );

  static const pastel = BlockSkin(
    id: 'pastel',
    name: 'Pastel',
    priceCoins: 600,
    colors: [
      Color(0xFFFFD98B),
      Color(0xFFFF9DB4),
      Color(0xFF96DDF2),
      Color(0xFF9FE8A6),
      Color(0xFFC6AEF5),
      Color(0xFFFFB98A),
      Color(0xFF9AB4FA),
    ],
  );

  static const gems = BlockSkin(
    id: 'sunset',
    name: 'Gems',
    priceCoins: 900,
    colors: [
      Color(0xFFE8B10E), // topaz
      Color(0xFFC8102E), // ruby
      Color(0xFF0FA3B1), // aquamarine
      Color(0xFF0B9E4F), // emerald
      Color(0xFF7B2CBF), // amethyst
      Color(0xFFE85D04), // amber
      Color(0xFF1D4ED8), // sapphire
    ],
  );

  static const neonGlow = BlockSkin(
    id: 'neon_glow',
    name: 'Neon Glow',
    priceCoins: 800,
    style: BlockStyle.neon,
    colors: [
      Color(0xFFFFE14D),
      Color(0xFFFF3D7F),
      Color(0xFF3DF2FF),
      Color(0xFF5CFF7A),
      Color(0xFFC45CFF),
      Color(0xFFFF9A3D),
      Color(0xFF4D7CFF),
    ],
  );

  static const wood = BlockSkin(
    id: 'wood',
    name: 'Wood',
    priceCoins: 1000,
    style: BlockStyle.wood,
    colors: [
      Color(0xFFE0B04A), // golden oak
      Color(0xFFB5523B), // cherry
      Color(0xFF6FA8A0), // sea-stained
      Color(0xFF7FA35A), // moss
      Color(0xFF8E6BA8), // plum stain
      Color(0xFFC98A4B), // teak
      Color(0xFF5E7FB0), // blue stain
    ],
  );

  static const sunset = BlockSkin(
    id: 'sunset_glow',
    name: 'Sunset',
    priceCoins: 500,
    colors: [
      Color(0xFFFFD166),
      Color(0xFFEF476F),
      Color(0xFFFF8FAB),
      Color(0xFFF78C6B),
      Color(0xFFB5179E),
      Color(0xFFFF9F1C),
      Color(0xFF7209B7),
    ],
  );

  static const mono = BlockSkin(
    id: 'mono',
    name: 'Mono',
    priceCoins: 500,
    colors: [
      Color(0xFFF2F2F2),
      Color(0xFF9AA0A6),
      Color(0xFFD0D4DA),
      Color(0xFF6E7681),
      Color(0xFFB6BCC4),
      Color(0xFF858C96),
      Color(0xFFE3E6EA),
    ],
  );

  static const all = [classic, neon, pastel, gems, sunset, mono, neonGlow, wood];

  static BlockSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => classic);
}
