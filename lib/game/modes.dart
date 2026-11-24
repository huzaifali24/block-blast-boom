/// Which ruleset a [GameSession] (see `session.dart`) is running.
enum GameMode {
  /// Endless: a fresh random seed every game, score chase against your own
  /// best.
  classic,

  /// One board a day, seeded from the calendar date so every player sees the
  /// exact same sequence of trays. Best score of the day is what counts.
  daily,
}

/// Seeding and sizing for [GameMode.daily]. Kept separate from
/// [GameSession] so "what board does today give everyone" is a pure
/// function you can unit-test without spinning up a session.
class DailyChallenge {
  DailyChallenge._();

  static const boardSize = 8;

  /// Deterministic per-calendar-day seed. Two calls for the same date
  /// always agree, on any device, in any timezone interpretation the caller
  /// uses consistently (callers should pass a local midnight `DateTime`).
  static int seedFor(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  /// Whether [a] and [b] fall on the same daily board.
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
