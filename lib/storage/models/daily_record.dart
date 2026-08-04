import 'package:hive/hive.dart';

import '../../core/utils/mala_calculator.dart';

part 'daily_record.g.dart';

/// A single day's chanting total. Records are keyed in Hive by their
/// `yyyy-MM-dd` date string, so each calendar day owns exactly one record.
@HiveType(typeId: 0)
class DailyRecord extends HiveObject {
  DailyRecord({required this.date, this.count = 0});

  /// `yyyy-MM-dd` key for the day this record represents.
  @HiveField(0)
  final String date;

  @HiveField(1)
  int count;

  MalaBreakdown get breakdown => MalaCalculator.breakdown(count);

  int get mala => breakdown.mala;

  int get remaining => breakdown.remaining;

  DateTime? get dateTime {
    try {
      final parts = date.split('-').map(int.parse).toList();
      return DateTime(parts[0], parts[1], parts[2]);
    } catch (_) {
      return null;
    }
  }
}
