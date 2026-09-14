// The Log sheet. Principle 1: logging is the heartbeat, under three seconds
// from thumb to saved. So it slides up OVER the screen you were on rather than
// being its own page, because that is how it is actually used and the dimmed
// screen behind it is part of the design, not a detail of the screenshot.
//
// The layout is the one the founder approved on 2026-09-13 (24 renders,
// docs/revamp/mockups/hapon/). What changed in C1 is that it is now real: the
// field takes input, the "Got it" line reads what was typed, the chips select,
// and Save writes a transaction that moves an account balance.
import 'package:flutter/material.dart';

import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'log_view_model.dart';

/// The scrim plus the sheet, pushed as a route over the shell.
class LogSheet extends StatefulWidget {
  const LogSheet({super.key});

  @override
  State<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<LogSheet> {
  LogViewModel? _vm;
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built here rather than in initState because it needs the store from the
    // tree. Guarded so a rebuild does not throw away a half-typed entry.
    _vm ??= LogViewModel(LedgerScope.read(context))..addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _vm?.removeListener(_onChanged);
    _vm?.dispose();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vm = _vm!;
    if (!vm.canSave) return;
    final nav = Navigator.of(context);
    await vm.save();
    // Only after the write has actually landed. LedgerStore persists before it
    // notifies, so a sheet that closed first would be telling the founder their
    // money is saved while the write was still in flight.
    if (nav.mounted) nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // The Material is not decoration. Text with no Material ancestor gets
    // Flutter's yellow double underline, and the first render of this screen
    // had it on every single label. Caught by looking at the picture,
    // invisible to analyze and to every test.
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // The scrim. Dark in both skins: it is a shadow, not a surface, so
          // it does not flip with the palette.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: ColoredBox(color: context.skin.scrim),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: _Sheet(
                vm: _vm!,
                field: _field,
                focus: _focus,
                onSave: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.vm,
    required this.field,
    required this.focus,
    required this.onSave,
  });

  final LogViewModel vm;
  final TextEditingController field;
  final FocusNode focus;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        gutter,
        12,
        gutter,
        // Clear of the keyboard, which is up the whole time this sheet is.
        30 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: skin.bg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(skin.radius + 6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: skin.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Log', style: TypeScale.sheetTitle(skin.text)),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Text('Cancel', style: TypeScale.quiet(skin.text3)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // The fast log field. One typed line becomes a saved expense with a
          // category, and the app says out loud what it understood BEFORE the
          // user commits, so a wrong guess is caught in the same glance.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: skin.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: field,
              focusNode: focus,
              autofocus: true,
              onChanged: vm.setLine,
              onSubmitted: (_) => onSave(),
              textInputAction: TextInputAction.done,
              style: TypeScale.input(skin.text),
              cursorColor: skin.accent,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                hintText: 'jollibee 250',
                hintStyle: TypeScale.input(skin.text3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GotIt(vm: vm),
          const SizedBox(height: 20),

          Segmented(
            options: const ['Expense', 'Income', 'Transfer'],
            index: switch (vm.type) {
              'income' => 1,
              'transfer' => 2,
              _ => 0,
            },
            onPick: (i) =>
                vm.pickType(const ['expense', 'income', 'transfer'][i]),
          ),
          const SizedBox(height: 22),

          // Categories are an expense-side idea, so the whole block goes away
          // rather than sitting there greyed out and unexplained.
          if (vm.type == 'expense' && vm.categories.isNotEmpty) ...[
            // When the parser did NOT recognise the word, the label says so and
            // asks. The chips were always here and always tappable, but eight
            // identical unselected chips under a silent "Category" heading read
            // as decoration rather than as a question, so an untagged entry got
            // saved untagged. The founder hit exactly that typing "kain 120".
            //
            // This is the better answer than chasing the vocabulary forever. No
            // word list can cover how everybody writes; a list that admits what
            // it does not know, in the one second before saving, can.
            Text(
              vm.categoryId == null ? 'Category, tap one' : 'Category',
              style: TypeScale.fieldLabel(
                vm.categoryId == null ? skin.text2 : skin.text3,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in vm.categories)
                  PickChip(
                    label: (c['name'] ?? '').toString(),
                    on: c['id'] == vm.categoryId,
                    onTap: () => vm.pickCategory(c['id'] as String?),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          if (vm.accounts.isNotEmpty) ...[
            Text('Account', style: TypeScale.fieldLabel(skin.text3)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in vm.accounts)
                  PickChip(
                    label: (a['name'] ?? '').toString(),
                    on: a['id'] == vm.accountId,
                    onTap: () => vm.pickAccount(a['id'] as String?),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          const Row(
            children: [
              Expanded(
                child: Field(value: 'Today', leading: Icons.event_outlined),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Field(
                  value: 'Note',
                  hint: true,
                  leading: Icons.notes_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Opacity(
            // Dimmed rather than hidden: a button that appears when you finish
            // typing is a button you did not know was coming.
            opacity: vm.canSave ? 1 : 0.45,
            child: PillButton(
              label: 'Save entry',
              onTap: vm.canSave ? onSave : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the app understood, said out loud before anything is written.
///
/// It only claims what it actually parsed. No amount yet means no line at all,
/// rather than a confident reading of nothing, and an unguessed category is
/// simply absent rather than shown as a shrug.
class _GotIt extends StatelessWidget {
  const _GotIt({required this.vm});
  final LogViewModel vm;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = vm.parsed;
    if (!p.understood) {
      return Text(
        'Type what you spent, like "jollibee 250".',
        style: TypeScale.hint(skin.text3),
      );
    }

    final parts = <String>[
      switch (vm.type) {
        'income' => 'Income',
        'transfer' => 'Transfer',
        _ => 'Expense',
      },
      if (p.amount != null) formatMoney(p.amount!),
      if (p.label.isNotEmpty) p.label,
      ?_categoryName(vm),
    ];

    return Text.rich(
      TextSpan(
        style: TypeScale.hint(skin.text3),
        children: [
          const TextSpan(text: 'Got it: '),
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) const TextSpan(text: ' · '),
            TextSpan(text: parts[i], style: TypeScale.hintStrong(skin.accent)),
          ],
        ],
      ),
    );
  }

  String? _categoryName(LogViewModel vm) {
    final id = vm.categoryId;
    if (id == null) return null;
    for (final c in vm.categories) {
      if (c['id'] == id) return (c['name'] ?? '').toString();
    }
    return null;
  }
}
