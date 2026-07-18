// Pan resolvers, ported 1:1 from mobile/lib/pan/resolvers.js: intent id ->
// FACTS. The ONLY layer allowed to call the money engine; every number Pan
// says originates here from the golden-locked engines, never invented. The
// responder gets plain values it cannot change.

import '../analytics.dart'
    show
        categoryVsAverage,
        forecastMonthEnd,
        goalPace,
        healthScore,
        savingsRate;
import '../commitments.dart'
    show bankDueDate, safeToSpend, upcomingCommitments;
import '../debtmath.dart' show cardForecast, debtFreeProjection;
import '../ledger.dart' show amountOf;
import '../recap.dart' show monthRecap;
import '../schedule.dart' show daysUntilPayday, nextPayday, scheduleLabel;
import '../utang.dart' show utangAging;

/// resolvers.js num(): Number.isFinite(Number(x)) ? Number(x) : 0.
double _num(dynamic x) => amountOf(x);

const List<String> _liquid = ['cash', 'ewallet', 'checking'];

List<Map<String, dynamic>> _rows(dynamic v) => [
      for (final r in (v is List ? v : const []))
        if (r is Map) r.cast<String, dynamic>(),
    ];

bool _jsFalsy(dynamic v) =>
    v == null || v == false || v == '' || v == 0 || (v is double && v.isNaN);

typedef PanCtx = ({DateTime now, double? amount, String raw});

typedef Resolver = Map<String, dynamic> Function(
    Map<String, dynamic> data, PanCtx ctx);

