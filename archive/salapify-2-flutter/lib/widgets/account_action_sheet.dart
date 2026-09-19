// One account's actions, in three plain tiers, opened from the account's card.
//
// It reuses everything. Every action here is a callback the caller wires to a
// flow the app ALREADY has: the ledger (History), logging money (the log
// sheet), moving money (the transfer sheet), editing the account, the account's
// own saved receiving QR (the QR vault), a per account PDF statement, the skin
// studio, and archive/hide. So this sheet adds no money behaviour of its own; it
// is a tidy front door onto flows that already exist and already have tests. It
// leads with the account's card ([cardPreview], a FloatingPanCard the caller
// builds) so the actions read as belonging to that specific card.
//
// HONEST BY DESIGN. There is no "freeze" that freezes nothing and no generated
// payment code that cannot be paid. QR Ph shows the user's OWN saved receiving
// QR when they have attached one, and otherwise points them to add one in the
// account's details. "Hide" is the app's real archive toggle, which leaves the
// account out of totals while keeping its history. Every colour is a Barako
// getter, so the sheet follows all sixteen palettes and both brightnesses.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

/// Open the account action sheet. All actions are wired by the caller to the
/// app's existing flows; a null [onShowQr] means no receiving QR is saved yet,
/// so that control routes to the account details instead of showing a code.
Future<void> showAccountActionSheet(
  BuildContext context, {
  required Widget cardPreview,
  required String title,
  required VoidCallback onViewLedger,
  required VoidCallback onLogExpense,
  required VoidCallback onTransfer,
  required VoidCallback onEditDetails,
  required VoidCallback onExportStatement,
  required VoidCallback onCustomizeSkin,
  required VoidCallback onArchiveToggle,
  required bool isArchived,
  VoidCallback? onShowQr,
  bool canTransfer = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => _AccountActionSheet(
      cardPreview: cardPreview,
      title: title,
      onViewLedger: onViewLedger,
      onLogExpense: onLogExpense,
      onTransfer: onTransfer,
      onEditDetails: onEditDetails,
      onExportStatement: onExportStatement,
      onCustomizeSkin: onCustomizeSkin,
      onArchiveToggle: onArchiveToggle,
      isArchived: isArchived,
      onShowQr: onShowQr,
      canTransfer: canTransfer,
    ),
  );
}

class _AccountActionSheet extends StatelessWidget {
  final Widget cardPreview;
  final String title;
  final VoidCallback onViewLedger;
  final VoidCallback onLogExpense;
  final VoidCallback onTransfer;
  final VoidCallback onEditDetails;
  final VoidCallback onExportStatement;
  final VoidCallback onCustomizeSkin;
  final VoidCallback onArchiveToggle;
  final bool isArchived;
  final VoidCallback? onShowQr;
  final bool canTransfer;

  const _AccountActionSheet({
    required this.cardPreview,
    required this.title,
    required this.onViewLedger,
    required this.onLogExpense,
    required this.onTransfer,
    required this.onEditDetails,
    required this.onExportStatement,
    required this.onCustomizeSkin,
    required this.onArchiveToggle,
    required this.isArchived,
    required this.onShowQr,
    required this.canTransfer,
  });

  // Pop the sheet first, then run the action, so the action's own sheet or
  // screen does not stack on top of this one.
  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Barako.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            cardPreview,
            const SizedBox(height: 16),
            Text(
              title,
              style: AppText.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Tier 1: fast, one tap things.
            Text('QUICK', style: Barako.kickerStyle),
            const SizedBox(height: 8),
            // IntrinsicHeight so the three tiles match the tallest, the same
            // pattern the accounts quick-actions row uses; a bare stretched Row
            // has no bounded height inside the scroll view and cannot lay out.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _quick(
                      context,
                      icon: 'qr',
                      label: 'QR Ph',
                      onTap: () => _run(context, onShowQr ?? onEditDetails),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quick(
                      context,
                      icon: 'activity',
                      label: 'Ledger',
                      onTap: () => _run(context, onViewLedger),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quick(
                      // A plus, distinct from Ledger's list glyph: Log RECORDS a
                      // new entry, Ledger opens the existing ones.
                      context,
                      icon: 'add',
                      label: 'Log',
                      onTap: () => _run(context, onLogExpense),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tier 2: statements and moving money.
            Text('STATEMENTS AND MOVES', style: Barako.kickerStyle),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: 'pdf',
              title: 'Export PDF statement',
              subtitle: "This account's balance and this month's transactions",
              onTap: () => _run(context, onExportStatement),
            ),
            _tile(
              context,
              icon: 'swap',
              title: 'Transfer',
              subtitle: canTransfer
                  ? 'Move money between your accounts'
                  : 'Add another account to move money between',
              onTap: () => _run(context, onTransfer),
            ),
            const SizedBox(height: 16),

            // Tier 3: customise and manage.
            Text('CUSTOMISE AND MANAGE', style: Barako.kickerStyle),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: 'appearance',
              title: 'Card skin studio',
              subtitle: 'Obsidian, Emerald, Gold, or Platinum finish',
              onTap: () => _run(context, onCustomizeSkin),
            ),
            _tile(
              context,
              icon: 'edit',
              title: 'Edit account details',
              subtitle: 'Name, type, and card metadata',
              onTap: () => _run(context, onEditDetails),
            ),
            _tile(
              context,
              icon: isArchived ? 'reveal' : 'hide',
              title: isArchived ? 'Unhide account' : 'Hide account',
              subtitle: isArchived
                  ? 'Count it in your totals again'
                  : 'Keep its history but leave it out of totals',
              onTap: () => _run(context, onArchiveToggle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quick(
    BuildContext context, {
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Barako.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Barako.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Barako.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  salapifyIcon(icon),
                  size: 20,
                  color: Barako.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.w6.tint(Barako.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SalapifyGlyph(icon, size: 20),
      title: Text(title, style: AppText.body.w6),
      subtitle: Text(subtitle, style: AppText.caption),
      trailing: Icon(salapifyIcon('forward'), color: Barako.faint, size: 18),
      onTap: onTap,
    );
  }
}
