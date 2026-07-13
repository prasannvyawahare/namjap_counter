import 'package:flutter_test/flutter_test.dart';

import 'package:namjap_counter/core/utils/mala_calculator.dart';

void main() {
  group('MalaCalculator', () {
    test('324 counts is exactly 3 Mala', () {
      final b = MalaCalculator.breakdown(324);
      expect(b.mala, 3);
      expect(b.remaining, 0);
      expect(b.formatted, '3 Mala');
    });

    test('350 counts is 3 Mala + 26 Counts', () {
      final b = MalaCalculator.breakdown(350);
      expect(b.mala, 3);
      expect(b.remaining, 26);
      expect(b.formatted, '3 Mala + 26 Counts');
    });

    test('negative counts clamp to zero', () {
      final b = MalaCalculator.breakdown(-5);
      expect(b.totalCount, 0);
      expect(b.mala, 0);
    });

    test('1 remaining count uses singular label', () {
      final b = MalaCalculator.breakdown(109);
      expect(b.formatted, '1 Mala + 1 Count');
    });

    test('mala goal converts to count', () {
      expect(MalaCalculator.malaToCount(10), 1080);
    });
  });
}
