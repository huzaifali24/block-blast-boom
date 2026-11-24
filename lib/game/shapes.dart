import 'dart:math';

/// A grid coordinate. `x` is the column, `y` is the row.
class Cell {
  const Cell(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is Cell && other.x == x && other.y == y;

  @override
  int get hashCode => x * 4099 + y;

  @override
  String toString() => '($x,$y)';
}

/// One of the colored block families a piece is drawn in. Purely cosmetic —
/// the engine only cares about shape, never color — but every placed cell
/// remembers its [PieceColor.index] so a theme (see `app/theme.dart`) can
/// pick the actual paint.
enum PieceColor { amber, pink, cyan, mint, violet, coral, blue }

/// An immutable polyomino: the cells it occupies, normalized so the
/// bounding box starts at (0,0). Two shapes with the same cells (in any
/// order) are the same shape, which is how [Shapes.all] dedupes rotations.
class PieceShape {
  PieceShape(this.family, Iterable<Cell> cells, this.color)
      : cells = List.unmodifiable(_normalize(cells));

  /// Name shared by every rotation of the same piece (e.g. "L4"). Used for
  /// anti-repeat weighting in [PieceBag], not by the board logic.
  final String family;
  final List<Cell> cells;
  final PieceColor color;

  late final int width = cells.map((c) => c.x).reduce(max) + 1;
  late final int height = cells.map((c) => c.y).reduce(max) + 1;
  late final int cellCount = cells.length;

  static List<Cell> _normalize(Iterable<Cell> cells) {
    final minX = cells.map((c) => c.x).reduce(min);
    final minY = cells.map((c) => c.y).reduce(min);
    return [for (final c in cells) Cell(c.x - minX, c.y - minY)];
  }

  /// The same cells in a different color (the bag paints each dealt piece
  /// at random, so color never hints at which shape is coming).
  PieceShape withColor(PieceColor c) => PieceShape(family, cells, c);

  /// Rotates the shape 90° clockwise about its own bounding box.
  PieceShape rotated() => PieceShape(
        family,
        [for (final c in cells) Cell(c.y, -c.x)],
        color,
      );

  /// Same cells, keyed so rotations that look identical (the square, the
  /// plus) collapse to one entry.
  String get _key =>
      (cells.toList()..sort((a, b) => a.x != b.x ? a.x - b.x : a.y - b.y))
          .map((c) => '${c.x},${c.y}')
          .join(';');

  @override
  bool operator ==(Object other) =>
      other is PieceShape && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

/// The full catalogue of piece families (one canonical orientation each) and
/// every distinct rotation of them, plus the weighted bag that deals trays.
///
/// Families are kept deliberately close to the genre's shared vocabulary —
/// single block, dominoes, the I/L/S/T/O tetrominoes, a couple of pentominoes
/// — rather than to any one game's exact piece set.
class Shapes {
  Shapes._();

