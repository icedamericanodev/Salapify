# ADR 0001: A durable, encrypted data foundation for the Salapify ledger

- Status: ACCEPTED (founder approved the recommendations on 2026-07-30, "go
  with your recommendations"). Implementation proceeds with PR A only; the
  native PR B stays gated for its own explicit approval.
- Date: 2026-07-30

### Decision record (founder approval, 2026-07-30)

The founder approved the recommended path. The chosen options, from Section 17:

1. Storage engine: SQLCipher-backed SQLite holding the JSON document behind the
   repository interface (Section 2).
2. Biometric key binding: NO. Encrypt at rest with a Keystore-wrapped DEK any run
   can use; App Lock stays the UI gate (Section 4). Avoids turning a sensor reset
   into data loss.
3. Money: Path 1. Keep double parity, introduce only the pass-through adapter
   seam; no number changes; goldens unchanged (Section 11). True zero drift, if
   ever wanted, is a separate later ADR.
4. Performance: the proposed budget (log-save p95 < 50ms, cold load < 400ms at a
   realistic ledger size) is accepted as the working target; the exact reference
   device is named when Phase C benchmarks are built.
5. Proceed to PR A now (pure-Dart, reversible, ships OTA). PR B (native SQLCipher
   + Keystore + base-APK rebuild + manual install) requires its own explicit
   approval before any native code, per the founder's standing rule.
- Scope: replace the SharedPreferences JSON ledger with a durable, encrypted
  store, preserving every user and every centavo. Significant stored-data,
  money, security, backup, and native change.

This is a decision record, not an implementation. It states the current failure
modes, the candidate technologies that the current Flutter and Android stack can
actually run, the crash-consistency and encryption design, key loss and
recovery, migration checkpoints, rollback and old-blob retention, backup
compatibility, performance, the money-representation question, and a threat model
that stays realistic for an offline consumer app. Where a choice is genuinely the
founder's to make, it is called out as a DECISION FOR THE FOUNDER rather than
decided here.

Every factual claim below was verified against the code on 2026-07-30 at the
merge of f2.97. File references are given so a reviewer can check them.

---

## 0. The one-paragraph summary

Salapify stores its entire ledger, and almost every setting, as one plaintext
JSON string under a single SharedPreferences key (`salapify_data_v2`), rewritten
in full on every mutation, with a second plaintext copy in `salapify_data_v2_prev`
and a third partial plaintext copy in the home-screen widget's own prefs file.
Nothing is encrypted; a single corrupt blob is total loss, mitigated only by that
`_prev` copy and by user backups. The recommendation is to move the ledger into a
durable, atomically-committed, **encrypted** container (SQLCipher-backed SQLite),
behind a new **repository interface** so the engines keep reading the same JSON
map they read today, with the key held in the Android Keystore, migrating the old
blob non-destructively and keeping it until the new store opens, validates, and
passes integrity checks. Money stays as `double` pesos on disk and in the engines
in this phase, because the golden vectors lock Flutter to the React Native engine
to 1e-9 and a minor-unit change would break them; the money work in Phase C is
limited to introducing an adapter SEAM, not changing any number. The single
biggest decision for the founder is whether "zero drift" is a goal, because zero
drift and React Native golden parity are mutually exclusive under the current
architecture (Section 11).

---

## 1. Current failure modes (with evidence)

The persistence lifecycle today (`flutter/lib/data/store.dart`):

- **Load** (`store.dart:393-421`): read the one key, `jsonDecode`, `sanitizeData`,
  then `ensureUniqueTxnIds` and `ensureEntityIds`. Any throw is caught into
  `loadError`, and **the app then refuses to write** (`canWrite = loaded &&
  loadError == null`, `store.dart:606`). This "never overwrite an unreadable
  ledger" rule is the single most important data-safety invariant in the app and
  MUST survive this change.
- **Write** (`store.dart:451-454`): `prefs.setString(storageKey,
  jsonEncode(data))`. The **entire ledger is re-encoded and rewritten on every
  mutation**. There is no partial write and no write-ahead log of the app's own.
- **Mutate** (`store.dart:685-704`): snapshot `previous` in memory, apply, save,
  roll back in memory on failure. This is transactional in memory only.
- **Import/replace** (`store.dart:460-504`): snapshot the raw on-disk blob into
  `salapify_data_v2_prev`, then swap. `undoLastImport` swaps them back.

Failure modes that follow from this shape:

1. **No encryption at rest.** Every account name, person's name, note, label, and
   amount sits in plaintext in the app's SharedPreferences XML, plus a full second
   plaintext copy in `_prev`, plus a partial plaintext copy (possibly the peso
   figure) in the home-widget prefs file read by another process
   (`home_tile.dart:199-203`, `YourNumberWidget.kt`). On a rooted device, an ADB
   backup where allowed, or forensic recovery, all of it is readable. The privacy
   bar the app already enforces for the diagnostics dump and the widget tile
   (`diagnostics_test.dart`, `widget_privacy_test.dart`) does NOT cover the ledger
   itself.
2. **Whole-blob rewrite is O(n) per write.** At a few thousand transactions this
   is cheap. At the 20,000 and 50,000 stress ceilings the founder named, the JSON
   is multiple megabytes and every single "log an expense" re-encodes and
   rewrites all of it. SharedPreferences is explicitly not designed for large
   values; it loads the whole file into memory and its `apply()` is a full-file
   async rewrite.
3. **Single point of failure.** One truncated or corrupt value is the whole
   ledger gone. Today's only nets are: `jsonDecode` throwing (caught, writes
   disabled, so at least not made worse), the one `_prev` copy, and user backups.
   There is no checksum, no A/B copy, no integrity field.
