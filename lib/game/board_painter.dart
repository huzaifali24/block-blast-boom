import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'engine.dart';
import 'skins.dart';

/// Color every filled block turns as the board "locks up" at game over.
const kLockedGrey = Color(0xFF8C91A8);

Color _fade(Color c, double opacity) =>
    opacity >= 1 ? c : c.withValues(alpha: c.a * opacity.clamp(0.0, 1.0));

/// Paints one chunky bevelled block filling [r]: light top/left bevels, dark
/// bottom/right bevels, a softly graded face and a small gloss highlight.
void paintBlock(Canvas canvas, Rect r, Color base, {double opacity = 1}) {
  if (opacity <= 0 || r.width <= 0) return;
  final s = r.width;
  final rect = r.deflate(s * .035);
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * .13));
  final b = s * .13; // bevel thickness

  canvas.save();
  canvas.clipRRect(rr);
  canvas.drawRect(rect, Paint()..color = _fade(base, opacity));

  final tl = rect.topLeft, tr = rect.topRight;
  final bl = rect.bottomLeft, br = rect.bottomRight;
  final itl = tl + Offset(b, b), itr = tr + Offset(-b, b);
  final ibl = bl + Offset(b, -b), ibr = br + Offset(-b, -b);

  void quad(Offset a, Offset b2, Offset c, Offset d, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b2.dx, b2.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close(),
      Paint()..color = _fade(color, opacity),
    );
  }

  quad(tl, tr, itr, itl, Color.lerp(base, Colors.white, .5)!); // top
  quad(tl, itl, ibl, bl, Color.lerp(base, Colors.white, .22)!); // left
  quad(tr, br, ibr, itr, Color.lerp(base, Colors.black, .2)!); // right
  quad(bl, ibl, ibr, br, Color.lerp(base, Colors.black, .38)!); // bottom

  final face = Rect.fromPoints(itl, ibr);
  canvas.drawRect(
    face,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _fade(Color.lerp(base, Colors.white, .14)!, opacity),
          _fade(base, opacity),
        ],
      ).createShader(face),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(face.left + face.width * .1, face.top + face.height * .1,
          face.width * .32, face.height * .14),
      Radius.circular(s * .05),
    ),
    Paint()..color = Colors.white.withValues(alpha: .38 * opacity),
  );
  canvas.restore();
}

/// An empty, sunken board slot.
void paintEmptyCell(Canvas canvas, Rect r, AppTheme theme) {
  final s = r.width;
  final rr = RRect.fromRectAndRadius(r.deflate(s * .035), Radius.circular(s * .13));
  canvas.drawRRect(rr, Paint()..color = theme.boardCell);
  // Inner shadow along the top edge sells the "recessed" look.
  canvas.save();
  canvas.clipRRect(rr);
  canvas.drawRect(
    Rect.fromLTWH(rr.left, rr.top, rr.width, s * .12),
    Paint()..color = theme.boardCellEdge,
  );
  canvas.restore();
}

/// Draws [shape]'s blocks at [cell] size starting from the canvas origin.
class PiecePainter extends CustomPainter {
  const PiecePainter({
    required this.shape,
    required this.color,
    required this.cell,
    this.opacity = 1,
  });

  final PieceShape shape;
  final Color color;
  final double cell;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in shape.cells) {
      paintBlock(canvas, Rect.fromLTWH(c.x * cell, c.y * cell, cell, cell),
          color, opacity: opacity);
    }
  }

  @override
  bool shouldRepaint(covariant PiecePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.cell != cell ||
      old.opacity != opacity;
}

