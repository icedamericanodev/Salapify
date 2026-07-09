// Regression suite for lib/backup.js: the migration ladder and sanitizeData.
// This is the strictest module because a bug here can silently destroy or
// mangle a user's entire saved history on restore. Every test injects fixed
// fixtures, never the real clock.

import {
  SCHEMA_VERSION,
  DEFAULT_CATEGORIES,
  sanitizeData,
  buildBackup,
  parseBackup,
} from '../lib/backup';

// A representative full blob at a given schemaVersion. Carries at least one
// row in every collection so a dropped collection shows up as a failure.
function fixtureAt(version) {
  const base = {
    schemaVersion: version,
    accounts: [{ id: 'a1', name: 'GCash', kind: 'ewallet', balance: 5000 }],
    assets: [{ id: 'as1', name: 'Phone', value: 12000 }],
    debts: [{ id: 'd1', name: 'Card', type: 'credit', remaining: 20000, monthlyRate: 3, minPayment: 1000 }],
    payments: [{ id: 'p1', debtId: 'd1', amount: 1000, date: '2026-01-10' }],
    transactions: [
      { id: 't1', type: 'income', label: 'Sweldo', amount: 25000, date: '2026-06-30' },
      { id: 't2', type: 'expense', label: 'Food', amount: 150, date: '2026-07-01' },
    ],
    goals: [{ id: 'g1', name: 'Emergency', target: 50000, saved: 10000 }],
    wins: [{ id: 'w1', text: 'Paid rent early' }],
    notes: [{ id: 'n1', text: 'remember load' }],
    recurring: [{ id: 'r1', type: 'expense', label: 'Netflix', amount: 149, dayOfMonth: 5 }],
    settings: { monthlyLimit: 20000, currency: '₱' },
  };
  return base;
}