final Map<String, Resolver> resolvers = {
  'safeToSpend': (data, ctx) {
    final s = safeToSpend(data, ctx.now);
    return {'kind': 'safe_to_spend', ...s};
  },
  'canAfford': (data, ctx) {
    final s = safeToSpend(data, ctx.now);
    final amount = _num(ctx.amount);
    final available = s['available'] as double;
    final daysLeft = s['daysLeft'] as int;
    return {
      'kind': 'can_afford',
      'amount': amount,
      'hasAmount': amount > 0,
      'available': available,
      'afterBuy': available - amount,
      'perDayAfter': daysLeft > 0 ? (available - amount) / daysLeft : 0.0,
      'daysLeft': daysLeft,
      'payday': s['payday'],
    };
  },
  'utang': (data, ctx) {
    final a = utangAging(data, ctx.now);
    final people = _rows(a['people']);
    final w = a['worst'] is Map
        ? (a['worst'] as Map).cast<String, dynamic>()
        : null;
    return {
      'kind': 'utang',
      'total': a['totalOutstanding'],
      'count': people.length,
      'overdueCount': a['overdueCount'],
      'worst': w != null
          ? {
              'name': w['name'],
              'outstanding': w['outstanding'],
              'daysOverdue': w['daysOverdue'],
            }
          : null,
      'top': [
        for (final p in people.take(3))
          {
            'name': p['name'],
            'outstanding': p['outstanding'],
            'daysOverdue': p['daysOverdue'],
          },
      ],
    };
  },
  'upcomingBills': (data, ctx) {
    final c = upcomingCommitments(data, ctx.now);
    return {
      'kind': 'upcoming_bills',
      'total': c['total'],
      'daysLeft': c['daysLeft'],
      'payday': c['payday'],
      'bills': [
        for (final b in _rows(c['bills']).take(6))
          {
            'name': b['name'],
            'kind': b['kind'],
            'date': b['date'],
            'amount': b['amount'],
          },
      ],
    };
  },
  'debtDue': (data, ctx) {
    final debts = [
      for (final d in _rows(data['debts']))
        if (_num(d['remaining']) > 0) d,
    ];
    final rows = <Map<String, dynamic>>[];
    for (final d in debts) {
      final bd = bankDueDate(d, ctx.now);
      final fc = cardForecast(d, data['payments'] ?? const [], ctx.now);
      final minOfBoth = _num(d['minPayment']) < _num(d['remaining'])
          ? _num(d['minPayment'])
          : _num(d['remaining']);
      final row = {
        'name': (d['name'] is String && (d['name'] as String).isNotEmpty)
            ? d['name']
            : 'Debt',
        'remaining': _num(d['remaining']),
        'due': bd?.date,
        'moved': bd != null && bd.moved,
        // fc is never null for a non-null debt, but mirror the RN fallback
        // shape faithfully: min(minPayment, remaining) || remaining.
        'minDue': fc != null
            ? fc['minDue']
            : (minOfBoth != 0 ? minOfBoth : _num(d['remaining'])),
        'lateInterest': fc != null ? fc['lateInterest'] : null,
      };
      if (row['due'] != null) rows.add(row);
    }
    // JS sorts by date ascending; stable via index tiebreak.
    final indexed = List.generate(rows.length, (i) => (rows[i], i));
    indexed.sort((a, b) {
      final c = (a.$1['due'] as DateTime).compareTo(b.$1['due'] as DateTime);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    final sorted = [for (final e in indexed) e.$1];
    return {
      'kind': 'debt_due',
      'count': debts.length,
      'soonest': sorted.isNotEmpty ? sorted.first : null,
      'rows': sorted.take(4).toList(),
    };
  },
  'debtFree': (data, ctx) {
    final debts = [
      for (final d in _rows(data['debts']))
        if (_num(d['remaining']) > 0) d,
    ];
    final extra = _num(ctx.amount);
    final base = debtFreeProjection(debts, 'avalanche', 0, ctx.now);
    final withExtra =
        extra > 0 ? debtFreeProjection(debts, 'avalanche', extra, ctx.now) : null;
    Map<String, dynamic>? pack(Map<String, dynamic>? p) => p != null
        ? {
            'months': p['months'],
            'totalInterest': p['totalInterest'],
            'date': p['date'],
          }
        : null;
    return {
      'kind': 'debt_free',
      'hasDebt': debts.isNotEmpty,
      'growing': debts.isNotEmpty && base == null,
      'base': pack(base),
      'extra': extra,
      'withExtra': pack(withExtra),
    };
  },
  'recap': (data, ctx) => {'kind': 'recap', 'recap': monthRecap(data, ctx.now)},
  'topSpending': (data, ctx) {
    final vs = categoryVsAverage(data['transactions'] ?? const [], ctx.now);
    Map<String, dynamic>? hot;
    for (final v in vs) {
      if ((v['expected'] as double) > 0 &&
          (v['now'] as double) > (v['expected'] as double) * 1.2) {
        hot = v;
        break;
      }
    }
    return {'kind': 'top_spending', 'rows': vs.take(3).toList(), 'hot': hot};
  },
  'forecast': (data, ctx) {
    final f = forecastMonthEnd(data['transactions'] ?? const [], ctx.now);
    final settings = data['settings'];
    final limit =
        _num(settings is Map ? settings['monthlyLimit'] : null);
    final projected = f['projected'] as double;
    return {
      'kind': 'forecast',
      'projected': projected,
      'spent': f['spent'],
      'limit': limit,
      'over': limit > 0 && projected > limit,
    };
  },
  'savingsRate': (data, ctx) => {
        'kind': 'savings_rate',
        'rate': savingsRate(
            data['transactions'] ?? const [], data['payments'] ?? const [], ctx.now),
      },
  'goalPace': (data, ctx) {
    final goals = [
      for (final g in _rows(data['goals']))
        if (_num(g['target']) > 0) g,
    ];
    if (goals.isEmpty) return {'kind': 'goal_pace', 'none': true};
    Map<String, dynamic>? named;
    if (ctx.raw.isNotEmpty) {
      final rawLower = ctx.raw.toLowerCase();
      for (final g in goals) {
        final name = (g['name'] ?? '').toString().toLowerCase();
        // RN truthiness: an empty goal name never matches.
        if (name.isNotEmpty && rawLower.contains(name)) {
          named = g;
          break;
        }
      }
    }
    final paces = [
      for (final g in goals)
        {
          'name': (g['name'] is String && (g['name'] as String).isNotEmpty)
              ? g['name']
              : 'Goal',
          'pace': goalPace(g, ctx.now),
        },
    ];
    Map<String, dynamic>? focus;
    if (named != null) {
      final namedName = (named['name'] is String &&
              (named['name'] as String).isNotEmpty)
          ? named['name']
          : 'Goal';
      for (final p in paces) {
        if (p['name'] == namedName) {
          focus = p;
          break;
        }
      }
    }
    if (focus == null) {
      for (final p in paces) {
        if ((p['pace'] as Map)['status'] == 'behind') {
          focus = p;
          break;
        }
      }
    }
    if (focus == null) {
      final indexed = List.generate(paces.length, (i) => (paces[i], i));
      indexed.sort((a, b) {
        final c = ((a.$1['pace'] as Map)['pct'] as num)
            .compareTo((b.$1['pace'] as Map)['pct'] as num);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });
      focus = indexed.first.$1;
    }
    return {'kind': 'goal_pace', 'focus': focus, 'count': goals.length};
  },
  'health': (data, ctx) {
    final h = healthScore(data, ctx.now);
    final hp = (h['parts'] as Map).cast<String, dynamic>();
    final parts = [
      ('savings rate', amountOf(hp['savings']), 35.0),
      ('budget discipline', amountOf(hp['budget']), 25.0),
      ('debt load', amountOf(hp['debt']), 25.0),
      ('logging habit', amountOf(hp['logging']), 15.0),
    ];
    final weakSorted = [...parts]..sort((a, b) {
        final c = (a.$2 / a.$3).compareTo(b.$2 / b.$3);
        return c != 0 ? c : parts.indexOf(a).compareTo(parts.indexOf(b));
      });
    final strongSorted = [...parts]..sort((a, b) {
        final c = (b.$2 / b.$3).compareTo(a.$2 / a.$3);
        return c != 0 ? c : parts.indexOf(a).compareTo(parts.indexOf(b));
      });
    return {
      'kind': 'health',
      'total': h['total'],
      'weakest': weakSorted.first.$1,
      'strongest': strongSorted.first.$1,
    };
  },
  'balances': (data, ctx) {
    final accts = data['accounts'] is List ? data['accounts'] as List : const [];
    var spendable = 0.0;
    var savings = 0.0;
    for (final a in accts) {
      if (a is Map && _liquid.contains(a['kind'])) {
        spendable += _num(a['balance']);
      }
      if (a is Map && a['kind'] == 'savings') savings += _num(a['balance']);
    }
    var debt = 0.0;
    for (final d in (data['debts'] is List ? data['debts'] as List : const [])) {
      debt += _num(d is Map ? d['remaining'] : null);
    }
    return {
      'kind': 'balances',
      'spendable': spendable,
      'savings': savings,
      'debt': debt,
      'hasAccounts': accts.isNotEmpty,
    };
  },
  'payday': (data, ctx) {
    final settings = data['settings'];
    final sched = settings is Map ? settings['paydaySchedule'] : null;
    if (_jsFalsy(sched)) return {'kind': 'payday', 'none': true};
    return {
      'kind': 'payday',
      'days': daysUntilPayday(ctx.now, sched),
      'next': nextPayday(ctx.now, sched),
      'label': scheduleLabel(sched),
    };
  },
};
