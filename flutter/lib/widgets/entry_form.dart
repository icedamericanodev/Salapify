// The one form language for writing a transaction.
//
// The log sheet and the edit sheet write the SAME object and were two
// different apps about it: amount at 28/w700 against 24/w700, sheet surface
// background against card, input fill card against background, input radius
// 12 against 14, chips filled two different ways, a drag handle on one and
// not the other. Log then edit within ten seconds and the app visibly
// changed dialect on its highest-frequency path.
//
// This file is the one dialect. The sheets keep their own STATE and SAVE
// logic, which genuinely differ (ids and undo semantics are not
// presentation), and compose their body from here, so a divergence now
// requires editing a shared file rather than being the path of least
// resistance.
//
// Planned, not yet built: the audit's P0-1 (category capture at log time)
// lands here as an optional categories/categoryId/onCategory trio mirroring
// the accounts trio, hidden when empty. It is a data-write change, so it
// rides the money-management phase with the data-migration review lane, but
// the API shape is decided now so it arrives as an added row rather than a
// reshape of a form both sheets already ship.

import 'package:flutter/material.dart';

import '../money/currencies.dart' show baseCurrencySymbol;
import '../money/format.dart' show prettyDay;
import '../theme.dart';
import '../typography.dart';
import 'amount_text.dart';
import 'choice_chip.dart';
import 'primary_button.dart';
import 'section.dart';

/// The money entry field: the figure a person is typing, drawn in the exact
/// face a saved figure renders in (AppText.amount, tabular), so entering an
/// amount and reading it back feel like one act. Consumes the theme's input
/// decoration; only the hint and the currency prefix are local.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool autofocus;

  // NOT const. build() reads mutable Barako getters. Same rule as every
  // shared widget here.
  // ignore: prefer_const_constructors_in_immutables
  AmountField({super.key, required this.controller, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final face = AmountText.styleFor(AmountRole.card);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: face,
      decoration: InputDecoration(
        hintText: '0.00',
        prefixText: '$baseCurrencySymbol ',
        // The symbol one ink quieter than the figure, same size, so the eye
        // reads the number and the currency without the symbol shouting.
        prefixStyle: face.tint(Barako.muted),
      ),
    );
  }
}

class EntryFormBody extends StatelessWidget {
  /// The uppercase title above the form ("EDIT ENTRY"), or null for none
  /// (the log sheet's type chips are its own header).
  final String? kicker;

  /// 'expense' or 'income'.
  final String type;
  final ValueChanged<String> onType;

  final TextEditingController amountController;
  final TextEditingController labelController;
  final bool amountAutofocus;

  /// Labels used before for this entry type, offered as one-tap chips.
  /// Empty hides the row (the edit sheet passes none).
  final List<String> recents;

  /// The day this entry is for.
  final DateTime day;
  final ValueChanged<DateTime> onDay;

  /// Linkable accounts (already filtered to real string ids by the caller).
  final List<Map<String, dynamic>> accounts;
  final String? accountId;
  final ValueChanged<String?> onAccount;

  /// The account section title and the unlinked chip's label, which the two
  /// sheets legitimately word differently ("FROM WHICH ACCOUNT" / "No
  /// account" when logging, "LINKED ACCOUNT" / "Not linked" when editing).
  final String accountsKicker;
  final String noAccountLabel;

  /// The category trio, the audit's P0-1: capture the spending category at log
  /// time so the breakdowns fill in without a later tagging pass. Optional so a
  /// caller that does not offer categories (the edit sheet, for now) is
  /// unchanged; the section only renders for an EXPENSE, when categories exist
  /// and onCategory is wired. It writes the transaction's `categoryId`, a field
  /// the schema already round-trips and spentByCategory/whereItWent already
  /// read, so nothing about stored data or migrations changes.
  final List<Map<String, dynamic>> categories;
  final String? categoryId;
  final ValueChanged<String?>? onCategory;
  final String categoriesKicker;
  final String noCategoryLabel;

  final String? error;
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  /// An optional last row under the save button (the edit sheet's "Split
  /// with friends instead").
  final Widget? footer;

