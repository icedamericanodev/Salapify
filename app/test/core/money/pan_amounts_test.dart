import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/pan/pan_amounts.dart';

/// Reading a peso figure out of a sentence.
///
/// Golden vectors, because everything the affordability answer says is
/// downstream of this one number. A wrong amount here does not produce a
/// wrong-looking answer, it produces a confident, well-formatted, completely
/// wrong one, which is the shape people act on.
void main() {
  void reads(String question, double? expected) {
    test('"$question" reads as ${expected ?? 'no amount'}', () {
      expect(extractAmount(question), expected);
    });
  }

  group('the shapes people actually type', () {
    reads('can i afford ₱2,500', 2500);
    reads('can i afford P1500', 1500);
    reads('can i afford php 1500', 1500);
    reads('can i afford 500 pesos', 500);
    reads('can i afford 500 peso', 500);
    reads('afford ko ba 2.5k', 2500);
    reads('kaya ko ba ang 10k', 10000);
    reads('what if i spend 2,500.50', 2500.5);
    reads('pwede ba bilhin ang 899', 899);
    reads('can i buy a 45000 phone', 45000);
  });

  group('what is NOT an amount', () {
    // The prototype returns a number for every one of these.
    reads('how much do i have', null);
    reads('what is safe to spend', null);
    reads('who owes me money', null);
    reads('what happened in 2025', null);
    reads('can i afford the 2026 trip', null);
    reads('show me the 15th', null);
  });

  group('a year modifies a noun, an amount ends the sentence', () {
    // Both directions are wrong answers and both are confident. Refusing
    // "can I afford 2000" because the digits fall in a year range is as bad
    // as reading "the 2026 trip" as a purchase, and nothing else in the
    // sentence separates them.
    reads('can i afford 2000', 2000);
    reads('can i afford 2026', 2026);
    reads('can i afford the 2026 trip', null);
    reads('can i afford a 1995 car', null);
    reads('can i afford 2000 pesos', 2000);
  });

  group('the thousands shortcut wins over the digits inside it', () {
    // "10k" contains "10". Reading the 10 and answering a question about ten
    // pesos is the failure this ordering exists to stop.
    reads('can i afford 10k', 10000);
    reads('afford 1.5k', 1500);
  });

  test('a marked amount beats a bare number earlier in the sentence', () {
    // "2 tickets at ₱800" is an 800 peso question, not a 2 peso one. The
    // prototype's regex takes the first run of digits and answers 2.
    expect(extractAmount('can i afford 2 tickets at ₱800'), 800);
  });

  test('an unmarked number needs the sentence to be about spending', () {
    expect(extractAmount('tell me about 3000'), isNull);
    expect(extractAmount('can i spend 3000'), 3000);
  });

  test('an absurd figure is refused rather than formatted', () {
    expect(extractAmount('can i afford 999999999999'), isNull);
  });
}
