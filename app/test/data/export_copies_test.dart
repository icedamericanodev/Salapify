import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/settings/export_backup.dart';

/// "Delete everything" promises nothing of the ledger is left behind, and
/// exports leave copies in the cache. This sweeps a throwaway folder laid
/// out like the phone's cache and checks both halves: every copy Salapify
/// made goes, and nothing else does.
void main() {
  late Directory cache;

  setUp(() => cache = Directory.systemTemp.createTempSync('salapify_cache'));
  tearDown(() {
    if (cache.existsSync()) cache.deleteSync(recursive: true);
  });

  File put(String name) => File('${cache.path}/$name')..writeAsStringSync('x');

  test('every export copy goes, and nothing else does', () async {
    final List<File> ours = <File>[
      put('salapify3-backup-20261008.json'),
      put('salapify-unreadable-20261008.json'),
      put('car_loan_schedule.csv'),
    ];
    final Directory shared = Directory('${cache.path}/share_plus')
      ..createSync();
    File(
      '${shared.path}/salapify3-backup-20261008.json',
    ).writeAsStringSync('x');
    final List<File> theirs = <File>[
      put('image_picker_123.jpg'),
      put('notes.json'),
    ];

    final int removed = await clearExportCopies(cache: cache);

    expect(removed, 4);
    for (final File f in ours) {
      expect(f.existsSync(), isFalse, reason: '${f.path} survived the wipe');
    }
    expect(shared.existsSync(), isFalse, reason: 'share_plus kept a copy');
    for (final File f in theirs) {
      expect(f.existsSync(), isTrue, reason: '${f.path} was not ours');
    }
  });

  test('off a phone, with no folder handed in, it touches nothing', () async {
    // The machine's own /tmp must never be swept.
    expect(await clearExportCopies(), 0);
  });
}
