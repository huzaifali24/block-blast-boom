import 'package:flutter/material.dart';

/// In-game helpers the player can spend during a Classic game.
enum PowerUp {
  undo(
    label: 'Undo',
    hint: 'Takes back your last move',
    icon: Icons.undo_rounded,
    color: Color(0xFF3D9BF2),
    price: 60,
  ),
  bomb(
    label: 'Bomb',
    hint: 'Tap a cell to blast the 3×3 around it',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF2554B),
    price: 100,
  ),
  rotate(
    label: 'Rotate',
    hint: 'Tap a piece to turn it 90°',
    icon: Icons.rotate_right_rounded,
    color: Color(0xFF9B5BF5),
    price: 40,
  ),
  shuffle(
    label: 'Shuffle',
    hint: 'Swaps your pieces for three new ones',
    icon: Icons.shuffle_rounded,
    color: Color(0xFF2FBF71),
    price: 80,
  );

  const PowerUp({
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.price,
  });

  final String label;
  final String hint;
  final IconData icon;
  final Color color;

  /// Coins to buy one more.
  final int price;

  /// How many of each a new player starts with.
  static const starterCount = 2;
}

/// Revive rules.
class ReviveRules {
  static const coinPrice = 150;
  static const perGame = 1;
  static const offerSeconds = 6;
}
