import 'package:flutter/material.dart';

/// Static background for the board: the playing-surface panel, a faint
/// checkerboard so empty cells read clearly at a glance, and the grid
/// lines on top. Filled/ghost blocks are drawn as ordinary widgets above
/// this (see `game_screen.dart`), not here — only the parts that never
/// animate live in the painter.
class BoardBackgroundPainter extends CustomPainter {
  const BoardBackgroundPainter({
    required this.size_,
    required this.panelColor,
    required this.lineColor,
    required this.checkerA,
    required this.checkerB,
  });

  /// Cells per side. (Named `size_`: `size` would shadow [Size].)
  final int size_;
  final Color panelColor;
  final Color lineColor;
  final Color checkerA;
  final Color checkerB;

  @override
  void paint(Canvas canvas, Size size) {
    final panel = Paint()..color = panelColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(size.width * .02)),
      panel,
    );

    final cell = size.width / size_;
    final checker = Paint();
    for (var y = 0; y < size_; y++) {
      for (var x = 0; x < size_; x++) {
        checker.color = (x + y).isEven ? checkerA : checkerB;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          checker,
        );
      }
    }

    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = size.width * .0025;
    for (var i = 0; i <= size_; i++) {
      final p = i * cell;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), grid);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), grid);
    }
  }

  @override
  bool shouldRepaint(covariant BoardBackgroundPainter old) =>
      old.size_ != size_ ||
      old.panelColor != panelColor ||
      old.lineColor != lineColor ||
      old.checkerA != checkerA ||
      old.checkerB != checkerB;
}

/// One filled (or ghost-preview) block: a rounded square with a light top
/// "bevel" and a darker bottom edge, the small 3D touch this genre's blocks
/// are known for. Reused for real blocks, the drag ghost, and tray previews.
class BlockTile extends StatelessWidget {
  const BlockTile({
    super.key,
    required this.color,
    this.opacity = 1.0,
    this.outlineOnly = false,
  });

  final Color color;
  final double opacity;

  /// Ghost-preview-only: draw just an outline in [color] instead of a solid
  /// tile (used for "this placement is invalid" feedback).
  final bool outlineOnly;

  @override
  Widget build(BuildContext context) {
    if (outlineOnly) {
      return Opacity(
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 2),
          ),
        ),
      );
    }
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, .22)!,
              color,
              Color.lerp(color, Colors.black, .12)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 2,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