/// The whole playing grid: empty slots, placed blocks, the drop preview
/// (ghost piece plus every line it would complete, re-tinted in the
/// piece's color), the "just placed" pop, and the game-over grey-out.
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
        : .72 + .28 * Curves.easeOutBack.transform(popT.clamp(0, 1));

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = board.indexOf(x, y);
        final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        final v = board.cells[i];
        final inPreview = ghostColor != null &&
            (previewRows.contains(y) || previewCols.contains(x));

        if (v == -1) {
          paintEmptyCell(canvas, rect, theme);
          if (ghost.contains(i)) {
            paintBlock(canvas, rect, ghostColor!, opacity: inPreview ? 1 : .45);
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
        paintBlock(canvas, r, color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}

/// A block that was just cleared, bursting out of the board.
class ClearingCell {
  ClearingCell(this.x, this.y, this.color, this.delay, this.spin);
  final int x;
  final int y;
  final Color color;

  /// 0..1 fraction of the effect's duration before this cell starts going,
  /// so a clear sweeps outward from where the piece landed.
  final double delay;
  final double spin;
}

class Particle {
  Particle(this.origin, this.velocity, this.color, this.size, this.delay);
  final Offset origin;

  /// Pixels travelled over the particle's whole life (before gravity).
  final Offset velocity;
  final Color color;
  final double size;
  final double delay;
}

/// Builds the burst for a clear: one [ClearingCell] per cleared index and a
/// few particles each, all sweeping outward from [from] (board-local px).
({List<ClearingCell> cells, List<Particle> particles}) buildClearFx({
  required Map<int, int> cleared,
  required int boardSize,
  required double cell,
  required Offset from,
  required BlockSkin skin,
  required math.Random rng,
}) {
  final cells = <ClearingCell>[];
  final particles = <Particle>[];
  final maxDist = boardSize * cell;
  for (final e in cleared.entries) {
    final x = e.key % boardSize, y = e.key ~/ boardSize;
    final center = Offset((x + .5) * cell, (y + .5) * cell);
    final delay = ((center - from).distance / maxDist) * .32;
    final color = skin.forIndex(e.value);
    cells.add(ClearingCell(x, y, color, delay, rng.nextBool() ? 1 : -1));
    final count = cleared.length > 30 ? 2 : 3;
    for (var k = 0; k < count; k++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = cell * (1.2 + rng.nextDouble() * 2.4);
      particles.add(Particle(
        center,
        Offset(math.cos(angle), math.sin(angle) - .6) * speed,
        Color.lerp(color, Colors.white, rng.nextDouble() * .4)!,
        cell * (.16 + rng.nextDouble() * .16),
        delay + .05,
      ));
    }
  }
  return (cells: cells, particles: particles);
}

/// Animates a [buildClearFx] burst; [t] runs 0..1 over the whole effect.
class ClearFxPainter extends CustomPainter {
  ClearFxPainter({
    required this.cells,
    required this.particles,
    required this.cell,
    required this.t,
  });

  final List<ClearingCell> cells;
  final List<Particle> particles;
  final double cell;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in cells) {
      final lt = ((t - c.delay) / .45).clamp(0.0, 1.0);
      if (lt >= 1) continue;
      final center = Offset((c.x + .5) * cell, (c.y + .5) * cell);
      // Flash white first, then shrink and spin away.
      final flash = lt < .25 ? 1 - lt / .25 : 0.0;
      final scale = lt < .2 ? 1 + lt * .5 : 1.1 * (1 - Curves.easeIn.transform((lt - .2) / .8));
      final color = Color.lerp(c.color, Colors.white, .7 * flash)!;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(c.spin * Curves.easeIn.transform(lt) * .9);
      paintBlock(
        canvas,
        Rect.fromCenter(center: Offset.zero, width: cell * scale, height: cell * scale),
        color,
        opacity: 1 - lt * .4,
      );
      canvas.restore();
    }

    final paint = Paint();
    for (final p in particles) {
      final pt = ((t - p.delay) / .6).clamp(0.0, 1.0);
      if (pt <= 0 || pt >= 1) continue;
      final pos = p.origin +
          p.velocity * Curves.easeOut.transform(pt) +
          Offset(0, cell * 3.2 * pt * pt);
      final s = p.size * (1 - pt * .7);
      paint.color = p.color.withValues(alpha: 1 - pt);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(pt * 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s, height: s),
            Radius.circular(s * .25)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ClearFxPainter old) => old.t != t;
}
