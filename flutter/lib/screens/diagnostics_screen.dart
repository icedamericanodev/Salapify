// Diagnostics for testers: a local, always-on view of the safe report.
//
// The report already existed, tucked behind the Update card's "Copy
// diagnostics" button, which is where a tester goes to send a bug but not
// where they go to SEE what the app knows about itself. This surfaces the same
// safe report as its own screen under Menu > Privacy, so a tester can look at
// the counts and recent errors at any time.
//
// It is the same safe report, which is the whole point. It reads only counts
// from the store (Diagnostics.counts) and the trimmed error buffer, never a
// single amount, name, or note. Nothing here leaves the phone on its own: the
// Copy and Share buttons are the only exits, both user-initiated, so this adds
// no automatic connection and the Privacy receipt's "two connections, no third"
// stays literally true. diagnostics_screen_test.dart renders this over
// deliberately incriminating data and fails if any of it appears.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../data/store.dart';
import '../main.dart' show updateStamp;
import '../services/diagnostics.dart';
import '../theme.dart';
import '../widgets/section.dart';
import '../widgets/salapify_icon.dart';

class DiagnosticsScreen extends StatefulWidget {
  /// Optional so the screen renders in tests and on the base build; when
  /// present its counts fill the "what is stored" card.
  final SalapifyStore? store;
  const DiagnosticsScreen({super.key, this.store});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  int? _patch;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _readPatch();
  }

  Future<void> _readPatch() async {
    try {
      final patch = await ShorebirdUpdater().readCurrentPatch();
      if (mounted && patch != null) setState(() => _patch = patch.number);
    } catch (_) {
      // Shorebird is unavailable in tests and on a plain flutter build. A
      // missing patch number is not an error; the report says "base build".
    }
  }

  String _report() => Diagnostics.report(
    stamp: updateStamp,
    patch: _patch,
    data: widget.store?.data,
  );

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _report()));
    if (mounted) {
      setState(() => _status = 'Copied. Paste it in a message to report a bug.');
    }
  }

  Future<void> _share() async {
    await Share.share(_report());
    if (mounted) setState(() => _status = 'Shared.');
  }

  Future<void> _clear() async {
    await Diagnostics.clear();
    if (mounted) setState(() => _status = 'Recorded errors cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final counts = Diagnostics.counts(widget.store?.data);
    final errors = Diagnostics.recent;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Diagnostics',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _introCard(),
            const SizedBox(height: 20),
            Kicker('WHAT IS STORED, COUNTS ONLY'),
            const SizedBox(height: 8),
            _countsCard(counts),
            const SizedBox(height: 20),
            Kicker('RECENT ERRORS'),
            const SizedBox(height: 8),
            _errorsCard(errors),
            const SizedBox(height: 20),
            _actions(),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _status,
                style: TextStyle(color: Barako.celebrate, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _introCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(salapifyIcon('setup'), color: Barako.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'For testers: what the app knows about itself',
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This helps report a bug. Nothing here leaves your phone on its '
              'own. It leaves only when you tap Copy or Share below, and even '
              'then it carries just these counts and error messages, never your '
              'amounts, account or category names, notes, or anyone\'s name.',
              style: TextStyle(color: Barako.muted, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countsCard(Map<String, int> counts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Column(
          children: [
            for (final e in counts.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: TextStyle(color: Barako.text, fontSize: 14),
                    ),
                    Text(
                      '${e.value}',
                      style: TextStyle(
                        color: Barako.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorsCard(List<DiagnosticEntry> errors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: errors.isEmpty
            ? Text(
                'No errors recorded on this phone. This is the good state.',
                style: TextStyle(color: Barako.muted, fontSize: 13, height: 1.4),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${errors.length} recorded, newest last. These are error '
                    'messages and code locations only.',
                    style: TextStyle(
                      color: Barako.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final e in errors)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '[${e.when}] ${e.message}',
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Barako.primary,
            foregroundColor: Barako.onPrimary,
          ),
          onPressed: _copy,
          icon: Icon(salapifyIcon('copy'), size: 18),
          label: const Text('Copy safe report'),
        ),
        OutlinedButton.icon(
          onPressed: _share,
          icon: Icon(salapifyIcon('share'), size: 18),
          label: const Text('Share'),
        ),
        TextButton(
          onPressed: _clear,
          child: Text(
            'Clear recorded errors',
            style: TextStyle(color: Barako.textSecondary),
          ),
        ),
      ],
    );
  }
}