describe('sanitizeData always produces the current schema shape', () => {
  test('a version-less blob migrates up to the current SCHEMA_VERSION', () => {
    const out = sanitizeData({ accounts: [{ name: 'Cash', balance: 100 }] });
    expect(out.schemaVersion).toBe(SCHEMA_VERSION);
    expect(SCHEMA_VERSION).toBe(10);
  });

  test('a v2 blob migrates and keeps every collection row', () => {
    const out = sanitizeData(fixtureAt(2));
    expect(out.schemaVersion).toBe(10);
    expect(out.accounts).toHaveLength(1);
    expect(out.assets).toHaveLength(1);
    expect(out.debts).toHaveLength(1);
    expect(out.payments).toHaveLength(1);
    expect(out.transactions).toHaveLength(2);
    expect(out.goals).toHaveLength(1);
    expect(out.wins).toHaveLength(1);
    expect(out.notes).toHaveLength(1);
    expect(out.recurring).toHaveLength(1);
  });

  test('a v2 blob preserves money values exactly through migration', () => {
    const out = sanitizeData(fixtureAt(2));
    expect(out.accounts[0].balance).toBe(5000);
    expect(out.debts[0].remaining).toBe(20000);
    expect(out.transactions[0].amount).toBe(25000);
    expect(out.goals[0].saved).toBe(10000);
    expect(out.payments[0].amount).toBe(1000);
  });

  test('the v4 migration seeds the starter categories for older blobs', () => {
    const out = sanitizeData(fixtureAt(2));
    expect(out.categories).toHaveLength(DEFAULT_CATEGORIES.length);
    expect(out.categories.map((c) => c.id)).toContain('cat_food');
  });

  test('a v3 blob (already has people/receivables) round-trips without loss', () => {
    const blob = {
      ...fixtureAt(3),
      people: [{ id: 'person_m3_0', name: 'Ate', phone: '0917', note: '' }],
      receivables: [
        { id: 'rc1', person: 'Ate', personId: 'person_m3_0', amount: 500, dueDate: '2026-05-01', payments: [] },
      ],
    };
    const out = sanitizeData(blob);
    expect(out.schemaVersion).toBe(10);
    expect(out.people).toHaveLength(1);
    expect(out.receivables).toHaveLength(1);
    expect(out.receivables[0].personId).toBe('person_m3_0');
    expect(out.receivables[0].amount).toBe(500);
  });

  test('receivable payments keep their txnId and get a fallback id if missing', () => {
    const blob = {
      ...fixtureAt(3),
      people: [{ id: 'person_m3_0', name: 'Ate', phone: '', note: '' }],
      receivables: [
        {
          id: 'rc1',
          person: 'Ate',
          personId: 'person_m3_0',
          amount: 500,
          payments: [
            { id: 'rpay_1', amount: 200, date: '2026-05-02', txnId: 'transactions_9' },
            { amount: 300, date: '2026-05-03' }, // no id: must gain a stable one
          ],
        },
      ],
    };
    const out = sanitizeData(blob);
    const pays = out.receivables[0].payments;
    expect(pays).toHaveLength(2);
    // The income link survives so a payment stays reversible after restore.
    expect(pays[0].txnId).toBe('transactions_9');
    // Both payments end up with a distinct, truthy id so remove keys cleanly.
    expect(pays[0].id).toBe('rpay_1');
    expect(pays[1].id).toBeTruthy();
    expect(pays[1].id).not.toBe(pays[0].id);
  });

  test('debts keep a real interestThroughISO stamp and drop a malformed one', () => {
    const blob = {
      schemaVersion: 9,
      debts: [
        { id: 'd1', name: 'Card A', remaining: 20000, monthlyRate: 3, interestThroughISO: '2026-06-09' },
        { id: 'd2', name: 'Card B', remaining: 10000, monthlyRate: 2, interestThroughISO: 'not-a-date' },
        { id: 'd3', name: 'Card C', remaining: 5000, monthlyRate: 1, interestThroughISO: 42 },
      ],
    };
    const out = sanitizeData(blob);
    // A valid stamp survives; a garbage string or non-string drops to undefined
    // (the safe no-back-accrual default) so it can never poison the balance.
    expect(out.debts[0].interestThroughISO).toBe('2026-06-09');
    expect(out.debts[1].interestThroughISO).toBeUndefined();
    expect(out.debts[2].interestThroughISO).toBeUndefined();
  });

  test('debt payments keep their interest/principal split and coerce bad values', () => {
    const blob = {
      schemaVersion: 9,
      debts: [{ id: 'd1', name: 'Card', remaining: 20000, monthlyRate: 3 }],
      payments: [
        { id: 'p1', debtId: 'd1', amount: 5000, interest: 600, principal: 4400, date: '2026-07-09' },
        { id: 'p2', debtId: 'd1', amount: 1000, date: '2026-06-09' }, // legacy, no split
      ],
    };
    const out = sanitizeData(blob);
    expect(out.payments[0].interest).toBe(600);
    expect(out.payments[0].principal).toBe(4400);
    // A legacy payment has no split; readers fall back to the whole amount.
    expect(out.payments[1].interest).toBeUndefined();
    expect(out.payments[1].principal).toBeUndefined();
  });

  test('a balance adjustment survives restore with its flow and account link', () => {
    const blob = {
      schemaVersion: 9,
      accounts: [{ id: 'a1', name: 'GCash', kind: 'ewallet', balance: 5000 }],
      transactions: [
        { id: 't1', type: 'adjustment', flow: 'in', amount: 500, date: '2026-07-02', accountId: 'a1', label: 'Balance adjustment' },
        // A corrupt adjustment with no valid flow must lose its accountId so it
        // can never move a balance in an unknown direction; it stays a record.
        { id: 't2', type: 'adjustment', amount: 300, date: '2026-07-03', accountId: 'a1', label: 'Balance adjustment' },
      ],
    };
    const out = sanitizeData(blob);
    const good = out.transactions.find((t) => t.id === 't1');
    const bad = out.transactions.find((t) => t.id === 't2');
    expect(good.type).toBe('adjustment');
    expect(good.flow).toBe('in');
    expect(good.accountId).toBe('a1');
    expect(good.amount).toBe(500);
    expect(bad.type).toBe('adjustment');
    expect(bad.flow).toBeUndefined();
    expect(bad.accountId).toBeUndefined();
  });

  test('a v3 migration from a v2 blob builds people out of receivable names', () => {
    const blob = {
      schemaVersion: 2,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      receivables: [
        { id: 'rc1', person: 'Kuya', amount: 300 },
        { id: 'rc2', person: 'Kuya', amount: 200 },
        { id: 'rc3', person: 'Ate', amount: 100 },
      ],
    };
    const out = sanitizeData(blob);
    // Two distinct names become two people; both receivables for Kuya link to one id.
    expect(out.people).toHaveLength(2);
    expect(out.receivables[0].personId).toBe(out.receivables[1].personId);
    expect(out.receivables[0].personId).not.toBe(out.receivables[2].personId);
  });

  test('a v4 blob keeps its own categories instead of reseeding', () => {
    const blob = {
      ...fixtureAt(4),
      categories: [{ id: 'cat_custom', name: 'Vape fund', icon: '💨', monthlyCap: 500 }],
    };
    const out = sanitizeData(blob);
    expect(out.categories).toHaveLength(1);
    expect(out.categories[0].id).toBe('cat_custom');
  });

  test('a v5 blob keeps transfer and debt record rows as their own types', () => {
    const blob = {
      ...fixtureAt(5),
      transactions: [
        { id: 'tr1', type: 'transfer', label: 'Move to savings', amount: 1000, date: '2026-07-02' },
        { id: 'db1', type: 'debt', label: 'Card payment', amount: 500, date: '2026-07-03' },
      ],
    };
    const out = sanitizeData(blob);
    expect(out.transactions.map((t) => t.type)).toEqual(['transfer', 'debt']);
  });

  test('a legacy transfer/debt record row (no flow) loses its accountId', () => {
    const out = sanitizeData({
      ...fixtureAt(8),
      accounts: [{ id: 'a1', name: 'Cash', balance: 100 }],
      transactions: [{ id: 'tr1', type: 'transfer', label: 'Move', amount: 100, date: '2026-07-02', accountId: 'a1' }],
    });
    expect(out.transactions[0].accountId).toBeUndefined();
  });

  test('a cash leg transfer (has flow) KEEPS its accountId so it can be reversed', () => {
    const out = sanitizeData({
      ...fixtureAt(8),
      accounts: [{ id: 'a1', name: 'GCash', balance: 5000 }],
      transactions: [
        { id: 'lend1', type: 'transfer', flow: 'out', source: 'receivable', label: 'Lent to Juan', amount: 3000, date: '2026-07-02', accountId: 'a1' },
      ],
    });
    const leg = out.transactions[0];
    expect(leg.accountId).toBe('a1');
    expect(leg.flow).toBe('out');
    expect(leg.source).toBe('receivable');
  });

  test('a corrupt flow on a non-transfer is stripped, so balanceSign cannot be flipped', () => {
    const out = sanitizeData({
      ...fixtureAt(8),
      accounts: [{ id: 'a1', name: 'Cash', balance: 100 }],
      transactions: [{ id: 'x1', type: 'expense', flow: 'in', label: 'Groceries', amount: 500, date: '2026-07-02', accountId: 'a1' }],
    });
    expect(out.transactions[0].flow).toBeUndefined();
  });

  test('cashLeg on utang is coerced to a real boolean', () => {
    const out = sanitizeData({
      ...fixtureAt(8),
      receivables: [{ id: 'r1', person: 'Juan', amount: 500, cashLeg: 'yes', payments: [] }],
      payables: [{ id: 'p1', person: 'Nanay', amount: 200, cashLeg: 0, payments: [] }],
    });
    expect(out.receivables[0].cashLeg).toBe(true);
    expect(out.payables[0].cashLeg).toBe(false);
  });

  test('a v6 blob (current) keeps treats intact', () => {
    const blob = {
      ...fixtureAt(6),
      settings: {
        monthlyLimit: 20000,
        treats: [{ id: 'treat_1', treat: 'Kape', action: 'Lakad', emoji: '☕', target: 3, windowDays: 7, checkIns: ['2026-07-01'], lifetime: 4 }],
      },
    };
    const out = sanitizeData(blob);
    expect(out.settings.treats).toHaveLength(1);
    expect(out.settings.treats[0].lifetime).toBe(4);
  });
});

