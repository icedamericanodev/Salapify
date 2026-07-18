// Pan's single public entry point, ported 1:1 from mobile/lib/pan/ask.js.
// Message in, grounded reply out: guardrails first, then the help menu,
// then tool pointers, then a resolver over the golden-locked engines and
// the responder. The FACTS always come from the deterministic resolvers.

import 'intents.dart';
import 'normalize.dart';
import 'resolvers.dart';
import 'respond.dart';

/// The help / empty-state reply, built from the registry so it always
/// matches what Pan can actually do.
Map<String, dynamic> helpReply([List<dynamic>? alternatives]) {
  final source = (alternatives != null && alternatives.isNotEmpty)
      ? intents.where((i) => alternatives.contains(i.id)).toList()
      : intents.take(4).toList();
  final lead = (alternatives != null && alternatives.isNotEmpty)
      ? 'I am not sure I got that. Did you mean one of these?'
      : "Hi, I'm Pan. I read only what is on your phone. Ask me things like:";
  return {
    'mood': 'idle',
    'intent': helpId,
    'text': lead,
    'suggestions': [for (final i in source) i.examples.first],
  };
}

/// The starter chips for the input screen: one example per top intent.
List<Map<String, String>> suggestions([int n = 6]) => [
      for (final i in intents.take(n))
        {'id': i.id, 'label': i.title, 'example': i.examples.first},
    ];

Map<String, dynamic> ask(dynamic data, dynamic message, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final raw = (message ?? '').toString();
  final norm = normalize(raw);
  final det = detectIntent(norm);

  final guardrail = det['guardrail'] as Guardrail?;
  if (guardrail != null) {
    return {
      'intent': det['id'],
      'mood': 'idle',
      'text': guardrail.reply,
      'cta': guardrail.cta,
    };
  }

  if (det['id'] == helpId) {
    return helpReply(det['alternatives'] as List<dynamic>?);
  }

  Intent? intent;
  for (final i in intents) {
    if (i.id == det['id']) {
      intent = i;
      break;
    }
  }

  if (intent != null && intent.pointer != null) {
    final p = intent.pointer!;
    return {
      'intent': intent.id,
      'mood': 'idle',
      'text': p['text'],
      'cta': {'label': p['label'], 'route': p['route']},
    };
  }

  final resolver = intent != null ? resolvers[intent.resolve] : null;
  if (resolver == null) return helpReply();

  final facts = resolver(
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{},
      (now: ref, amount: extractAmount(raw), raw: raw));
  final reply = respond(facts);
  return {'intent': intent!.id, ...reply};
}
