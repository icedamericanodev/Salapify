import '../../core/money/money.dart';
import 'package:flutter/material.dart';

import '../../core/money/debt.dart';
import '../../core/money/format.dart';
import '../../core/money/reports.dart' show liabilityKinds;
import '../../design/pan_art.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/debt/add_debt_sheet.dart';
import '../../features/debt/payment_sheet.dart';
import '../../features/debt/payments_sheet.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'debt_calculators.dart';
import 'installments_view.dart';
import '../../features/shared/sheet_scaffold.dart';

/// The debt register, both ways, from archive/prototype-google-ai-studio/src/components/DebtScreen.tsx.
///
/// Debt here means what you owe AND what is owed to you, which is the
/// product's own definition and the reason the two directions are a segmented
/// control rather than one list with the receivables tucked underneath.
///
/// SCOPE, named rather than implied. The prototype's screen has three
/// sections. Two are here: the register itself, which holds the write path,
/// and the nine calculators. The third, `InstallmentsView` (565 lines, formal
/// instalment plans with their own amortisation), is a later batch and is NOT
/// offered as a third tab rather than being offered and empty.
class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key, required this.state, this.onBack});

  final FinancialState state;
  final VoidCallback? onBack;

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

/// The prototype's three main sections, all present.
enum _Section { debts, installments, calculators }