describe('the payables collection (People I owe) migrates and coerces', () => {
  test('an old backup with no payables key migrates to an empty payables array', () => {
    // A v2 blob predates payables entirely: it must arrive with payables: [],
    // never undefined, so the People I owe screen can read it without a guard.
    const out = sanitizeData(fixtureAt(2));
    expect(Array.isArray(out.payables)).toBe(true);
    expect(out.payables).toHaveLength(0);
  });

  test('a v6 backup (before payables) also lands on an empty payables array', () => {
    const out = sanitizeData(fixtureAt(6));
    expect(out.payables).toEqual([]);
  });

  test('a v7 backup round-trips payables, preserving amount, person, and payments', () => {
    const blob = {
      ...fixtureAt(7),
      people: [{ id: 'person_m3_0', name: 'Nanay', phone: '', note: '' }],
      payables: [
        {
          id: 'pay1',
          person: 'Nanay',
          personId: 'person_m3_0',
          amount: 800,
          dueDate: '2026-08-01',
          paid: false,
          payments: [
            { id: 'ppay_1', amount: 300, date: '2026-07-05' },
            { amount: 200, date: '2026-07-06' }, // no id: must gain a stable one
          ],
        },
      ],
    };
    const out = sanitizeData(blob);
    expect(out.schemaVersion).toBe(10);
    expect(out.payables).toHaveLength(1);
    const pay = out.payables[0];
    expect(pay.person).toBe('Nanay');
    expect(pay.personId).toBe('person_m3_0');
    expect(pay.amount).toBe(800);
    expect(pay.payments).toHaveLength(2);
    expect(pay.payments[0].amount).toBe(300);
    // The id-less payment gains a distinct, truthy id so remove keys cleanly.
    expect(pay.payments[0].id).toBe('ppay_1');
    expect(pay.payments[1].id).toBeTruthy();
    expect(pay.payments[1].id).not.toBe(pay.payments[0].id);
  });

  test('payable payments keep their txnId and get a fallback id if missing', () => {
    // Paying a payable posts a real expense; the payment remembers that
    // expense as txnId. A restored backup must keep that link intact so the
    // expense can still be reversed on remove or delete, exactly like the
    // receivable income link.
    const blob = {
      ...fixtureAt(7),
      people: [{ id: 'person_m3_0', name: 'Nanay', phone: '', note: '' }],
      payables: [
        {
          id: 'pay1',
          person: 'Nanay',
          personId: 'person_m3_0',
          amount: 800,
          paid: false,
          payments: [
            { id: 'ppay_1', amount: 300, date: '2026-07-05', txnId: 'transactions_9' },
            { amount: 200, date: '2026-07-06' }, // no id: must gain a stable one
          ],
        },
      ],
    };
    const out = sanitizeData(blob);
    const pays = out.payables[0].payments;
    expect(pays).toHaveLength(2);
    // The expense link survives sanitize untouched.
    expect(pays[0].txnId).toBe('transactions_9');
    // Both payments end up with a distinct, truthy id so remove keys cleanly.
    expect(pays[0].id).toBe('ppay_1');
    expect(pays[1].id).toBeTruthy();
    expect(pays[1].id).not.toBe(pays[0].id);
  });

  test('an unknown field on a payable survives so future data is never erased', () => {
    const blob = {
      schemaVersion: 7,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      payables: [
        { id: 'pay1', person: 'Kuya', amount: 500, futureField: 'from a newer build', note: 'keep me' },
      ],
    };
    const out = sanitizeData(blob);
    expect(out.payables[0].futureField).toBe('from a newer build');
    expect(out.payables[0].note).toBe('keep me');
  });

  test('a blob one version above the current is refused, protecting older builds', () => {
    expect(() => sanitizeData({ schemaVersion: SCHEMA_VERSION + 1, accounts: [] })).toThrow(
      /newer version of Salapify/
    );
  });

  test('a blob at the current version is accepted', () => {
    const out = sanitizeData({ schemaVersion: SCHEMA_VERSION, accounts: [{ id: 'a1', name: 'Cash', balance: 0 }] });
    expect(out.schemaVersion).toBe(SCHEMA_VERSION);
  });

  test('receivables still sanitize as before while payables coexist', () => {
    const blob = {
      schemaVersion: 7,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      receivables: [
        { id: 'rc1', person: 'Ate', amount: 500, paid: false, payments: [{ id: 'rpay_1', amount: 100, date: '2026-07-01', txnId: 'transactions_3' }] },
      ],
      payables: [
        { id: 'pay1', person: 'Nanay', amount: 800, paid: false, payments: [] },
      ],
    };
    const out = sanitizeData(blob);
    expect(out.receivables).toHaveLength(1);
    expect(out.receivables[0].amount).toBe(500);
    // The receivable's income link is still protected exactly as before.
    expect(out.receivables[0].payments[0].txnId).toBe('transactions_3');
    expect(out.payables).toHaveLength(1);
    expect(out.payables[0].amount).toBe(800);
  });
});

