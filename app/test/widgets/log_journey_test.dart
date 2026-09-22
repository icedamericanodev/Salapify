import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/home_screen.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

/// The Log write path, tested the way CLAUDE.md requires a write path to be
/// tested: in BOTH halves.
///
/// Half one asks whether the money moved correctly. Half two asks whether a
/// person can FOLLOW it afterwards, by walking to every screen that should
/// now mention it and asserting it is actually on the screen.
///
/// Half two is the half that gets forgotten, and it is the half that matters:
/// a payment was once written perfectly and was invisible on the screen an
/// auditor would look at, and every money test was green the whole time.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
  }

  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<HomeScreen>(find.byType(HomeScreen)).state;

  /// The Log button exists TWICE by design, once in the tab bar and once as a
  /// Home quick action, so a bare find.text('Log') matches both and throws
  /// "Bad state: Too many elements". The journey goes through Home's.
  final Finder logButton = find.descendant(
    of: find.byType(QuickActions),
    matching: find.text('Log'),
  );

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  double balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  double netWorthOf(FinancialState s) =>
      s.accounts.fold<double>(0, (double sum, Account a) => sum + a.balance);

  testWidgets('logging a spend moves the money AND shows up where a person '
      'would look for it', (WidgetTester tester) async {
    await pumpApp(tester);
    final FinancialState state = storeOf(tester);

    final double cashBefore = balanceOf(state, 'acc_cash');
    final int countBefore = state.transactions.length;

    await tapAndSettle(tester, logButton);
    expect(find.byType(LogSheet), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '250',
    );
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-merchant')),
        matching: find.byType(TextField),
      ),
      'Mang Tonio Carinderia',
    );
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Save entry'));

    // ---------------------------------------------------------------- half one
    // The money moved, by exactly the amount typed, out of exactly the account
    // chosen. Directional, so a save that silently did nothing fails here.
    expect(balanceOf(state, 'acc_cash'), cashBefore - 250);
    expect(state.transactions.length, countBefore + 1);
    expect(
      state.transactions.first.merchant,
      'Mang Tonio Carinderia',
      reason: 'the newest entry should be the one just logged',
    );

    // ---------------------------------------------------------------- half two
    // Saving lands on Activity, because being left on a screen that does not
    // show the entry is how somebody concludes it did not save.
    expect(
      find.text('Mang Tonio Carinderia'),
      findsWidgets,
      reason: 'the logged entry is not on the screen the app landed on',
    );

    // And it is under Today, not filed under some other day.
    expect(find.text('Today'), findsOneWidget);

    // Now walk BACK to Home and check the screen that lists recent entries.
    await tapAndSettle(tester, find.byIcon(Icons.home_outlined));
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Mang Tonio Carinderia'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Mang Tonio Carinderia'),
      findsWidgets,
      reason: 'Home does not mention an entry logged seconds ago',
    );
  });

  testWidgets(
    'a transfer changes net worth by nothing, and both accounts move',
    (WidgetTester tester) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);

      final double netBefore = netWorthOf(state);
      final double bpiBefore = balanceOf(state, 'acc_bpi');
      final double gcashBefore = balanceOf(state, 'acc_gcash');

      await tapAndSettle(tester, logButton);
      await tapAndSettle(tester, find.text('Moved'));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-amount')),
          matching: find.byType(TextField),
        ),
        '1500',
      );
      await tester.pumpAndSettle();

      // Scoped to each picker by key. Both pickers list account names, so a
      // bare find.text names two controls and the tap is a coin toss.
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byKey(const Key('log-source-picker')),
          matching: find.text('BPI Preferred Payroll'),
        ),
      );
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byKey(const Key('log-destination-picker')),
          matching: find.text('GCash Wallet'),
        ),
      );
      await tapAndSettle(tester, find.text('Save entry'));

      // The invariant.
      expect(netWorthOf(state), netBefore);
      // The directional companion, without which a transfer that transferred
      // nothing would satisfy the invariant perfectly.
      expect(balanceOf(state, 'acc_bpi'), bpiBefore - 1500);
      expect(balanceOf(state, 'acc_gcash'), gcashBefore + 1500);
    },
  );

  testWidgets('Save is refused until there is an amount', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final FinancialState state = storeOf(tester);
    final int countBefore = state.transactions.length;

    await tapAndSettle(tester, logButton);
    await tester.tap(find.text('Save entry'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Still open, nothing written. An entry with no amount is a row that can
    // never be reconciled against anything.
    expect(find.byType(LogSheet), findsOneWidget);
    expect(state.transactions.length, countBefore);
  });

  testWidgets(
    'the sheet says out loud that nothing is saved to the phone yet',
    (WidgetTester tester) async {
      await pumpApp(tester);

      await tapAndSettle(tester, logButton);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-amount')),
          matching: find.byType(TextField),
        ),
        '100',
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Save entry'));

      // This used to demand the opposite: a warning that the entry would not
      // survive a restart, which was the honest thing to say while app/ had
      // no storage. Storage landed, so the warning became the lie and the
      // confirmation became the truth. The assertion is kept rather than
      // deleted, because "does this screen tell the person what really
      // happened to their money" is the question either way.
      expect(
        find.textContaining('Saved to this phone'),
        findsOneWidget,
        reason: 'the app must say plainly that the entry was kept',
      );
      expect(
        find.textContaining('not saved to the phone yet'),
        findsNothing,
        reason: 'a stale warning is as misleading as a stale promise',
      );
    },
  );

  testWidgets('a spend tells you what it is about to do before you save it', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapAndSettle(tester, logButton);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '250',
    );
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
    );

    expect(
      find.textContaining('${formatPeso(250)} leaves Cash on Hand (Pitaka)'),
      findsOneWidget,
    );
  });

  testWidgets('a transfer cannot be sent to the account it came from', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapAndSettle(tester, logButton);
    await tapAndSettle(tester, find.text('Moved'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '500',
    );
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
    );

    // The source is now Cash, so the destination list must not offer it. This
    // is the guard against the engine's preserved quirk, where a transfer
    // with a destination that is not a real other account debits the source
    // and credits nobody.
    expect(
      find.descendant(
        of: find.byKey(const Key('log-destination-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
      findsNothing,
      reason: 'a transfer to itself moves nothing and reads as a bug',
    );
  });

  testWidgets('Transfer is not offered as a category for a spend', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tapAndSettle(tester, logButton);

    // Found by looking at the render. A transfer is a TYPE, and offering it as
    // a spending category produces rows tagged Transfer that are not
    // transfers, which is exactly the entry nobody can reconcile later.
    expect(
      find.text('Transfer'),
      findsNothing,
      reason: 'Transfer is a type, not a category to pick for a spend',
    );
    // The categories that DO belong are still there, so this is not passing
    // because the picker rendered nothing at all.
    expect(find.text('Food & Dining'), findsOneWidget);
  });

  group('the quick parse line', () {
    testWidgets('"Jollibee 500" fills the form and then saves correctly', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);
      final double cashBefore = balanceOf(state, 'acc_cash');

      await tapAndSettle(tester, logButton);

      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'Jollibee 500',
      );
      await tester.pumpAndSettle();

      // It reads back what it understood BEFORE anything is filled in. A
      // parser that guesses silently is one nobody should trust with money.
      expect(
        find.textContaining('Spent ₱500.00 at Jollibee, filed under Food'),
        findsOneWidget,
      );

      await tapAndSettle(tester, find.text('Fill the form with this'));

      // The amount landed in the real amount field, and the category picker
      // moved. Both are checked because filling one and not the other is the
      // failure a person would not notice until the entry was already saved.
      expect(
        find.textContaining('₱500.00 leaves'),
        findsOneWidget,
        reason: 'the amount did not reach the form',
      );

      await tapAndSettle(tester, find.text('Save entry'));

      final Transaction saved = state.transactions.first;
      expect(saved.amount, 500);
      expect(saved.merchant, 'Jollibee');
      expect(saved.category, 'Food & Dining');
      expect(saved.type, TransactionType.expense);
      // The default account is Cash on Hand and no account word was typed.
      expect(balanceOf(state, 'acc_cash'), cashBefore - 500);

      // And a person can SEE it.
      expect(find.text('Jollibee'), findsWidgets);
    });

    testWidgets('an account word picks the account', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);
      final double gcashBefore = balanceOf(state, 'acc_gcash');

      await tapAndSettle(tester, logButton);
      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'angkas 85 gcash',
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Fill the form with this'));
      await tapAndSettle(tester, find.text('Save entry'));

      expect(balanceOf(state, 'acc_gcash'), gcashBefore - 85);
      expect(state.transactions.first.category, 'Transport & Commute');
    });

    testWidgets('sweldo is understood as money coming IN', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);
      final double cashBefore = balanceOf(state, 'acc_cash');

      await tapAndSettle(tester, logButton);
      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'sweldo 32500',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Received ₱32,500.00'), findsOneWidget);

      await tapAndSettle(tester, find.text('Fill the form with this'));
      await tapAndSettle(tester, find.text('Save entry'));

      // The sign is the whole point: getting this backwards would take 32,500
      // OUT of an account on payday.
      expect(state.transactions.first.type, TransactionType.income);
      expect(balanceOf(state, 'acc_cash'), cashBefore + 32500);
    });

    testWidgets('a line with no amount is not offered as an entry', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tapAndSettle(tester, logButton);

      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'jollibee',
      );
      await tester.pumpAndSettle();

      expect(find.text('Fill the form with this'), findsNothing);
      expect(
        find.textContaining('An amount plus a word or two'),
        findsOneWidget,
      );
    });

    testWidgets('a parsed category that does not fit the type is not applied', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);

      await tapAndSettle(tester, logButton);
      // "mp2" maps to Investment & Passive Income, an INCOME category, while
      // the type stays expense. Applying it would select a category the
      // picker filters out, so the entry would be filed under something
      // invisible and unchangeable.
      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'mp2 2000',
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Fill the form with this'));
      await tapAndSettle(tester, find.text('Save entry'));

      expect(state.transactions.first.amount, 2000);
      expect(
        state.transactions.first.category,
        isNot('Investment & Passive Income'),
        reason: 'an income category must not be attached to an expense',
      );
    });

    testWidgets('"Electricity 1500" files a utility bill, not lunch', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);

      await tapAndSettle(tester, logButton);
      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'Electricity 1500',
      );
      await tester.pumpAndSettle();

      // The read-back has to say it BEFORE anything is filled in. That
      // sentence is the only place a wrong guess is visible while it is still
      // cheap to correct.
      expect(find.textContaining('filed under Bills & Utilities'), findsOne);

      await tapAndSettle(tester, find.text('Fill the form with this'));
      await tapAndSettle(tester, find.text('Save entry'));

      expect(state.transactions.first.category, 'Bills & Utilities');
    });

    testWidgets('an unknown word does not silently become Food & Dining', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);

      await tapAndSettle(tester, logButton);

      // Pick a real category FIRST, so the test can tell "left alone" apart
      // from "happened to match the default". Without this the assertion
      // below passes for the wrong reason, because the sheet's own default
      // is Food & Dining too.
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byKey(const Key('log-category-picker')),
          matching: find.text('Transport & Commute'),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'Xylophone 1500',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('category not recognized'),
        findsOne,
        reason: 'the read-back claimed a category it had no evidence for',
      );

      await tapAndSettle(tester, find.text('Fill the form with this'));
      await tapAndSettle(tester, find.text('Save entry'));

      expect(state.transactions.first.amount, 1500);
      expect(
        state.transactions.first.category,
        'Transport & Commute',
        reason: 'an unrecognised word overwrote a category the person chose',
      );
    });
  });

  group('defects the QA pass found in the Log sheet', () {
    testWidgets('switching to Received moves the category off an expense one', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);

      await tapAndSettle(tester, logButton);
      // Default is Spent with Food & Dining selected.
      await tapAndSettle(tester, find.text('Received'));

      // Food & Dining is an EXPENSE category and the picker filters by type,
      // so leaving it selected meant nothing was highlighted and the income
      // saved under it anyway. Save never looked at the category.
      expect(find.text('Food & Dining'), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-amount')),
          matching: find.byType(TextField),
        ),
        '32500',
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Save entry'));

      final Transaction saved = state.transactions.first;
      expect(saved.type, TransactionType.income);
      expect(
        saved.category,
        isNot('Food & Dining'),
        reason: 'income must not be filed under an expense category',
      );
      final CategoryInfo filed = state.categories.firstWhere(
        (CategoryInfo c) => c.name == saved.category,
      );
      expect(
        filed.kind == CategoryKind.income || filed.kind == CategoryKind.both,
        isTrue,
        reason: '${saved.category} is not an income category',
      );
    });

    testWidgets('an entry logged under a profile is visible on Activity', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);

      // The profile is chosen on Home and silently scopes the whole Activity
      // tab. An entry saved while one was active used to vanish from the very
      // screen the app navigates to after saving, while the money had already
      // left the account.
      state.setActiveProfile(ProfileEntity.household);
      await tester.pumpAndSettle();

      await tapAndSettle(tester, logButton);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-amount')),
          matching: find.byType(TextField),
        ),
        '500',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-merchant')),
          matching: find.byType(TextField),
        ),
        'Kuryente Ambag',
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Save entry'));

      expect(
        state.transactions.first.profile,
        ProfileEntity.household,
        reason: 'the entry must carry the profile it was logged under',
      );
      expect(
        find.text('Kuryente Ambag'),
        findsWidgets,
        reason: 'the entry vanished from the screen the app landed on',
      );
    });
  });

  group('the date picker', () {
    testWidgets('defaults to today and says so', (WidgetTester tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, logButton);

      await tester.ensureVisible(find.text('When'));
      await tester.pumpAndSettle();
      // Scoped to the sheet: Home's Coming Up card also says "Today".
      expect(
        find.descendant(
          of: find.byType(LogSheet),
          matching: find.text('Today'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('yesterday\'s coffee files under yesterday and still moves '
        'the money today', (WidgetTester tester) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);
      final double cashBefore = balanceOf(state, 'acc_cash');

      await tapAndSettle(tester, logButton);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-amount')),
          matching: find.byType(TextField),
        ),
        '180',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('log-merchant')),
          matching: find.byType(TextField),
        ),
        'Kape Kahapon',
      );
      await tester.pumpAndSettle();

      // Open the picker and step back one day. The picker is a Material
      // dialog, so this drives it the way a person does rather than poking
      // state directly.
      await tapAndSettle(tester, find.text('Change'));
      expect(find.byType(DatePickerDialog), findsOneWidget);

      final DateTime yesterday = state.now.subtract(const Duration(days: 1));
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('${yesterday.day}'),
        ),
      );
      await tapAndSettle(tester, find.text('OK'));

      // It warns that the money still moves now, which is true and surprising.
      expect(
        find.textContaining('The balance changes now'),
        findsOneWidget,
        reason: 'a backdated entry still debits the account today',
      );

      await tapAndSettle(tester, find.text('Save entry'));

      final Transaction saved = state.transactions.first;
      final String expectedIso =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';
      expect(saved.date, expectedIso, reason: 'stored under the chosen day');

      // The money moved anyway. This is the half that would be easy to lose
      // while making the date work.
      expect(balanceOf(state, 'acc_cash'), cashBefore - 180);

      // A backdated entry is NOT at the top of Activity, because the list is
      // newest day first. Landing on a screen whose first rows are today's
      // reads exactly like it did not save, so the confirmation has to say
      // which day it went under. This assertion is that sentence.
      expect(
        find.textContaining('Logged under Yesterday'),
        findsOneWidget,
        reason: 'nothing told the user where the entry actually went',
      );

      // And a person can SEE it, filed under Yesterday rather than Today.
      // It is below the fold by construction, so scroll the way they would.
      await tester.scrollUntilVisible(
        find.text('Kape Kahapon'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kape Kahapon'), findsWidgets);
      expect(find.text('Yesterday'), findsWidgets);
    });

    testWidgets('the future is not offered, because the balance moves today', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);

      await tapAndSettle(tester, logButton);
      await tapAndSettle(tester, find.text('Change'));

      // Tomorrow is present in the grid but disabled. A future dated expense
      // would take the money out today and file the entry under a day that
      // has not happened, so the two would disagree until it arrived.
      final DateTime tomorrow = state.now.add(const Duration(days: 1));
      final Finder tomorrowCell = find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('${tomorrow.day}'),
      );
      await tester.tap(tomorrowCell, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('OK'));

      // Still today, because the tap did nothing.
      expect(
        find.descendant(
          of: find.byType(LogSheet),
          matching: find.text('Today'),
        ),
        findsOneWidget,
      );
    });
  });

  group('a pasted bank or e-wallet receipt', () {
    // The same box, a different shape of text. The prototype puts this
    // behind a second collapsible panel with its own button, which is a
    // second place to look for something already in the clipboard.
    //
    // Nothing here reads a message. The person pastes one, which is why the
    // feature needs no Android permission and could ship today.

    testWidgets('a GCash receipt fills the form and saves correctly', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);
      final double before = balanceOf(state, 'acc_gcash');

      await tapAndSettle(tester, logButton);
      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'You have sent PHP 450.00 of GCash to JOLLIBEE 09171234567 on '
        '09-20-26 12:30. Ref. No. 100234567891. Your new balance is PHP '
        '2,150.75.',
      );
      await tester.pumpAndSettle();

      // It reads back what it understood BEFORE filling anything in, the
      // same as a typed line does. 450, not 09171234567 and not the closing
      // balance of 2,150.75.
      expect(
        find.textContaining('Spent ₱450.00 at Jollibee'),
        findsOneWidget,
        reason: 'it read the wrong number out of a message full of numbers',
      );

      await tapAndSettle(tester, find.text('Fill the form with this'));
      await tapAndSettle(tester, find.text('Save entry'));

      // BOTH HALVES. The money moved, and it moved out of the account the
      // message named rather than whichever one was first in the list.
      expect(
        balanceOf(state, 'acc_gcash'),
        closeTo(before - 450, 0.001),
        reason: 'the 450 did not leave the GCash account',
      );
    });

    testWidgets('money RECEIVED is saved as income, not as spending', (
      WidgetTester tester,
    ) async {
      // The prototype files every message as an expense, so this would take
      // 5,000 OUT of an account that just gained it. Wrong in both
      // directions at once, and the kind of wrong somebody finds a week
      // later when nothing reconciles.
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);
      final double before = balanceOf(state, 'acc_gcash');

      await tapAndSettle(tester, logButton);
      await tester.enterText(
        find.byKey(const Key('log-quick-parse')),
        'You have received PHP 5,000.00 from JUAN DELA CRUZ via GCash on '
        '09-20-26. Ref. No. 900112233445.',
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Fill the form with this'));
      await tapAndSettle(tester, find.text('Save entry'));

      expect(
        balanceOf(state, 'acc_gcash'),
        closeTo(before + 5000, 0.001),
        reason: 'a received amount was logged as money leaving',
      );
    });
  });
}