class _DebtScreenState extends State<DebtScreen> {
  DebtDirection _direction = DebtDirection.iOwe;
  _Section _section = _Section.debts;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final List<Debt> debts = widget.state.debts;
    final ({List<Debt> open, List<Debt> settled}) split = splitByStatus(
      debts,
      _direction,
    );
    // Archived debts are filtered out of state.debts, so they reach this
    // screen only here, and only in the direction being looked at.
    final List<Debt> archived = widget.state.archivedDebts
        .where((Debt d) => d.direction == _direction)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Header(
          palette: p,
          onBack: widget.onBack,
          onAdd: _section == _Section.debts ? () => _openAdd(context, p) : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _Tab(
                  palette: p,
                  // "Debts", not "Owed". The filter right under it reads
                  // "Owed to you", so a tab called "Owed" looked like it held
                  // only one direction when it holds both.
                  label: 'Debts',
                  selected: _section == _Section.debts,
                  onTap: () => setState(() => _section = _Section.debts),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _Tab(
                  palette: p,
                  label: 'Plans',
                  selected: _section == _Section.installments,
                  onTap: () => setState(() => _section = _Section.installments),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _Tab(
                  palette: p,
                  label: 'Amortization',
                  selected: _section == _Section.calculators,
                  onTap: () => setState(() => _section = _Section.calculators),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xl,
            ),
            children: switch (_section) {
              _Section.calculators => <Widget>[DebtCalculators(palette: p)],
              _Section.installments => <Widget>[
                InstallmentsView(state: widget.state),
              ],
              _Section.debts => <Widget>[
                _Beam(palette: p, debts: debts),
                const SizedBox(height: Spacing.md),
                _DirectionPicker(
                  palette: p,
                  current: _direction,
                  owe: outstanding(debts, DebtDirection.iOwe).pesos,
                  owed: outstanding(debts, DebtDirection.owedToMe).pesos,
                  onSelect: (DebtDirection d) => setState(() => _direction = d),
                ),
                const SizedBox(height: Spacing.lg),
                // `archived` belongs in this test. Without it, a person
                // whose only debt in this direction is archived gets the
                // empty state AND no Archived section, which puts the one
                // way back out of reach entirely.
                if (split.open.isEmpty &&
                    split.settled.isEmpty &&
                    archived.isEmpty)
                  _Empty(
                    palette: p,
                    direction: _direction,
                    // Calm Pan means NOTHING is owed anywhere, not only on
                    // this list. An instalment plan or a card balance is
                    // still owed, and an "all clear" over it is the wrong
                    // conclusion at the worst moment.
                    allClear:
                        widget.state.installments.isEmpty &&
                        !widget.state.accounts.any(
                          (Account a) =>
                              liabilityKinds.contains(a.kind) &&
                              !a.balance.isZero,
                        ),
                  )
                else ...<Widget>[
                  for (final Debt d in split.open) ...<Widget>[
                    _DebtCard(
                      palette: p,
                      debt: d,
                      onViewPayments: () => _openPayments(context, p, d),
                      onPay: () => _openPayment(context, p, d),
                      onSettle: () => _confirmSettle(context, p, d),
                      onTakeBack: d.payments.isEmpty
                          ? null
                          : () => _confirmTakeBack(context, p, d),
                      onDelete: _canDelete(d)
                          ? () => _confirmDelete(context, p, d)
                          : null,
                    ),
                    const SizedBox(height: Spacing.sm),
                  ],
                  if (split.settled.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Spacing.sm),
                    Text('CLEARED', style: AppType.kicker(p)),
                    const SizedBox(height: Spacing.sm),
                    for (final Debt d in split.settled) ...<Widget>[
                      _DebtCard(
                        palette: p,
                        debt: d,
                        onViewPayments: () => _openPayments(context, p, d),
                        onPay: null,
                        onSettle: () => _confirmSettle(context, p, d),
                        // Offered on a CLEARED debt too, and deliberately: a
                        // payment that settled a debt by mistake is exactly
                        // the one somebody needs back, and hiding the control
                        // on the settled list would put it out of reach in
                        // the case that matters most.
                        onTakeBack: d.payments.isEmpty
                            ? null
                            : () => _confirmTakeBack(context, p, d),
                        // Settled, so this is the archive side of the gate.
                        onArchive: () => _confirmArchive(context, p, d),
                      ),
                      const SizedBox(height: Spacing.sm),
                    ],
                  ],
                  // PUT AWAY, and still reachable. Rendered only when the
                  // list is non-empty: a permanent "0 archived" heading is
                  // the clutter that teaches people to stop reading.
                  if (archived.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Spacing.sm),
                    Text('ARCHIVED', style: AppType.kicker(p)),
                    const SizedBox(height: Spacing.sm),
                    for (final Debt d in archived) ...<Widget>[
                      _DebtCard(
                        palette: p,
                        debt: d,
                        onViewPayments: () => _openPayments(context, p, d),
                        onPay: null,
                        // ONE ACTION on an archived card, and that is the
                        // whole point. Offering settle here let a debt be
                        // made live while it stayed archived, which hid a
                        // real liability from every total in the app.
                        onSettle: null,
                        onUnarchive: () {
                          widget.state.unarchiveDebt(d.id);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: Spacing.sm),
                    ],
                  ],
                ],
              ],
            },
          ),
        ),
      ],
    );
  }

  // Splitting a bill used to open from a card on this screen, and the comment
  // that lived here argued it belonged on the screen where debts live. The
  // founder went looking for it the way anybody would, did not find it, and
  // moved it to Home's shortcut row on 2026-10-01. It opens from there now.

  Future<void> _openAdd(BuildContext context, Palette palette) async {
    final Debt? added = await AddDebtSheet.show(context, palette);
    if (added != null) widget.state.addDebt(added);
    if (mounted) setState(() {});
  }

  /// Opens the list of payments recorded against one debt.
  ///
  /// Passes the ID rather than the Debt, because the sheet outlives any single
  /// copy of it: taking a payment back rewrites the debt, and a captured value
  /// would then describe rows that no longer exist.
  Future<void> _openPayments(
    BuildContext context,
    Palette palette,
    Debt debt,
  ) async {
    await DebtPaymentsSheet.show(context, palette, widget.state, debt.id);
    if (mounted) setState(() {});
  }

  Future<void> _openPayment(
    BuildContext context,
    Palette palette,
    Debt debt,
  ) async {
    await PaymentSheet.show(
      context,
      palette: palette,
      state: widget.state,
      debt: debt,
    );
    if (mounted) setState(() {});
  }

  /// "Mark settled" FILLS IN the rest of the debt as paid, and until now it
  /// did that on one unconfirmed tap.
  ///
  /// The amount it invents is the thing worth saying out loud, because it is
  /// invisible otherwise: a debt at 7,350 of 12,000 silently becomes 12,000
  /// of 12,000. The person reading the card sees a progress bar fill, not a
  /// figure being written.
  ///
  /// The reverse direction needs no confirmation and deliberately does not
  /// get one. Un-settling now puts the real figure back, so there is nothing
  /// to lose by tapping it and nothing to warn about, which is the point of
  /// having fixed the engine rather than only signposting it.
  Future<void> _confirmSettle(
    BuildContext context,
    Palette palette,
    Debt debt,
  ) async {
    if (debt.isSettled) {
      widget.state.toggleDebtSettledById(debt.id);
      setState(() {});
      return;
    }

    final Money fills = debt.remaining;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Mark ${debt.person} settled?',
          style: AppType.title(palette),
        ),
        content: Text(
          // Figures first, then the one thing somebody would otherwise get
          // wrong: this is a correction, not a payment, so no account moves
          // and nothing appears in Activity.
          'This fills in the rest as paid. '
          '${formatPeso(debt.paidAmount.pesos)} of ${formatPeso(debt.totalAmount.pesos)} '
          'is recorded now, so Salapify will record the remaining '
          '${formatPeso(fills.pesos)} as paid too.\n\n'
          'Use this when the books were wrong and the debt is really clear. '
          'It moves no account and nothing appears in your Activity.\n\n'
          'If you change your mind, "Not settled after all" puts '
          '${formatPeso(debt.paidAmount.pesos)} back.',
          style: AppType.body(palette),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppType.body(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Mark it settled', style: AppType.body(palette)),
          ),
        ],
      ),
    );

    if (yes == true) {
      widget.state.toggleDebtSettledById(debt.id);
      if (mounted) setState(() {});
    }
  }

  /// Confirms taking the last payment back, naming BOTH sides in pesos.
  ///
  /// A payment moved two things, so the question has to name two things.
  /// Saying only "take back ₱1,500?" leaves somebody to work out what happens
  /// to the debt and to the account, which is the arithmetic they came here to
  /// avoid doing.
  /// The delete gate, repeated from [FinancialState.deleteDebt] on purpose.
  ///
  /// The state refuses regardless of what this returns, so the two cannot
  /// disagree about what HAPPENS. This one exists so the screen never offers
  /// a control that would be refused, which is its own kind of lie.
  static bool _canDelete(Debt d) =>
      !d.paidAmount.isPositive && d.payments.isEmpty;

  Future<void> _confirmDelete(
    BuildContext context,
    Palette palette,
    Debt debt,
  ) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Delete ${debt.person}?', style: AppType.title(palette)),
        content: Text(
          '${formatPeso(debt.totalAmount.pesos)}, nothing paid. No payment is '
          'recorded against this debt, so nothing in your Activity changes '
          'and no account moves.\n\n'
          // Said plainly, and not softened by pointing at the backup. An
          // export is a snapshot of now, not a history, so it only helps
          // somebody who already made one BEFORE this tap.
          'There is no undo. If you want it back you will have to type it '
          'in again.',
          style: AppType.body(palette),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it', style: AppType.body(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppType.body(palette)),
          ),
        ],
      ),
    );

    if (yes == true) {
      widget.state.deleteDebt(debt.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmArchive(
    BuildContext context,
    Palette palette,
    Debt debt,
  ) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Archive ${debt.person}?', style: AppType.title(palette)),
        content: Text(
          'This takes it off your list. It is NOT deleted. It moves to '
          'Archived at the bottom of this screen, and "Put it back" brings '
          'it up again.\n\n'
          // The sentence that stops the wrong conclusion. A person who has
          // just watched this app's figures move on every other action will
          // reasonably expect this one to move something too.
          'No total changes. A debt you have cleared is already out of what '
          'you owe.'
          '${debt.payments.isEmpty ? '' : '\n\nIts ${debt.payments.length} '
                    'payment${debt.payments.length == 1 ? '' : 's'} stay in '
                    'your Activity and still count. That money really left '
                    'your account, so Salapify does not put it back.'}',
          style: AppType.body(palette),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it here', style: AppType.body(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Archive it', style: AppType.body(palette)),
          ),
        ],
      ),
    );

    if (yes == true) {
      widget.state.archiveDebt(debt.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmTakeBack(
    BuildContext context,
    Palette palette,
    Debt debt,
  ) async {
    final DebtPayment row = debt.payments.last;
    final Account? from = row.accountId == null
        ? null
        : widget.state.accounts
              .where((Account a) => a.id == row.accountId)
              .firstOrNull;

    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Take this payment back?', style: AppType.title(palette)),
        content: Text(
          'This takes back the ${formatPeso(row.amount.pesos)} payment you '
          'recorded ${formatDateLabel(row.date, now: widget.state.now).toLowerCase()} '
          'against ${debt.person}.\n\n'
          '${debt.person} goes back to ${formatPeso(row.paidBefore.pesos)} '
          'paid of ${formatPeso(debt.totalAmount.pesos)}.\n\n'
          // The account half, and the no-account case said out loud rather
          // than left as a silence. A person who chose "no account, just the
          // debt" is entitled to know nothing will move in Activity either.
          '${from == null ? 'No account moves, because this payment was recorded against the debt alone.' : '${from.name} goes back up by ${formatPeso(row.amount.pesos)}, and the entry stays in your Activity, marked as taken back.'}',
          style: AppType.body(palette),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it', style: AppType.body(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Take it back', style: AppType.body(palette)),
          ),
        ],
      ),
    );

    if (yes == true) {
      // `row` is the payment this dialog just described in pesos, by date and
      // by account. Passing its id is what makes the store act on THAT row or
      // refuse, rather than independently resolving `payments.last` and
      // trusting the two to agree.
      widget.state.takeBackDebtPayment(debt.id, paymentId: row.id);
      if (mounted) setState(() {});
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.onBack,
    required this.onAdd,
  });

  final Palette palette;
  final VoidCallback? onBack;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.md, Spacing.sm, 0),
      child: Row(
        children: <Widget>[
          if (onBack != null)
            Semantics(
              button: true,
              label: 'Back',
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: Spacing.sm),
          Text('Debts', style: AppType.screenTitle(palette)),
          InfoDot(
            color: palette.textMuted,
            semanticLabel: 'How debt both ways works',
            onTap: () =>
                InfoSheet.show(context, palette, InfoTopic.debtBothWays),
          ),
          const Spacer(),
          // Hidden rather than disabled on the calculators tab. A greyed
          // button invites a tap and then does nothing, which reads as a bug;
          // an absent one reads as "not on this tab".
          if (onAdd != null)
            Semantics(
              button: true,
              label: 'Add a debt',
              child: InkWell(
                key: const Key('debt-add'),
                onTap: onAdd,
                borderRadius: BorderRadius.circular(Radii.pill),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.add, size: 16, color: palette.accent),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        'Add',
                        style: AppType.button(palette, color: palette.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two totals with the proportional bar between them.
class _Beam extends StatelessWidget {
  const _Beam({required this.palette, required this.debts});

  final Palette palette;
  final List<Debt> debts;

  @override
  Widget build(BuildContext context) {
    final Money owe = outstanding(debts, DebtDirection.iOwe);
    final Money owed = outstanding(debts, DebtDirection.owedToMe);
    final ({double owedToMe, double youOwe}) split = beamSplit(debts);
    final Money net = owed - owe;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('YOU OWE', style: AppType.kicker(palette)),
                    Text(
                      formatPeso(owe.pesos),
                      style: AppType.amount(
                        palette,
                      ).copyWith(color: palette.negative),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('OWED TO YOU', style: AppType.kicker(palette)),
                  Text(
                    formatPeso(owed.pesos),
                    style: AppType.amount(
                      palette,
                    ).copyWith(color: palette.positive),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: (split.youOwe * 10).round(),
                  child: Container(height: 8, color: palette.negative),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: (split.owedToMe * 10).round(),
                  child: Container(height: 8, color: palette.positive),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            // The one figure that matters, said as a sentence rather than left
            // for the reader to subtract. The bar itself is clamped so neither
            // side vanishes, which makes it an illustration; this is the
            // number.
            net.isZero
                ? 'What you owe and what you are owed cancel out exactly.'
                : net.isPositive
                ? 'On balance, ${formatPeso(net.pesos)} is owed to you.'
                : 'On balance, you owe ${formatPeso(net.pesos)}.',
            style: AppType.caption(palette),
          ),
        ],
      ),
    );
  }
}

class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({
    required this.palette,
    required this.current,
    required this.owe,
    required this.owed,
    required this.onSelect,
  });

  final Palette palette;
  final DebtDirection current;
  final double owe;
  final double owed;
  final ValueChanged<DebtDirection> onSelect;

  @override
  Widget build(BuildContext context) {
    // THE SHARED SLIDING SWITCH, not a second row of orange tabs. The UI
    // review of 2026-10-07 counted four solid orange shapes above the first
    // card: two rows of tabs that looked identical, so nothing said which was
    // the screen's sections and which was a filter inside one. Sections keep
    // the solid tabs; this filter now looks like every other filter in the
    // app, with the thumb that slides.
    return SegmentedChoice<DebtDirection>(
      palette: palette,
      options: const <(DebtDirection, String)>[
        (DebtDirection.iOwe, 'You owe'),
        (DebtDirection.owedToMe, 'Owed to you'),
      ],
      selected: current,
      onSelect: onSelect,
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? palette.onAccent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One debt, with everything a person needs to decide what to do about it.
class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.palette,
    required this.debt,
    required this.onPay,
    required this.onSettle,
    this.onTakeBack,
    this.onDelete,
    this.onArchive,
    this.onUnarchive,
    this.onViewPayments,
  });

  final Palette palette;
  final Debt debt;
  final VoidCallback? onPay;

  /// Opens the payment list. A callback rather than the store, because this
  /// card is stateless and every other action on it already arrives this way.
  ///
  /// Null is a real answer and the card checks `payments.isEmpty` before
  /// drawing the control anyway, so a debt with nothing recorded shows the
  /// plain caption with no chevron and nothing to tap.
  final VoidCallback? onViewPayments;

  /// Null on an ARCHIVED card, which offers one action and no others.
  ///
  /// It was not null once, and the bug that produced is the reason this is
  /// nullable now. The archived card drew the ordinary "Not settled after
  /// all" control, so two taps made a debt live while it stayed archived,
  /// and an archived debt is filtered out of every total in the app.
  final VoidCallback? onSettle;

  /// Taking the debt off the list. Exactly one of these is ever non-null for
  /// a given debt, and which one is decided by the debt's own figures rather
  /// than by the caller, so the screen cannot offer something the state
  /// would refuse.
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;

  /// Null when there is nothing to take back, which is every debt from a
  /// restored backup and every payment made before the register existed. The
  /// control is ABSENT rather than disabled: a dead button on a money screen
  /// reads as the app being broken, when the truth is simply that this debt
  /// has no record of how it got where it is.
  final VoidCallback? onTakeBack;

  @override
  Widget build(BuildContext context) {
    final bool owing = debt.direction == DebtDirection.iOwe;
    final Color tint = owing ? palette.negative : palette.positive;

    final List<String> meta = <String>[
      if (debt.installmentCurrent != null && debt.installmentTotal != null)
        'Payment ${debt.installmentCurrent} of ${debt.installmentTotal}'
      else if (debt.schedule == DebtSchedule.flexible)
        'Flexible, pay when you can',
      if (debt.dueDate != null && !debt.isSettled) 'Due ${debt.dueDate}',
      if (debt.isSettled && debt.settledDate != null)
        'Cleared ${debt.settledDate}',
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(debt.person, style: AppType.section(palette)),
                    if (meta.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(meta.join(' · '), style: AppType.rowMeta(palette)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatPeso(
                      (debt.isSettled ? debt.totalAmount : debt.remaining)
                          .pesos,
                    ),
                    style: AppType.amountSmall(palette).copyWith(
                      color: debt.isSettled ? palette.textMuted : tint,
                    ),
                  ),
                  Text(
                    debt.isSettled ? 'paid in full' : 'still to go',
                    style: AppType.caption(palette),
                  ),
                ],
              ),
            ],
          ),
          if (!debt.isSettled) ...<Widget>[
            const SizedBox(height: Spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              // Grows after a payment, so the bar shows the payment did it.
              child: GrowTo(
                value: debt.progress,
                builder: (double v) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: palette.trackSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(tint),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            // THE WAY IN TO THE PAYMENT LIST, built on the caption that was
            // already here rather than as a new row, so it costs no height on
            // a card that already stacks up to nine blocks.
            //
            // No chevron and no tap when the register is empty. A dead
            // affordance on a money card is what cost the founder their
            // emulator data once, and three of the five seeded debts carry a
            // paid figure with no register at all.
            if (debt.payments.isEmpty)
              Text(
                '${formatPeso(debt.paidAmount.pesos)} of '
                '${formatPeso(debt.totalAmount.pesos)} so far',
                style: AppType.caption(palette),
              )
            else
              InkWell(
                onTap: onViewPayments,
                borderRadius: BorderRadius.circular(Radii.control),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${formatPeso(debt.paidAmount.pesos)} of '
                          '${formatPeso(debt.totalAmount.pesos)} so far',
                          // WRAPS rather than ellipsizes. A seven digit pair
                          // collides with the count on the right at 320dp, and
                          // an ellipsis would cut a peso figure in half, which
                          // the readability sweep fails on and a person cannot
                          // read either way.
                          maxLines: 2,
                          style: AppType.caption(palette),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        debt.payments.length == 1
                            ? '1 payment'
                            : '${debt.payments.length} payments',
                        style: AppType.caption(palette),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: palette.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (debt.notes != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(debt.notes!, style: AppType.caption(palette)),
          ],
          const SizedBox(height: Spacing.md),
          Row(
            children: <Widget>[
              if (onPay != null)
                Expanded(
                  child: _Action(
                    palette: palette,
                    label: owing ? 'Record a payment' : 'Record a collection',
                    filled: true,
                    onTap: onPay,
                  ),
                ),
              if (onPay != null && onSettle != null)
                const SizedBox(width: Spacing.sm),
              if (onSettle != null)
                Expanded(
                  child: _Action(
                    palette: palette,
                    label: debt.isSettled
                        ? 'Not settled after all'
                        : 'Mark settled',
                    filled: false,
                    onTap: onSettle,
                  ),
                ),
            ],
          ),
          if (onTakeBack != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Action(
              palette: palette,
              // Named for the LAST one on purpose. Only the most recent
              // payment can go back, because paidAmount is one running figure
              // and an older row's "before" is only the right answer when
              // nothing landed after it. Saying so in the label is what stops
              // somebody tapping it expecting to pick.
              label: 'Take back the last payment',
              filled: false,
              onTap: onTakeBack,
            ),
          ]
          // A DEBT THAT HAS BEEN PAID AND HAS NO RECORD OF IT SAYS SO.
          //
          // This is the case that cost the founder their emulator data. The
          // control is absent whenever there is nothing to take back, which
          // is right, and silence cannot be told apart from a broken screen:
          // they restarted, saw no button, concluded the feature was broken,
          // and reinstalled. The evidence went with it.
          //
          // Deliberately NOT shown on a debt with nothing paid. There is
          // nothing surprising about having no payments to take back when no
          // payment was ever made, and a line on every card is the clutter
          // that makes people stop reading the one that matters. It appears
          // only where a figure says money moved and Salapify cannot say when,
          // which is every debt from a restored backup and every payment made
          // before the register existed.
          // THE BRANCH IS DECIDED BY THE DATA, NOT BY THE CALLBACK, and that
          // distinction is a fix rather than a flourish.
          //
          // It used to read `else if (paidAmount.isPositive)`, which asked
          // "is the button absent" and answered a different question: "is
          // there nothing to take back". Those agree on a live card, where
          // the callback is computed from payments.isEmpty, and they disagree
          // on an ARCHIVED card, which passes no callback for its own
          // reasons. An archived debt is always settled and settling fills
          // paidAmount, so every archived card drew this sentence, and it is
          // FALSE for any debt cleared by real payments.
          //
          // That is worse than clutter. reconciliation_view.dart sends people
          // to this exact screen to take a payment back, and the card they
          // arrive at was telling them it could not be done.
          else if (debt.paidAmount.isPositive && debt.payments.isEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              'Salapify has no record of the payments on this debt, so it '
              'cannot take one back. Payments you record from now on can be.',
              style: AppType.caption(palette),
            ),
          ]
          // Archived, and it DOES have a register. The way back is real, so
          // the card names it instead of denying it.
          else if (debt.payments.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(
              'Its ${debt.payments.length} '
              'payment${debt.payments.length == 1 ? '' : 's'} '
              '${debt.payments.length == 1 ? 'is' : 'are'} still recorded. '
              'Put it back on the list first if you need to take one back.',
              style: AppType.caption(palette),
            ),
          ],
          // TAKING THE DEBT OFF THE LIST.
          //
          // Three outcomes, and the third one is why there is a line here at
          // all. Shipping Delete on some cards and nothing on others invites
          // exactly one wrong conclusion, that the app is inconsistent or
          // broken, so the card that cannot offer it says why and names the
          // way out instead of going quiet. That is this session's own
          // lesson: an unexplained missing control is what cost the founder
          // their emulator data.
          if (onUnarchive != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Action(
              palette: palette,
              label: 'Put it back',
              filled: false,
              // No confirmation anywhere behind this, deliberately. Nothing
              // is lost by tapping it, which is the same reasoning this
              // screen already applies to un-settling.
              onTap: onUnarchive,
            ),
          ] else if (onDelete != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Action(
              palette: palette,
              label: 'Delete this debt',
              filled: false,
              onTap: onDelete,
            ),
          ] else if (onArchive != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _Action(
              palette: palette,
              label: 'Archive it',
              filled: false,
              onTap: onArchive,
            ),
          ],
          // NO LINE on a debt that can be neither deleted nor archived, and
          // this is a deliberate reversal made after LOOKING at the render.
          //
          // A first version explained the absence on the card itself. It was
          // correct and it was unreadable: part paid and live is the normal
          // state of a real debt, so that sentence landed on every card
          // forever, under the take-back line, and turned the screen into
          // the wall of grey text the founder ruled against on 2026-09-18.
          //
          // It is a LESSON, read once and skipped forever after, so it goes
          // behind the "i" dot in this screen's own header, under "Taking a
          // debt off the list". The take-back line above stays, because that
          // one is not a lesson: it explains a control that USED to be there
          // and is specific to this debt's own history.
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.palette,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  // `filled` is TONAL, a soft accent fill with accent text, rather than solid
  // orange. Every card on this screen carries one, and with two or three
  // debts the list was a column of solid orange bars competing with the tabs
  // above it. The pair is in palette_contrast_test.dart as "accent on
  // accentSoft", so it holds AA in every palette.
  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: onTap != null,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            decoration: BoxDecoration(
              color: filled ? palette.accentSoft : palette.surface,
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(
                color: filled ? palette.accentSoft : palette.border,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppType.family,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: filled ? palette.accent : palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.palette,
    required this.direction,
    this.allClear = true,
  });

  final Palette palette;
  final DebtDirection direction;

  /// Nothing owed elsewhere either: no instalment plan, no card or loan
  /// balance. Only then does Pan appear calm.
  final bool allClear;

  @override
  Widget build(BuildContext context) {
    final bool owing = direction == DebtDirection.iOwe;
    final Widget title = Text(
      owing ? 'You owe nobody anything' : 'Nobody owes you anything',
      style: AppType.section(palette),
    );
    final Widget body = Text(
      owing
          ? 'Add a loan, a card plan or a pahiram and Salapify will '
                'track what is left and when it is due.'
          : 'Lent somebody money? Add it here so it is written down '
                'somewhere other than your memory.',
      textAlign: TextAlign.center,
      style: AppType.body(palette),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      // Pan calm on "You owe nobody anything" (D30), the all-clear. The other
      // side, nobody owing YOU, is neither good nor bad news, so it keeps its
      // icon.
      child: owing && allClear
          ? PanEmptyContent(mood: PanMood.calm, title: title, body: body)
          : Column(
              children: <Widget>[
                Icon(
                  Icons.volunteer_activism_outlined,
                  size: 28,
                  color: palette.textMuted,
                ),
                const SizedBox(height: Spacing.sm),
                title,
                const SizedBox(height: Spacing.xs),
                body,
              ],
            ),
    );
  }
}