describe('sanitizeData refuses data from a newer app', () => {
  test('a schemaVersion above the current one throws the clear update message', () => {
    expect(() => sanitizeData({ schemaVersion: 99, accounts: [] })).toThrow(
      /newer version of Salapify/
    );
  });

  test('the refusal never partially applies (it throws, returns nothing)', () => {
    let result;
    try {
      result = sanitizeData({ schemaVersion: SCHEMA_VERSION + 1, accounts: [] });
    } catch (e) {
      result = 'threw';
    }
    expect(result).toBe('threw');
  });
});

describe('sanitizeData survives hostile version markers without hanging', () => {
  test.each([
    ['Infinity', Infinity],
    ['-Infinity', -Infinity],
    ['NaN', NaN],
    ['a negative', -5],
    ['a string', 'banana'],
  ])('a %s schemaVersion clamps to a real version and still migrates', (_label, v) => {
    const out = sanitizeData({ schemaVersion: v, accounts: [{ name: 'Cash', balance: 1 }] });
    expect(out.schemaVersion).toBe(SCHEMA_VERSION);
  });
});

describe('unknown fields survive so future data is never silently erased', () => {
  test('an unknown field on a treat round-trips (the fixed treats-block bug)', () => {
    const blob = {
      schemaVersion: 6,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      settings: {
        treats: [
          {
            id: 'treat_1',
            treat: 'Kape',
            action: 'Lakad',
            emoji: '☕',
            target: 3,
            windowDays: 7,
            checkIns: [],
            lifetime: 0,
            futureField: 'from a newer build',
            note: 'keep me',
            color: '#abc',
          },
        ],
      },
    };
    const out = sanitizeData(blob);
    const t = out.settings.treats[0];
    expect(t.futureField).toBe('from a newer build');
    expect(t.note).toBe('keep me');
    expect(t.color).toBe('#abc');
  });

  test('an unknown field on an account row survives', () => {
    const out = sanitizeData({
      schemaVersion: 6,
      accounts: [{ id: 'a1', name: 'Cash', balance: 10, futureField: 'x', color: 'green' }],
    });
    expect(out.accounts[0].futureField).toBe('x');
    expect(out.accounts[0].color).toBe('green');
  });

  test('an unknown field on a transaction row survives', () => {
    const out = sanitizeData({
      schemaVersion: 6,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      transactions: [{ id: 't1', type: 'expense', label: 'Food', amount: 100, date: '2026-07-01', futureTag: 'keep' }],
    });
    expect(out.transactions[0].futureTag).toBe('keep');
  });

  test('an unknown field inside settings survives', () => {
    const out = sanitizeData({
      schemaVersion: 6,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      settings: { monthlyLimit: 1000, futureSetting: 'keep me too' },
    });
    expect(out.settings.futureSetting).toBe('keep me too');
  });

  test('an unknown TOP-LEVEL collection is dropped by design (schema-bump guardrail)', () => {
    // Documented behavior: sanitizeData rebuilds a fixed key list, so an
    // unrecognized top-level collection at a known version is intentionally
    // dropped. Real future collections are protected differently: they arrive
    // with a higher schemaVersion, which is refused wholesale (see the refusal
    // tests above). This test locks in that guardrail so it is not weakened by
    // accident.
    const out = sanitizeData({
      schemaVersion: 6,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      subscriptions: [{ id: 'sub1', name: 'Spotify' }],
    });
    expect(out.subscriptions).toBeUndefined();
  });
});

