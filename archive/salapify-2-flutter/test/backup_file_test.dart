// The file share/pick calls need platform channels, so they are exercised on
// device, not here. This locks the one pure part: the dated backup filename.
// The time is in the name ON PURPOSE (see backupFileName): every save must land
// as a new file, because overwriting an existing file through a cloud folder
// does not truncate it and a smaller backup written over a bigger one would be
// corrupt. No colons, so the name is safe on every filesystem.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup_file.dart';

void main() {
  test('backupFileName is date-and-time stamped, zero-padded, and .json', () {
    expect(
      backupFileName(DateTime(2026, 7, 21, 14, 30)),
      'salapify-backup-2026-07-21-1430.json',
    );
    expect(
      backupFileName(DateTime(2026, 1, 5, 8, 5)),
      'salapify-backup-2026-01-05-0805.json',
    );
    expect(
      backupFileName(DateTime(2026, 12, 31, 0, 0)),
      'salapify-backup-2026-12-31-0000.json',
    );
  });

  test('two saves in different minutes never suggest the same name', () {
    expect(
      backupFileName(DateTime(2026, 7, 21, 14, 30)),
      isNot(backupFileName(DateTime(2026, 7, 21, 14, 31))),
    );
  });
}
