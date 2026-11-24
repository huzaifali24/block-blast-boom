import 'engine.dart';

/// One scripted tutorial move: a prepared board, the single piece to
/// place, exactly where it must go, and what to tell the player.
class TutorialStep {
  const TutorialStep({
    required this.filled,
    required this.piece,
    required this.target,
    required this.title,
    required this.text,
  });

  /// Board indices that start filled (8x8).
  final List<int> filled;
  final PieceShape piece;
  final Cell target;
  final String title;
  final String text;
}

class Tutorial {
  Tutorial._();

  static int _i(int x, int y) => y * 8 + x;

  static final steps = <TutorialStep>[
    TutorialStep(
      filled: [for (var x = 0; x < 6; x++) _i(x, 7)],
      piece: PieceShape('domino', const [Cell(0, 0), Cell(1, 0)], PieceColor.cyan),
      target: const Cell(6, 7),
      title: 'Drag & drop',
      text: 'Drag the piece onto the glowing spot to fill the row.',
    ),
    TutorialStep(
      filled: [for (var y = 0; y < 5; y++) _i(3, y)],
      piece: PieceShape(
          'i3', const [Cell(0, 0), Cell(0, 1), Cell(0, 2)], PieceColor.amber),
      target: const Cell(3, 5),
      title: 'Columns count too',
      text: 'Fill a whole column and it clears as well.',
    ),
    TutorialStep(
      filled: [
        for (var y = 0; y < 6; y++) _i(3, y),
        for (final x in const [0, 1, 4, 5, 6, 7]) _i(x, 6),
      ],
      piece: PieceShape(
          'l3', const [Cell(0, 0), Cell(1, 0), Cell(1, 1)], PieceColor.pink),
      target: const Cell(2, 6),
      title: 'Double clear!',
      text: 'Finish a row and a column in one move for big points.',
    ),
  ];
}
