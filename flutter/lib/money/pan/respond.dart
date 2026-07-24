// Pan responder, ported 1:1 from mobile/lib/pan/respond.js: FACTS -> reply
// map { mood, text, cta?, reminder? }. The phrasing layer only; it receives
// numbers it did not compute and cannot change. Every string here is byte
// identical to the RN copy, golden-verified.

import '../debtmath.dart' show formatMoneyText;
import '../ledger.dart' show amountOf;

const List<String> _mon = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const List<String> _day = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// RN m(): formatMoney(Math.round(Number(n) || 0)).
String _m(dynamic n) => formatMoneyText(amountOf(n));

double _jsRound(num x) => (x + 0.5).floorToDouble();

String _fmtDate(dynamic d) {
  final DateTime? dt = d is DateTime
      ? d
      : (d != null ? DateTime.tryParse(d.toString()) : null);
  if (dt == null) return '';
  return '${_day[dt.weekday % 7]}, ${_mon[dt.month - 1]} ${dt.day}';
}

/// Goal target dates are "YYYY-MM" or "YYYY-MM-DD"; formatted by hand so a
/// month-only target never gets a spurious day.
String _fmtTarget(dynamic iso) {
  final mt = RegExp(
    r'^(\d{4})-(\d{2})(?:-(\d{2}))?$',
  ).firstMatch((iso ?? '').toString().trim());
  if (mt == null) return '';
  final monNum = int.parse(mt.group(2)!);
  if (monNum < 1 || monNum > 12) return '';
  final mon = _mon[monNum - 1];
  return mt.group(3) != null
      ? '$mon ${int.parse(mt.group(3)!)}, ${mt.group(1)}'
      : '$mon ${mt.group(1)}';
}