  // NOT const. build() reads mutable Barako getters. Same rule as every
  // shared widget here.
  // ignore: prefer_const_constructors_in_immutables
  EntryFormBody({
    super.key,
    this.kicker,
    required this.type,
    required this.onType,
    required this.amountController,
    required this.labelController,
    this.amountAutofocus = false,
    this.recents = const [],
    required this.day,
    required this.onDay,
    this.accounts = const [],
    required this.accountId,
    required this.onAccount,
    this.accountsKicker = 'FROM WHICH ACCOUNT',
    this.noAccountLabel = 'No account',
    this.categories = const [],
    this.categoryId,
    this.onCategory,
    this.categoriesKicker = 'CATEGORY',
    this.noCategoryLabel = 'No category',
    this.error,
    required this.saving,
    required this.saveLabel,
    required this.onSave,
    this.footer,
  });

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String get _iso => day.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Gap.gutter,
          Gap.lg,
          Gap.gutter,
          Gap.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kicker != null) ...[
              Kicker(kicker!, inCard: true),
              const SizedBox(height: Gap.md),
            ],
            // Wrap, not Row, like every other chip group here: at 2.0x text
            // scale on a 320dp phone two chips plus a gap outgrow the line,
            // and a Wrap gets taller where a Row clips.
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                SalapifyChoiceChip(
                  label: 'Expense',
                  selected: type == 'expense',
                  onSelected: (_) => onType('expense'),
                ),
                SalapifyChoiceChip(
                  label: 'Income',
                  selected: type == 'income',
                  onSelected: (_) => onType('income'),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            AmountField(
              controller: amountController,
              autofocus: amountAutofocus,
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: labelController,
              style: AppText.bodyLg,
              decoration: InputDecoration(
                hintText: type == 'income' ? 'e.g. Salary' : 'e.g. Groceries',
              ),
            ),
            if (recents.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final label in recents)
                    ActionChip(
                      label: Text(label),
                      onPressed: () {
                        // A recent chip IS a selection (it sets the label
                        // field), so it speaks the same haptic word the
                        // choice chips beside it do.
                        Haptics.select();
                        labelController.text = label;
                        labelController.selection = TextSelection.collapsed(
                          offset: label.length,
                        );
                      },
                    ),
                ],
              ),
            ],
            // CATEGORY, for an expense only (income has no spending bucket).
            // Optional and hidden when the caller offers no categories, so the
            // edit sheet is unchanged. Writes the transaction's categoryId, an
            // existing field the breakdowns already read.
            if (type == 'expense' &&
                categories.isNotEmpty &&
                onCategory != null) ...[
              const SizedBox(height: Gap.lg),
              Kicker(categoriesKicker, inCard: true),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  SalapifyChoiceChip(
                    label: noCategoryLabel,
                    selected: categoryId == null,
                    onSelected: (_) => onCategory!(null),
                  ),
                  for (final c in categories)
                    SalapifyChoiceChip(
                      label:
                          '${(c['icon'] ?? '').toString()} ${c['name'] ?? 'Category'}'
                              .trim(),
                      selected: categoryId == c['id'],
                      onSelected: (_) => onCategory!(c['id'] as String),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Gap.lg),
            Kicker('WHEN', inCard: true),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: _dayChips(context),
            ),
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: Gap.lg),
              Kicker(accountsKicker, inCard: true),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  SalapifyChoiceChip(
                    label: noAccountLabel,
                    selected: accountId == null,
                    onSelected: (_) => onAccount(null),
                  ),
                  for (final a in accounts)
                    SalapifyChoiceChip(
                      label: a['name']?.toString() ?? 'Account',
                      selected: accountId == a['id'],
                      onSelected: (_) => onAccount(a['id'] as String),
                    ),
                ],
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: Gap.md),
              // liveRegion so a screen reader hears the failure the moment it
              // appears; without it, focus sits on the Save button and the
              // save fails in silence.
              Semantics(
                liveRegion: true,
                child: Text(error!, style: AppText.small.tint(Barako.warning)),
              ),
            ],
            const SizedBox(height: Gap.lg),
            PrimaryButton(
              saveLabel,
              busy: saving,
              busyLabel: 'Saving...',
              onPressed: onSave,
            ),
            if (footer != null) ...[const SizedBox(height: Gap.sm), footer!],
          ],
        ),
      ),
    );
  }

  /// Today, Yesterday, and a picker for any other day, one selected at a
  /// time. When a picked day is neither of the quick two, the picker chip
  /// itself shows the chosen date, so the selection is always readable on
  /// the sheet and never hidden inside a dialog that already closed.
  List<Widget> _dayChips(BuildContext context) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final isToday = _sameDay(day, now);
    final isYesterday = _sameDay(day, yesterday);
    final custom = !isToday && !isYesterday;
    return [
      SalapifyChoiceChip(
        label: 'Today',
        selected: isToday,
        onSelected: (_) => onDay(now),
      ),
      SalapifyChoiceChip(
        label: 'Yesterday',
        selected: isYesterday,
        onSelected: (_) => onDay(yesterday),
      ),
      SalapifyChoiceChip(
        label: custom ? prettyDay(_iso) : 'Pick a date',
        selected: custom,
        onSelected: (_) async {
          // BOTH bounds clamped around the entry's own day. A restored RN
          // backup can legally carry any date, and showDatePicker asserts
          // initialDate inside [firstDate, lastDate]; an unclamped floor
          // crashed the edit sheet on a 2014 entry once. No future dates:
          // this form records money that already moved.
          final floor = DateTime(2015);
          final picked = await showDatePicker(
            context: context,
            initialDate: day.isAfter(now) ? now : day,
            firstDate: day.isBefore(floor) ? day : floor,
            lastDate: now,
          );
          if (picked != null) onDay(picked);
        },
      ),
    ];
  }
}
