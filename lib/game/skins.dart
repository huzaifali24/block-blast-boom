import 'package:flutter/material.dart';

import 'shapes.dart';

/// A purchasable coat of paint for the board: one [Color] per [PieceColor],
/// in enum order (amber, pink, cyan, mint, violet, coral). The engine never
/// looks at this — it only ever deals in [PieceColor] — so adding a skin
/// never touches game logic.
class BlockSkin {
  const BlockSkin({
    required this.id,
    required this.name,
    required this.colors,
    this.priceCoins = 0,
  });

  final String id;
  final String name;
  final List<Color> colors;

  /// Coins to unlock in the shop. 0 = free/default.
  final int priceCoins;

  Color forPiece(PieceColor c) => colors[c.index];
}

class Skins {
  Skins._();

  static const classic = BlockSkin(
    id: 'classic',
    name: 'Classic',
    colors: [
      Color(0xFFFF8A3D), // amber
      Color(0xFFFF5283), // pink
      Color(0xFF38BDF8), // cyan
      Color(0xFF32FF00), // mint (brand green)
      Color(0xFFA78BFA), // violet
      Color(0xFFFF6B6B), // coral
    ],
  );

  static const neon = BlockSkin(
    id: 'neon',
    name: 'Neon Night',
    priceCoins: 600,
    colors: [
      Color(0xFFFFB703), // amber
      Color(0xFFFF006E), // pink
      Color(0xFF00F5FF), // cyan
      Color(0xFF39FF14), // mint
      Color(0xFFB026FF), // violet
      Color(0xFFFF4365), // coral
    ],
  );

  static const pastel = BlockSkin(
    id: 'pastel',
    name: 'Soft Pastel',
    priceCoins: 600,
    colors: [
      Color(0xFFFFC98B), // amber
      Color(0xFFFFADC6), // pink
      Color(0xFFA7E3F2), // cyan
      Color(0xFFB7F0AD), // mint
      Color(0xFFCBB8F2), // violet
      Color(0xFFFFB3A7), // coral
    ],
  );

  static const sunset = BlockSkin(
    id: 'sunset',
    name: 'Sunset',
    priceCoins: 900,
    colors: [
      Color(0xFFFFA62B), // amber
      Color(0xFFE4572E), // pink slot
      Color(0xFF29335C), // cyan slot
      Color(0xFFF3A712), // mint slot
      Color(0xFF9C3848), // violet slot
      Color(0xFFDB6C79), // coral
    ],
  );

  static const all = [classic, neon, pastel, sunset];

  static BlockSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => classic);
}
