# AI Strategy

Sprint 1, 2026-07-10. The architecture design for Salapify's AI future.
Design only; nothing here is implemented in this sprint. Builds on
AI_Readiness.md from Sprint 0, which assessed the current state; this
document designs the target state and the path.

## 1. Vision

Salapify's AI is a financial coach that can only tell the truth. The model
never computes money; it phrases numbers the app's tested, deterministic
resolvers computed from the user's own on device ledger. It speaks Taglish,
it knows sweldo culture, utang etiquette, and 13th month season, and it
works within the app's promises: offline first (the rule based Pan brain is
the permanent fallback), private (the ledger never leaves the device, only
minimal derived facts do), and calm (the same tone guardrails the coach rule
engine already enforces).

The strategic bet: every finance app will bolt on a chatbot; almost none
will be able to guarantee the numbers are real. Salapify's existing
architecture (facts computed by resolvers, phrasing separated in
lib/pan/respond.js) is that guarantee, built before the model arrived.

## 2. Architecture

### The PanBrain abstraction

One interface, two implementations, selected at runtime:

- RulesBrain: today's engine (normalize, intents, resolvers, respond).
  Offline, instant, free, deterministic. Never removed; it is the fallback
  for offline, for quota exhaustion, for provider outages, and for free
  tier users.
- LlmBrain: online path. The model receives the user message plus a tool
  catalog generated from the existing intent registry. It selects tools;
  the tools execute ON DEVICE against local data via the existing
  resolvers; the model receives only the resolver facts and phrases the
  reply. The ledger itself is never in the context window.

Contract (shape, not code):
- understand(message, shortContext) resolves to either a tool invocation
  plan or a guardrail decision.
- phrase(facts, mood, locale) resolves to streamed text plus a structured
  trailer (mood for the mascot, optional CTA route).
- Both brains implement the same contract so the chat UI, memory, and
  telemetry are brain agnostic.

### The proxy backend

No provider key ever ships in the app (an APK is public). A minimal proxy
(one serverless function to start) owns:

- Provider API keys and provider selection.
- Per install quotas and rate limits (anonymous install id, no accounts).
- Request and response logging (see observability), with prompt content
  retention policy documented in the privacy policy.
- The kill switch: a config endpoint the app polls that can disable
  LlmBrain globally or per version instantly, degrading to RulesBrain with
  honest copy (Pan is thinking simpler today).

Device to proxy is HTTPS with a pinned domain; certificate pinning decision
rides the rebuild that introduces the AI feature. The proxy is intentionally
dumb: no user data storage, no ledger access, stateless per request except
quota counters.

### LLM provider abstraction

Lives server side in the proxy, not in the app. The app speaks one private
API shaped like PanBrain. Provider swaps (Claude, OpenAI, Gemini) are proxy
deployments, invisible to devices, requiring no OTA. Default provider
recommendation at implementation time: a current mid tier model with tool
use and streaming (evaluate on the harness in section 10 before deciding;
do not hardcode this choice in docs that outlive pricing pages).

## 3. Conversation memory

- Short term: the last N turns (target 10) travel with each request as
  compact summaries, held in component state and persisted under a
  DEDICATED AsyncStorage key (never salapify_data_v2; see Database_Review
  DB-6), hard capped at 50KB with oldest turn eviction.
- Long term: a small persistent profile of durable facts the user
  volunteered to Pan (payday rhythm already known from settings; things
  like I am saving for a laptop). Stored on device, editable and erasable
  by the user in one place (a Pan knows this about you screen is the
  design intent), included in prompts as a short system section.
- Never remembered: raw amounts history (the resolvers already have the
  ledger locally; memory must not become a second, unsanitized ledger),
  and nothing memory holds ever leaves the device except within the
  prompt of an active request.
- Erase everything erases Pan memory too, same rule as the snapshot key.

## 4. RAG readiness

Deferred by design, with a trigger condition: when Learn content exceeds
roughly 50 lessons or a PH tax and benefits knowledge base is added,
retrieval becomes worth it. The design when triggered:

- Content chunks as markdown with precomputed embeddings shipped in the
  app bundle (no on device embedding model needed; embeddings are computed
  at build time).
- In memory cosine scan on device (a few thousand chunks is trivial), top
  K chunks injected into the phrase step as citations.
- The user's ledger is never embedded. RAG is for content, not for
  transactions; structured resolver queries remain the only ledger access.

## 5. Prompt management

- All prompts live in one versioned module (lib/pan/prompts.js by design
  intent) next to the intent registry: system prompt, guardrail preamble,
  per intent phrasing exemplars, locale variants.
- Every prompt carries a version string; the proxy logs prompt version
  with every request so behavior changes are attributable.
- Snapshot tests render every prompt with fixture facts so silent drift
  fails CI (the same discipline the money math already has).
- Prompt changes ship OTA like any JS change, gated by the eval harness
  (section 10) rather than vibes.

## 6. Future MCP support

The intent registry is already a tool catalog (id, title, examples,
resolver). The design commitment: tool schemas for the LLM are GENERATED
from the registry, not hand written, so RulesBrain, LlmBrain, and any
future MCP surface can never drift apart. When MCP matters (exposing
Salapify tools to external assistants, or consuming external MCP servers
for things like bank statement parsing), the same generated catalog becomes
the MCP tool list. Guardrails enforce at the resolver layer (resolvers
simply cannot compute out of scope answers), which is the only enforcement
that survives any protocol.

## 7. Streaming responses

- The PanBrain contract streams from day one (token callback, not a
  promise of full text); retrofitting streaming touches every call site,
  so it is in the interface before the first implementation.
- Transport: server sent events from the proxy (fetch streaming on RN, or
  react-native-sse; decide at implementation on the current RN version).
