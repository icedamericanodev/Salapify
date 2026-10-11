import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/settings/export_backup.dart';
import 'package:salapify/state/financial_state.dart';

/// The backup export reaches the share sheet whole (share_plus 13,
/// 2026-10-11).
///
/// Nothing tested this path before the upgrade, and it is the one that keeps
/// somebody's records safe: a share sheet that receives the wrong file, or
/// none, is found out the day the phone is lost. So this reads the file the
/// way the phone would, AT the share call, from the plugin's own channel,
/// before the export cleans up after itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel paths = MethodChannel('plugins.flutter.io/path_provider');
  const MethodChannel share = MethodChannel('dev.fluttercommunity.plus/share');

  late Directory temp;
  final List<MethodCall> calls = <MethodCall>[];
  final List<String> received = <String>[];

  setUp(() {
    temp = Directory.systemTemp.createTempSync('salapify_share_');
    calls.clear();
    received.clear();
    final TestDefaultBinaryMessenger m =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(paths, (MethodCall call) async => temp.path);
    m.setMockMethodCallHandler(share, (MethodCall call) async {
      calls.add(call);
      final Map<Object?, Object?> args =
          call.arguments as Map<Object?, Object?>;
      for (final Object? p in args['paths'] as List<Object?>) {
        received.add(File(p! as String).readAsStringSync());
      }
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
  });

  tearDown(() {
    final TestDefaultBinaryMessenger m =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(paths, null);
    m.setMockMethodCallHandler(share, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('the whole ledger reaches the share sheet as one JSON file, and the '
      'staging copy is gone afterwards', () async {
    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    state.startWithExampleData();
    final List<String> said = <String>[];

    await exportBackup(state: state, say: said.add);

    expect(calls, hasLength(1), reason: 'nothing reached the share sheet');
    final Map<Object?, Object?> args =
        calls.single.arguments as Map<Object?, Object?>;
    expect(calls.single.method, 'share');
    expect(args['mimeTypes'], <String>['application/json']);
    expect(args['subject'], startsWith('Salapify backup 2026-09-18'));
    expect(
      (args['paths'] as List<Object?>).single,
      contains('salapify3-backup-2026-09-18-'),
    );
    // The file the phone received IS the ledger, byte for byte.
    expect(received.single, state.snapshot().encode(at: state.now));
    // No clipboard fallback was needed.
    expect(said, isEmpty);
    // The staging copy is removed once the share sheet has it.
    expect(
      temp.listSync().whereType<File>().where(
        (File f) => f.path.contains('salapify3-backup'),
      ),
      isEmpty,
    );
  });
}
