// Add an account, and change one.
//
// The Accounts empty state has been saying "Add where your money actually sits"
// since the screen was built, with nothing in the app that could do it. An
// instruction nobody can follow is the same defect as the payday sentence that
// pointed at a screen which could not set a payday, and a competitor review
// called this one below the floor rather than a roadmap item: accounts could
// only arrive through a restored backup or the debug sample data.
//
// ONLY FOUR KINDS, and that is not a simplification. `account_taxonomy.dart`
// maps exactly cash, savings, checking and ewallet, and anything else derives
// SILENTLY to cash on hand. The fixture once said 'bank' and the screen duly
// labelled a savings account "Cash on hand" with no error anywhere. A free text
// field here would ship that defect to every user, so the kinds are a fixed
// list and the list is the engine's.
//
// The choice matters for money, not just for a label: `liquidKinds` in the
// golden locked engine counts cash, ewallet and checking as spendable and
// leaves SAVINGS out, because the whole point of safe to spend is to protect
// savings. Marking an account savings is therefore the difference between it
// being counted as today's pocket money or not.
//
// NO institutionId IS WRITTEN, and that is on purpose. The first version put
// `initialsFor(name).toLowerCase()` in it, which is a monogram, not an
// institution: `institutionId` is a CATALOG KEY that institutionById,
// institutionBrandColor and institutionLogoAsset all look up. An account named
// GCash got 'gc' and one named with an emoji got '?'. It was inert only by
// luck, because every real catalog id is three characters or more and
// initialsFor returns at most two, so nothing ever collided. It still wrote
// junk into the user's backup file for no gain, since monogramFor already falls
// back to initialsFor(name) when there is no institution. Matching a typed name
// to a real institution is a feature that can be built later; guessing at the
// key is not the start of it.
import 'package:flutter/material.dart';

import '../../app/ledger_scope.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/editor_safety.dart';

/// The kinds the engine actually understands, with what each one MEANS for the
/// money rather than what it is called at a bank.
const accountKinds = <(String, String, String)>[
  ('cash', 'Cash', 'Money in your pocket. Counts as spendable.'),
  ('ewallet', 'E-wallet', 'GCash, Maya and the like. Counts as spendable.'),
  ('checking', 'Checking', 'A current account. Counts as spendable.'),
  (
    'savings',
    'Savings',
    'Kept OUT of safe to spend on purpose, so you do not spend it by accident.',
  ),
];

/// Open the editor. Returns true when something was saved.
///
/// `useRootNavigator` is not a nicety here, it is the difference between a
/// working screen and a broken one. The shell puts the nav bar in a Stack ON
/// TOP of the tab it is showing (app/shell.dart), and a sheet opened from a tab
/// goes into that tab's own Navigator, which lives UNDER the bar. The save
/// button then sits behind the tab bar: it is drawn, it looks pressable, and
/// the tap lands on a tab instead. The root navigator is above the whole
/// Scaffold, bar included. A test caught this before the founder did, which is
/// the only reason it is written down rather than suffered.
Future<bool> showAccountEditor(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final store = context.ledger;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        LedgerScope(store: store, child: _AccountSheet(existing: existing)),
  );
  return saved ?? false;
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  late final _name = TextEditingController(
    text: (widget.existing?['name'] ?? '').toString(),
  );
  late final _balance = TextEditingController(
    text: widget.existing == null
        ? ''
        : moneyField(amountOf(widget.existing!['balance'])),
  );
  late String _kind = (widget.existing?['kind'] ?? 'ewallet').toString();
  String? _error;

  /// One save at a time. See [closeAfterSaving]: a second save means a second
  /// pop, and on the root navigator the second pop closes the app, not the
  /// sheet.
  var _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Container(
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isNew ? 'Add an account' : 'Edit account',
                  style: TypeScale.sheetTitle(skin.text),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: TypeScale.action(skin.text2)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('Name', style: TypeScale.fieldLabel(skin.text3)),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              style: TypeScale.input(skin.text),
              textCapitalization: TextCapitalization.words,
              decoration: _box(skin, 'GCash, BPI, Cash on hand'),
            ),

            const SizedBox(height: 18),
            Text('What kind', style: TypeScale.fieldLabel(skin.text3)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, label, _) in accountKinds)
                  PickChip(
                    label: label,
                    on: id == _kind,
                    onTap: () => setState(() => _kind = id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // The consequence, in words, because the difference between
            // "Savings" and "E-wallet" is not cosmetic: one is counted as
            // today's spendable money and one is deliberately protected from
            // it. Nobody should have to learn that by watching a figure move.
            Text(
              accountKinds.firstWhere((k) => k.$1 == _kind).$3,
              style: TypeScale.caption(skin.text3),
            ),

            const SizedBox(height: 18),
            Text(
              _isNew ? 'What is in it now' : 'Balance',
              style: TypeScale.fieldLabel(skin.text3),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TypeScale.input(skin.text),
              decoration: _box(skin, '0.00'),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TypeScale.caption(skin.bad)),
            ],

            const SizedBox(height: 22),
            PillButton(
              label: _isNew ? 'Add account' : 'Save changes',
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _box(Skin skin, String hint) => InputDecoration(
    filled: true,
    fillColor: skin.card,
    hintText: hint,
    hintStyle: TypeScale.input(skin.text3),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  Future<void> _save() async {
    if (_saving) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name so you can tell it apart.');
      return;
    }

    // A blank balance means zero, which is honest for a new account. An
    // UNREADABLE one is a different thing and must not be silently taken as
    // zero: on an edit that would wipe a real balance.
    //
    // NEGATIVE is allowed here, unlike in the budget editor, and deliberately:
    // an overdrawn checking account is a real thing and refusing to record it
    // would make the app unable to describe somebody's actual position.
    final typed = _balance.text.trim().replaceAll(',', '');
    final parsed = typed.isEmpty ? 0.0 : double.tryParse(typed);
    // `isFinite` is the half that plain tryParse misses. It returns real
    // values for "NaN", "Infinity" and "1e400"; sanitizeData then coerces a
    // non-finite number to 0 on the way to disk, so the sheet would report a
    // successful save while quietly zeroing a real balance.
    if (parsed == null || !parsed.isFinite) {
      setState(() => _error = 'That amount cannot be read. Try 1500 or 1500.50');
      return;
    }

    setState(() => _saving = true);
    final store = context.ledger;
    try {
      await store.mutate((draft) {
        final accounts = [
          for (final a in (draft['accounts'] is List
              ? draft['accounts'] as List
              : const []))
            if (a is Map) a.cast<String, dynamic>(),
        ];

        if (_isNew) {
          accounts.add({
            'id': 'a_${DateTime.now().microsecondsSinceEpoch}',
            'name': name,
            'kind': _kind,
            'balance': parsed,
          });
        } else {
          final id = widget.existing!['id'];
          for (var i = 0; i < accounts.length; i++) {
            if (accounts[i]['id'] == id) {
              accounts[i] = {
                ...accounts[i],
                'name': name,
                'kind': _kind,
                'balance': parsed,
              };
            }
          }
        }
        draft['accounts'] = accounts;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Nothing was changed.';
        });
      }
      return;
    }

    if (mounted) closeAfterSaving(context, true);
  }
}
