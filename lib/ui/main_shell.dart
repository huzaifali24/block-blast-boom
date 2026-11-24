import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/sound.dart';
import '../app/theme.dart';
import 'fx.dart';
import 'home_screen.dart';
import 'me_screen.dart';
import 'rewards_ui.dart';
import 'shop_screen.dart';

/// Bottom-tab shell: Home (play), Shop, Me (stats/achievements/settings),
/// over the animated ambient background with a floating glass tab bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Greet returning players with today's login reward.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppState.instance.loginRewardReady) {
        showLoginCalendar(context);
      }
    });
  }

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.storefront_rounded, label: 'Shop'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final t = AppState.instance.theme;
        return Scaffold(
          backgroundColor: t.background,
          extendBody: true,
          body: AmbientBackground(
            theme: t,
            // With extendBody, the bottom inset already includes the
            // floating tab bar and the system navigation bar.
            child: SafeArea(
              child: IndexedStack(
                index: _tab,
                children: const [
                  HomeScreen(),
                  ShopScreen(),
                  MeScreen(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(t.surface, Colors.white, .12)!.withValues(alpha: .95),
                    t.surface.withValues(alpha: .95),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .14)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _TabButton(
                        icon: _tabs[i].icon,
                        label: _tabs[i].label,
                        selected: _tab == i,
                        theme: t,
                        onTap: () {
                          if (_tab != i) Sound.instance.play(SoundEffect.tap);
                          setState(() => _tab = i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFD45C), Color(0xFFFF9F1C)],
                )
              : null,
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x66FFA41C), blurRadius: 14)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1,
              duration: const Duration(milliseconds: 220),
              child: Icon(icon,
                  color: selected ? const Color(0xFF5A2E00) : theme.subtext,
                  size: 26),
            ),
            Text(label,
                style: TextStyle(
                    fontFamily: kFont,
                    color: selected ? const Color(0xFF5A2E00) : theme.subtext,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