Map<String, dynamic> respond(Map<String, dynamic> facts) {
  switch (facts['kind']) {
    case 'safe_to_spend':
      {
        if ((facts['available'] as double) <= 0) {
          return {
            'mood': 'worried',
            'text':
                'The bills and minimums due before your ${_fmtDate(facts['payday'])} payday already use up your spendable cash. Best to hold off on extras until then. This counts only the bills you have logged, so add any I am missing.',
            'cta': {'label': 'See what is committed', 'route': '/insights'},
          };
        }
        return {
          'mood': 'idle',
          'text':
              'You have ${_m(facts['available'])} free to spend until your ${_fmtDate(facts['payday'])} payday, about ${_m(facts['perDay'])} a day for ${facts['daysLeft']} days. '
              'That already sets aside ${_m(facts['committed'])} for bills and minimums, and it does not touch your savings, on purpose.',
          'cta': {'label': 'See the breakdown', 'route': '/insights'},
        };
      }

    case 'can_afford':
      {
        if (facts['hasAmount'] != true) {
          return {
            'mood': 'idle',
            'text':
                'Tell me the price and I will check it against what you can safely spend, like "can I afford 2000".',
          };
        }
        if ((facts['afterBuy'] as double) < 0) {
          return {
            'mood': 'worried',
            'text':
                'A ${_m(facts['amount'])} buy is more than the ${_m(facts['available'])} you have safe until payday. If it can wait until after ${_fmtDate(facts['payday'])}, that is the safer call.',
          };
        }
        final perDayAfter = facts['perDayAfter'] as double;
        return {
          'mood': 'happy',
          'text':
              'You have ${_m(facts['available'])} safe until payday. A ${_m(facts['amount'])} buy leaves ${_m(facts['afterBuy'])}, about ${_m(facts['perDayAfter'])} a day for ${facts['daysLeft']} days. ${perDayAfter < 100 ? 'Doable, but tight.' : 'Comfortably doable.'}',
        };
      }

    case 'utang':
      {
        if (facts['count'] == 0) {
          return {
            'mood': 'idle',
            'text':
                'No one owes you right now, your IOU list is clear. When you lend, log it here and I will track who to follow up.',
          };
        }
        final w = facts['worst'] as Map<String, dynamic>?;
        final count = facts['count'] as int;
        final overdue = w != null && (w['daysOverdue'] as int) > 0;
        final lead = overdue
            ? '$count ${count == 1 ? 'person owes' : 'people owe'} you ${_m(facts['total'])} total. Follow up ${w['name']} first, ${_m(w['outstanding'])} and ${w['daysOverdue']} ${w['daysOverdue'] == 1 ? 'day' : 'days'} past due.'
            : '$count ${count == 1 ? 'person owes' : 'people owe'} you ${_m(facts['total'])} total. Nothing is overdue yet, a gentle reminder is enough.';
        final reminder = w != null
            ? 'Hi ${w['name']}, gentle reminder about the ${_m(w['outstanding'])} when you get the chance. Thank you!'
            : null;
        return {
          'mood': overdue ? 'worried' : 'idle',
          'text':
              '$lead Collecting is not being stingy, a calm reminder keeps both the money and the friendship healthy.',
          'reminder': reminder,
          'cta': {'label': 'Open Utang', 'route': '/receivables'},
        };
      }

    case 'upcoming_bills':
      {
        final bills = (facts['bills'] as List).cast<Map<String, dynamic>>();
        if (bills.isEmpty) {
          return {
            'mood': 'idle',
            'text':
                'No bills logged before your ${_fmtDate(facts['payday'])} payday. If you have some coming, add them so I can protect that cash for you.',
          };
        }
        final lines = bills
            .map(
              (b) =>
                  '${b['name']} ${_m(b['amount'])}${!_falsy(b['date']) ? ' (${_fmtDate(b['date'])})' : ''}',
            )
            .join(', ');
        return {
          'mood': 'idle',
          'text':
              'Before your ${_fmtDate(facts['payday'])} payday: $lines. Total ${_m(facts['total'])}. Keep that parked so nothing bounces.',
          'cta': {'label': 'See bills', 'route': '/insights'},
        };
      }

    case 'debt_due':
      {
        final s = facts['soonest'] as Map<String, dynamic>?;
        if (s == null) {
          final count = facts['count'] as int;
          return {
            'mood': count != 0 ? 'idle' : 'happy',
            'text': count != 0
                ? 'None of your debts have a due date set. Add one and I will remind you before it lands.'
                : 'No debts to pay, nice. Debt free is a strong place to be.',
          };
        }
        final interest = !_falsy(s['lateInterest'])
            ? ' Paying only the minimum adds about ${_m(s['lateInterest'])} interest next month.'
            : '';
        return {
          'mood': 'idle',
          'text':
              'Soonest: ${s['name']}, due ${_fmtDate(s['due'])}${s['moved'] == true ? ' (moved to the next banking day)' : ''}, balance ${_m(s['remaining'])}. '
              'Pay in full to stay interest free, or at least the ${_m(s['minDue'])} minimum.$interest',
          'cta': {'label': 'Open debts', 'route': '/debts'},
        };
      }

    case 'debt_free':
      {
        if (facts['hasDebt'] != true) {
          return {
            'mood': 'happy',
            'text':
                'You have no debts to pay off. That is the finish line most people are working toward, and you are already there.',
          };
        }
        final withExtra = facts['withExtra'] as Map<String, dynamic>?;
        if (facts['growing'] == true) {
          if (withExtra != null) {
            return {
              'mood': 'idle',
              'text':
                  'At the current minimums, interest is outpacing your payments, so the balance is not going down. But adding ${_m(facts['extra'])} a month gets you to debt free around ${_fmtDate(withExtra['date'])}. Paying more than the minimum is the way out.',
              'cta': {'label': 'Plan payoff', 'route': '/reports'},
            };
          }
          return {
            'mood': 'worried',
            'text':
                'At the current minimums, interest is outpacing your payments, so the balance is not going down. Paying more than the minimum, even a little, is what turns it around. Try "if I add 1000 a month" to see the difference.',
            'cta': {'label': 'Plan payoff', 'route': '/reports'},
          };
        }
        final baseFacts = facts['base'] as Map<String, dynamic>;
        final base =
            'Paying current minimums, you are debt free around ${_fmtDate(baseFacts['date'])} with about ${_m(baseFacts['totalInterest'])} total interest.';
        if (withExtra != null) {
          return {
            'mood': 'happy',
            'text':
                '$base Adding ${_m(facts['extra'])} a month moves that to ${_fmtDate(withExtra['date'])} and cuts interest to about ${_m(withExtra['totalInterest'])}. Small extra, big difference.',
            'cta': {'label': 'Plan payoff', 'route': '/reports'},
          };
        }
        return {
          'mood': 'idle',
          'text':
              '$base Try asking "if I add 1000 a month" to see how much sooner you finish.',
          'cta': {'label': 'Plan payoff', 'route': '/reports'},
        };
      }

    case 'recap':
      {
        final r = (facts['recap'] as Map).cast<String, dynamic>();
        final keptRate = r['keptRate'] as double?;
        final daysLogged = r['daysLogged'] as int;
        final kept = keptRate == null
            ? '$daysLogged ${daysLogged == 1 ? 'day' : 'days'} logged'
            : keptRate < 0
            ? 'spending passed income'
            : 'you kept ${_jsRound(keptRate * 100).toInt()}%';
        final topCats = (r['topCats'] as List).cast<Map<String, dynamic>>();
        final top = topCats.isNotEmpty
            ? ' Top spend was ${topCats.first['label']} at ${(topCats.first['pct'] as num).toInt()}%.'
            : '';
        return {
          'mood': keptRate != null && keptRate >= 0.2 ? 'happy' : 'idle',
          'text':
              '${r['label']}: ${keptRate != null ? '${_m(r['moneyIn'])} in, ${_m(r['moneyOut'])} out, $kept.' : '$kept.'}$top ${r['verdict']}',
          'cta': {'label': 'Make a share card', 'route': '/insights'},
        };
      }

    case 'top_spending':
      {
        final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
        if (rows.isEmpty) {
          return {
            'mood': 'idle',
            'text':
                'Not enough spending logged yet to spot a pattern. Log a few more and I will show where it goes.',
          };
        }
        final hot = facts['hot'] as Map<String, dynamic>?;
        if (hot != null) {
          final hotAmt = _jsRound(
            (hot['now'] as double) - (hot['expected'] as double),
          );
          return {
            'mood': 'worried',
            'text':
                '${hot['label']} is at ${_m(hot['now'])} this month. For this point your usual pace is about ${_m(hot['expected'])}, so you are running roughly ${_m(hotAmt)} hot. Easing back frees that before payday.',
            'cta': {'label': 'See categories', 'route': '/insights'},
          };
        }
        final top = rows.first;
        return {
          'mood': 'idle',
          'text':
              'Your biggest category this month is ${top['label']} at ${_m(top['now'])}, in line with your normal pace. Nothing running hot right now.',
          'cta': {'label': 'See categories', 'route': '/insights'},
        };
      }

    case 'forecast':
      {
        final base =
            "At today's pace you are on track to spend about ${_m(facts['projected'])} by month end.";
        final limit = facts['limit'] as double;
        if (limit > 0) {
          return {
            'mood': facts['over'] == true ? 'worried' : 'happy',
            'text': facts['over'] == true
                ? '$base Your limit is ${_m(limit)}, so roughly ${_m((facts['projected'] as double) - limit)} over. Trimming a little each day gets you back under.'
                : '$base That is under your ${_m(limit)} limit, you are on track.',
          };
        }
        return {
          'mood': 'idle',
          'text':
              '$base Set a monthly budget and I will tell you if you are on track to stay under.',
        };
      }

    case 'savings_rate':
      {
        final rate = facts['rate'] as double?;
        if (rate == null) {
          return {
            'mood': 'idle',
            'text':
                'Log some income this month and I can show your savings rate, the share of income you kept.',
          };
        }
        if (rate < 0) {
          return {
            'mood': 'worried',
            'text':
                'Your spending outran your income this month, so nothing was saved and you dipped into reserves. No shame, it happens. The fix is one category at a time, and I can show which one ran hottest.',
          };
        }
        final pct = _jsRound(rate * 100).toInt();
        return {
          'mood': pct >= 20 ? 'happy' : 'idle',
          'text':
              'This month you kept $pct% of your income. A common starter target is 20%, ${pct >= 20 ? 'and you are there. Strong.' : 'so you are close.'} Debt payments count as money out here, so paying down debt is progress too.',
        };
      }

    case 'goal_pace':
      {
        if (facts['none'] == true) {
          return {
            'mood': 'idle',
            'text':
                'You have no savings goals yet. Add one, like a Christmas fund or emergency fund, and I will pace it for you.',
            'cta': {'label': 'Add a goal', 'route': '/goals'},
          };
        }
        final f = (facts['focus'] as Map).cast<String, dynamic>();
        final p = (f['pace'] as Map).cast<String, dynamic>();
        if (p['status'] == 'done') {
          return {
            'mood': 'happy',
            'text':
                'Your ${f['name']} is fully funded. Time to set the next one.',
            'cta': {'label': 'Goals', 'route': '/goals'},
          };
        }
        final pctStr =
            '${f['name']} is ${_jsRound((p['pct'] as num) * 100).toInt()}%';
        if (p['status'] == 'active') {
          final perMonth = amountOf(p['perMonth']);
          final nudge = perMonth > 0 && perMonth <= 3000
              ? ' That is one small habit change.'
              : ' Set that aside each payday and you stay on track.';
          return {
            'mood': 'idle',
            'text':
                '$pctStr. To finish by ${_fmtTarget(p['targetDate'])} you need about ${_m(p['perMonth'])} a month, or ${_m(p['perWeek'])} a week.$nudge',
            'cta': {'label': 'Goals', 'route': '/goals'},
          };
        }
        if (p['status'] == 'due-soon') {
          return {
            'mood': 'idle',
            'text':
                '$pctStr. Your ${_fmtTarget(p['targetDate'])} target lands this month, so you would need about ${_m(p['remaining'])} more to finish on time. Even part of it keeps you close.',
            'cta': {'label': 'Goals', 'route': '/goals'},
          };
        }
        if (p['status'] == 'behind') {
          return {
            'mood': 'worried',
            'text':
                '$pctStr, and the target date has passed with ${_m(p['remaining'])} still to go. Set a fresh date and I will give you a new weekly pace.',
            'cta': {'label': 'Goals', 'route': '/goals'},
          };
        }
        return {
          'mood': 'idle',
          'text':
              '$pctStr, ${_m(p['remaining'])} to go. Add a target date and I will pace it for you.',
          'cta': {'label': 'Goals', 'route': '/goals'},
        };
      }

    case 'health':
      {
        return {
          'mood': (facts['total'] as num) >= 60 ? 'happy' : 'idle',
          'text':
              'Your money health is ${(facts['total'] as num).toInt()} out of 100. Strongest: ${facts['strongest']}. Weakest: ${facts['weakest']}. Working on that one is the fastest way to raise your score.',
          'cta': {'label': 'See the full score', 'route': '/insights'},
        };
      }

    case 'balances':
      {
        if (facts['hasAccounts'] != true) {
          return {
            'mood': 'idle',
            'text':
                'You have no accounts set up yet. Add your cash, GCash, or bank so I can track what you have.',
            'cta': {'label': 'Add accounts', 'route': '/accounts'},
          };
        }
        final debt = facts['debt'] as double;
        final savings = facts['savings'] as double;
        final debtLine = debt > 0 ? ' You also owe ${_m(debt)} on debts.' : '';
        return {
          'mood': 'idle',
          'text':
              'You have ${_m(facts['spendable'])} spendable in cash and e-wallets${savings > 0 ? ', plus ${_m(savings)} in savings' : ''}.$debtLine Savings are yours to protect, not daily spending money.',
          'cta': {'label': 'See accounts', 'route': '/accounts'},
        };
      }

    case 'payday':
      {
        if (facts['none'] == true) {
          return {
            'mood': 'idle',
            'text':
                'Set your payday schedule in More and I will count down to your payday and figure your safe to spend.',
            'cta': {'label': 'Set payday', 'route': '/(tabs)/more'},
          };
        }
        final d = facts['days'] as int;
        return {
          'mood': 'idle',
          'text':
              'Your next payday is ${_fmtDate(facts['next'])}, ${d <= 0 ? 'today' : '$d ${d == 1 ? 'day' : 'days'} away'}, on your ${facts['label']} schedule. Want your safe to spend for those days?',
        };
      }

    default:
      return {'mood': 'idle', 'text': 'I did not catch that one.'};
  }
}

/// JS template truthiness for optional fields like a bill date or a late
/// interest amount: null, '', 0, and false all suppress the clause.
bool _falsy(dynamic v) =>
    v == null || v == false || v == '' || v == 0 || (v is double && v.isNaN);
