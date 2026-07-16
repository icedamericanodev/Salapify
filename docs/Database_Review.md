# Database Review

Sprint 0 engineering audit, 2026-07-10. Salapify has no server database; the
database is one JSON blob in AsyncStorage on the device. This document records
the exact stored shape (schemaVersion 12), the versioning and migration
approach, every storage key in use, and the findings.

## Storage architecture

- Engine: @react-native-async-storage/async-storage. One JSON blob under a
  single key. No SQLite, no SecureStore, no encryption at rest beyond OS
  sandboxing.
- mobile/lib/storage.js: loadData returns a three state result (ok, empty,
  error); on error the app keeps running on seed data but disables saving so
  a bad read can never overwrite real data. saveData returns ok plus size.
  Size thresholds SIZE_NUDGE 700KB and SIZE_WARN 1500KB exist because
  Android's SQLite backed AsyncStorage refuses reads near 2MB per row; this
  is the hard scaling ceiling of the current design.
- mobile/context/AppData.js: a single React context owns the whole blob.
  Saves are debounced 500ms, flushed on AppState background and on provider
  unmount; three consecutive save failures raise a persistent user facing
  banner. All mutations go through helpers; account balance moves are always
  reversed and reapplied on edit and delete via balanceSign (income or flow
  in raises, everything else lowers).

## AsyncStorage keys (complete list, verified by grep)

| Key | Written by | Purpose |
| --- | --- | --- |
| salapify_data_v2 | lib/storage.js (also read directly by widgets/widget-task-handler.js) | The entire app data blob |
| salapify_data_v2_prev | lib/storage.js | One deep snapshot taken before restore, import, erase, or a schema migration; cleared on erase |
| salapify_theme_mode | context/Theme.js | light, dark, or system |
| salapify_theme_palette | context/Theme.js | chosen color palette |
| salapify_peak_networth | app/(tabs)/index.js (cleared by app/data.js on start fresh) | highest seen net worth for the gold pill |
| salapify_fx_v1 | hooks/useFxRates.js | cached FX rates, kept out of the main blob so backups do not bloat |

Receipt photos live outside AsyncStorage in the app documents folder under
receipts/receipt_(id).(ext) (lib/receipts.js); only the relative path is
stored on the transaction, and sanitizeData rejects any receiptUri not
matching that exact pattern (path escape defense).

## Blob shape under salapify_data_v2 (schemaVersion 12)

Defined by seedData in mobile/context/AppData.js and enforced by sanitizeData
in mobile/lib/backup.js:

- schemaVersion: number (currently 12)
- accounts: list of { id, name, brand, icon, kind: cash, savings, checking,
  or ewallet (anything else coerced to cash), balance: number, target:
  number }
- assets: list of { id, name, kind, value: number }
- debts: list of { id, name, type (card, loan, other), remaining,
  monthlyRate, minPayment, dueDay, statementDay, graceDays, creditLimit (all
  numbers), interestThroughISO optional YYYY-MM-DD (interest accrual clock;
  malformed values dropped so there is no back accrual) }
- payments: debt payments { id, debtId, amount at least 0, date, interest
  optional, principal optional (absent on legacy payments means the whole
  amount is treated as principal), status optional (pending for card
  payments) }
- transactions: { id, type: income, expense, transfer, debt, or adjustment
  (unknown coerced to expense), label, amount at least 0 (direction lives in
  type and flow, never in sign), date YYYY-MM-DD (ISO datetimes truncated;
  undated legacy entries stamped to the first of last month), accountId
  optional, categoryId optional, receiptUri optional (strict pattern),
  origCurrency plus origAmount optional (foreign display pair, kept or
  dropped together), flow optional in or out (only trusted on transfer and
  adjustment rows; drives balance direction for cash leg utang moves), source
  optional, recurringId optional }
  - Record row rules: transfer and debt rows without flow lose accountId
    (inert history); adjustment without flow loses accountId too.
- goals: { id, name, target, saved, targetDate }
- wins: opaque objects { id, text, date } (mindset screen)
- notes: opaque note objects (notes screen)
- recurring: { id, type income or expense, label, amount at least 0,
  dayOfMonth 1 to 31 (clamped to month length at post time), accountId,
  lastPosted YYYY-MM (ordered string comparison prevents double posting even
  across clock jumps) }
- categories: { id (uniqueness enforced, duplicates suffixed), name, icon,
  monthlyCap at least 0, parentId optional }, normalized by
  normalizeCategoryTree to at most two levels with no self, orphan, or cycle
  references
- people: { id, name, phone, note }
- receivables: { id, person (legacy display name), personId, amount, dueDate,
  phone, note, paid boolean, cashLeg boolean (true means lending posted a
  real cash outflow that counts in net worth), payments list of { id, amount
  at least 0, date, settled boolean, txnId optional (link to the posted
  income or transfer for reversal) } }
- payables: exact mirror of receivables (borrowing cash leg; payment txnId
  links to posted expenses)
