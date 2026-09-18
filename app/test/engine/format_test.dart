import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/engine/format.dart';

/// These guard a real crash. The first version of format.dart named the
/// 'en_PH' locale, which makes intl demand initializeDateFormatting() before
/// first use. Every screen showing a date threw LocaleDataException on its very
/// first build. Calling the formatters at all is what proves they are usable.
void main() {
  group('formatPeso', () {
    test('groups in threes and shows two decimals by default', () {
      expect(formatPeso(110720.5), '₱110,720.50');
      expect(formatPeso(1850), '₱1,850.00');
      expect(formatPeso(0), '₱0.00');
    });

    test('drops the decimals when asked', () {
      expect(formatPeso(38414, showDecimals: false), '₱38,414');
      expect(formatPeso(110720.5, showDecimals: false), '₱110,721');
    });

    test('always shows the absolute value, the way the prototype does', () {
      expect(formatPeso(-2840), '₱2,840.00');
    });
  });

  group('formatSignedPeso', () {
    test('income leads with a plus, spending reads plain', () {
      expect(formatSignedPeso(32500, isIncome: true), '+₱32,500.00');
      expect(formatSignedPeso(-285), '₱285.00');
    });
  });

  group('formatDateLabel', () {
    final DateTime now = DateTime(2026, 9, 18);

    test('names today and yesterday', () {
      expect(formatDateLabel('2026-09-18', now: now), 'Today');
      expect(formatDateLabel('2026-09-17', now: now), 'Yesterday');
    });

    test('older dates get a short weekday label, and do not throw', () {
      expect(formatDateLabel('2026-09-14', now: now), 'Mon, Sep 14');
    });

    test('a value that is not a date is handed back untouched', () {
      expect(formatDateLabel('not a date', now: now), 'not a date');
    });
  });
}
