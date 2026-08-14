import 'package:share_plus/share_plus.dart';

import '../core/utils/mala_calculator.dart';

/// Builds beautiful spiritual share messages and hands them to the OS share
/// sheet (WhatsApp, etc.).
class ShareService {
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  String dailyMessage({
    required String name,
    required int count,
    required int goalMala,
  }) {
    final b = MalaCalculator.breakdown(count);
    return '🙏 Hari Om 🙏\n\n'
        "Today's Namjap Progress\n\n"
        'Name : ${_name(name)}\n\n'
        "Today's Count : $count\n\n"
        "Today's Mala : ${b.formatted}\n\n"
        'Daily Goal : $goalMala Mala\n\n'
        'Keep Chanting 🙏';
  }

  String weeklyMessage({required String name, required int totalCount}) {
    final b = MalaCalculator.breakdown(totalCount);
    return '🙏 Weekly Namjap Summary 🙏\n\n'
        'Name : ${_name(name)}\n\n'
        'Total Count : $totalCount\n\n'
        'Completed Mala : ${b.mala} Mala\n\n'
        'Remaining Count : ${b.remaining}\n\n'
        'Hari Om 🙏';
  }

  String monthlyMessage({required String monthName, required int totalCount}) {
    final b = MalaCalculator.breakdown(totalCount);
    return '🙏 Monthly Namjap Summary 🙏\n\n'
        'Month : $monthName\n\n'
        'Total Count : $totalCount\n\n'
        'Completed Mala : ${b.mala} Mala\n\n'
        'Hari Om 🙏';
  }

  String _name(String name) => name.trim().isEmpty ? 'Devotee' : name.trim();
}