- settings: { currency symbol, currencyCode, monthlyLimit, quickAdds (label,
  amount, accountId optional, categoryId optional), notifications { payday,
  bills, collect, daily }, appLock, onboarded, pro (strict true only),
  budgetCarryOver (strict true only), paydaySchedule (three normalized
  shapes: semimonthly with days 15 and 31 as the default, monthly with a
  day, weekly with a weekday; see lib/format.js normalizeSchedule),
  autoBackup, autoBackupUri, lastAutoBackupAt, autoBackupKeep,
  autoBackupBroken, treats (id, treat, action, emoji, target 1 to 14,
  windowDays 1 to 31, checkIns of unique dates, lifetime, createdAt), plus
  screen written extras such as nwHistory (net worth snapshots from
  insights.js), lessonsRead, and firstLogPrompt }

## Versioning and migration approach (mobile/lib/backup.js)

- SCHEMA_VERSION is 12. MIGRATIONS is a map of forward only, pure,
  synchronous functions keyed by the version each produces. v3 (people
  extraction from receivables, idempotent) and v4 (seed default categories)
  transform data; v5 through v12 are deliberate fence no-ops that exist so an
  older build refuses a newer backup instead of silently mangling it (new
  transaction types, treats, payables, cash legs, interest split,
  adjustments, per transaction currency, subcategories).
- migrate() clamps garbage version values to 2 (guarding against Infinity or
  NaN loops) and throws on a version newer than the build; AppData catches
  that throw and disables saving for the session so newer data is never
  overwritten.
- sanitizeData coerces every collection to arrays of objects, every money
  field to a finite non negative number, every date to a valid string, and
  strips or normalizes hostile values (receiptUri pattern, flow whitelisting,
  strict booleans for pro, cashLeg, settled). appLock is forced off on
  restore to prevent biometric lockout on a different phone.
- A documented guardrail: adding any new top level collection requires a
  version bump, because sanitizeData rebuilds a fixed key list and would
  silently drop unknown collections.
- Backup file format (buildBackup): { app salapify, version 2, exportedAt,
  data } as pretty printed JSON. parseBackup accepts wrapped or bare data and
  requires data.accounts to be an array. parseV1 imports the legacy Peso
  Smart web app format. toCSV exports transactions and debts only.
- Pre migration and pre restore snapshots go to salapify_data_v2_prev (one
  deep, best effort); replaceAll also re stamps recurring lastPosted
  conservatively so a restore can never double post or skip a bill, and
  cleans orphan receipt files.

## Assessment

For an AsyncStorage JSON design this is an unusually disciplined data layer.
The three state load, version refusal, migration fences, hostile input
coercion, snapshot before destruction, and the fact that backup.test.js is
the largest test suite all indicate the team treats the data layer as the
crown jewels, correctly.

## Findings

### DB-1: The single 2MB row ceiling is a permanent lockout, and writes never refuse

Severity: Critical (slow burn) | Effort: S for a guard, XL for the structural
fix
This is the same finding as Technical_Debt.md TD-2 and TD-4, recorded here
because it is fundamentally a database design property: Android CursorWindow
refuses to read AsyncStorage rows near 2MB but allows the writes that get
there. The snapshot key doubles the footprint in the same SQLite file
(Android default 6MB total cap). Immediate: hard cap plus a blocking export
modal in saveData. Structural: expo-sqlite migration (native module, APK
rebuild plus runtime bump), transactions in a real table, settings and small
collections in a KV row, keeping the existing sanitize and migration
discipline at the boundary.

### DB-2: No encryption at rest

Severity: Medium | Effort: L
The blob and receipts are plaintext, protected only by the OS sandbox and
allowBackup false. Full analysis in Security_Audit.md SEC-4. The right moment
to add encryption is the SQLite migration (one rebuild, one migration path,
SQLCipher or a Keystore wrapped key).

### DB-3: Widgets read the raw blob directly, bypassing the seam

Severity: Medium | Effort: S
widgets/widget-task-handler.js reads salapify_data_v2 with its own
AsyncStorage call and its own reimplementation of the net worth math. Two
problems: math drift (Technical_Debt.md TD-6) and a second reader that must
be remembered in any storage engine change. Route the widget reads through
lib/storage.js loadData and lib/analytics.js helpers now, so the SQLite
migration later has exactly one seam to swap.

### DB-4: Screen written settings keys are informal schema

Severity: Low | Effort: S
nwHistory, lessonsRead, and firstLogPrompt are written into settings by
screens without appearing in seedData or the sanitize whitelist description.
sanitizeData spreads settings so they survive, which is deliberate, but it
also means anything can accumulate in settings unnamed. nwHistory in
particular is a growing array (net worth snapshots) living inside the blob.
Recommendation: document every settings key in this file going forward, cap
nwHistory's length explicitly (verify the cap in insights.js when next
touched), and keep the rule that new top level collections need a version
bump.

### DB-5: The snapshot safety net shares fate with the main blob

Severity: Low | Effort: none now
salapify_data_v2_prev lives in the same SQLite database as the main key, so a
corrupted AsyncStorage database loses both. The file based auto backup is the
real second copy, which is one more argument for un-gating it from Pro
(Technical_Debt.md TD-3). No code change beyond that policy decision.

### DB-6: Conversation and history style data must never enter the blob

Severity: advisory
Any future unbounded append data (Pan chat memory, event logs, notification
history) belongs in its own key or the future SQLite store with a hard cap,
never in salapify_data_v2. The FX cache and theme keys already follow this
rule; keep it. Recorded here and in AI_Readiness.md AI-3 so the trap is
documented before anyone builds into it.
