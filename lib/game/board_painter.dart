import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'engine.dart';
import 'skins.dart';

/// Color every filled block turns as the board "locks up" at game over.
const kLockedGrey = Color(0xFF7D8299);

/// Pre-rendered block and cell art.
///
/// A realistic block is a dozen gradient fills; painting that for every
/// cell on every drag frame would be heavy on low-end phones. Instead each
/// (color, size) is recorded into a [ui.Picture] once and replayed, which
/// costs about as much as drawing a single rectangle.
class BlockArt {
  BlockArt._();

  static final _blocks = <int, ui.Picture>{};
  static final _cells = <int, ui.Picture>{};

  static int _key(Color c, int px) => Object.hash(c.toARGB32(), px);

  static void _trim(Map<int, ui.Picture> m) {
    if (m.length < 400) return;
    for (final p in m.values) {
      p.dispose();
    }
    m.clear();
  }

  /// Draws a glossy 3D block filling [r] (square).
  static void block(Canvas canvas, Rect r, Color base, {double opacity = 1}) {
    if (opacity <= 0 || r.width < 1) return;
    final px = r.width.round().clamp(1, 512);
    _trim(_blocks);
    final pic = _blocks[_key(base, px)] ??= _recordBlock(base, px.toDouble());
    _replay(canvas, r, px, pic, opacity);
  }

  /// Draws an empty, recessed board slot filling [r].
  static void cell(Canvas canvas, Rect r, AppTheme t) {
    final px = r.width.round().clamp(1, 512);
    _trim(_cells);
    final pic =
        _cells[Object.hash(t.name, px)] ??= _recordCell(t, px.toDouble());
    _replay(canvas, r, px, pic, 1);
  }

  static void _replay(
      Canvas canvas, Rect r, int px, ui.Picture pic, double opacity) {
    canvas.save();
    canvas.translate(r.left, r.top);
    final k = r.width / px;
    if (k != 1) canvas.scale(k);
    if (opacity < 1) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
      canvas.drawPicture(pic);
      canvas.restore();
    } else {
      canvas.drawPicture(pic);
    }
    canvas.restore();
  }

  static ui.Picture _recordBlock(Color base, double s) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final m = s * .045;
    final outer = Rect.fromLTRB(m, m, s - m, s - m);
    final radius = s * .15;

    // Soft contact shadow just below the block.
    c.drawRRect(
      RRect.fromRectAndRadius(
          outer.shift(Offset(0, s * .035)), Radius.circular(radius)),
      Paint()..color = Colors.black.withValues(alpha: .32),
    );

    // Dark outline body.
    c.drawRRect(RRect.fromRectAndRadius(outer, Radius.circular(radius)),
        Paint()..color = Color.lerp(base, Colors.black, .42)!);

    // Bevel: a vertical light→dark ramp that reads as lit top, shaded sides.
    final bevel = outer.deflate(s * .022);
    c.drawRRect(
      RRect.fromRectAndRadius(bevel, Radius.circular(radius * .9)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, Colors.white, .55)!,
            Color.lerp(base, Colors.white, .1)!,
            Color.lerp(base, Colors.black, .28)!,
          ],
          stops: const [0, .45, 1],
        ).createShader(bevel),
    );
    // Side shading so left/right bevels differ from the face.
    c.drawRRect(
      RRect.fromRectAndRadius(bevel, Radius.circular(radius * .9)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .12),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: .14),
          ],
          stops: const [0, .2, .8, 1],
        ).createShader(bevel),
    );

    // Face.
    final face = bevel.deflate(s * .1);
    final faceRR = RRect.fromRectAndRadius(face, Radius.circular(s * .08));
    c.drawRRect(
      faceRR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, .22)!,
            base,
            Color.lerp(base, Colors.black, .08)!,
          ],
        ).createShader(face),
    );
    // Thin crease where face meets bevel.
    c.drawRRect(
      faceRR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .012
        ..color = Color.lerp(base, Colors.black, .18)!.withValues(alpha: .6),
    );

    // Curved gloss across the upper face.
    final gloss = Path()
      ..moveTo(face.left, face.top + s * .06)
      ..quadraticBezierTo(face.left, face.top, face.left + s * .06, face.top)
      ..lineTo(face.right - s * .06, face.top)
      ..quadraticBezierTo(face.right, face.top, face.right, face.top + s * .06)
      ..lineTo(face.right, face.top + face.height * .34)
      ..quadraticBezierTo(face.center.dx, face.top + face.height * .52,
          face.left, face.top + face.height * .4)
      ..close();
    c.drawPath(
      gloss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .5),
            Colors.white.withValues(alpha: .06),
          ],
        ).createShader(face),
    );

    // Rim light along the top edge and a specular sparkle.
    c.drawLine(
      Offset(outer.left + radius, outer.top + s * .03),
      Offset(outer.right - radius, outer.top + s * .03),
      Paint()
        ..color = Colors.white.withValues(alpha: .65)
        ..strokeWidth = s * .022
        ..strokeCap = StrokeCap.round,
    );
    final spark =
        Offset(face.left + face.width * .2, face.top + face.height * .2);
    c.drawCircle(
        spark, s * .05, Paint()..color = Colors.white.withValues(alpha: .9));
    c.drawCircle(spark + Offset(s * .08, s * .01), s * .022,
        Paint()..color = Colors.white.withValues(alpha: .7));

    return rec.endRecording();
  }

  static ui.Picture _recordCell(AppTheme t, double s) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final r = Rect.fromLTWH(0, 0, s, s).deflate(s * .045);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(s * .15));
    c.drawRRect(rr, Paint()..color = t.boardCell);
    c.save();
    c.clipRRect(rr);
    // Inner shadow from the top (the slot is sunk into the board)...
    final top = Rect.fromLTWH(r.left, r.top, r.width, r.height * .45);
    c.drawRect(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.boardCellEdge, t.boardCell.withValues(alpha: 0)],
        ).createShader(top),
    );
    c.restore();
    // ...and a faint lip of light catching its bottom edge.
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .018
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: .25),
            Colors.white.withValues(alpha: .07),
          ],
        ).createShader(r),
    );
    return rec.endRecording();
  }
}

