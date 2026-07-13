// Overview: the first real screen of the Flutter rebuild. Net worth from the
// same golden-verified netWorthParts the Reports use, the accounts list, and
// this month's income statement. Empty state offers the backup import (paste
// the text the RN Backup screen shows), so the founder's data carries over
// with zero extra plugins.

import 'package:flutter/material.dart';

import '../data/backup.dart';
import '../data/store.dart';
import '../main.dart' show updateStamp;
import '../money/statements.dart';
import '../theme.dart';

String formatMoney(num value) {
  final negative = value < 0;
  final rounded = (value.abs() * 100).round() / 100;
  var whole = rounded.floor();
  final cents = ((rounded - whole) * 100).round();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final centsPart = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${negative ? '-' : ''}₱$buf$centsPart';
}

class OverviewScreen extends StatelessWidget {
  final SalapifyStore store;
  const OverviewScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final data = store.data;
    final parts = netWorthParts(data);
    final istmt = incomeStatement(data, DateTime.now());
    final accounts =
        (data['accounts'] as List).cast<Map<String, dynamic>>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Row(
              children: const [
                Text('₱',
                    style: TextStyle(
                        color: Barako.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
                SizedBox(width: 10),
                Text('SALAPIFY',
                    style: TextStyle(
                        color: Barako.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3)),
              ],
            ),
            const SizedBox(height: 20),
            if (store.loadError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Your saved data could not be read, so nothing was overwritten. ${store.loadError}',
                    style: const TextStyle(color: Barako.warning),
                  ),
                ),
              ),
            _kickerCard(
              'NET WORTH',
              formatMoney(parts['netWorth'] as double),
              sub:
                  'Assets ${formatMoney(parts['assets'] as double)}  ·  Owed ${formatMoney(parts['liabilities'] as double)}',
            ),
            const SizedBox(height: 12),
            if (accounts.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kicker('MY MONEY'),
                      const SizedBox(height: 6),
                      for (final a in accounts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(a['name'] as String? ?? 'Account',
                                    style: const TextStyle(
                                        color: Barako.text, fontSize: 16)),
                              ),
                              Text(formatMoney(amount(a['balance'])),
                                  style: const TextStyle(
                                      color: Barako.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (accounts.isNotEmpty) const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kicker('THIS MONTH'),
                    const SizedBox(height: 6),
                    _line('Income earned',
                        formatMoney(istmt['income'] as double)),
                    _line('Spending', formatMoney(istmt['expenses'] as double)),
                    const Divider(),
                    _line('Net income',
                        formatMoney(istmt['netIncome'] as double),
                        strong: true,
                        color: (istmt['netIncome'] as double) >= 0
                            ? Barako.primary
                            : Barako.warning),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!store.hasData)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kicker('BRING YOUR DATA OVER'),
                      const SizedBox(height: 8),
                      const Text(
                        'Open the current Salapify app, go to Backup, copy the backup text, and paste it here. Everything comes over: accounts, entries, utang, goals, settings.',
                        style: TextStyle(
                            color: Barako.textSecondary,
                            fontSize: 14,
                            height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Barako.primary,
                            foregroundColor: Barako.onPrimary),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => ImportScreen(store: store)),
                        ),
                        child: const Text('Import backup'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update stamp',
                        style: TextStyle(color: Barako.text, fontSize: 14)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(updateStamp,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: Barako.muted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double amount(dynamic v) => v is num ? v.toDouble() : 0;

  Widget _kicker(String text) => Text(text,
      style: const TextStyle(
          color: Barako.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2));

  Widget _kickerCard(String kicker, String big, {String? sub}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kicker(kicker),
              const SizedBox(height: 6),
              Text(big,
                  style: const TextStyle(
                      color: Barako.primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w800)),
              if (sub != null) ...[
                const SizedBox(height: 4),
                Text(sub,
                    style: const TextStyle(
                        color: Barako.muted, fontSize: 13)),
              ],
            ],
          ),
        ),
      );

  Widget _line(String label, String value,
          {bool strong = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: strong ? Barako.text : Barako.muted,
                    fontSize: 15,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w400)),
            Text(value,
                style: TextStyle(
                    color: color ?? Barako.textSecondary,
                    fontSize: 15,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w600)),
          ],
        ),
      );
}

class ImportScreen extends StatefulWidget {
  final SalapifyStore store;
  const ImportScreen({super.key, required this.store});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final controller = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> _import() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.importBackupText(controller.text.trim());
      if (mounted) Navigator.of(context).pop();
    } on NewerBackupException catch (e) {
      setState(() => error = e.message);
    } on NotABackupException catch (e) {
      setState(() => error = e.message);
    } on FormatException {
      setState(() => error =
          'That text is not valid JSON. Copy the whole backup from the Backup screen and paste it unchanged.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: const Text('Import backup'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the backup text from the current Salapify app (Backup screen, copy button). Importing replaces what is in this preview app only; your current app is untouched.',
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                      color: Barako.text, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '{"app":"salapify", ...}',
                    hintStyle: const TextStyle(color: Barako.faint),
                    filled: true,
                    fillColor: Barako.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Barako.border),
                    ),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style:
                        const TextStyle(color: Barako.warning, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary),
                  onPressed: busy ? null : _import,
                  child: Text(busy ? 'Importing...' : 'Import'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
