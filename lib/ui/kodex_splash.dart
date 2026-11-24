import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'main_shell.dart';

/// Studio logo shown when the app opens, then fades into the home screen.
class KodexSplash extends StatefulWidget {
  const KodexSplash({super.key});

  @override
  State<KodexSplash> createState() => _KodexSplashState();
}

class _KodexSplashState extends State<KodexSplash>
    with SingleTickerProviderStateMixin {
  // 0-0.3 fade/scale in, 0.3-0.8 hold, 0.8-1 fade out.
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))
    ..forward().whenComplete(_goHome);

  bool _left = false;

  void _goHome() {
    if (!mounted || _left) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => const MainShell(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppState.instance.theme;
    final logo = t.dark
        ? 'assets/brand/kodex_logo_light.png'
        : 'assets/brand/kodex_logo_dark.png';
    return Scaffold(
      backgroundColor: t.background,
      body: DecoratedBox(
        // Same indigo gradient as the native launch screen, so the hand-off
        // from Android's splash to Flutter is seamless.
        decoration: BoxDecoration(gradient: t.backgroundGradient),
        child: GestureDetector(
          // Tap to skip.
          onTap: _goHome,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final v = _c.value;
                final fadeIn = Curves.easeOut.transform((v / .3).clamp(0, 1));
                final fadeOut =
                    1 - Curves.easeIn.transform(((v - .8) / .2).clamp(0, 1));
                return Opacity(
                  opacity: fadeIn * fadeOut,
                  child: Transform.scale(scale: .9 + .1 * fadeIn, child: child),
                );
              },
              child: FractionallySizedBox(
                widthFactor: .72,
                child: Image.asset(logo, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
