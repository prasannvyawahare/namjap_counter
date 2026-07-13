import '../constants/app_constants.dart';

/// A value object describing a count broken down into Malas and remaining
/// counts, following the rule: 108 counts = 1 Mala.
class MalaBreakdown {
  const MalaBreakdown({
    required this.totalCount,
    required this.mala,
    required this.remaining,
  });

  final int totalCount;
  final int mala;
  final int remaining;

  /// Whole-and-fractional Mala value, e.g. 350 counts -> 3.24 Mala.
  double get malaDecimal => totalCount / AppConstants.countsPerMala;

  /// Human readable mala string.
  ///
  /// * 324 counts -> "3 Mala"
  /// * 350 counts -> "3 Mala + 26 Counts"
  /// * 0 counts   -> "0 Mala"
  String get formatted {
    if (remaining == 0) {
      return '$mala Mala';
    }
    final countWord = remaining == 1 ? 'Count' : 'Counts';
    return '$mala Mala + $remaining $countWord';
  }

  /// Short form used where space is tight, e.g. "3" or "3.24".
  String get shortFormatted {
    if (remaining == 0) return '$mala';
    return malaDecimal.toStringAsFixed(2);
  }
}

/// Pure helpers for converting between counts and Malas.
class MalaCalculator {
  const MalaCalculator._();

  static MalaBreakdown breakdown(int count) {
    final safe = count < 0 ? 0 : count;
    return MalaBreakdown(
      totalCount: safe,
      mala: safe ~/ AppConstants.countsPerMala,
      remaining: safe % AppConstants.countsPerMala,
    );
  }

  /// Number of completed Malas for a given count.
  static int malaCount(int count) =>
      (count < 0 ? 0 : count) ~/ AppConstants.countsPerMala;

  /// Counts left to finish the current Mala. Returns 0 when exactly on a
  /// Mala boundary.
  static int remainingInCurrentMala(int count) =>
      (count < 0 ? 0 : count) % AppConstants.countsPerMala;

  /// Convert a goal expressed in Malas to the equivalent count.
  static int malaToCount(int mala) => mala * AppConstants.countsPerMala;
}
