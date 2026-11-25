// Generates the launcher icon set, Play Store icon and splash marks from the
// same glossy block art the game draws, so the icon always matches the game.
//
// Run from the project root:
//   flutter test tool/icon/generate_icons_test.dart
//
// (It lives outside test/ so a normal `flutter test` never rewrites assets.)
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:block_bloom/game/board_painter.dart';
import 'package:block_bloom/game/skins.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// Adaptive-icon densities: 108dp canvas, legacy icon is 48dp.
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

final _c = Skins.classic.colors;
Color get _yellow => _c[0];
Color get _red => _c[1];
Color get _green => _c[3];
Color get _orange => _c[5];
Color get _blue => _c[6];

// Everything below is drawn in a 108 x 108 unit space (the adaptive-icon
// canvas). The middle 66 units are the guaranteed-visible safe zone.

/// Indigo sunburst background.
void drawBackground(Canvas c) {
  const rect = Rect.fromLTWH(0, 0, 108, 108);
  c.drawRect(
    rect,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -.15),
        radius: .85,
        colors: [Color(0xFF7C84FF), Color(0xFF3F44BC), Color(0xFF1B1C5A)],
        stops: [0, .5, 1],
      ).createShader(rect),
  );
  // Soft rays.
  const center = Offset(54, 50);
  final ray = Paint()
    ..shader = RadialGradient(colors: [
      Colors.white.withValues(alpha: .16),
      Colors.white.withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(center: center, radius: 80));
  for (var i = 0; i < 16; i++) {
    final a = i * math.pi * 2 / 16 + .1;
    c.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a - .085) * 90, center.dy + math.sin(a - .085) * 90)
        ..lineTo(center.dx + math.cos(a + .085) * 90, center.dy + math.sin(a + .085) * 90)
        ..close(),
      ray,
    );
  }
  // Vignette.
  c.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: .75,
        colors: [Colors.transparent, Colors.black.withValues(alpha: .35)],
        stops: const [.6, 1],
      ).createShader(rect),
  );
}

void _sparkle(Canvas c, Offset at, double r, {double alpha = 1}) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final rr = i.isEven ? r : r * .28;
    final a = i * math.pi / 4 - math.pi / 2;
    final o = at + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  p.close();
  c.drawCircle(
      at,
      r * 1.2,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: .5 * alpha),
          Colors.white.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: at, radius: r * 1.2)));
  c.drawPath(p, Paint()..color = Colors.white.withValues(alpha: alpha));
}

const _cluster = Offset(51, 57); // centre of the 2x2 stack
const _b = 19.0; // block size
const _tilt = -.1; // radians
const _flyAt = Offset(71, 34);
const _flySize = 13.0;
const _flyTilt = .42;

/// The block cluster, a block bursting off it, glow and sparkles.
void drawForeground(Canvas c) {
  // Glow behind the cluster.
  c.drawCircle(
    _cluster,
    42,
    Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFF3C4).withValues(alpha: .55),
        const Color(0xFF9FB0FF).withValues(alpha: .18),
        Colors.transparent,
      ], stops: const [0, .45, 1])
          .createShader(Rect.fromCircle(center: _cluster, radius: 42)),
  );

  // Contact shadow under the stack.
  c.drawOval(
    Rect.fromCenter(center: _cluster + const Offset(1, 22), width: 46, height: 9),
    Paint()
      ..color = Colors.black.withValues(alpha: .35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  // Speed lines trailing the flying block (drawn before the stack so the
  // stack covers their tails).
  for (final (dx, dy, w) in const [(-5.0, 4.0, 2.2), (-1.0, 7.0, 1.6), (-7.0, 0.0, 1.4)]) {
    final end = _flyAt + Offset(dx, dy);
    final start = end + const Offset(-9, 9);
    c.drawLine(
      start,
      end,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w
        ..shader = LinearGradient(colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: .75),
        ]).createShader(Rect.fromPoints(start, end)),
    );
  }

  c.save();
  c.translate(_cluster.dx, _cluster.dy);
  c.rotate(_tilt);
  final blocks = [
    (const Offset(-1, -1), _yellow),
    (const Offset(0, -1), _red),
    (const Offset(-1, 0), _blue),
    (const Offset(0, 0), _green),
  ];
  for (final (o, color) in blocks) {
    BlockArt.block(c, Rect.fromLTWH(o.dx * _b, o.dy * _b, _b, _b), color);
  }
  c.restore();

  c.save();
  c.translate(_flyAt.dx, _flyAt.dy);
  c.rotate(_flyTilt);
  BlockArt.block(
      c,
      Rect.fromCenter(center: Offset.zero, width: _flySize, height: _flySize),
      _orange);
  c.restore();

  _sparkle(c, const Offset(31, 33), 5.2);
  _sparkle(c, const Offset(80, 55), 3.6, alpha: .9);
  _sparkle(c, const Offset(62, 23), 2.6, alpha: .85);
  _sparkle(c, const Offset(33, 78), 2.4, alpha: .7);
}