describe('coercion protects the app from crash-inducing junk', () => {
  test('a negative transaction amount is neutralized to zero, never left negative', () => {
    // Direction lives in the type field, not the sign. A smuggled negative
    // expense (one that would ADD money) is clamped to zero, the harmless
    // value, rather than flipped into a real positive expense.
    const out = sanitizeData({
      schemaVersion: 6,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      transactions: [{ id: 't1', type: 'expense', label: 'Refund smuggling', amount: -500, date: '2026-07-01' }],
    });
    expect(out.transactions[0].amount).toBe(0);
  });

  test('a non-array collection coerces to an empty array, never throws', () => {
    const out = sanitizeData({ schemaVersion: 6, accounts: 'not an array', transactions: null });
    expect(out.accounts).toEqual([]);
    expect(out.transactions).toEqual([]);
  });

  test('a crafted receiptUri that escapes the receipts folder is stripped', () => {
    const out = sanitizeData({
      schemaVersion: 6,
      accounts: [{ id: 'a1', name: 'Cash', balance: 0 }],
      transactions: [{ id: 't1', type: 'expense', label: 'x', amount: 1, date: '2026-07-01', receiptUri: 'receipts/../secret.png' }],
    });
    expect(out.transactions[0].receiptUri).toBeUndefined();
  });

  test('a restored backup forces app lock off so no one is locked out', () => {
    const out = sanitizeData({ schemaVersion: 6, accounts: [], settings: { appLock: true } });
    expect(out.settings.appLock).toBe(false);
  });
});

describe('buildBackup and parseBackup are a lossless round trip', () => {
  test('data survives a build then parse cycle unchanged in shape', () => {
    const data = sanitizeData(fixtureAt(6));
    const text = buildBackup(data);
    const restored = parseBackup(text);
    expect(restored.accounts).toHaveLength(1);
    expect(restored.transactions).toHaveLength(2);
    expect(restored.transactions[0].amount).toBe(25000);
    expect(restored.schemaVersion).toBe(SCHEMA_VERSION);
  });

  test('parseBackup rejects text that is not a Salapify backup', () => {
    expect(() => parseBackup(JSON.stringify({ hello: 'world' }))).toThrow(
      /does not look like a Salapify backup/
    );
  });
});
