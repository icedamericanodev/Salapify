# Executive Summary

Salapify Sprint 0 engineering audit, 2026-07-10. Conducted as a technical due
diligence pass across engineering, product, architecture, security, UX,
accessibility, performance, and AI readiness. No code was changed; this docs/
set is the deliverable.

## What Salapify is

An offline first budget, debt, and utang tracker for Filipino Gen Z,
millennials, and working adults. React Native on Expo SDK 54 in mobile/, no
backend, all data on device in one AsyncStorage key (salapify_data_v2,
schema version 12). Six tabs, 27 stack screens, 9 Philippine specific
financial calculators, a rule based chat assistant (Pan), 10 Android home
widgets, and a legacy v1 web app still served from the repository root.
JavaScript changes ship over the air via EAS Update from GitHub Actions;
native changes need an APK rebuild.

## The headline verdict

This is an unusually well engineered codebase for a solo founder plus AI
agent project. The data safety engineering (a sanitize everything load
boundary, forward only migrations with version fences, a load state machine
that can never overwrite real data after a bad read, snapshot before
destruction, balance consistent transaction mutations) is better than what
many funded fintech apps ship. The pure logic layer carries 313 passing unit
tests over the money math. The inline comments explain failure modes, not
syntax. Real accessibility and privacy work exists and is visible in the
code.

The risk profile is equally clear. It concentrates in four places, none of
them expensive to close relative to the value at risk.

## The four findings that matter most

1. The tests do not protect anyone. CI runs lint and a smoke test for the
   dead legacy web page; the 313 tests guarding the money math never execute
   in any workflow, and OTA updates publish to real phones on every push
   with zero automated gate. One small workflow change fixes this.
   (Technical_Debt.md TD-1)

2. The storage design has a cliff with no guardrail. Everything lives in one
   JSON blob, and Android refuses to read AsyncStorage rows near 2MB while
   happily writing them. A daily logger crosses that line in roughly three
   years and is then permanently locked out of their own data. The warning
   today is a banner on a screen most users never open. An immediate write
   guard is under a day of work; the structural fix is a planned SQLite
   migration the code was explicitly seamed for. (TD-2, TD-4,
   Database_Review.md)

3. Trust surface gaps that contradict the brand. The Play data safety draft
   says no data is transmitted while the app calls an exchange rate API on
   open; the OTA pipeline has no code signing, an unpinned CLI, and no
   branch protection, meaning one leaked token could push arbitrary code
   into a finance app; and the legacy web page on the same origin as the
   privacy policy has unescaped HTML injection and an unpinned CDN script.
   All are S to M effort. (Security_Audit.md SEC-1 to SEC-3)

4. The core loop is slower and less inclusive than the engineering deserves.
   Logging a custom expense takes 4 to 6 taps plus a scroll; the add entry
   sheet leaks TalkBack focus into the screen behind it, its chips announce
   no selected state, and its errors are silent, making the app unusable end
   to end for blind users; and the differentiating utang features are buried
   while formal debts own a tab. (UX_Audit.md UX-1 to UX-4,
   Accessibility_Audit.md A11Y-1 to A11Y-3)

## Secondary themes

- Free users have no durability story: system backup is disabled and
  automatic backup is Pro only, so a lost phone means a lost financial
  history. This is a policy choice worth revisiting. (TD-3)
- There is zero observability: no crash reporting, no telemetry. The crash
  rate is unknowable today. (TD-9, DEP-1)
- Performance is fine now and degrades predictably with data volume: one
  context re-renders every mounted screen per change and derived data is
  recomputed unmemoized. Cheap memoization buys years of headroom.
  (Performance_Audit.md)
- The Philippine tax and payroll calculators hardcode 2026 statutory rates
  with no versioning; they go silently stale the year rates change. (TD-13)
- Pro is a free settings flag; no billing infrastructure exists yet. (DEP-4)
- AI readiness is unusually good conceptually: the Pan assistant already
  separates understanding, computation, and phrasing, with the phrasing
  layer explicitly designed as the future LLM seam. Everything around a
  model call (proxy backend, key custody, streaming, memory, observability)
  is greenfield. (AI_Readiness.md)

## Scale readiness in one paragraph

On device, the architecture handles 1,000 transactions effortlessly, gets
slow at 10,000, and physically breaks at 50,000; the SQLite migration removes
that ceiling. By user count, nothing server side exists to fall over: 100 to
10,000 users need CI gating, crash reporting, and OTA discipline; 100,000
users need staged rollouts, update signing, and paid Expo bandwidth; a
million users still run fine on device but demand a real operations posture
and likely a thin backend for entitlements and AI. Offline first is doing
exactly what it was chosen to do. (Performance_Audit.md)

## The document set

| Document | Contents |
| --- | --- |
| Current_Architecture.md | How the system is built, strengths, ceilings |
| Current_Features.md | Full feature inventory with maturity and test coverage |
| Technical_Debt.md | Ranked debt with severity, impact, effort |
| Security_Audit.md | Findings, OWASP Mobile ratings, PII inventory, must fix list |
| Accessibility_Audit.md | TalkBack, contrast, dynamic type, targets, motion |
| Performance_Audit.md | Render and storage cost math, device and user scaling |
| UX_Audit.md | Product designer review of every core flow |
| AI_Readiness.md | LLM, RAG, memory, streaming, MCP readiness and target design |
| Database_Review.md | Exact stored schema, migrations, storage findings |
| API_Review.md | Every network surface, inbound validation boundaries |
| Component_Review.md | Component organization, duplication, DX |
| Folder_Structure_Review.md | Repo and app layout, the legacy root problem |
| Dependencies_Review.md | Every dependency, gaps for a production finance app |
| Risk_Register.md | All 32 risks consolidated, ranked, cross referenced |
| Roadmap_Recommendations.md | Prioritized plan: quick wins through AI |

## Recommended first moves (detail in Roadmap_Recommendations.md)

Week one is nine quick wins, all under a day each: CI running the real tests
and gating OTA, the storage write guard, the data safety form fix, supply
chain pinning, the FX fetch privacy alignment, the render time singleton fix,
the TalkBack logging flow batch, the sample data banner, and retiring the
legacy page from the trust origin. Together they close every Critical finding
in this audit without touching the data schema or requiring a rebuild.

Per the Sprint 0 instruction, no code changes have been made. This audit
awaits founder approval before any implementation begins.
