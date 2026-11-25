import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/ads.dart';
import '../app/app_state.dart';
import '../app/rewards.dart';
import '../app/sound.dart';
import '../app/theme.dart';
import 'fx.dart';
import 'widgets.dart';
import '../l10n/l10n.dart';

/// The icon for a reward: a coin for coins, else the first power-up.
class RewardIcon extends StatelessWidget {
  const RewardIcon({super.key, required this.reward, this.size = 40});
  final Reward reward;
  final double size;

  @override
  Widget build(BuildContext context) => reward.items.isEmpty
      ? CoinIcon(size: size)
      : PowerUpIcon(p: reward.items.keys.first, size: size);
}

Widget _sheet(AppTheme t, Widget child) => Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(t.surface, Colors.white, .14)!, t.surface],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );

// ------------------------------------------------------------ login calendar

Future<void> showLoginCalendar(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .7),
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18),
        child: _LoginCalendar(),
      ),
    );

class _LoginCalendar extends StatefulWidget {
  const _LoginCalendar();

  @override
  State<_LoginCalendar> createState() => _LoginCalendarState();
}

class _LoginCalendarState extends State<_LoginCalendar> {
  Reward? _claimed;

  void _claim() {
    final r = AppState.instance.claimLoginReward();
    if (r == null) return;
    Sound.instance.play(SoundEffect.coin);
    if (AppState.instance.hapticsOn) HapticFeedback.mediumImpact();
    setState(() => _claimed = r);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final t = app.theme;
    final today = app.loginStreakDay;
    final ready = app.loginRewardReady;

    Widget tile(int day) {
      final r = LoginCalendar.days[day - 1];
      final done = day < today || (day == today && !ready);
      final isToday = day == today && ready;
      final big = day == 7;
      Widget box = Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isToday
                ? const [Color(0xFFFFE27A), Color(0xFFFFA51C)]
                : done
                    ? [const Color(0xFF3FD16B), const Color(0xFF1E9E4F)]
                    : [
                        Colors.white.withValues(alpha: .12),
                        Colors.white.withValues(alpha: .05),
                      ],
          ),
          border: Border.all(
              color: isToday ? Colors.white : Colors.white.withValues(alpha: .12),
              width: isToday ? 2.5 : 1),
          boxShadow: isToday
              ? const [BoxShadow(color: Color(0x88FFB321), blurRadius: 16)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('DAY {n}', {'n': day}),
                style: TextStyle(
                    fontFamily: kFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isToday ? const Color(0xFF5A2E00) : Colors.white)),
            const SizedBox(height: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                RewardIcon(reward: r, size: big ? 44 : 34),
                if (done)
                  const Positioned(
                    right: -6,
                    bottom: -4,
                    child: Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              r.coins > 0 ? '${r.coins}' : '×${r.items.values.fold(0, (a, b) => a + b)}',
              style: TextStyle(
                  fontFamily: kFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isToday ? const Color(0xFF5A2E00) : Colors.white),
            ),
          ],
        ),
      );
      if (isToday) box = Pulse(amount: .05, period: 700, child: box);
      return box;
    }

    return _sheet(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArcadeText(tr('Daily Rewards'), size: 34),
          const SizedBox(height: 4),
          Text(tr('Come back every day for bigger prizes!'),
              style: t.body(14, color: t.subtext, weight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(children: [
            for (var d = 1; d <= 4; d++)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(4), child: tile(d))),
          ]),
          Row(children: [
            for (var d = 5; d <= 6; d++)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(4), child: tile(d))),
            Expanded(
                flex: 2,
                child: Padding(padding: const EdgeInsets.all(4), child: tile(7))),
          ]),
          const SizedBox(height: 14),
          if (_claimed != null) ...[
            ArcadeText('+ ${_claimed!.label}',
                size: 22,
                colors: const [Colors.white, Color(0xFFFFE27A)],
                stroke: const Color(0xFF14154A)),
            const SizedBox(height: 10),
            ChunkyButton(
              color: t.accent,
              onPressed: () => Navigator.of(context).pop(),
              child: _Label(tr('Awesome!')),
            ),
          ] else if (ready)
            Pulse(
              child: ChunkyButton(
                color: t.accent,
                height: 58,
                onPressed: _claim,
                child: _Label(tr('CLAIM'), icon: Icons.card_giftcard_rounded),
              ),
            )
          else ...[
            Text(tr('Come back tomorrow for Day {n}!', {'n': today % 7 + 1}),
                style: t.body(15, color: Colors.white, weight: FontWeight.w700)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Close'),
                  style: t.body(15, color: t.subtext, weight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
          ],
          Text(text,
              style: const TextStyle(
                  fontFamily: kFont,
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
        ],
      );
}

// ------------------------------------------------------------ lucky wheel

Future<void> showLuckyWheel(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .7),
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18),
        child: _Wheel(),
      ),
    );

