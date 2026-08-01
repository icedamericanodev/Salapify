// One "Add" button instead of two, and one question instead of a guess.
//
// Delivery B of docs/features/unified-financial-accounts.md.
//
// What this replaces: two buttons, "+ Account" and "+ Asset", side by side,
// which asked people to already know Salapify's internal split before they
// could record anything. A car loan had no button at all; it lived on a
// different tab entirely, and nothing said so.
//
// What it does NOT do, and this is the design: it does not unify STORAGE. An
// item still lands in the collection its behaviour needs, because the three
// are not interchangeable. An account can be spent from and transferred
// between, an asset is a value with no transactions, and a debt has an
// interest engine, due dates and payment history. Moving a row between them
// would orphan every ledger entry and payment pointing at it. The unification
// is in the question, which is the only place a person experiences it.
//
// TWO DELIBERATE DEPARTURES from the flow written in the design document:
//
// 1. The document has category and subtype as separate steps, collapsing when
//    a category has three or fewer subtypes. Every category here has six or
//    fewer, and a screen that shows six labelled choices is easier than two
//    screens that show three each. So it is one grouped list, and the person
//    sees everything Salapify can record in a single glance, which is worth
//    more than a shorter first screen.
// 2. The document has the institution as its own step. It is a field in the
//    form instead. A whole screen for one optional question is the tap tax the
//    document itself warns about, and it is the answer people most often want
//    to skip.

import 'package:flutter/material.dart';

import '../money/account_taxonomy.dart';
import '../money/institutions.dart';
import '../theme.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/section.dart';

/// The chosen subtype, handed back to whoever opened the sheet.
class AddAccountChoice {
  final AccountCategory category;
  final AccountSubtype subtype;
  const AddAccountChoice(this.category, this.subtype);

  AccountStore get store => category.store;
  bool get isLiability => category.cls == AccountClass.liability;
}

/// The one icon per category. Salapify's own icons, so a theme change moves
/// them; see widgets/salapify_icon.dart for why these are never emoji.
const Map<String, String> _categoryIcon = {
  'cash_equivalents': 'wallet',
  'investments': 'growth',
  'property': 'foundation',
  'credit': 'card',
  'loans': 'decline',
  'installments': 'repeat',
};

Future<AddAccountChoice?> showAddAccountSheet(BuildContext context) {
  return showModalBottomSheet<AddAccountChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _AddAccountSheet(),
  );
}

class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet();

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  /// Null until a category is picked. The sheet is two panes, not two routes,
  /// so Back closes the sheet from the first pane and returns to the list from
  /// the second, which is what a person expects from a sheet.
  AccountCategory? _open;

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return SafeArea(
      child: ConstrainedBox(
        // Not full height: a sheet that fills the screen reads as a page, and
        // the point of this one is that it is a quick question.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Barako.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  if (open != null)
                    IconButton(
                      onPressed: () => setState(() => _open = null),
                      icon: Icon(salapifyIcon('back'), color: Barako.text),
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      open?.label ?? 'What are you adding?',
                      style: TextStyle(
                        color: Barako.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: open == null ? _categories() : _subtypes(open),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _categories() {
    // Assets first. Somebody opening this is far more often recording what
    // they have than what they owe, and the order of a list is a claim about
    // what is normal.
    final assets = categoriesFor(AccountClass.asset);
    final owed = categoriesFor(AccountClass.liability);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        Kicker('WHAT YOU HAVE'),
        const SizedBox(height: 8),
        for (final c in assets) _categoryTile(c),
        const SizedBox(height: 18),
        Kicker('WHAT YOU OWE'),
        const SizedBox(height: 8),
        for (final c in owed) _categoryTile(c),
      ],
    );
  }

  Widget _categoryTile(AccountCategory c) {
    // The examples come from the subtypes themselves, so adding a subtype
    // updates this line and it can never go stale describing a list it is not
    // read from.
    //
    // With exactly one subtype the list would read "Credit cards / Credit
    // card", which says nothing twice. That case shows the subtype's HINT
    // instead, which is the sentence that actually helps somebody decide.
    final examples = c.subtypes.length == 1
        ? c.subtypes.first.hint
        : c.subtypes.take(3).map((s) => s.label).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Barako.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // A category with exactly one subtype has nothing to ask, so it
            // returns straight away rather than showing a list of one.
            if (c.subtypes.length == 1) {
              Navigator.of(context).pop(AddAccountChoice(c, c.subtypes.first));
              return;
            }
            setState(() => _open = c);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                SalapifyGlyph(_categoryIcon[c.id] ?? 'wallet', size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.label,
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        examples,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Barako.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(salapifyIcon('forward'), color: Barako.faint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subtypes(AccountCategory c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        for (final s in c.subtypes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Barako.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () =>
                    Navigator.of(context).pop(AddAccountChoice(c, s)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.label,
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.hint,
                        style: TextStyle(color: Barako.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The institution picker, opened from the details form.
// ---------------------------------------------------------------------------

/// Returns the chosen institution id, or the empty string for "none".
///
/// Null means dismissed without choosing, which is NOT the same as choosing
/// none, and the caller has to treat them differently or a back swipe silently
/// clears an answer somebody already gave.
Future<String?> showInstitutionPicker(
  BuildContext context, {
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _InstitutionPicker(current: current),
    ),
  );
}

class _InstitutionPicker extends StatefulWidget {
  final String? current;
  const _InstitutionPicker({this.current});

  @override
  State<_InstitutionPicker> createState() => _InstitutionPickerState();
}

class _InstitutionPickerState extends State<_InstitutionPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchInstitutions(_query.text);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Which bank or wallet?',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: Barako.text),
                decoration: InputDecoration(
                  hintText: 'Search, or type your own',
                  prefixIcon: Icon(salapifyIcon('search')),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  for (final i in results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: InstitutionAvatar(id: i.id),
                      title: Text(
                        i.displayName,
                        style: TextStyle(
                          color: Barako.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: widget.current == i.id
                          ? Icon(salapifyIcon('check'), color: Barako.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(i.id),
                    ),
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Nothing matches "${_query.text}". You can still use '
                        'it as a custom name.',
                        style: TextStyle(color: Barako.muted),
                      ),
                    ),
                  const Divider(height: 24),
                  // Always reachable, whatever the search says, because "not
                  // on your list" and "none at all" are both real answers.
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: InstitutionAvatar(id: 'none'),
                    title: Text(
                      'No institution',
                      style: TextStyle(color: Barako.text),
                    ),
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The avatar.
// ---------------------------------------------------------------------------

/// A bank's mark, or its initials on a tinted circle.
///
/// There are no logo files, and that is a decision rather than a gap. Images
/// cannot travel in a Shorebird patch, so every batch of them costs the
/// founder a base APK and a manual install, and using a bank's actual mark
/// needs permission this project does not have. Initials work offline, cost
/// nothing, never need clearing, and cannot break a screen by going missing.
class InstitutionAvatar extends StatelessWidget {
  final String? id;

  /// For a custom institution, whose name is user data and not in the catalog.
  final String? customName;
  final double size;

  // Not const: every Barako read happens at build time, so a const constructor
  // would freeze the palette at whatever it was when the widget was created.
  // ignore: prefer_const_constructors_in_immutables
  InstitutionAvatar({super.key, this.id, this.customName, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final inst = institutionById(id);
    final name = inst?.displayName ?? (customName ?? '');
    final letters = name.isEmpty ? '?' : initialsFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Barako.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: Barako.border),
      ),
      child: Text(
        letters,
        style: TextStyle(
          color: Barako.muted,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