/// Draws [shape]'s blocks at [cell] size starting from the canvas origin.
/// With [lifted], each block also casts a soft shadow onto whatever is
/// below, so a dragged piece reads as hovering above the board.
class PiecePainter extends CustomPainter {
  const PiecePainter({
    required this.shape,
    required this.color,
    required this.cell,
    this.opacity = 1,
    this.lifted = 0,
  });

  final PieceShape shape;
  final Color color;
  final double cell;
  final double opacity;

  /// 0..1 hover height.
  final double lifted;

  @override
  void paint(Canvas canvas, Size size) {
    if (lifted > 0) {
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: .35 * lifted)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * .14);
      for (final c in shape.cells) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c.x * cell, c.y * cell, cell, cell)
                .deflate(cell * .08)
                .shift(Offset(cell * .1, cell * .3) * lifted),
            Radius.circular(cell * .15),
          ),
          shadow,
        );
      }
    }
    for (final c in shape.cells) {
      BlockArt.block(
          canvas, Rect.fromLTWH(c.x * cell, c.y * cell, cell, cell), color,
          opacity: opacity);
    }
  }

  @override
  bool shouldRepaint(covariant PiecePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.cell != cell ||
      old.opacity != opacity ||
      old.lifted != lifted;
}

/// The whole playing grid: empty slots, placed blocks, the drop preview
/// (ghost piece plus every line it would complete, re-tinted in the
/// piece's color and shimmering), the "just placed" pop, and the game-over
/// grey-out.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.board,
    required this.skin,
    required this.theme,
    this.ghostShape,
    this.ghostOrigin,
    this.ghostColor,
    this.previewRows = const [],
    this.previewCols = const [],
    this.popCells = const {},
    this.popT = 1,
    this.greyT = 0,
    this.pulse = 0,
  });

  final Board board;
  final BlockSkin skin;
  final AppTheme theme;
  final PieceShape? ghostShape;
  final Cell? ghostOrigin;
  final Color? ghostColor;
  final List<int> previewRows;
  final List<int> previewCols;

  /// Cells placed by the last move, scaled in by [popT] (0..1).
  final Set<int> popCells;
  final double popT;

  /// 0..1: how far down the board the game-over grey has spread.
  final double greyT;

  /// 0..1 looping value used to make preview lines shimmer.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    final cell = size.width / n;

    final ghost = <int>{};
    if (ghostShape != null && ghostOrigin != null) {
      for (final c in ghostShape!.cells) {
        ghost.add(board.indexOf(ghostOrigin!.x + c.x, ghostOrigin!.y + c.y));
      }
    }
    final popScale = popT >= 1
        ? 1.0
        : .7 + .3 * Curves.easeOutBack.transform(popT.clamp(0, 1));

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        BlockArt.cell(
            canvas, Rect.fromLTWH(x * cell, y * cell, cell, cell), theme);
      }
    }

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = board.indexOf(x, y);
        final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        final v = board.cells[i];
        final inPreview = ghostColor != null &&
            (previewRows.contains(y) || previewCols.contains(x));

        if (v == -1) {
          if (ghost.contains(i)) {
            BlockArt.block(canvas, rect, ghostColor!,
                opacity: inPreview ? 1 : .42);
          }
          continue;
        }

        var color = inPreview ? ghostColor! : skin.forIndex(v);
        if (greyT > 0 && y < greyT * n) color = kLockedGrey;
        final r = popCells.contains(i) && popScale != 1
            ? Rect.fromCenter(
                center: rect.center,
                width: cell * popScale,
                height: cell * popScale)
            : rect;
        BlockArt.block(canvas, r, color);
      }
    }

    // Shimmering glow over lines the current drop would complete.
    if (ghostColor != null &&
        (previewRows.isNotEmpty || previewCols.isNotEmpty)) {
      final glow = Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white
            .withValues(alpha: .08 + .12 * math.sin(pulse * math.pi * 2).abs());
      for (final y in previewRows) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(0, y * cell, size.width, cell)
                    .deflate(cell * .04),
                Radius.circular(cell * .15)),
            glow);
      }
      for (final x in previewCols) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x * cell, 0, cell, size.height)
                    .deflate(cell * .04),
                Radius.circular(cell * .15)),
            glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}

