import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The living backdrop behind every screen: the theme gradient, slowly
/// drifting pools of colored light, translucent blocks floating upward,
/// and a vignette pulling the eye to the center.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.theme, this.child});

  final AppTheme theme;
  final Widget? child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 40))
    ..repeat();

  static final _floaters = () {
    final rng = math.Random(11);
    return List.generate(
      12,
      (_) => (
        x: rng.nextDouble(),
        phase: rng.nextDouble(),
        size: 18 + rng.nextDouble() * 34,
        speed: .5 + rng.nextDouble() * .8,
        spin: (rng.nextDouble() - .5) * 2,
        hue: rng.nextInt(5),
      ),
    );
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _AmbientPainter(_c, widget.theme, _floaters),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.anim, this.theme, this.floaters) : super(repaint: anim);

  final Animation<double> anim;
  final AppTheme theme;
  final List<
      ({double x, double phase, double size, double speed, double spin, int hue})>
      floaters;

  static const _tints = [
    Color(0xFF5AA9FF),
    Color(0xFFFF5FA2),
    Color(0xFF8C6BFF),
    Color(0xFF3FE0C5),
    Color(0xFFFFC14D),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = theme.backgroundGradient.createShader(rect));

    final t = anim.value * math.pi * 2;
    // Drifting light pools.
    final pools = [
      (Offset(size.width * (.2 + .1 * math.sin(t)), size.height * (.18 + .05 * math.cos(t))),
          size.width * .9, const Color(0xFF7B8CFF), .32),
      (Offset(size.width * (.85 + .08 * math.cos(t * 2)), size.height * (.55 + .06 * math.sin(t))),
          size.width * .8, const Color(0xFFFF6FB5), .2),
      (Offset(size.width * (.3 + .1 * math.cos(t * 3)), size.height * (.92 + .03 * math.sin(t * 2))),
          size.width * .9, const Color(0xFF3FD7FF), .2),
    ];
    for (final (c, r, color, a) in pools) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: a),
            color.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // Floating translucent blocks rising slowly.
    for (final f in floaters) {
      final p = (anim.value * f.speed * 3 + f.phase) % 1;
      final y = size.height * (1.1 - p * 1.25);
      final x = size.width * f.x + math.sin(p * math.pi * 4 + f.phase * 6) * 14;
      final fade = math.sin(p * math.pi);
      final tint = _tints[f.hue];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * math.pi * f.spin);
      final r = Rect.fromCenter(center: Offset.zero, width: f.size, height: f.size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(f.size * .22)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: .22 * fade),
              tint.withValues(alpha: .05 * fade),
            ],
          ).createShader(r),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(f.size * .22)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: .12 * fade),
      );
      canvas.restore();
    }

    // Vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: .95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: .38)],
          stops: const [.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => old.theme != theme;
}

/// Slowly rotating sunburst rays (behind results and rewards).
class LightRays extends StatefulWidget {
  const LightRays({super.key, required this.size, this.color = const Color(0xFFFFE08A)});
  final double size;
  final Color color;

  @override
  State<LightRays> createState() => _LightRaysState();
}

class _LightRaysState extends State<LightRays> with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _RaysPainter(_c, widget.color),
          ),
        ),
      );
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.anim, this.color) : super(repaint: anim);
  final Animation<double> anim;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(anim.value * math.pi * 2);
    const n = 14;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: .45),
        color.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    for (var i = 0; i < n; i++) {
      final a = i * math.pi * 2 / n;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(a - .09) * r, math.sin(a - .09) * r)
        ..lineTo(math.cos(a + .09) * r, math.sin(a + .09) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      r * .55,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: .35),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * .55)),
    );
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => false;
}

/// A one-shot confetti burst falling over its whole area.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
        ..forward();

  static const _colors = [
    Color(0xFFFFC02E),
    Color(0xFFF23F5B),
    Color(0xFF26C6F0),
    Color(0xFF3FD16B),
    Color(0xFF9B5BF5),
    Color(0xFFFF8A26),
  ];

  late final _bits = () {
    final rng = math.Random();
    return List.generate(
      90,
      (_) => (
        x: rng.nextDouble(),
        vx: (rng.nextDouble() - .5) * .5,
        vy: -.4 - rng.nextDouble() * .7,
        spin: (rng.nextDouble() - .5) * 18,
        w: 6 + rng.nextDouble() * 6,
        color: _colors[rng.nextInt(_colors.length)],
        delay: rng.nextDouble() * .15,
      ),
    );
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_c, _bits),
          ),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, this.bits) : super(repaint: anim);
  final Animation<double> anim;
  final List<
      ({double x, double vx, double vy, double spin, double w, Color color, double delay})>
      bits;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final b in bits) {
      final t = ((anim.value - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      // Launched up from the lower middle, then falls under gravity.
      final x = size.width * (b.x * .6 + .2 + b.vx * t * 1.6);
      final y = size.height * (.55 + b.vy * t + 1.4 * t * t);
      paint.color = b.color.withValues(alpha: t > .8 ? (1 - t) / .2 : 1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * t);
      // Fake 3D flutter: squash one axis over time.
      canvas.scale(1, math.cos(t * b.spin).abs() * .8 + .2);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: b.w, height: b.w * .55), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}

/// Gently breathes its child's scale forever (call-to-action buttons).
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.amount = .04, this.period = 1400});
  final Widget child;
  final double amount;
  final int period;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: widget.period))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(
          scale: 1 + widget.amount * Curves.easeInOut.transform(_c.value),
          child: child,
        ),
        child: widget.child,
      );
}

/// Bobs its child up and down (floating logos).
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.distance = 6});
  final Widget child;
  final double distance;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -widget.distance * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: widget.child,
      );
}