/// Flat white silhouette for Android 13+ themed icons.
void drawMonochrome(Canvas c) {
  final white = Paint()..color = Colors.white;
  c.save();
  c.translate(_cluster.dx, _cluster.dy);
  c.rotate(_tilt);
  for (final o in const [Offset(-1, -1), Offset(0, -1), Offset(-1, 0), Offset(0, 0)]) {
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(o.dx * _b, o.dy * _b, _b, _b).deflate(1.4),
          const Radius.circular(4)),
      white,
    );
  }
  c.restore();
  c.save();
  c.translate(_flyAt.dx, _flyAt.dy);
  c.rotate(_flyTilt);
  c.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: _flySize, height: _flySize)
            .deflate(1),
        const Radius.circular(3)),
    white,
  );
  c.restore();
}

Future<void> _png(String path, int px, void Function(Canvas c) draw) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  draw(canvas);
  final img = await rec.endRecording().toImage(px, px);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Draws [draw] (108-unit art) scaled to [px], optionally zoomed so that
/// only the central [visible] units fill the image.
void Function(Canvas) _scaled(int px, void Function(Canvas) draw,
        {double visible = 108}) =>
    (c) {
      c.scale(px / visible);
      c.translate(-(108 - visible) / 2, -(108 - visible) / 2);
      draw(c);
    };

/// A finished square icon (background + foreground), as legacy launchers
/// and the Play Store show it. [rounded] clips to a rounded square.
void Function(Canvas) _composite(int px, {required bool rounded}) => (c) {
      if (rounded) {
        final r = Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble())
            .deflate(px * .04);
        c.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(px * .22)));
      }
      // Show the same central 76 units an adaptive mask would.
      _scaled(px, (c) {
        drawBackground(c);
        drawForeground(c);
      }, visible: 76)(c);
    };

void main() {
  testWidgets('generate icons', (tester) async {
    await tester.runAsync(() async {
      for (final MapEntry(key: d, value: k) in _densities.entries) {
        final adaptive = (108 * k).round();
        await _png('$_res/mipmap-$d/ic_launcher_foreground.png', adaptive,
            _scaled(adaptive, drawForeground));
        await _png('$_res/mipmap-$d/ic_launcher_background.png', adaptive,
            _scaled(adaptive, drawBackground));
        await _png('$_res/mipmap-$d/ic_launcher_monochrome.png', adaptive,
            _scaled(adaptive, drawMonochrome));
        final legacy = (48 * k).round();
        await _png('$_res/mipmap-$d/ic_launcher.png', legacy,
            _composite(legacy, rounded: true));
      }

      // Notification small icon: white silhouette filling a 24dp square
      // (the mark spans roughly units 26..84, so show ~60 units).
      const statDensities = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96};
      for (final MapEntry(key: d, value: px) in statDensities.entries) {
        await _png('$_res/drawable-$d/ic_stat_boom.png', px,
            _scaled(px, drawMonochrome, visible: 62));
      }

      // Play Store: full-bleed square (Play applies its own mask).
      await _png('store/icon_512.png', 512, _composite(512, rounded: false));

      // Android 12+ splash icon: the system masks it to a circle 2/3 the
      // size, exactly like an adaptive foreground.
      await _png('$_res/drawable-nodpi/splash_icon.png', 768,
          _scaled(768, drawForeground));
      // Pre-12 launch screen mark (shown at 180dp).
      await _png('$_res/drawable-nodpi/launch_mark.png', 720,
          _scaled(720, drawForeground, visible: 80));
    });
  });
}