- UI: the existing chat bubble appends tokens; the mascot mood and CTA
  arrive in the structured trailer after the text completes. RulesBrain
  fakes a fast stream for visual consistency (or renders instantly;
  decide in design review, consistency favors the former).
- Interruption: a user leaving the screen aborts the request (and the
  spend) via AbortController through the proxy.

## 8. Observability

Prerequisite: Sentry (rebuild batch 1) for the app side. AI specific,
proxy side:

- Per request: latency, token counts in and out, model and prompt version,
  intent or tool selected, guardrail hits, finish reason, quota state.
  Content logging is off by default; a short lived debugging mode with
  explicit disclosure can be enabled per build, never per user silently.
- Per user signal: an in chat thumbs up or down on each Pan answer,
  stored with the request id, the primary quality feed for evaluation.
- On device: a small ring buffer of recent Pan interactions (intent,
  brain used, latency, no content) attachable to a user initiated bug
  report, preserving the no silent telemetry stance.
- Dashboards: cost per day, cost per user distribution, guardrail hit
  rate, fallback rate to RulesBrain, thumbs ratio. Alarms on cost and
  fallback anomalies.

## 9. AI evaluation

Before any user sees LlmBrain:

- A golden set of at least 100 real phrasing tasks (facts in, expected
  qualities out) covering every intent, both locales, and edge moods
  (zero balances, overdue utang, negative safe to spend).
- Property checks over outputs: every number in the reply must appear in
  the supplied facts (the no invented numbers property, mechanically
  checkable), no advice in guardrailed domains, length and tone bounds,
  no em or en dashes (house style).
- A jailbreak and scope suite: attempts to extract investment advice, to
  make Pan compute math itself, to leak the system prompt, to elicit
  other users data (there is none, but the answer must be the designed
  one).
- Regression gate: prompt or model changes run the suite in CI (proxy
  repo); a score drop blocks deploy. Thumbs data feeds new cases
  monthly.

## 10. Token cost optimization

- Facts, not ledgers: resolver outputs are compact (tens of tokens); the
  design keeps context under roughly 2K tokens per request (system prompt
  plus memory summary plus facts) as a budget, enforced in the proxy.
- RulesBrain first: the intent matcher runs on device before any network
  call; high confidence matches with simple phrasing needs can skip the
  LLM entirely (a hybrid mode), reserving the model for ambiguous or
  conversational turns.
- Caching: the system prompt and tool catalog are static per version,
  structured for provider prompt caching.
- Quotas: per install daily caps (generous for Pro, small free taste),
  enforced in the proxy; the app shows remaining budget honestly rather
  than failing silently. Unit economics and pricing in Monetization.md.
- Model tiering: phrasing is not hard reasoning; default to a small or
  mid tier model, escalate only if evaluation demands it.

## 11. Security

- No provider keys in the client, ever (AI-1 from Sprint 0). Keys live in
  the proxy environment.
- The proxy authenticates devices with an anonymous install token minted
  on first use (no accounts), rate limited per token and per IP.
- Tool execution is on device only; the proxy cannot invoke tools or read
  the ledger even if fully compromised. Blast radius of a proxy breach:
  prompt content of in flight requests and quota metadata, and that fact
  is documented in the privacy policy.
- Model output is untrusted input to the app: CTAs from the trailer are
  validated against a route allowlist; no model output is ever executed,
  interpolated into storage writes, or used to mutate the ledger. Pan
  stays read only in the LLM era until a separate, explicitly confirmed
  write flow is designed (out of scope this horizon).
- Prompt injection stance: the only third party content that ever enters
  a prompt is Learn content we author. If external content (like OCR
  text) is ever added to prompts, it is delimited, and instructions in it
  are ignored per the system prompt plus the property checks in the eval
  suite.

## 12. Privacy

- The ledger never leaves the device. Requests carry: the user message,
  compact resolver facts, memory summary, locale. No names of debtors, no
  account lists, no full transaction rows; resolvers must aggregate
  before facts leave (design rule: a fact may contain a total or a single
  referenced item the user named, never a bulk enumeration).
- Disclosure before the first message: a one time explainer that Pan's
  smart mode sends your question and the specific numbers needed to
  answer it to Salapify's server, with an always available offline
  toggle. The data safety form updates the day the feature ships (the
  Sprint 0 lesson: code and policy must never diverge).
- Retention: proxy logs keep metadata; content retention zero by default.
- The free RulesBrain remains fully private and offline, so privacy is
  never a paywall: users who refuse the disclosure lose nothing they had.

## 13. Future financial coach

The destination the architecture builds toward, in order:

1. Reactive coach (this horizon): ask Pan anything about your own money;
   honest numbers, warm phrasing, guardrails.
2. Proactive coach: Pan initiates at the moments the behavior model says
   matter (payday plan, pre bill crunch, lapse comeback), composing the
   existing coach rule engine's priorities with LLM phrasing. Frequency
   capped, always dismissible, never shaming (the notification rules in
   Product_Strategy.md apply to Pan too).
3. Planning coach: multi turn goal planning (an emergency fund by June)
   built on the resolvers plus a plan object the user approves; still no
   silent writes.
4. Document understanding: receipts and statements parsed on device (ML
   Kit OCR exists) with LLM cleanup through the proxy as an opt in,
   feeding the same confirm before save flow.

Each stage ships only when the previous stage's evaluation and cost data
say it is ready; the sprint plan carries stage 1 only.

## 14. What we will NOT do

- No model computed money math, ever.
- No accounts requirement for AI (anonymous install tokens).
- No silent data collection to improve the AI.
- No autonomous writes to the ledger.
- No shipping AI before billing, observability, and the proxy exist.
