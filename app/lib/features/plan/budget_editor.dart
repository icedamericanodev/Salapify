// Set the monthly limit, and a cap per category.
//
// The founder hit this wall directly: a screen called Budget, showing four rows
// that all said "No limit set", with nothing anywhere in the app that could set
// one. Worse than the empty state, because empty at least explains itself.
//
// Both fields already exist in the stored schema and have for twelve versions:
// `settings.monthlyLimit` is what the golden locked `budgetSummary` reads, and
// `monthlyCap` on a category is what the per category rows read. So this writes
// fields the engine already understands and adds no new stored shape.
//
// FREE, not Pro. Decision D19: the shipped app reads monthlyCap only when
// settings.pro is set, that rule is untouched in the engine, and this screen
// does not consult it. A budget app whose budgets sit behind a wall fails the
// core features free forever promise at the first screen a stranger opens.
import 'package:flutter/material.dart';

import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// Open the editor. Returns true when something was saved.
///
/// `useRootNavigator`, for the reason spelled out in account_editor.dart: a
/// sheet opened from a tab lands in that tab's Navigator, which the shell
/// draws UNDERNEATH the nav bar, so the save button ends up behind the tabs.
Future<bool> showBudgetEditor(BuildContext context) async {
  final store = context.ledger;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LedgerScope(store: store, child: const _BudgetSheet()),
  );
  return saved ?? false;
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet();

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  final _monthly = TextEditingController();
  final _caps = <String, TextEditingController>{};
  String? _error;
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    final data = context.ledger.data;
    final settings = data['settings'] is Map
        ? data['settings'] as Map
        : const {};
    final limit = amountOf(settings['monthlyLimit']);
    if (limit > 0) _monthly.text = limit.toStringAsFixed(0);

    for (final c in _categories) {
      final cap = amountOf(c['monthlyCap']);
      _caps[c['id'] as String] = TextEditingController(
        text: cap > 0 ? cap.toStringAsFixed(0) : '',
      );
    }
  }

  List<Map<String, dynamic>> get _categories => [
    for (final c in (context.ledger.data['categories'] as List? ?? const []))
      if (c is Map && c['id'] is String) c.cast<String, dynamic>(),
  ];

  @override
  void dispose() {
    _monthly.dispose();
    for (final c in _caps.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: skin.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      // The title and the save button are OUTSIDE the scroll view, and only
      // the fields scroll between them. With everything in one scroll view the
      // render showed a sliver of orange at the bottom edge and nothing else:
      // eight categories pushed "Save budget" off the sheet, so the one
      // control the screen exists for was reachable only by scrolling past
      // every field. A form's primary action does not hide behind its own
      // contents.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Set your budget', style: TypeScale.sheetTitle(skin.text)),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TypeScale.action(skin.text2)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For the whole month',
                    style: TypeScale.fieldLabel(skin.text3),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _monthly,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TypeScale.input(skin.text),
                    decoration: _box(skin, '20000'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Everything you spend counts against this, whether or not '
                    'it has a category.',
                    style: TypeScale.caption(skin.text3),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Per category',
                    style: TypeScale.fieldLabel(skin.text3),
                  ),
                  const SizedBox(height: 6),
                  // Says what blank MEANS, because a blank field that quietly
                  // means "no limit" and a blank field that means "zero" look
                  // identical and are opposite instructions.
                  Text(
                    'Leave one blank and it has no limit, so it is tracked '
                    'but never flagged.',
                    style: TypeScale.caption(skin.text3),
                  ),
                  const SizedBox(height: 12),

                  for (final c in _categories) ...[
                    Row(
                      children: [
                        if ((c['icon'] ?? '').toString().isNotEmpty) ...[
                          Text(
                            (c['icon'] ?? '').toString(),
                            style: TypeScale.rowTitle(skin.text),
                          ),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                          child: Text(
                            (c['name'] ?? '').toString(),
                            style: TypeScale.rowTitle(skin.text),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _caps[c['id']],
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            textAlign: TextAlign.right,
                            style: TypeScale.input(skin.text),
                            decoration: _box(skin, 'none'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TypeScale.caption(skin.bad)),
          ],

          const SizedBox(height: 16),
          PillButton(label: 'Save budget', onTap: _save),
        ],
      ),
    );
  }

  InputDecoration _box(Skin skin, String hint) => InputDecoration(
    filled: true,
    fillColor: skin.card,
    hintText: hint,
    hintStyle: TypeScale.input(skin.text3),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  /// Blank means "no limit" and returns zero. Unreadable returns null, which is
  /// a refusal rather than a value: silently taking "2o,000" as zero would wipe
  /// a limit somebody had set.
  double? _read(String raw) {
    final t = raw.trim().replaceAll(',', '');
    if (t.isEmpty) return 0;
    final n = double.tryParse(t);
    if (n == null || n < 0) return null;
    return n;
  }

  Future<void> _save() async {
    final monthly = _read(_monthly.text);
    if (monthly == null) {
      setState(() => _error = 'The monthly amount cannot be read.');
      return;
    }

    final caps = <String, double>{};
    for (final entry in _caps.entries) {
      final v = _read(entry.value.text);
      if (v == null) {
        final name = _categories.firstWhere((c) => c['id'] == entry.key)['name'];
        setState(() => _error = 'The amount for $name cannot be read.');
        return;
      }
      caps[entry.key] = v;
    }

    final total = caps.values.fold<double>(0, (a, b) => a + b);
    if (monthly > 0 && total > monthly) {
      // A warning and not a refusal. People genuinely budget this way, leaving
      // headroom on categories they will not all max out, and the app has no
      // business telling somebody their own plan is invalid. It just has to
      // make sure they know.
      setState(
        () => _error =
            'Your categories add up to ${formatMoney(total)}, more than the '
            '${formatMoney(monthly)} monthly limit. Saving anyway.',
      );
    }

    final store = context.ledger;
    await store.mutate((draft) {
      final settings = draft['settings'] is Map
          ? Map<String, dynamic>.from(draft['settings'] as Map)
          : <String, dynamic>{};
      settings['monthlyLimit'] = monthly;
      draft['settings'] = settings;

      draft['categories'] = [
        for (final c in (draft['categories'] is List
            ? draft['categories'] as List
            : const []))
          if (c is Map)
            {...c.cast<String, dynamic>(), 'monthlyCap': caps[c['id']] ?? 0.0},
      ];
    });

    if (mounted) Navigator.of(context).pop(true);
  }
}
