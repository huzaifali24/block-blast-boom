import 'package:flutter/material.dart';

import '../app/achievements.dart';
import '../app/theme.dart';
import 'widgets.dart';

/// Queue of achievements waiting to be announced.
class AchievementToasts {
  AchievementToasts._();
  static final queue = ValueNotifier<List<AchievementDef>>(const []);

  static void show(AchievementDef a) => queue.value = [...queue.value, a];
}

/// Wraps the whole app and slides an "Achievement unlocked" banner down
/// from the top for each queued achievement, one at a time.
class AchievementBannerHost extends StatefulWidget {
  const AchievementBannerHost({super.key, required this.child});
  final Widget child;

  @override
  State<AchievementBannerHost> createState() => _AchievementBannerHostState();
}

class _AchievementBannerHostState extends State<AchievementBannerHost>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000));
  AchievementDef? _current;

  @override
  void initState() {
    super.initState();
    AchievementToasts.queue.addListener(_next);
  }

  @override
  void dispose() {
    AchievementToasts.queue.removeListener(_next);
    _c.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_current != null || AchievementToasts.queue.value.isEmpty) return;
    final q = AchievementToasts.queue.value;
    setState(() => _current = q.first);
    AchievementToasts.queue.value = q.sublist(1);
    await _c.forward(from: 0);
    if (!mounted) return;
    setState(() => _current = null);
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final a = _current;
    return Stack(
      children: [
        widget.child,
        if (a != null)
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final v = _c.value;
              // Slide in, hold, slide out.
              final show = v < .12
                  ? Curves.easeOutBack.transform(v / .12)
                  : v > .88
                      ? 1 - Curves.easeIn.transform((v - .88) / .12)
                      : 1.0;
              return Positioned(
                left: 14,
                right: 14,
                top: MediaQuery.paddingOf(context).top + 8,
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(0, -120 * (1 - show)),
                    child: Opacity(opacity: show.clamp(0, 1), child: child),
                  ),
                ),
              );
            },
            child: _Banner(a: a),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.a});
  final AchievementDef a;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
                colors: [Color(0xFF3B2A8C), Color(0xFF26206A)]),
            border: Border.all(color: const Color(0xFFFFC93C), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 18, offset: Offset(0, 8)),
              BoxShadow(color: Color(0x55FFC93C), blurRadius: 18),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-.3, -.4),
                    colors: [Color(0xFFFFF1A8), Color(0xFFFFB21E), Color(0xFFC77A0C)],
                  ),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFF8A4E00), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ACHIEVEMENT UNLOCKED',
                        style: TextStyle(
                            fontFamily: kFont,
                            color: Color(0xFFFFD45C),
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800)),
                    Text(a.title,
                        style: const TextStyle(
                            fontFamily: kFont,
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    Text(a.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: kFont,
                            color: Color(0xFFB7BBF0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const CoinIcon(size: 22),
              const SizedBox(width: 4),
              Text('+${a.coinReward}',
                  style: const TextStyle(
                      fontFamily: kFont,
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}
