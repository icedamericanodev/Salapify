// Utang aging, ported 1:1 from utangAging in mobile/lib/analytics.js and
// golden-verified against it. Groups open receivables per person (a personId
// row and a legacy name-only row for the same person fold into one), sums the
// outstanding after partial payments, and ages each person by their OLDEST
// due date so the person you follow up first is the one who has owed longest.

import 'ledger.dart' show amountOf;

final RegExp _dueRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> utangAging(Map<String, dynamic> data, DateTime ref) {
  final today = DateTime(ref.year, ref.month, ref.day);

  final nameById = <String, String>{};
  for (final p in (data['people'] as List? ?? [])) {
    if (p is Map && p['id'] is String && (p['id'] as String).isNotEmpty) {
      nameById[p['id'] as String] = p['name'] is String ? p['name'] as String : '';
    }
  }

  final groups = <String, Map<String, dynamic>>{};
  final order = <String>[]; // JS Map preserves insertion order; so do we.
  for (final r in (data['receivables'] as List? ?? [])) {
    if (r is! Map || r['paid'] == true) continue;
    var paidSoFar = 0.0;
    for (final p in (r['payments'] as List? ?? [])) {
      final a = p is Map ? amountOf(p['amount']) : 0.0;
      paidSoFar += a > 0 ? a : 0;
    }
    final outstanding = amountOf(r['amount']) - paidSoFar;
    if (outstanding <= 0) continue;

    final byId = r['personId'] is String
        ? (nameById[r['personId']] ?? '').trim()
        : '';
    final byRow = r['person'] is String ? (r['person'] as String).trim() : '';
    final name = byId.isNotEmpty ? byId : (byRow.isNotEmpty ? byRow : 'Someone');

    final key = name.toLowerCase();
    var g = groups[key];
    if (g == null) {
      g = {
        'personId': r['personId'] is String ? r['personId'] : '',
        'name': name,
        'phone': '',
        'outstanding': 0.0,
        'count': 0,
        'oldestDue': null,
      };
      groups[key] = g;
      order.add(key);
    }
    if ((g['personId'] as String).isEmpty && r['personId'] is String) {
      g['personId'] = r['personId'];
    }
    g['outstanding'] = (g['outstanding'] as double) + outstanding;
    g['count'] = (g['count'] as int) + 1;
    if ((g['phone'] as String).isEmpty &&
        r['phone'] is String &&
        (r['phone'] as String).isNotEmpty) {
      g['phone'] = r['phone'];
    }
    final dm = _dueRe.firstMatch((r['dueDate'] ?? '').toString().trim());
    if (dm != null) {
      final due = DateTime(int.parse(dm.group(1)!), int.parse(dm.group(2)!),
          int.parse(dm.group(3)!));
      final oldest = g['oldestDue'] as DateTime?;
      if (oldest == null || due.isBefore(oldest)) g['oldestDue'] = due;
    }
  }

  final people = [
    for (final key in order)
      () {
        final g = groups[key]!;
        final oldest = g['oldestDue'] as DateTime?;
        return {
          'personId': g['personId'],
          'name': g['name'],
          'phone': g['phone'],
          'outstanding': g['outstanding'],
          'count': g['count'],
          'daysOverdue': oldest == null
              ? 0
              : (today.difference(oldest).inMilliseconds / 86400000)
                  .round()
                  .clamp(0, 1 << 31),
          'oldestDue': oldest == null ? '' : _isoDate(oldest),
        };
      }()
  ];

  // Longest overdue first, then biggest balance, then stable by name.
  people.sort((a, b) {
    final d = (b['daysOverdue'] as int).compareTo(a['daysOverdue'] as int);
    if (d != 0) return d;
    final o = (b['outstanding'] as double).compareTo(a['outstanding'] as double);
    if (o != 0) return o;
    return (a['name'] as String).compareTo(b['name'] as String);
  });

  final totalOutstanding =
      people.fold<double>(0, (t, p) => t + (p['outstanding'] as double));
  final overdue = people.where((p) => (p['daysOverdue'] as int) > 0).toList();
  final overdueTotal =
      overdue.fold<double>(0, (t, p) => t + (p['outstanding'] as double));
  return {
    'people': people,
    'totalOutstanding': totalOutstanding,
    'overdueTotal': overdueTotal,
    'overdueCount': overdue.length,
    'worst': people.isEmpty ? null : people.first,
  };
}
