// The file share/pick calls need platform channels, so they are exercised on
// device, not here. This locks the one pure part: the dated backup filename.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup_file.dart';

void main() {
  test('backupFileName is dated, zero-padded, and .json', () {
    expect(backupFileName(DateTime(2026, 7, 21)),
        'salapify-backup-2026-07-21.json');
    expect(backupFileName(DateTime(2026, 1, 5)),
        'salapify-backup-2026-01-05.json');
    expect(backupFileName(DateTime(2026, 12, 31)),
        'salapify-backup-2026-12-31.json');
  });
}
