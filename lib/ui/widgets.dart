import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A full-width chunky 3D button in the accent color, used for every
/// primary call to action ("Play", "Claim", "Buy").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppTheme theme;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => ChunkyButton(
        color: color ?? theme.accent,
        onPressed: onPressed,
        height: 54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(
                    fontFamily: kFont,
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

/// A pill button with a darker "lip" underneath that it presses down into,
/// the tactile look arcade puzzle games use for their buttons.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.color,
    required this.onPressed,
    required this.child,
    this.height = 56,
    this.width,
    this.radius = 18,
  });

  final Color color;
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double? width;
  final double radius;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final base = enabled ? widget.color : Colors.grey;
    const lip = 5.0;
    final shift = _down ? lip - 1 : 0.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: () => _set(false),
      onTap: widget.onPressed,
      child: SizedBox(
        height: widget.height + lip,
        width: widget.width,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(base, Colors.black, .35),
                  borderRadius: BorderRadius.circular(widget.radius),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              left: 0,
              right: 0,
              top: shift,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(base, Colors.white, .18)!, base],
                  ),
                ),
                child: Center(child: widget.child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big bold text with a dark outline and a warm gradient fill, for score
/// call-outs ("Great!", "New Best!") and titles.
class ArcadeText extends StatelessWidget {
  const ArcadeText(
    this.text, {
    super.key,
    required this.size,
    this.colors = const [Color(0xFFFFF3A6), Color(0xFFFFB321)],
    this.stroke = const Color(0xFF3A1D00),
  });

  final String text;
  final double size;
  final List<Color> colors;
  final Color stroke;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: kFont,
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.05,
      letterSpacing: -.01 * size,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * .16
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: .35),
                offset: Offset(0, size * .08),
                blurRadius: size * .06,
              ),
            ],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(r),
          child: Text(text,
              textAlign: TextAlign.center,
              style: style.copyWith(color: Colors.white)),
        ),
      ],
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
