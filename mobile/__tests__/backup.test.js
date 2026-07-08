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
    expect(SCHEMA_VERSION).toBe(6);
  });

  test('a v2 blob migrates and keeps every collection row', () => {
    const out = sanitizeData(fixtureAt(2));
    expect(out.schemaVersion).toBe(6);
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
    expect(out.schemaVersion).toBe(6);
    expect(out.people).toHaveLength(1);
    expect(out.receivables).toHaveLength(1);
    expect(out.receivables[0].personId).toBe('person_m3_0');
    expect(out.receivables[0].amount).toBe(500);
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

describe('sanitizeData refuses data from a newer app', () => {
  test('a schemaVersion above the current one throws the clear update message', () => {
    expect(() => sanitizeData({ schemaVersion: 99, accounts: [] })).toThrow(
      /newer version of Salapify/
    );
  });

  test('the refusal never partially applies (it throws, returns nothing)', () => {
    let result;
    try {
      result = sanitizeData({ schemaVersion: 7, accounts: [] });
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
