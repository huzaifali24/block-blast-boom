import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/powerups.dart';

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
                  color: Color.lerp(base, Colors.black, .38),
                  borderRadius: BorderRadius.circular(widget.radius),
                  boxShadow: [
                    BoxShadow(
                      color: base.withValues(alpha: .35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
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
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .25), width: 1),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(base, Colors.white, .28)!,
                      base,
                      Color.lerp(base, Colors.black, .08)!,
                    ],
                    stops: const [0, .55, 1],
                  ),
                ),
                child: Stack(
                  children: [
                    // Glass highlight across the top half.
                    Positioned(
                      left: 6,
                      right: 6,
                      top: 3,
                      height: widget.height * .42,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(widget.radius * .8),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: .38),
                              Colors.white.withValues(alpha: .04),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Labels shrink rather than overflow on narrow screens
                    // or with large system font sizes.
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: FittedBox(
                            fit: BoxFit.scaleDown, child: widget.child),
                      ),
                    ),
                  ],
                ),
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

/// A frosted-glass card used as the base for most home/shop/me tiles.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.theme,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.glow,
  });

  final AppTheme theme;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Optional colored rim (e.g. the selected item in a grid).
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(theme.surface, Colors.white, .1)!.withValues(alpha: .92),
            theme.surface.withValues(alpha: .82),
          ],
        ),
        border: Border.all(
          color: glow ?? Colors.white.withValues(alpha: .12),
          width: glow == null ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (glow ?? Colors.black)
                .withValues(alpha: glow == null ? .25 : .45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// A gold 3D coin.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-.35, -.4),
            colors: [Color(0xFFFFF4B0), Color(0xFFFFC53A), Color(0xFFC9861A)],
            stops: [0, .55, 1],
          ),
          border: Border.all(color: const Color(0xFF9A5F0B), width: size * .07),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB524).withValues(alpha: .5),
              blurRadius: size * .4,
            ),
          ],
        ),
        child: Center(
          child: Text('\$',
              style: TextStyle(
                  fontFamily: kFont,
                  fontSize: size * .55,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9A5F0B))),
        ),
      );
}

/// The coin-count chip shown in the home/shop app bars.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins, required this.theme});

  final int coins;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 16, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 26),
          const SizedBox(width: 8),
          Text('$coins',
              style: const TextStyle(
                  fontFamily: kFont,
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Big outlined screen heading ("Shop", "Profile").
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => ArcadeText(text,
      size: 36,
      colors: const [Colors.white, Color(0xFFCFD6FF)],
      stroke: const Color(0xFF14154A));
}

/// Small caps section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, required this.theme});
  final String text;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontFamily: kFont,
                color: theme.subtext,
                fontSize: 13,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800)),
      );
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

/// A glossy round badge for a power-up.
class PowerUpIcon extends StatelessWidget {
  const PowerUpIcon({super.key, required this.p, this.size = 54});
  final PowerUp p;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-.3, -.45),
            colors: [
              Color.lerp(p.color, Colors.white, .45)!,
              p.color,
              Color.lerp(p.color, Colors.black, .35)!,
            ],
            stops: const [0, .55, 1],
          ),
          border:
              Border.all(color: Colors.white.withValues(alpha: .5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child:
            Icon(p.icon, color: Colors.white, size: size * .52, shadows: const [
          Shadow(
              color: Color(0x66000000), offset: Offset(0, 1.5), blurRadius: 2),
        ]),
      );
}
