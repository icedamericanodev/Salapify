# AI Readiness Review

Sprint 0 engineering audit, 2026-07-10. Reviewed by Claude acting as principal engineer.
Scope: can Salapify support LLM providers (Claude, OpenAI, Gemini), RAG, vector
storage, conversation memory, prompt management, observability, streaming, and MCP,
and what has to change first.

## Verdict up front

Salapify is unusually well positioned for AI, better than most apps this size,
because of one deliberate architecture decision already in the code: the Pan
assistant (mobile/lib/pan/) separates understanding, computation, and phrasing
into three layers, and the phrasing layer was explicitly built as the future LLM
seam. The hard part of an AI finance assistant is not calling a model API, it is
making sure the model can never invent numbers. Salapify already solved that part.

What is missing is everything around the model call: no networking layer, no
provider abstraction, no key management, no streaming UI, no memory, no
observability. All of it is greenfield, none of it fights the existing
architecture.

## What exists today: the Pan assistant

Pan is a fully offline, rule based chat assistant. The pipeline is:

1. mobile/lib/pan/normalize.js lowercases and strips the message (108 lines).
2. mobile/lib/pan/intents.js (343 lines) is a data driven registry: GUARDRAILS
   are checked first (investment, loans, tax, legal, insurance topics get a safe
   scripted decline, several with a CTA into the relevant calculator), then
   INTENTS match on weighted keywords (strong and any) with Taglish coverage
   (baon, pautang, niningil).
3. mobile/lib/pan/resolvers.js (181 lines) computes FACTS from on device data:
   safe to spend, can I afford X, who owes me, goal pacing, and so on. Pure
   functions over the AppData blob.
4. mobile/lib/pan/respond.js (237 lines) turns facts into copy. Its header
   comment states the design rule: this is the ONLY place an LLM would later
   plug in, it receives numbers it did not compute and cannot change, so even a
   future language model can only restate verified figures.
5. mobile/app/pan.js (265 lines) is the chat UI with suggested question chips
   and a mascot mood driven by the answer.

This is exactly the tool use pattern that LLM apps converge on: the model
handles language, deterministic code handles money math. Salapify built the
deterministic half first, which is the correct order for a finance app.

## Capability by capability assessment

### LLM providers (Claude, OpenAI, Gemini)

Status: not supported today, cleanly addable.

There is no HTTP client abstraction in the app at all; the only fetch in the
product is the FX rates hook (mobile/hooks/useFxRates.js). Nothing prevents
calling a provider API, but three real constraints shape the design:

- No backend exists. Calling a provider directly from the device means shipping
  an API key inside the APK, which is extractable by anyone with the file. For
  a paid API this is a billing and abuse hole, not just theoretical. Any real
  LLM feature needs a thin proxy backend (a single serverless function is
  enough) that holds the key, enforces per user quotas, and forwards prompts.
- Offline first is the product promise. AI must degrade to the current rule
  based Pan when offline, which the layering already makes natural: keep the
  intent matcher as the offline path, use the LLM as the online path, same
  resolver and respond contracts.
- Privacy is the brand. Sending a user's full ledger to a provider would
  contradict the current privacy story (nothing leaves the device). The
  resolver pattern helps: send only the minimal FACTS needed for phrasing, not
  the raw ledger, and say so in the privacy policy.

Recommendation: define a small PanBrain interface (understand(message) ->
intent, phrase(facts) -> reply) with two implementations, RulesBrain (today's
code, offline, free tier) and LlmBrain (online, behind the proxy, possibly a
Pro feature). Effort M for the abstraction, L including the proxy backend.

### RAG and vector database

Status: not needed for the current product, and the current data layer could
not support it well anyway.

Salapify's answerable corpus is small and structured (the user's own ledger
plus about a dozen Learn lessons in mobile/lib/lessons.js). Structured queries
via resolvers beat embedding retrieval for the ledger. Where RAG becomes
relevant is a larger financial literacy content library or BIR guidance
content; at that point content should live as chunked markdown with embeddings
computed offline and shipped in the bundle, or served from the future backend.
On device vector search in React Native is feasible at small scale (a few
thousand chunks with a simple cosine scan, no native module needed) but there
is no on device embedding model, so embeddings must be precomputed or fetched.

Recommendation: defer. If Learn content grows past roughly 50 lessons, ship
precomputed embeddings with the bundle and do an in memory cosine scan. Effort
M when the time comes.

### Conversation memory

Status: not supported. Pan is stateless per message by design (each message is
matched and answered independently, history lives only in component state in
mobile/app/pan.js and is lost when the screen unmounts).

The storage layer makes persistent memory easy to add wrongly: dropping chat
history into the salapify_data_v2 blob would bloat the single AsyncStorage key
that already has a documented 2MB Android read cliff (mobile/lib/storage.js
lines 15 to 19). Chat history must NOT go into the main blob.

Recommendation: when memory is needed, store the last N turns under a separate
AsyncStorage key (or the future SQLite store) with a hard cap, and summarize
older turns. Effort S to M.

### Prompt management

Status: nothing exists, but the guardrail and intent registries in
mobile/lib/pan/intents.js are already the right shape: prompts as data, not
scattered string literals. The same registry pattern extends naturally to
system prompts and few shot examples per intent, versioned in git alongside
the code they steer.