  // Canonical orientation of every family. Rotations are generated below, so
  // only one representative per family needs to be hand-written.
  static final _families = <(String, List<Cell>, double)>[
    ('dot', [Cell(0, 0)], 2.0),
    ('domino', [Cell(0, 0), Cell(1, 0)], 5.0),
    ('tromino_i', [Cell(0, 0), Cell(1, 0), Cell(2, 0)], 5.0),
    ('tromino_l', [Cell(0, 0), Cell(0, 1), Cell(1, 1)], 6.0),
    ('tetromino_i', [Cell(0, 0), Cell(1, 0), Cell(2, 0), Cell(3, 0)], 3.0),
    ('tetromino_o', [Cell(0, 0), Cell(1, 0), Cell(0, 1), Cell(1, 1)], 4.0),
    ('tetromino_l',
        [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 2)], 4.0),
    ('tetromino_j',
        [Cell(1, 0), Cell(1, 1), Cell(0, 2), Cell(1, 2)], 4.0),
    ('tetromino_t',
        [Cell(0, 0), Cell(1, 0), Cell(2, 0), Cell(1, 1)], 3.5),
    ('tetromino_s',
        [Cell(1, 0), Cell(2, 0), Cell(0, 1), Cell(1, 1)], 3.0),
    ('tetromino_z',
        [Cell(0, 0), Cell(1, 0), Cell(1, 1), Cell(2, 1)], 3.0),
    ('pentomino_i',
        [Cell(0, 0), Cell(1, 0), Cell(2, 0), Cell(3, 0), Cell(4, 0)], 1.2),
    ('pentomino_plus', [
      Cell(1, 0),
      Cell(0, 1), Cell(1, 1), Cell(2, 1),
      Cell(1, 2),
    ], 1.5),
    ('pentomino_corner', [
      Cell(0, 0), Cell(1, 0), Cell(2, 0),
      Cell(0, 1), Cell(0, 2),
    ], 1.3),
    ('rect2x3', [
      Cell(0, 0), Cell(1, 0),
      Cell(0, 1), Cell(1, 1),
      Cell(0, 2), Cell(1, 2),
    ], 1.2),
    ('square3', [
      Cell(0, 0), Cell(1, 0), Cell(2, 0),
      Cell(0, 1), Cell(1, 1), Cell(2, 1),
      Cell(0, 2), Cell(1, 2), Cell(2, 2),
    ], 0.5),
  ];

  static const _colors = PieceColor.values;

  /// Every distinct oriented shape, each tagged with the sampling [weight]
  /// its whole family shares (so a 4-rotation family isn't 4x as likely to
  /// turn up as a symmetric one with a single orientation).
  static final List<(PieceShape shape, double weight)> all = () {
    final out = <(PieceShape, double)>[];
    var colorIdx = 0;
    for (final (name, cells, weight) in _families) {
      final color = _colors[colorIdx++ % _colors.length];
      final seen = <PieceShape>{};
      var shape = PieceShape(name, cells, color);
      for (var r = 0; r < 4; r++) {
        if (seen.add(shape)) out.add((shape, weight / seen.length));
        shape = shape.rotated();
      }
      // The loop above divides by the running `seen.length`, which isn't
      // quite right once rotations repeat; recompute cleanly instead.
    }
    // Recompute weights per family so the whole family sums to `weight`
    // regardless of how many distinct rotations it has.
    final byFamily = <String, List<int>>{};
    for (var i = 0; i < out.length; i++) {
      (byFamily[out[i].$1.family] ??= []).add(i);
    }
    final fixed = <(PieceShape, double)>[...out];
    for (final (name, _, weight) in _families) {
      final idxs = byFamily[name]!;
      for (final i in idxs) {
        fixed[i] = (fixed[i].$1, weight / idxs.length);
      }
    }
    return fixed;
  }();
}

/// Deals trays of 3 pieces. Draws each piece independently from the weighted
/// catalogue (small/common shapes far more often than big/awkward ones),
/// with a soft anti-repeat pass so a tray only rarely shows the same family
/// three times in a row across trays.
class PieceBag {
  PieceBag(this.rng);
  final Random rng;

  String? _lastFamily;

  PieceShape _draw() {
    var pool = Shapes.all;
    // Halve the weight of whatever family came out last, rather than
    // banning it outright — keeps variety without making any shape feel
    // unfairly rare.
    final totalWeight = pool.fold<double>(
        0, (sum, e) => sum + (e.$1.family == _lastFamily ? e.$2 * .5 : e.$2));
    var roll = rng.nextDouble() * totalWeight;
    for (final (shape, weight) in pool) {
      final w = shape.family == _lastFamily ? weight * .5 : weight;
      if (roll < w) {
        _lastFamily = shape.family;
        return shape;
      }
      roll -= w;
    }
    return pool.last.$1; // Unreachable in practice; keeps the method total.
  }

  /// Deals [count] pieces, each painted a random color with no two pieces in
  /// the same tray sharing one.
  List<PieceShape> nextTray({int count = 3}) {
    final colors = [...PieceColor.values]..shuffle(rng);
    return [
      for (var i = 0; i < count; i++)
        _draw().withColor(colors[i % colors.length]),
    ];
  }
}