4. **Cross-key operations are not atomic.** During import, `data` and `_prev` are
   two separate `setString` calls. A crash between them can leave the two keys
   inconsistent (the in-memory rollback cannot run if the process is gone).
5. **Durability depends entirely on the platform SharedPreferences
   implementation.** `apply()` returns before the disk write completes; a crash in
   that window silently loses the last write with no signal to the user that the
   receipt they saw was a lie.
6. **No Data Health signal.** The app cannot tell the user "your last save
   succeeded at 3:41pm, schema v12, integrity OK, last backup 4 days ago." It only
   knows load succeeded or failed.

None of these is a bug in the current code; the current code is careful within the
limits of SharedPreferences. They are limits of the storage substrate.

---

## 2. Candidate storage technologies (that this stack can actually run)

Constraints: Flutter SDK `^3.12.2` (`pubspec.yaml`), Android `compileSdk 36`,
`minSdk`/`targetSdk` at Flutter defaults, offline-only, and a golden-locked JSON
document model the engines read as `Map<String, dynamic>`. No storage or crypto
dependency exists today; every option below is a NET-NEW native dependency, which
means a base-APK rebuild and a hand-installed version bump (Section 12).

| Option | Encryption | Crash-consistency | Fit with the JSON-document model | Native weight | Verdict |
|---|---|---|---|---|---|
| **SQLCipher SQLite** (`sqflite_sqlcipher` or `sqlite3` + `sqlcipher_flutter_libs`) | Whole-file AES-256, authenticated | ACID + WAL, battle-tested | Store the document as a few coarse rows; engines still get the map | ~a few MB native lib | **RECOMMENDED** |
| Encrypted single file (AES-GCM via `cryptography` pkg) + atomic A/B rename + checksum, key in `flutter_secure_storage` | AES-256-GCM (authenticated, tamper-evident) | We own the atomic A/B + fsync logic | Perfect: the document stays one JSON value | Lightest (only `flutter_secure_storage` is native) | **Strong alternative** (Section 3) |
| Drift over SQLCipher | via SQLCipher | ACID + WAL | Typed tables; a bigger re-model | Heavier codegen | Overkill this phase |
| Hive / Isar | Hive has AES; Isar via native | Weaker (Hive box compaction); Isar maintenance is uncertain | NoSQL re-model | Isar large | Rejected: durability and project-health risk |
| Sembast + encryption codec | codec-based | Append-log, decent but less proven at our scale | Good (document-ish) | Pure-Dart | Viable but less battle-tested than SQLite |
| Android `EncryptedSharedPreferences` (Jetpack Security) | AES via Keystore | Same key-value model, no transactions | No gain over today except encryption | native | Rejected: Jetpack Security is deprecated and solves only encryption |

