import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A full-width filled button in the accent color, used for every primary
/// call to action ("Play", "Claim", "Buy").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppTheme theme;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.accent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// A rounded card used as the base for most home/shop/me tiles.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.theme,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final AppTheme theme;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.line),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// The little rounded coin-count chip shown in the home/shop app bars.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins, required this.theme});

  final int coins;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.gold.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on, color: theme.gold, size: 18),
          const SizedBox(width: 6),
          Text('$coins',
              style: TextStyle(color: theme.gold, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// A thin horizontal progress bar (missions, achievements).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.theme,
    this.color,
  });

  /// 0..1
  final double value;
  final AppTheme theme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        backgroundColor: theme.line,
        valueColor: AlwaysStoppedAnimation(color ?? theme.accent),
      ),
    );
  }
}
