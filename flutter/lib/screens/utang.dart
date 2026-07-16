// The utang ledger: who owes you, aged. Per-person groups from the
// golden-verified utangAging engine, following the UX critique of the RN
// screens: aging lives HERE where you act (relative wording, warning color
// only for genuinely overdue money), amounts use tabular figures so pesos
// never jitter, and the calm reminder framing is preserved. Logging payments
// and marking paid arrive with the receivables engine port; this slice is
// the honest, aged view of the ledger.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/utang.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;

class UtangScreen extends StatelessWidget {
  final SalapifyStore store;
  const UtangScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final aging = utangAging(store.data, DateTime.now());
    final people = (aging['people'] as List).cast<Map<String, dynamic>>();
    final total = aging['totalOutstanding'] as double;
    final overdueTotal = aging['overdueTotal'] as double;
    final overdueCount = aging['overdueCount'] as int;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            const Text('UTANG',
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3)),
            const SizedBox(height: 4),
            const Text('Money owed to you, oldest first',
                style: TextStyle(color: Barako.muted, fontSize: 13)),
            const SizedBox(height: 20),
            if (people.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nobody owes you right now',
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text(
                          'When someone borrows, log it in the current app and '
                          'import your backup here, so it never gets awkward later.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 14,
                              height: 1.4)),
                    ],
                  ),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STILL OUT',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(formatMoney(total),
                          style: const TextStyle(
                              color: Barako.primary,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const SizedBox(height: 4),
                      Text(
                        overdueCount > 0
                            ? '${formatMoney(overdueTotal)} of it is overdue with $overdueCount ${overdueCount == 1 ? 'person' : 'people'}. Follow up gently, oldest first.'
                            : 'Nothing is overdue yet, so a gentle reminder is enough.',
                        style: TextStyle(
                            color: overdueCount > 0
                                ? Barako.warning
                                : Barako.muted,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < people.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: Barako.border),
                        _PersonRow(person: people[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Map<String, dynamic> person;
  const _PersonRow({required this.person});

  @override
  Widget build(BuildContext context) {
    final days = person['daysOverdue'] as int;
    final count = person['count'] as int;
    final overdue = days > 0;
    final sub = overdue
        ? 'Overdue $days ${days == 1 ? 'day' : 'days'}'
        : (person['oldestDue'] as String).isNotEmpty
            ? 'Due ${person['oldestDue']}'
            : 'No due date';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person['name'] as String,
                    style: const TextStyle(
                        color: Barako.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$sub · $count ${count == 1 ? 'utang' : 'utang entries'}',
                  style: TextStyle(
                      color: overdue ? Barako.warning : Barako.muted,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Text(formatMoney(person['outstanding'] as double),
              style: TextStyle(
                  color: overdue ? Barako.warning : Barako.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}
