// Debt, both ways. Roadmap step 7.
//
// Pushed over the shell, like account detail: 04-screens.md keeps details and
// secondary screens off the tab bar, so this carries a BackBar. It is reached
// from the Debt quick action on Home, which pointed at nothing until now.
//
// Every peso here comes from `debt_rows.dart`, which in turn takes its
// headline from the same `debtTotals` Home's beam uses. This screen does no
// arithmetic of its own, deliberately: the founder taps a card on Home that
// says what they owe, and lands on a list that has to agree with it.
import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../core/money/institutions.dart' show initialsFor;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../home/home_screen.dart' show shortDate;
import 'debt_detail_screen.dart';
import 'debt_rows.dart';

/// The route this screen lives at. A constant so Home and the router cannot
/// drift apart over a typo in a string.
const String debtRoutePath = '/debt';

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  DebtDirection _dir = DebtDirection.iOwe;

  @override
  Widget build(BuildContext context) {
    final board = debtBoardFrom(context.ledger.data, context.now);
    final side = board.side(_dir);

    return Scaffold(
      backgroundColor: context.skin.bg,
      body: Screen(
        children: [
          const BackBar(),
          const SizedBox(height: 14),
          const ScreenTitle(
            title: 'Debt',
            sub: 'Both ways: what you owe, and what is owed to you.',
          ),
          const SizedBox(height: 18),
          _Beam(board: board),
          const SizedBox(height: 18),
          Segmented(
            options: const ['I owe', 'Owed to me'],
            index: _dir == DebtDirection.iOwe ? 0 : 1,
            onPick: (i) => setState(
              () => _dir = i == 0 ? DebtDirection.iOwe : DebtDirection.owedToMe,
            ),
          ),
          const SizedBox(height: 20),
          if (side.isEmpty)
            _EmptySide(dir: _dir)
          else ...[
            if (side.open.isNotEmpty) ...[
              const Head(title: 'Open'),
              const SizedBox(height: 10),
              Group(
                children: [
                  for (final r in side.open) _DebtItemRow(row: r, dir: _dir),
                ],
              ),
              // Rows the headline above does not include, named rather than
              // quietly dropped. Without this line the list adds up to more
              // than the figure over it and nothing on screen says why.
              if (side.uncountedRows > 0) ...[
                const SizedBox(height: 10),
                _UncountedNote(count: side.uncountedRows),
              ],
            ],
            if (side.settled.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Head(title: 'Settled'),
              const SizedBox(height: 10),
              Group(
                children: [
                  for (final r in side.settled) _DebtItemRow(row: r, dir: _dir),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The two totals, side by side, in the direction the money moves.
///
/// Both figures come straight from `debtTotals`, which is what Home's beam
/// reads, so this card and Home always say the same thing.
class _Beam extends StatelessWidget {
  const _Beam({required this.board});
  final DebtBoard board;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _BeamHalf(
              label: 'You owe',
              amount: board.iOwe.total,
              count: board.iOwe.open.length,
              // Accent, not red. The same colour `Tone.owe` gives a row, and a
              // deliberate choice the design system already made: owing money
              // is a fact to act on, not an alarm to panic at.
              tone: skin.accent,
            ),
          ),
          Container(width: 1, height: 42, color: skin.line),
          Expanded(
            child: _BeamHalf(
              label: 'Owed to you',
              amount: board.owedToMe.total,
              count: board.owedToMe.open.length,
              tone: skin.good,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeamHalf extends StatelessWidget {
  const _BeamHalf({
    required this.label,
    required this.amount,
    required this.count,
    required this.tone,
  });

  final String label;
  final double amount;
  final int count;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TypeScale.caption(skin.text2)),
          const SizedBox(height: 4),
          // sheetTitle, not the 47pt hero: two of these sit side by side in
          // half a card each, and the hero size cannot fit six digits there on
          // a 320dp phone. Guarded by a width test rather than by eye.
          Text(formatMoney(amount), style: TypeScale.sheetTitle(tone)),
          const SizedBox(height: 2),
          Text(
            // "1 open" reads fine, "1 open debts" does not. A finance app that
            // cannot count to one reads as one that cannot count.
            count == 0 ? 'nothing open' : '$count open',
            style: TypeScale.caption(skin.text3),
          ),
        ],
      ),
    );
  }
}

/// One lender or person.
class _DebtItemRow extends StatelessWidget {
  const _DebtItemRow({required this.row, required this.dir});

  final DebtRow row;
  final DebtDirection dir;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // Composed by `debtRowCaption` in debt_rows.dart rather than here, so the
    // width guard in row_fits_test.dart can measure what this screen ACTUALLY
    // says. It was built inline first and the guard measured a hand-copied list
    // of caption strings beside it, which would have stayed green through any
    // change to the wording: a test protecting itself rather than the founder.
    final content = ItemRow(
      monogram: initialsFor(row.name),
      title: row.name,
      sub: debtRowCaption(row, shortDate),
      // A SETTLED row shows what was settled, not zero. `remaining` is zero by
      // definition once a debt is paid, so the first version drew "₱0" beside
      // a struck-through name, which tells the founder nothing and reads like
      // a bug. What they want to see on a cleared debt is its size.
      amount: formatMoney(
        row.settled && row.original > 0 ? row.original : row.remaining,
      ),
      tone: row.settled
          ? Tone.good
          : (dir == DebtDirection.iOwe ? Tone.owe : Tone.good),
      strike: row.settled,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DebtDetailScreen(id: row.id, source: row.source),
        ),
      ),
    );

    if (!row.hasProgress || row.settled) return content;

    // A progress bar ONLY where the ledger records what the debt started at.
    // A `debts` row is rewritten in place on every payment, so it has no
    // original and gets no bar rather than a bar drawn against a guess.
    return Column(
      children: [
        content,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ThinBar(
            fraction: row.progress,
            fill: dir == DebtDirection.iOwe ? skin.accent : skin.good,
          ),
        ),
      ],
    );
  }
}

/// Says out loud that the headline does not cover every row above it.
class _UncountedNote extends StatelessWidget {
  const _UncountedNote({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      count == 1
          ? 'One of these was recorded without saying which account the money '
                'came from, so it is listed here but left out of the total '
                'above and out of your net worth.'
          : '$count of these were recorded without saying which account the '
                'money came from, so they are listed here but left out of the '
                'total above and out of your net worth.',
      style: TypeScale.caption(context.skin.text3),
    ),
  );
}

class _EmptySide extends StatelessWidget {
  const _EmptySide({required this.dir});
  final DebtDirection dir;

  @override
  Widget build(BuildContext context) => dir == DebtDirection.iOwe
      ? const EmptyState(
          icon: Icons.handshake_outlined,
          title: 'You owe nothing',
          body:
              'Loans and anything you borrowed show up here, with what is left '
              'and when the next payment is due.',
        )
      : const EmptyState(
          icon: Icons.volunteer_activism_outlined,
          title: 'Nobody owes you',
          body:
              'When you lend money, record it here and Salapify keeps track of '
              'what came back and what has not.',
        );
}
