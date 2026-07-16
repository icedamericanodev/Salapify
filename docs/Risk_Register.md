# Risk Register

Sprint 0 engineering audit, 2026-07-10. The consolidated register of every
material risk found across the audit documents, deduplicated and ranked.
Likelihood and impact are rated low, medium, or high. Each row names the
owning document where the full analysis and recommendation live.

## Critical severity

| ID | Risk | Likelihood | Impact | Detail in | Effort |
| --- | --- | --- | --- | --- | --- |
| R1 | Mobile tests never run in CI; OTA updates publish to real phones ungated by any automated check. A money math regression ships silently. | High (it is the current state) | High | Technical_Debt.md TD-1 | S |
| R2 | The 2MB AsyncStorage read wall permanently locks heavy users out of their data; writes never refuse, the only warning is a buried banner. | Medium (grows with tenure of best users) | High (permanent data loss, worst possible review) | Technical_Debt.md TD-2, Database_Review.md DB-1 | S guard, XL structural |
| R3 | The core logging flow is unusable with TalkBack (focus leaks, stateless chips, silent errors), excluding blind users entirely from a money app. | High for affected users | High for them, Medium for the business | Accessibility_Audit.md A11Y-1 to A11Y-3 | S each |
| R4 | Logging a custom expense takes 4 to 6 taps plus a scroll; daily logging friction erodes the single habit the product monetizes. | High | High (retention) | UX_Audit.md UX-1 | M |

## High severity

| ID | Risk | Likelihood | Impact | Detail in | Effort |
| --- | --- | --- | --- | --- | --- |
| R5 | OTA supply chain: unpinned eas-cli, tag pinned actions, no branch protection, no update code signing. One leaked token or hostile publish reaches every phone. | Low to Medium | High (company ending trust event) | Security_Audit.md SEC-1 | M |
| R6 | Play data safety form claims no transmission while the app calls an FX API; policy takedown and credibility risk. | High at next store review | High | Security_Audit.md SEC-2 | S |
| R7 | Legacy PWA on the shared Pages origin: unescaped innerHTML (self XSS) and an unpinned CDN script next to the privacy policy. | Low | Medium to High | Security_Audit.md SEC-3 | S to retire |
| R8 | Free users have no backup path (allowBackup false, auto backup Pro only); every lost or broken phone is silent total data loss and a churned detractor. | High over time | High | Technical_Debt.md TD-3 | M |
| R9 | Single blob plus single context: startup, save, and render cost grow linearly with history; jank lands on the best users first. | Medium | Medium to High | Performance_Audit.md PERF-1, PERF-2 | M now, XL structural |
| R10 | Zero crash reporting or telemetry: field failures are invisible; a bad OTA bricking startup would be discovered by email volume. | Medium | High at scale | Dependencies_Review.md DEP-1, Technical_Debt.md TD-9 | M |
| R11 | The utang differentiator is buried (no tab presence, split three levels deep) while the commodity debt feature owns the tab; positioning and discovery risk. | High | Medium to High | UX_Audit.md UX-3, UX-13 | L |
| R12 | faint text tier fails WCAG AA contrast on raised dark surfaces and warm light backgrounds, degrading exactly the explanatory copy for low vision users. | High for affected users | Medium | Accessibility_Audit.md A11Y-4 | M |

## Medium severity

| ID | Risk | Likelihood | Impact | Detail in | Effort |
| --- | --- | --- | --- | --- | --- |
| R13 | Manual runtimeVersion pinning: one forgotten bump ships an OTA referencing missing native modules, crashing every preview phone at once. | Medium | High blast, quick fix | Technical_Debt.md TD-8 | S |
| R14 | Financial data and receipts are plaintext at rest; the app lock is an overlay, not a boundary. Rooted, infected, or seized devices read everything. | Low | High for affected users | Security_Audit.md SEC-4, SEC-6 | L |
| R15 | Widget math duplicated from lib/analytics.js can drift and show a different net worth on the home screen than in the app. | Medium | Medium (trust in math) | Technical_Debt.md TD-6 | S |
| R16 | phtax.js hardcodes 2026 statutory rates with no year versioning; all five payroll and tax tools go silently wrong the year any rate changes. | High (annual event) | Medium to High (wrong tax figures) | Technical_Debt.md TD-13 | M |
| R17 | Untested money code: loan amortization solver, SOA forecasts, 13th month, the recurring posting engine, split rounding, the notes math parser. | Medium | Medium to High | Technical_Debt.md TD-13, Current_Features.md | M |
| R18 | receivables and payables twin files: every utang fix risks shipping half applied. | Medium | Medium | Technical_Debt.md TD-7 | M |
| R19 | Sample data mixes into real totals with no persistent indicator; users see fictional net worth and blame the math. | Medium | Medium (trust, uninstalls) | UX_Audit.md UX-8 | S |
| R20 | FX fetch on app open contradicts the privacy policy's only when you use a currency feature wording. | High at audit | Medium | Security_Audit.md SEC-5 | S |
| R21 | setCurrencySymbol mutates a module singleton during render; a concurrent rendering change could break it silently. | Low | Medium | Technical_Debt.md TD-11 | S |
| R22 | Pro is a free settings flag; no billing infrastructure exists, so monetization cannot start without an XL workstream and a rebuild. | Certain when monetizing | Medium now | Dependencies_Review.md DEP-4 | XL |
| R23 | One shot notification scheduling windows run dry if the app is not opened (14 daily nudges, 6 paydays), silently ending reminders for lapsed users. | Medium | Medium (retention tool fails those who need it) | Current_Features.md platform section | M |
| R24 | AI features built naively would ship a provider API key in the APK or bloat the storage blob with chat history. | Medium if rushed | High | AI_Readiness.md AI-1, AI-3 | design rule now |

## Low severity (watch list)

| ID | Risk | Likelihood | Impact | Detail in |
| --- | --- | --- | --- | --- |
| R25 | Legacy root app confuses onboarding and owns root CI and Pages. | Certain (state) | Low to Medium | Technical_Debt.md TD-10 |
| R26 | Snapshot safety key shares fate with the main blob in one SQLite file. | Low | Medium | Database_Review.md DB-5 |
| R27 | FX provider single sourced, no timeout on the fetch. | Low | Low (graceful fallback) | API_Review.md API-1, API-2 |
| R28 | ML Kit native telemetry unverified against the no transmission story. | Low | Low to Medium | Security_Audit.md SEC-9 |
| R29 | Expo OTA bandwidth pricing bites around 10k monthly active users. | Medium at growth | Low to Medium | Performance_Audit.md scaling section |
| R30 | Dead code (MascotSkia, Placeholder) and stray founder .bat scripts pad the review surface. | Certain (state) | Low | Component_Review.md CMP-5, Folder_Structure_Review.md FS-4 |
| R31 | Tax deadlines tool skips weekend and holiday shifting despite lib/holidays.js existing. | High (dates land on weekends) | Low to Medium | Technical_Debt.md TD-13 |
| R32 | Currency converter attributes the wrong provider in the UI. | Certain (state) | Low | Technical_Debt.md TD-13 |

## Standing mitigations already in place (credit where due)

- The load state machine (never overwrite after a failed read) removes the
  most common catastrophic bug class in offline apps.
- The sanitize funnel and migration fences make hostile or newer data
  non destructive by construction.
- Snapshot before destructive operations, plus double confirmed erase flows.
- The save debounce with background and unmount flushes closes the swipe kill
  data loss window.
- Injection safe OTA workflow with least privilege permissions.
- No analytics, ads, or trackers, which keeps the privacy attack surface and
  compliance surface small.
