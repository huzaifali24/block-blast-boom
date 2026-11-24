import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/theme.dart';
import 'home_screen.dart';
import 'me_screen.dart';
import 'shop_screen.dart';

/// Bottom-tab shell: Home (play), Shop, Me (stats/achievements/settings).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.storefront_rounded, label: 'Shop'),
    (icon: Icons.person_rounded, label: 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final t = AppState.instance.theme;
        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: const [
                HomeScreen(),
                ShopScreen(),
                MeScreen(),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: t.surface,
                border: Border(top: BorderSide(color: t.line)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _TabButton(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      selected: _tab == i,
                      theme: t,
                      onTap: () => setState(() => _tab = i),
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
    final color = selected ? theme.accent : theme.subtext;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