Recommendation: when LlmBrain lands, keep every prompt in one prompts module
next to intents.js, exported as named constants with a version string, and
snapshot test the rendered prompts so silent prompt drift fails CI. Effort S.

### Observability

Status: none anywhere in the app, which is a gap wider than AI. There is no
crash reporting, no analytics, and no way to know an LLM feature is
hallucinating, slow, or erroring for real users. console.warn calls in
storage.js and AppData.js are the entire observability story, and they go
nowhere in a release build.

Recommendation: adopt Sentry (sentry-expo) for crash and error reporting
before any AI feature ships, and log LLM calls (latency, token counts, intent
resolved, guardrail hits, user thumbs up or down) through the future proxy
backend where the data can actually be inspected. On device, a small ring
buffer of recent Pan interactions attached to bug reports would be enough.
Effort S for Sentry, M for LLM call logging.

### LLM provider abstraction

Status: trivially achievable because zero provider specific code exists yet.
Starting clean is an advantage: define the internal contract first (messages
in, streamed tokens out, tool call requests surfaced as intent invocations)
and adapt providers to it. The proxy backend is the natural place for the
abstraction, which also means switching providers never requires an app
update, let alone an APK rebuild.

Recommendation: put the provider abstraction server side. The app should speak
one private API shaped like the PanBrain interface. Effort included in the
proxy work above.

### Streaming

Status: not supported. The chat UI (mobile/app/pan.js) renders complete
messages. React Native supports SSE or fetch streaming well enough via
react-native-sse or XHR incremental mode; the UI change is a message bubble
that appends tokens. The mascot mood system already animates per reply, so the
affordance fits the product's feel.

Recommendation: build streaming into the LlmBrain contract from day one
(token callback, not promise of full text); retrofitting streaming later
touches every call site. Effort S once the brain abstraction exists.

### Future MCP

Status: conceptually well aligned. The resolver registry is already a tool
catalog: each intent has an id, a description (title plus examples), and a
deterministic function over user data. Exposing these as MCP tools (or as tool
definitions for provider tool use APIs, which is the nearer term need) is a
mechanical transformation. The guardrails would need to move from keyword
matching to a policy layer the model cannot bypass, meaning enforcement in the
resolvers themselves (they already never compute investment advice, which is
the right kind of enforcement).

Recommendation: when LlmBrain lands, generate the tool schema from the intent
registry so the rule based path and the LLM tool path can never drift. Effort
S at that time.

## Issues found

### AI-1: Any direct from device LLM call would expose the API key

Severity: Critical (if built naively; nothing is exposed today)
Business impact: stolen key means unbounded API billing and abuse attributed to Salapify.
Technical impact: keys in a JS bundle are extractable from the APK in minutes.
User impact: none directly, but a key rotation outage would kill the feature.
Recommendation: never ship a provider key in the app. Build a minimal proxy
backend (one serverless function with per device quotas) before the first LLM
feature. Effort: L (backend, auth, quotas).

### AI-2: No observability for any future AI behavior

Severity: High (prerequisite gap)
Business impact: cannot detect a misbehaving assistant before users churn or post screenshots.
Technical impact: no crash reporting or telemetry pipeline exists to extend.
User impact: bad answers persist invisibly.
Recommendation: Sentry now, LLM call logging in the proxy later. Effort: S then M.

### AI-3: Chat memory would collide with the single blob storage design

Severity: Medium (latent design trap)
Business impact: storage cliff lockout is a one star review generator.
Technical impact: salapify_data_v2 already warns at 700KB and 1.5MB; conversation
history grows unboundedly and would accelerate the blob toward the 2MB Android read cliff.
User impact: app could refuse to load all data.
Recommendation: keep conversation memory out of the main blob, separate key or
SQLite, hard capped. Document this rule in CLAUDE.md before anyone builds it. Effort: S.

### AI-4: Guardrails are keyword based and English or Taglish only

Severity: Medium (fine for rules, insufficient for an LLM path)
Business impact: liability exposure if an LLM path answers investment or loan
questions the keyword guardrails missed.
Technical impact: substring guardrails cannot gate free form model output.
User impact: users could receive advice the product deliberately declines to give.
Recommendation: for LlmBrain, enforce scope in the system prompt AND validate
output (the respond contract of facts in, phrasing out already prevents number
invention; add a topic classifier or a rule that the model may only phrase
resolver output, never answer open questions). Effort: M.

## Recommended target architecture (when AI ships)

1. Keep RulesBrain exactly as is, the offline and free path.
2. Add a proxy backend: device -> Salapify API -> provider. Key, quotas,
   logging, provider abstraction all live there.
3. LlmBrain uses provider tool use where the tools are generated from the
   intent registry and execute on device against local data; the model sees
   facts, never the raw ledger.
4. Stream tokens into the existing chat UI; mascot mood from a final
   structured field.
5. Conversation memory in its own store, capped.
6. Sentry plus proxy side LLM telemetry from day one.

This keeps the product promises intact: offline first (rules path always
works), privacy (ledger never leaves the device, only facts), and honest
numbers (models phrase, resolvers compute).