**Recommendation: SQLCipher-backed SQLite**, because the founder's strongest
requirements are transactionality and crash-consistency ("kill the process at each
checkpoint and prove restart finds a complete store"), and SQLite's transaction
engine is the most battle-tested implementation of exactly that. We lean on proven
durability rather than proving our own. SQLCipher adds encryption to the same file
with no change to the transaction semantics.

The encrypted-file A/B alternative is documented in full in Section 3 because it is
genuinely competitive (lighter native footprint, preserves the one-document model
exactly), and the founder may prefer it. Either satisfies every requirement; the
recommendation is SQLCipher for the proven durability.

**Document model is preserved either way.** We do NOT re-model the ledger into
per-entity tables in this phase (the founder's non-goal: "no big-bang replacement
of every dynamic map"). The store holds the SAME JSON document; SQLCipher just
holds it durably and encrypted. To keep a normal log save from rewriting the whole
document at 50k transactions, the document is split into a small number of COARSE
rows, one per top-level collection (accounts, transactions, debts, receivables,
payables, goals, assets, notes, recurring, categories, people, settings, plus a
`schemaVersion` + integrity header). A log then rewrites only the `transactions`
row inside one SQLite transaction. The engines still receive the reassembled
`Map<String, dynamic>`; nothing above the repository boundary changes.

---

## 3. Transaction and crash-consistency guarantees

**With SQLCipher (recommended):** every commit is a single SQLite transaction
across the coarse rows, so a mutation is all-or-nothing at the database level.
SQLite in WAL mode guarantees that a crash at any instant leaves either the fully
committed new state or the fully committed previous state, never a torn write.
This is the guarantee the founder asked to test by killing the process at each
checkpoint; SQLite provides it by construction, and the tests prove our USE of it
is correct (we never report success before `COMMIT` returns).

**With the encrypted-file A/B alternative:** two files, `ledger.a` and `ledger.b`,
each carrying `{seq, schemaVersion, integrityTag, ciphertext}`. A commit writes the
inactive file, `fsync`s it, then flips a tiny atomic pointer (itself written by
temp-file-plus-rename, which is atomic on the Android filesystem). A crash leaves
at least one file with a valid tag and a monotonic `seq`; load picks the
highest-`seq` file that decrypts and verifies, falling back to the other. This is a
classic double-buffer and is correct, but the atomic logic is ours to prove, which
is why SQLCipher is recommended.

**The invariant that must survive, in both designs:** a failed write NEVER produces
a success receipt (Section, tests). The store's `_mutate` already rolls back memory
on a throw; the new store adds that the on-disk state is only advanced after the
durable commit returns, and the UI "saved" signal is only emitted after that.

---

## 4. Encryption and Android Keystore design

- **Cipher:** AES-256, authenticated. SQLCipher uses AES-256-CBC with an HMAC per
  page (tamper-evident). The file alternative uses AES-256-GCM (authenticated).
  Authenticated encryption is required so a tampered file fails closed rather than
  decrypting to garbage the engines might act on.
- **Data-encryption key (DEK):** a random 256-bit key generated once on first run.
- **Key protection:** the DEK is wrapped by a key held in the **Android Keystore**
  (hardware-backed on devices with a TEE/StrongBox, software-backed otherwise). In
  practice this is reached through `flutter_secure_storage`, which on Android stores
  values in `EncryptedSharedPreferences` with a master key in the AndroidKeyStore;
  or through a thin platform channel that generates a Keystore key directly. The DEK
  never leaves the app process in plaintext and is never written to disk in
  plaintext.
- **DECISION FOR THE FOUNDER, biometric binding:** the Keystore key CAN be marked
  `setUserAuthenticationRequired`, so the ledger can only be decrypted right after a
  biometric unlock. This is stronger, but it collides with today's App Lock
  lockout-safety: `lock_gate.dart:152-176` turns App Lock OFF and hides widget
  amounts when no biometrics are enrolled, precisely so a broken sensor never
  strands the owner. If the DEK is bound to biometrics, a sensor failure or a
  biometric reset would make the ledger undecryptable, which is data loss, not a
  lockout. **Recommendation: do NOT bind the DEK to biometrics in this phase.**
  Encrypt at rest with a Keystore-wrapped DEK that any run of the app can use, and
  keep App Lock as the UI gate it is today. Biometric-bound decryption can be a
  later, opt-in setting with a mandatory backup-first flow. The founder should
  confirm this, because it trades some at-rest strength (a determined attacker with
  the unlocked device and root could reach the DEK) for zero risk of key-loss data
  loss, which is the right trade for a consumer money diary.
- **The home-widget copy cannot be decrypted by the widget process.** The launcher
  process that draws `YourNumberWidget.kt` has no access to the app's Keystore key.
  So the widget stays on its current model: Dart computes the display strings and
  writes them to the widget prefs, already substituting non-money strings when App
  Lock or `widgetHideAmount` is on (`home_tile.dart:154-156`, `widget_privacy_test`).
  The ledger is encrypted; the widget mirror stays a deliberately minimal,
  amount-suppressible projection, never the ledger itself. This is called out
  because "a plaintext search of stored files finds no amounts" must account for it:
  with App Lock/hide on, the widget file has no peso figure; with them off, the
  user has chosen to show their number on their own home screen, and that is a
  product choice, not a leak. The plaintext-search test asserts the LEDGER file has
  no names/notes/labels/amounts; the widget projection is governed by the existing
  hide flag and its existing test.

---

## 5. Key loss and recovery behavior

Key loss is the scariest failure in an encrypted design, because a lost key turns
the user's own data into noise. The design treats it as a first-class case:

- **The key is stored, not derived from a user secret.** There is no password to
  forget. As long as the app's Keystore entry survives, the key survives.
- **When the Keystore entry is gone** (app data cleared, device migration without
  key transfer, OS key invalidation after a biometric/lock-screen reset if we ever
  bind to auth), the ciphertext cannot be decrypted. The store then behaves exactly
  like today's unreadable-blob path: `loadError` is set, `canWrite` is false, the
  ledger is NOT overwritten, and the app shows the recovery route it already has,
  IMPORT A BACKUP or START FRESH (`store.dart:460-504`, `576-592`). Fail closed,
  never fail destructive.
- **This is why backups remain the ultimate recovery, and why the exported backup
  stays plaintext, portable JSON** (Section 8). The encrypted store protects data at
  rest on THIS device; the user's exported backup is how data survives a lost key or
  a new phone. Data Health surfaces the last-backup age (Section 11) precisely so the
  app can nudge a backup before a key can be lost.
- **Key rotation is out of scope and gated.** The ADR does not rotate keys. If
  rotation is ever added, it is decrypt-with-old then encrypt-with-new inside one
  atomic checkpoint, with the old store retained until the new one validates, and it
  requires explicit founder approval (the founder's standing rule).

---

## 6. Migration checkpoints and restart recovery

The migration from the v12 SharedPreferences blob to the encrypted store is the
riskiest moment. It is designed as a sequence of atomic, individually-recoverable
checkpoints, each of which leaves the app able to boot to a complete store if the
process is killed at that instant:

- **C0, nothing done.** Old blob is the source of truth. App reads SharedPreferences
  as today. A durable "migration state" marker (in the small preferences store,
  Section 10) reads `none`.
- **C1, new store created and populated, marker `migrating`.** Read the old blob,
  run the existing `sanitizeData` + `ensureUniqueTxnIds` + `ensureEntityIds`
  (unchanged, golden-locked), write the result into the new encrypted store in one
  transaction. The OLD blob is untouched. If killed here, restart sees marker
  `migrating`, discards any partial new store, and falls back to the old blob (still
  complete). Restart recovery = old complete store.
- **C2, new store validated, marker still `migrating`.** Re-open the new store from
  disk (not from memory), decrypt, verify the integrity tag, run `sanitizeData` over
  the reloaded document, and assert a set of INTEGRITY CHECKS: the collection counts
  match the old blob, the golden-style `netWorthParts` computed from the new store
  equals the one computed from the old blob to 1e-9, and every id resolves. If any
  check fails, abort: keep marker `migrating` unusable, keep using the old blob,
  surface a diagnostic. Restart recovery = old complete store.
- **C3, cutover, marker flips to `migrated` atomically.** Only after C2 passes, a
  single atomic write flips the marker to `migrated`. From this instant the
  encrypted store is the source of truth. If killed BEFORE the flip, restart uses the
  old blob; if killed AFTER, restart uses the new store. There is no in-between,
  because the marker flip is one atomic write. Restart recovery = whichever complete
  store the marker names.
- **C4, old blob retention.** The old SharedPreferences blob and its `_prev` are NOT
  deleted at cutover. They are retained (read-only) until a later, separately-approved
  cleanup, so a defect discovered days later can still fall back. Deleting the old
  store requires explicit founder approval (the founder's standing rule).

Every checkpoint is proven by a test that kills the process (simulated by tearing
down and re-constructing the store mid-sequence) at that checkpoint and asserts
restart finds EITHER the old complete store OR the new complete store, never a
partial one.

---

## 7. Rollback and old-blob retention plan

- **In-session rollback** is unchanged: `_mutate` rolls back memory on a failed
  commit, and the commit is atomic, so a failed write leaves the previous durable
  state intact.
- **Migration rollback** is the checkpoint design above: until C3, the old blob is
  authoritative; the marker is the only thing that cuts over, and it is one atomic
  write.
- **Post-cutover rollback** is possible because of C4 retention: a build that flips
  back to reading the old blob (or an import of a backup) recovers the pre-migration
  state, since the old blob was never mutated after C0.
- **Old-blob retention:** keep `salapify_data_v2` and `salapify_data_v2_prev`
  untouched through this phase. A future PR may add a user-visible "your data has
  been on the new secure store for N days, you can clear the old copy" step, gated on
  founder approval. This ADR does not delete anything.

---

## 8. Backup compatibility

Backups are the app's portability and disaster-recovery layer and must not change:

- **Export stays plaintext, portable JSON.** `store.exportBackupText()` and the
  shared backup file (`backup_file.dart`) keep producing the exact same
  React-Native-compatible v12 JSON. Encryption is AT REST on this device only; a
  backup a user shares to Drive or another phone must remain readable by the RN app
  and by a fresh Flutter install. Changing the backup format is explicitly forbidden
  without founder approval.
- **Import stays identical.** `parseBackupObject` + `sanitizeData` +
  `ensureUniqueTxnIds` + `ensureEntityIds` are unchanged. Import writes into the new
  encrypted store instead of SharedPreferences, but the parsing, migration, and
  id-repair are byte-for-byte the same code, so RN backups and existing Flutter
  backups import with no centavo change. The `undoLastImport` safety copy is
  preserved (as a row/entry in the new store, or the retained `_prev`).
- **Golden lock:** `backup_goldens.json` / `backup_export_goldens.json` continue to
  pass unchanged, because the document that goes in and comes out is the same JSON;
  only its on-disk container changed.

---

## 9. Performance plan

- **Budget, DECISION FOR THE FOUNDER on the reference device.** Propose: a normal
  log save (append one transaction and commit) completes with p95 under **50ms** on
  the founder's reference low-end Android at a realistic ledger size (a few thousand
  transactions), and cold load under **400ms** at that size. These numbers are
  proposals; the founder names the reference device and the exact budget.
- **Why coarse per-collection rows.** A normal log save rewrites only the
  `transactions` collection row, not accounts/debts/goals/etc., so write cost scales
  with the transactions blob, not the whole ledger. Encryption of one collection is
  cheap.
- **Benchmarks at 1,000 / 20,000 / 50,000 transactions** are required tests: measure
  log-save p95 and cold-load at each size. 50,000 is a stress ceiling (about 27 years
  at 5 logs/day), not a realistic target; 20,000 (about 11 years) is the practical
  upper bound. If 50k blows the budget, the escape hatch is per-entity row storage
  for transactions behind the SAME repository interface, in a LATER phase, without
  touching the UI or the engines. That is why Phase A introduces the interface first.
- **No synchronous work on the main isolate for large writes.** Encryption and
  serialization of a large collection move to a background isolate if the benchmarks
  show jank; the repository interface makes this invisible to callers.

---

## 10. Separating small preferences from critical financial data

Today there is no split: theme, `onboarded`, `appLock`, `widgetHideAmount`,
`displayName`, notifications, and the whole ledger all live in one
`salapify_data_v2` blob (`data['settings']`), so the App Lock flag lives inside the
very blob it nominally protects.

- **Introduce a small, unencrypted preferences store** (plain SharedPreferences, a
  new namespaced key) for boot-critical, non-sensitive flags: theme/appearance,
  `onboarded`, `appLock` on/off, `widgetHideAmount`, the migration-state marker, and
  the Data Health header (last commit time, schema version, last integrity result,
  last backup verification). None of these is sensitive (a theme name and a boolean
  are not financial data), and keeping them readable WITHOUT decrypting the ledger
  lets the app boot, render the lock screen, and show Data Health even if the ledger
  fails to open.
- **The critical financial data** (accounts, transactions, debts, receivables,
  payables, goals, assets, notes, and the sensitive settings sub-keys like
  `displayName`, `paluwagans`, `steadyPay`) lives in the encrypted store.
- **Backup compatibility is preserved** by reassembling the full v12 document
  (small prefs + critical data) for export, so the exported JSON is unchanged even
  though on disk the two are separated. The split is an on-disk concern, invisible
  to the backup format.
- The `appLock` boolean moving to the small prefs store is a strict improvement:
  the gate no longer depends on decrypting the thing it guards.

---

## 11. Money representation, and the "zero drift" decision

This is the section that most needs the founder's eyes, because a requirement and a
constraint are in direct tension.

**What is true today (verified):** money is `double` pesos everywhere, not integer
minor units. `amountOf` (`ledger.dart:16-26`) coerces like JS `Number(x) || 0`.
`netWorthParts` sums raw doubles with no per-row rounding (`statements.dart`).
Transfers round each leg to the centavo the RN way (`transfers.dart:19-23`), which
DELIBERATELY permits up to half a centavo of total drift, and there is a test that
asserts exactly that bound (`transfer_golden_test.dart:162`, `<= 0.005001`, with a
comment calling the drift "faithful, not a bug"). Debt interest rounds to the WHOLE
PESO, not the centavo (`debtmath.dart`, golden `100.50 -> 101`). Roughly 38 golden
fixtures and 30 golden test runners lock every money output to the RN engine at
`1e-9`. Sub-centavo residue on untouched accounts is preserved on purpose.

**The tension:** the founder's required test says "repeated-centavo and
transfer-conservation tests show ZERO drift under the approved money
representation." Zero drift is only achievable by moving OFF doubles to integer
minor units (centavos) or a `Decimal` type. But the moment the numbers stop being
RN-faithful doubles, the RN golden vectors no longer match (they encode the
double-based ±0.005 drift and the whole-peso interest rounding), so "golden parity
with React Native" and "zero drift" cannot both hold.

**DECISION FOR THE FOUNDER.** There are two coherent paths, and the founder must
pick:

- **Path 1, keep double parity (recommended for this phase).** Keep `double` pesos
  on disk and in the engines. The durable-store migration changes zero numbers;
  every golden and conservation test passes unchanged. "Zero drift" is NOT claimed,
  because the RN-faithful ±0.005 transfer residue remains by design. Phase C's money
  work is limited to introducing a `MoneyCodec` ADAPTER SEAM at the repository
  boundary that is, by default, a pass-through preserving doubles, so the plumbing
  for a future representation exists without changing a single stored or computed
  value. This is the low-risk path and preserves the golden lock.
- **Path 2, adopt a minor-unit or decimal representation (larger, later, gated).**
  Make the Flutter engine the source of truth with integer centavos or `Decimal`,
  achieving true zero drift, and RE-DERIVE every golden vector from the new Flutter
  engine (RN parity is knowingly given up for the money math, though the backup JSON
  can still export doubles for RN import compatibility). This is a multi-week,
  high-risk effort that touches every money engine and every golden, and it must not
  ride inside the durable-store migration. It gets its own ADR, its own re-derived
  goldens, and explicit founder approval before a line is written.

The recommendation is **Path 1 now**: the durable store and encryption are valuable
and safe on their own; the money representation is a separate, heavier decision that
should not be entangled with the storage migration. Phase C delivers the adapter
seam and the benchmarks, not a representation change. If the founder wants true zero
drift, that is Path 2 as a distinct, later, approved effort.

---

## 12. Native change, delivery, and versioning

An encrypted store with a Keystore-protected key is a NATIVE change (new plugin,
Kotlin/manifest work). Per the pubspec header and the delivery rules, it CANNOT ship
as a Shorebird over-the-air patch. It requires a fresh base APK, a bump of
`version: 0.6.3+12` (both the semver and the `+12` versionCode, or the new APK
refuses to install over the old), and a HAND INSTALL by the founder. Until that
manual install happens, the founder receives nothing while later builds report
green. This must be flagged loudly at the moment the native PR is ready, and a
base-APK publish requires explicit founder approval (the founder's standing rule).

---

## 13. Threat model (realistic for an offline consumer app)

Salapify is offline-first with no backend, no account system, and no sync
(confirmed: the only outbound call is the FX rate fetch, which sends only a base
currency code like `PHP`, `fx_service.dart`). The realistic threats, and what this
design does about each:

- **Lost or stolen unlocked phone.** App Lock (biometric) gates the UI. At-rest
  encryption does not help here (the device is unlocked), which is honest to state.
  In scope: App Lock, already present.
- **Lost or stolen LOCKED phone, later powered off / rooted / imaged.** This is what
  at-rest encryption is FOR. The ledger ciphertext is useless without the
  Keystore-wrapped key, which is bound to the device and (on TEE/StrongBox hardware)
  not extractable. In scope: the whole encrypted-store design.
- **Malware or another app on the device reading Salapify's files.** Android app
  sandboxing already isolates per-app storage; encryption is defense in depth if the
  sandbox is bypassed (root). In scope.
- **Device backup / cloud sync of app data (ADB backup, some OEM cloud).** Plaintext
  SharedPreferences can be swept into such backups today; encrypted-at-rest data is
  useless there without the key. In scope. (`allowBackup` posture should be reviewed
  as part of the native PR.)
- **The user's OWN exported backup file.** Deliberately plaintext and portable, so
  the user can restore on a new phone or the RN app. This is a user-initiated egress
  the user controls; the app should keep reminding them it is unencrypted and theirs
  to protect. NOT in scope to encrypt (it would break portability and RN parity).
- **Forensic recovery of deleted data.** The retained old blob (Section 7) is
  plaintext until the approved cleanup; that is an accepted, temporary residual risk
  during the migration window, the price of a safe rollback path, and it is named
  rather than hidden.
- **OUT of scope, realistically:** a nation-state extracting a StrongBox key, a
  compromised OS, and any network attacker (there is no network surface for user
  data). Chasing these would add key-loss risk for a consumer money diary with no
  real-world benefit.

The guiding principle: this is a personal money DIARY, not a bank vault. The design
maximizes protection against a lost/stolen device while minimizing any path to the
user losing their OWN data, because for this app, self-inflicted data loss is a far
more likely and more damaging outcome than an attacker reading a lunch expense.

---

## 14. Proposed PR split (each independently safe, each preserving a recovery path)

Per the founder's split, three reviewable PRs. None deletes the old store, rotates
keys, changes backup defaults, or publishes a native build without explicit
approval.

- **PR A, repository interface and dual-read scaffolding.** Introduce a
  `LedgerRepository` interface the UI/store depend on instead of SharedPreferences
  directly. Implement it FIRST as a thin wrapper over the existing SharedPreferences
  path (zero behavior change), plus dual-read plumbing and the small-preferences
  split (Section 10) and Data Health primitives (Section 11 header). No encryption
  yet. Independently safe: it is the current store behind an interface. Pure-Dart,
  no native change, ships OTA.
- **PR B, encrypted store and migration.** Add the SQLCipher (or encrypted-file)
  implementation of `LedgerRepository`, the Keystore-wrapped key, the checkpointed
  non-destructive migration (Section 6), old-blob retention (Section 7), and the
  full failure-injection and kill-at-checkpoint test suite. NATIVE change, base-APK
  rebuild, founder-approved manual install. Independently safe: migration is
  non-destructive and falls back to the old blob at every checkpoint.
- **PR C, money adapter seam and performance work.** Introduce the `MoneyCodec`
  pass-through adapter (Path 1, no numeric change) and the 1k/20k/50k benchmarks and
  any background-isolate work they justify. Pure-Dart. Independently safe: the
  adapter is a no-op by default and every golden passes unchanged. (A representation
  change, Path 2, is explicitly NOT in PR C; it is a separate future ADR.)

---

## 15. Required tests (restating the founder's list, mapped to the design)

- Every RN and Flutter golden fixture migrates with no centavo change: the
  migration runs the unchanged `sanitizeData` pipeline; a test asserts
  `netWorthParts` and every golden are identical pre- and post-migration to 1e-9.
- Kill the process at each migration checkpoint (C0-C3) and prove restart finds
  either the old complete store or the new complete store (Section 6).
- Inject write, disk-full, key-access, and corruption failures: each returns an
  error, disables writes (`canWrite` false), and never advances on-disk state.
- A failed write never produces a success receipt: the "saved" signal is emitted
  only after the durable commit returns.
- Wrong keys and tampered encrypted files fail closed without changing current
  data: authenticated encryption rejects them; the store enters the unreadable-blob
  recovery path, never overwrites.
- A plaintext search of the stored LEDGER files finds no names, notes, labels, or
  amounts (the widget projection is governed by the existing hide flag and its test,
  Section 4).
- Repeated-centavo and transfer-conservation tests show the drift the APPROVED
  representation defines (zero under Path 2; the RN-faithful <= 0.005 bound under
  Path 1). This test's assertion depends on the founder's Section 11 decision.
- Benchmarks at 1,000 / 20,000 / 50,000 transactions; normal log save p95 and cold
  load within the founder-approved budget.

---

## 16. What this ADR explicitly does NOT do

No CSV Import redesign, no cloud sync, no account system, no LLM, no new product
tab, no unrelated visual redesign, no big-bang replacement of every dynamic map, no
deletion of the old store, no key rotation, no backup-format change, and no native
build published, until and unless the founder approves each. Money numbers do not
change in this phase under the recommended Path 1.

---

## 17. The decisions the founder needs to make before implementation

1. **Storage engine:** SQLCipher SQLite (recommended) or the encrypted-file A/B
   alternative (Section 2, 3).
2. **Biometric key binding:** NO (recommended, avoids key-loss data loss) or yes as
   a later opt-in (Section 4).
3. **Money path:** Path 1, keep double parity and add only the adapter seam
   (recommended), or Path 2, pursue true zero drift via a decimal/minor-unit
   representation as a separate later effort (Section 11).
4. **Performance budget and reference device** (Section 9).
5. **Approval to proceed to PR A** (pure-Dart, no native change, reversible), while
   PR B's native/base-APK step waits for a separate explicit approval.

Nothing is implemented until these are answered.

---

## 18. Implementation update (2026-07-30, added when this ADR was landed on main)

This ADR was accepted on the `claude/phase-2-durable-store` branch but that
branch never merged, so the record lived where the code on main could not reach
it. This section is added as the ADR is brought onto main, and it records what
implementation actually did, so a reader on main is not pointed at a plan that
has already moved.

- **PR A shipped (stamp f2.99).** The `LedgerRepository` interface (Section 2's
  seam) landed with a `SharedPrefsLedgerRepository` default. Zero behaviour
  change; the store and UI no longer touch SharedPreferences directly.

- **PR B was split into B1 and B2.** The native encryption cannot be tested in
  `flutter test` (headless Linux, no device or native libs), so the durable step
  was divided: B1 is pure Dart, ships over the air, and is fully testable; B2 is
  the native SQLCipher plus Android Keystore step that needs a base-APK rebuild
  and a manual install, and stays gated on its own explicit approval.

- **PR B1 shipped (stamp f3.01, patch 24) as a validated SHADOW, not an authority
  swap.** The first cut made the new atomic file store authoritative and
  dual-wrote to SharedPreferences as a revert mirror. A pre-merge review (the
  qa-tester and principal-engineer agents, run as a real gate) found two
  data-loss paths, both reproduced before any change: a valid-but-older file
  trusted over newer SharedPreferences and then overwriting it, and a
  half-finished start-fresh resurrecting the just-erased ledger. Root cause: two
  independently-writable stores with no reliable which-is-newer signal. The fix
  was a redesign, not a patch: SharedPreferences stays the single source of truth
  and every read comes from it; the file store is a crash-safe copy written
  alongside but never read back as truth in B1. A stale or half-cleared shadow can
  therefore never override or resurrect anything, and a plain revert is lossless
  unconditionally. Both findings are kept as regression tests.

- **Requirements this hands to PR B2** (from the same review, recorded here so the
  decision is where the ADR is):
  1. Sever the plaintext shadow. B2 encrypts the ledger at rest; a plaintext copy
     living beside it makes the encryption theater, so B2 must stop maintaining a
     plaintext copy.
  2. Migrate from two possible sources. Some users jump straight from pre-B1 to B2
     (a base-APK install) and never ran B1, so their data is in SharedPreferences;
     users who ran B1 have it in the file too. B2's encrypted primary must migrate
     from "file if present, else SharedPreferences."
  3. Own which-is-newer properly. The reconciliation B1 deliberately avoided
     belongs in B2's transactional engine.

The Section 17 decisions themselves are unchanged and still hold; this section
only records their implementation status.
