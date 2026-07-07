// Pan's single public entry point. Every caller and every future LLM goes
// through ask(): message in, a grounded reply out. The FACTS always come from
// the deterministic resolvers; only the wording could ever be swapped for a
// model, and it still gets FACTS it cannot alter. This is the seam.

import { normalize, extractAmount } from './normalize';
import { detectIntent, INTENTS, GUARDRAILS, HELP_ID } from './intents';
import { RESOLVERS } from './resolvers';
import { respond } from './respond';

// The help / empty-state reply, built from the registry so it always matches
// what Pan can actually do.
export function helpReply(alternatives) {
  const suggestions = (alternatives && alternatives.length
    ? INTENTS.filter((i) => alternatives.includes(i.id))
    : INTENTS.slice(0, 4)
  ).map((i) => i.examples[0]);
  const lead = alternatives && alternatives.length
    ? 'I am not sure I got that. Did you mean one of these?'
    : "Hi, I'm Pan. I read only what is on your phone. Ask me things like:";
  return { mood: 'idle', intent: HELP_ID, text: lead, suggestions };
}

// The starter chips for the input screen: one example per top intent.
export function suggestions(n = 6) {
  return INTENTS.slice(0, n).map((i) => ({ id: i.id, label: i.title, example: i.examples[0] }));
}

export function ask(data, message, ctx = {}) {
  const now = ctx.now || new Date();
  const raw = String(message || '');
  const norm = normalize(raw);
  const det = detectIntent(norm);

  // Out-of-scope, liability-sensitive topics: decline and redirect. Matched
  // before any data intent so investment or loan guidance can never leak.
  if (det.guardrail) {
    return { intent: det.id, mood: 'idle', text: det.guardrail.reply };
  }

  if (det.id === HELP_ID) {
    return helpReply(det.alternatives);
  }

  const intent = INTENTS.find((i) => i.id === det.id);
  const resolver = intent && RESOLVERS[intent.resolve];
  if (!resolver) return helpReply();

  const facts = resolver(data || {}, { now, amount: extractAmount(raw), raw });
  const reply = respond(facts);
  return { intent: intent.id, ...reply };
}