class _Wheel extends StatefulWidget {
  const _Wheel();

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  final _rng = math.Random();
  double _from = 0, _to = 0;
  bool _spinning = false;
  Reward? _won;
  int _lastTick = -1;

  static const _colors = [
    Color(0xFFF23F5B),
    Color(0xFFFFC02E),
    Color(0xFF3D6CF2),
    Color(0xFF3FD16B),
    Color(0xFF9B5BF5),
    Color(0xFFFF8A26),
    Color(0xFF26C6F0),
    Color(0xFFE84393),
  ];

  @override
  void initState() {
    super.initState();
    _c.addListener(_tick);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _angle =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_c.value);

  /// Clicks as each slice edge passes the pointer.
  void _tick() {
    final n = LuckyWheel.slices.length;
    final slice = (_angle / (2 * math.pi) * n).floor();
    if (slice != _lastTick) {
      _lastTick = slice;
      if (_c.isAnimating) Sound.instance.play(SoundEffect.tap);
    }
  }

  Future<void> _spin({required bool viaAd}) async {
    if (_spinning) return;
    if (viaAd) {
      final earned = await Ads.instance.showRewarded();
      if (!earned || !mounted) return;
    }
    final n = LuckyWheel.slices.length;
    final idx = LuckyWheel.spin(_rng);
    final seg = 2 * math.pi / n;
    // Slice i is centred at i*seg (clockwise from the top pointer); the
    // wheel turns clockwise, so to bring it under the pointer we rotate by
    // -i*seg, plus a few full turns and a little jitter inside the slice.
    final current = _to % (2 * math.pi);
    final jitter = (_rng.nextDouble() - .5) * seg * .6;
    final target = 2 * math.pi * 5 + (2 * math.pi - idx * seg) + jitter;
    setState(() {
      _spinning = true;
      _won = null;
      _from = current;
      _to = target;
    });
    await _c.forward(from: 0);
    if (!mounted) return;
    final prize = LuckyWheel.slices[idx].reward;
    AppState.instance.recordSpin(prize, viaAd: viaAd);
    Sound.instance.play(SoundEffect.coin);
    if (AppState.instance.hapticsOn) HapticFeedback.heavyImpact();
    setState(() {
      _spinning = false;
      _won = prize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final t = app.theme;
    return ListenableBuilder(
      listenable: Listenable.merge([app, Ads.instance]),
      builder: (context, _) {
        final free = app.freeSpinReady;
        final adLeft = app.adSpinsLeft;
        return _sheet(
          t,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ArcadeText(tr('Lucky Spin'), size: 36),
              const SizedBox(height: 12),
              SizedBox(
                width: 290,
                height: 300,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 10,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) => Transform.rotate(
                          angle: _angle,
                          child: CustomPaint(
                            size: const Size.square(280),
                            painter: _WheelPainter(_colors),
                          ),
                        ),
                      ),
                    ),
                    // Slice icons ride on top of the painted wheel.
                    Positioned(
                      top: 10,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) => SizedBox(
                          width: 280,
                          height: 280,
                          child: Stack(
                            children: [
                              for (var i = 0; i < LuckyWheel.slices.length; i++)
                                _sliceIcon(i),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Hub.
                    Positioned(
                      top: 10 + 140 - 26,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-.3, -.4),
                            colors: [Color(0xFFFFF1A8), Color(0xFFFFB21E), Color(0xFFC77A0C)],
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                        ),
                        child: const Icon(Icons.star_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                    // Pointer.
                    const Positioned(
                      top: 0,
                      child: Icon(Icons.arrow_drop_down_rounded,
                          size: 64,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: _won == null
                    ? null
                    : ArcadeText(tr('You won {prize}!', {'prize': _won!.label}),
                        size: 22,
                        colors: const [Colors.white, Color(0xFFFFE27A)],
                        stroke: const Color(0xFF14154A)),
              ),
              const SizedBox(height: 8),
              if (free)
                Pulse(
                  child: ChunkyButton(
                    color: t.accent,
                    height: 58,
                    onPressed: _spinning ? null : () => _spin(viaAd: false),
                    child: _Label(tr('FREE SPIN'), icon: Icons.casino_rounded),
                  ),
                )
              else
                ChunkyButton(
                  color: const Color(0xFF9B5BF5),
                  height: 58,
                  onPressed: !_spinning && adLeft > 0 && Ads.instance.ready
                      ? () => _spin(viaAd: true)
                      : null,
                  child: _Label(
                      adLeft <= 0
                          ? tr('Come back tomorrow')
                          : Ads.instance.ready
                              ? tr('Spin again · Watch ad ({n})', {'n': adLeft})
                              : tr('Ad loading…'),
                      icon: Icons.smart_display_rounded),
                ),
              TextButton(
                onPressed: _spinning ? null : () => Navigator.of(context).pop(),
                child: Text(tr('Close'),
                    style: t.body(15, color: t.subtext, weight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sliceIcon(int i) {
    final n = LuckyWheel.slices.length;
    final a = _angle + i * 2 * math.pi / n - math.pi / 2;
    const r = 96.0;
    final c = Offset(140 + math.cos(a) * r, 140 + math.sin(a) * r);
    final reward = LuckyWheel.slices[i].reward;
    return Positioned(
      left: c.dx - 22,
      top: c.dy - 26,
      child: SizedBox(
        width: 44,
        child: Column(
          children: [
            RewardIcon(reward: reward, size: 30),
            Text(reward.coins > 0 ? '${reward.coins}' : tr(reward.items.keys.first.label),
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: const TextStyle(
                    fontFamily: kFont,
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 3)])),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.colors);
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final n = LuckyWheel.slices.length;
    final seg = 2 * math.pi / n;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF14154A));
    final rect = Rect.fromCircle(center: c, radius: r - 8);
    for (var i = 0; i < n; i++) {
      // Slice i centred on angle i*seg measured from the top.
      final start = -math.pi / 2 + i * seg - seg / 2;
      final base = colors[i % colors.length];
      canvas.drawArc(
        rect,
        start,
        seg,
        true,
        Paint()
          ..shader = RadialGradient(colors: [
            Color.lerp(base, Colors.white, .35)!,
            base,
            Color.lerp(base, Colors.black, .2)!,
          ], stops: const [0, .6, 1])
              .createShader(rect),
      );
      final edge = Offset(c.dx + math.cos(start) * (r - 8), c.dy + math.sin(start) * (r - 8));
      canvas.drawLine(c, edge, Paint()
        ..color = Colors.white.withValues(alpha: .6)
        ..strokeWidth = 2);
    }
    // Rim with light bulbs.
    canvas.drawCircle(
        c,
        r - 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0xFFFFC93C));
    for (var i = 0; i < n * 2; i++) {
      final a = i * math.pi / n;
      canvas.drawCircle(Offset(c.dx + math.cos(a) * (r - 4), c.dy + math.sin(a) * (r - 4)),
          3, Paint()..color = i.isEven ? Colors.white : const Color(0xFFFFF4C2));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => false;
}
