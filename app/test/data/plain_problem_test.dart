import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';

/// Turning a plugin's error into a sentence somebody can act on.
///
/// This exists because of a real screenshot. The headline on the founder's
/// phone was a MissingPluginException naming a channel and a method, which
/// answers none of the three questions a person actually has: is my money
/// gone, was this my fault, and what do I do now.
void main() {
  group('the failures we know', () {
    test('a missing plugin becomes an instruction, not a channel name', () {
      const String raw =
          'MissingPluginException(No implementation found for method '
          'getApplicationDocumentsDirectory on channel '
          'plugins.flutter.io/path_provider)';
      final String plain = plainStorageProblem(raw);

      expect(plain, isNot(contains('MissingPluginException')));
      expect(plain, isNot(contains('plugins.flutter.io')));
      expect(plain, isNot(contains('getApplicationDocumentsDirectory')));
      expect(
        plain.toLowerCase(),
        contains('reinstall'),
        reason:
            'naming the fault without naming the fix leaves somebody staring '
            'at a red box with nothing to do about it',
      );
      expect(
        plain.toLowerCase(),
        contains('nothing already saved'),
        reason:
            'the first fear is that the money is gone. Answer it in the same '
            'breath as the bad news.',
      );
    });

    test('a full disk says so, because that one is fixable right now', () {
      final String plain = plainStorageProblem(
        'FileSystemException: ... errno = 28, No space left on device',
      );
      expect(plain.toLowerCase(), contains('storage'));
      expect(plain.toLowerCase(), contains('freeing up'));
    });

    test('a refused write points at reinstalling', () {
      expect(
        plainStorageProblem(
          'FileSystemException(..., errno = 13, '
          'Permission denied)',
        ).toLowerCase(),
        contains('permission'),
      );
    });

    test('an unreadable file avoids the word corrupted', () {
      final String plain = plainStorageProblem(
        'SnapshotFormatException: accounts is not a list',
      );
      expect(
        plain.toLowerCase(),
        isNot(contains('corrupt')),
        reason:
            '"corrupted" reads as everything is lost, when the previous copy '
            'has usually already been opened instead',
      );
      expect(plain.toLowerCase(), contains('not overwritten'));
    });
  });

  group('staying silent when it should', () {
    // The other half of the alarm, and the half that gets skipped. A
    // translator that rewrites everything is a translator that invents a
    // cause, and a confidently wrong reassurance is worse than an ugly
    // accurate line.
    test('a failure nobody has seen is passed through unchanged', () {
      const String odd = 'SomeFutureException: the flux capacitor is at 41%';
      expect(plainStorageProblem(odd), odd);
    });

    test('an empty message is not turned into a sentence', () {
      expect(plainStorageProblem(''), '');
    });

    test('a plain sentence is not translated twice', () {
      final String once = plainStorageProblem('MissingPluginException(x)');
      expect(
        plainStorageProblem(once),
        once,
        reason:
            'the banner decides whether to show the raw text by comparing it '
            'with the translation, so a second pass that changed it again '
            'would hide the detail a screenshot needs',
      );
    });
  });
}