/// A block that was just cleared, bursting out of the board.
class ClearingCell {
  ClearingCell(this.x, this.y, this.color, this.delay, this.spin, this.drift);
  final int x;
  final int y;
  final Color color;

  /// 0..1 fraction of the effect's duration before this cell starts going,
  /// so a clear sweeps outward from where the piece landed.
  final double delay;
  final double spin;
  final Offset drift;
}

class Particle {
  Particle(this.origin, this.velocity, this.color, this.size, this.delay,
      {this.star = false});
  final Offset origin;

  /// Pixels travelled over the particle's whole life (before gravity).
  final Offset velocity;
  final Color color;
  final double size;
  final double delay;
  final bool star;
}

class ClearFx {
  ClearFx(this.cells, this.particles, this.rows, this.cols, this.origin,
      this.strength);
  final List<ClearingCell> cells;
  final List<Particle> particles;
  final List<int> rows;
  final List<int> cols;

  /// Board-local point the burst radiates from.
  final Offset origin;

  /// Lines cleared at once; drives the shockwave.
  final int strength;
}

/// Builds the burst for a line clear, sweeping outward from [from].
ClearFx buildClearFx({
  required PlacementResult result,
  required int boardSize,
  required double cell,
  required Offset from,
  required BlockSkin skin,
  required math.Random rng,
}) =>
    buildBurstFx(
      cleared: result.clearedCellColors,
      rows: result.clearedRows,
      cols: result.clearedCols,
      strength: result.linesCleared,
      boardSize: boardSize,
      cell: cell,
      from: from,
      skin: skin,
      rng: rng,
    );

/// Builds a burst for any set of destroyed cells (line clears, Bomb,
/// Revive): [cleared] maps board index -> color index. [rows]/[cols] get
/// light beams; [strength] >= 2 adds a shockwave.
ClearFx buildBurstFx({
  required Map<int, int> cleared,
  List<int> rows = const [],
  List<int> cols = const [],
  required int strength,
  required int boardSize,
  required double cell,
  required Offset from,
  required BlockSkin skin,
  required math.Random rng,
}) {
  final cells = <ClearingCell>[];
  final particles = <Particle>[];
  final maxDist = boardSize * cell;
  final many = cleared.length > 30;
  for (final e in cleared.entries) {
    final x = e.key % boardSize, y = e.key ~/ boardSize;
    final center = Offset((x + .5) * cell, (y + .5) * cell);
    final delay = ((center - from).distance / maxDist) * .3;
    final color = skin.forIndex(e.value);
    final away = center - from;
    final dir = away.distance < 1 ? const Offset(0, -1) : away / away.distance;
    cells.add(ClearingCell(x, y, color, delay, rng.nextBool() ? 1 : -1,
        dir * cell * (.3 + rng.nextDouble() * .4)));
    final count = many ? 3 : 4;
    for (var k = 0; k < count; k++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = cell * (1.2 + rng.nextDouble() * 2.8);
      particles.add(Particle(
        center,
        Offset(math.cos(angle), math.sin(angle) - .7) * speed,
        Color.lerp(color, Colors.white, rng.nextDouble() * .5)!,
        cell * (.12 + rng.nextDouble() * .16),
        delay + .04,
        star: rng.nextDouble() < .3,
      ));
    }
  }
  return ClearFx(cells, particles, rows, cols, from, strength);
}

