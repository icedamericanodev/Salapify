// Hatian: split one expense you fronted into centavo exact shares, so each
// friend's part can become collectible utang and your own part stays a plain
// expense. This file is PURE math only. It reads a total and a list of who was
// in, and returns the per person shares plus the one honest decision the card
// shows: what you fronted, what your own share was, and how much is still
// coming back to you. It never touches accounts or receivables; the store does
// that through the golden locked receivables engine using this plan.
//
// The load bearing promise: the shares ALWAYS add up to the total to the
// centavo. Money is split in whole centavos (integers), and any leftover
// centavo from an uneven division is handed to the first people in order, so
// nobody is ever short a peso and the app never invents or drops one.
//
// Net new math with no RN counterpart, so it is covered by Dart unit tests
// rather than a golden replay. Non-finite totals and junk shares are guarded.

import 'ledger.dart' show amountOf;

int _centavos(double pesos) => (pesos * 100).round();

double _pesos(int centavos) => centavos / 100.0;

/// Does this participant carry a custom exact amount (as opposed to sharing
/// the bill equally)? A custom amount is any finite number >= 0; anything else
/// (null, blank, junk) means "split me equally".
bool _hasCustom(dynamic amount) {
  if (!_looksNumeric(amount)) return false;
  return amountOf(amount) >= 0;
}

bool _looksNumeric(dynamic x) {
  if (x is num) return x.isFinite;
  if (x is String) {
    final t = x.trim();
    if (t.isEmpty) return false;
    final p = double.tryParse(t);
    return p != null && p.isFinite;
  }
  return false;
}

/// Split a fronted total among participants and return the decision the screen
/// renders. Input participants are maps: { name, isYou (bool), included (bool,
/// default true), amount (optional custom exact peso amount) }. Every peso on
/// the returned card comes from here, never invented in the widget.
///
/// Returns, on success:
///   { ok: true, total, shares: [ {name, isYou, share, custom} ... ],
///     yourShare, toCollect, collectFrom }
/// where `shares` lists the INCLUDED participants only, `yourShare` is your own
/// part (a plain expense, never utang), `toCollect` is the sum coming back, and
/// `collectFrom` counts the people who owe you something.
///
/// Returns, on a problem the user must fix:
///   { ok: false, error, gap? }
/// with error one of: 'total' (bad or negative total), 'empty' (nobody in),
/// 'over' (custom amounts exceed the total), 'mismatch' (everyone is custom but
/// their amounts do not add up to the total; `gap` is the peso difference).
Map<String, dynamic> splitExpense(dynamic total, dynamic participants) {
  final totalC = _centavos(amountOf(total));
  if (totalC < 0) return {'ok': false, 'error': 'total'};

  final rows = <Map<String, dynamic>>[];
  for (final p in (participants is List ? participants : const [])) {
    if (p is! Map) continue;
    final m = p.cast<String, dynamic>();
    // A participant defaults to included; only an explicit false drops them.
    if (m['included'] == false) continue;
    rows.add(m);
  }
  if (rows.isEmpty) return {'ok': false, 'error': 'empty'};

  // Custom rows take their exact amount; the rest share what is left equally.
  var sumCustomC = 0;
  final equalIdx = <int>[];
  final shareC = List<int>.filled(rows.length, 0);
  final isCustom = List<bool>.filled(rows.length, false);
  for (var i = 0; i < rows.length; i++) {
    if (_hasCustom(rows[i]['amount'])) {
      final c = _centavos(amountOf(rows[i]['amount']));
      shareC[i] = c;
      isCustom[i] = true;
      sumCustomC += c;
    } else {
      equalIdx.add(i);
    }
  }

  if (sumCustomC > totalC) return {'ok': false, 'error': 'over'};
  final remainderC = totalC - sumCustomC;

  if (equalIdx.isEmpty) {
    // Everyone entered a custom amount. They must add up to the total exactly,
    // or we would silently drop or invent pesos. Surface the gap instead.
    if (remainderC != 0) {
      return {'ok': false, 'error': 'mismatch', 'gap': _pesos(remainderC)};
    }
  } else {
    final n = equalIdx.length;
    final base = remainderC ~/ n;
    final extra = remainderC % n;
    // The leftover centavos go to the first `extra` equal split people in
    // order, deterministically, so the shares always sum back to the total.
    for (var k = 0; k < n; k++) {
      shareC[equalIdx[k]] = base + (k < extra ? 1 : 0);
    }
  }

  final shares = <Map<String, dynamic>>[];
  var yourC = 0;
  var toCollectC = 0;
  var collectFrom = 0;
  for (var i = 0; i < rows.length; i++) {
    final isYou = rows[i]['isYou'] == true;
    final name =
        (rows[i]['name'] is String &&
            (rows[i]['name'] as String).trim().isNotEmpty)
        ? (rows[i]['name'] as String).trim()
        : 'Someone';
    shares.add({
      'name': name,
      'isYou': isYou,
      'share': _pesos(shareC[i]),
      'custom': isCustom[i],
    });
    if (isYou) {
      yourC += shareC[i];
    } else {
      toCollectC += shareC[i];
      if (shareC[i] > 0) collectFrom += 1;
    }
  }

  return {
    'ok': true,
    'total': _pesos(totalC),
    'shares': shares,
    'yourShare': _pesos(yourC),
    'toCollect': _pesos(toCollectC),
    'collectFrom': collectFrom,
  };
}

/// Fold split receivables into per-activity summaries for the utang screen:
/// one entry per activityId, in first-seen order, with its label, the total
/// still out (unpaid), and how many distinct people still owe you. Pure
/// aggregation, so the totals are covered by a vector instead of summed inside
/// a widget. "Still out" is amount minus payments floored at zero, matching
/// remainingOf; a fully settled activity drops out.
List<Map<String, dynamic>> activitySummaries(dynamic receivables) {
  final byId = <String, Map<String, dynamic>>{};
  final order = <String>[];
  for (final r in (receivables is List ? receivables : const [])) {
    if (r is! Map) continue;
    final aid = r['activityId'];
    if (aid is! String || aid.isEmpty) continue;
    final paid = (r['payments'] is List)
        ? (r['payments'] as List).fold<double>(
            0,
            (t, p) => t + (p is Map ? amountOf(p['amount']) : 0),
          )
        : 0.0;
    final rem = amountOf(r['amount']) - paid;
    if (rem <= 0) continue;
    final label =
        (r['activityLabel'] is String &&
            (r['activityLabel'] as String).trim().isNotEmpty)
        ? (r['activityLabel'] as String).trim()
        : 'Split';
    final g = byId.putIfAbsent(aid, () {
      order.add(aid);
      return {'label': label, 'stillOut': 0.0, 'names': <String>{}};
    });
    g['stillOut'] = (g['stillOut'] as double) + rem;
    (g['names'] as Set<String>).add((r['person'] ?? '').toString());
  }
  return [
    for (final id in order)
      {
        'label': byId[id]!['label'],
        'stillOut': byId[id]!['stillOut'],
        'people': (byId[id]!['names'] as Set).length,
      },
  ];
}

/// The plain equal share of a total among `count` people, for a live preview as
/// the user toggles people in and out. Centavo exact for the first person, so
/// the preview never shows a figure the real split cannot hit. Returns 0 for a
/// bad count or total.
double equalShare(dynamic total, int count) {
  if (count <= 0) return 0;
  final totalC = _centavos(amountOf(total));
  if (totalC <= 0) return 0;
  final base = totalC ~/ count;
  final extra = totalC % count;
  return _pesos(base + (extra > 0 ? 1 : 0));
}