/// Animates a [ClearFx]; [t] runs 0..1 over the whole effect.
class ClearFxPainter extends CustomPainter {
  ClearFxPainter({required this.fx, required this.cell, required this.t});

  final ClearFx fx;
  final double cell;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    _beams(canvas, size);
    _shockwave(canvas, size);

    for (final c in fx.cells) {
      final lt = ((t - c.delay) / .45).clamp(0.0, 1.0);
      if (lt >= 1) continue;
      final center = Offset((c.x + .5) * cell, (c.y + .5) * cell) +
          c.drift * Curves.easeIn.transform(lt);
      final flash = lt < .25 ? 1 - lt / .25 : 0.0;
      final scale = lt < .18
          ? 1 + lt * .9
          : 1.16 * (1 - Curves.easeIn.transform((lt - .18) / .82));
      final color = Color.lerp(c.color, Colors.white, .75 * flash)!;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(c.spin * Curves.easeIn.transform(lt) * 1.2);
      BlockArt.block(
        canvas,
        Rect.fromCenter(
            center: Offset.zero, width: cell * scale, height: cell * scale),
        color,
        opacity: 1 - lt * .35,
      );
      canvas.restore();
    }

    final paint = Paint()..blendMode = BlendMode.plus;
    for (final p in fx.particles) {
      final pt = ((t - p.delay) / .6).clamp(0.0, 1.0);
      if (pt <= 0 || pt >= 1) continue;
      final pos = p.origin +
          p.velocity * Curves.easeOut.transform(pt) +
          Offset(0, cell * 3.4 * pt * pt);
      final s = p.size * (1 - pt * .6);
      paint.color = p.color.withValues(alpha: (1 - pt) * .95);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(pt * 7);
      if (p.star) {
        _star(canvas, s * 1.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s, height: s),
              Radius.circular(s * .25)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _beams(Canvas canvas, Size size) {
    final bt = (t / .42).clamp(0.0, 1.0);
    if (bt >= 1) return;
    final a = (1 - bt) * (bt < .15 ? bt / .15 : 1);
    final grow = 1 + bt * 1.2;
    void beam(Rect core, bool horizontal) {
      final glowRect = horizontal
          ? Rect.fromCenter(
              center: core.center,
              width: core.width + cell,
              height: cell * grow)
          : Rect.fromCenter(
              center: core.center,
              width: cell * grow,
              height: core.height + cell);
      canvas.drawRect(
        glowRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: horizontal ? Alignment.topCenter : Alignment.centerLeft,
            end: horizontal ? Alignment.bottomCenter : Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: .85 * a),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(glowRect),
      );
    }

    for (final y in fx.rows) {
      beam(Rect.fromLTWH(0, y * cell, size.width, cell), true);
    }
    for (final x in fx.cols) {
      beam(Rect.fromLTWH(x * cell, 0, cell, size.height), false);
    }
  }

  void _shockwave(Canvas canvas, Size size) {
    if (fx.strength < 2) return;
    final st = (t / .6).clamp(0.0, 1.0);
    if (st >= 1) return;
    final r =
        Curves.easeOut.transform(st) * size.width * (.5 + fx.strength * .12);
    canvas.drawCircle(
      fx.origin,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * .35 * (1 - st)
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withValues(alpha: .55 * (1 - st)),
    );
  }

  static void _star(Canvas canvas, double s, Paint paint) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? s : s * .32;
      final a = i * math.pi / 4;
      final o = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    p.close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant ClearFxPainter old) => old.t != t;
}

/// Paints a single block (used by home/shop previews).
void paintBlock(Canvas canvas, Rect r, Color base, {double opacity = 1}) =>
    BlockArt.block(canvas, r, base, opacity: opacity);
