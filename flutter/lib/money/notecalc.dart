// The notes calculator engine, ported 1:1 from the pure block at the top of
// mobile/app/notes.js (lines 27-238). A small, safe calculator with no eval:
// tokenize chops text into numbers (commas allowed, trailing % divides by
// 100, currency symbols stripped) and operators, then a recursive descent
// parser computes it with * and / binding tighter than + and -. Anything
// suspicious (divide by zero, unbalanced parens, leftover junk, results too
// big to trust) makes the line evaluate to null; a bad line simply shows no
// result and never crashes the screen. Golden-verified against outputs from
// executing the real RN engine.

const double _maxResult = 1e15;

final RegExp _currencyRe = RegExp(r'[₱$€£¥₩₹¢]');
final RegExp _numberSanityRe = RegExp(r'^(\d+(\.\d+)?|\.\d+)$');
final RegExp _digitCommaDotRe = RegExp(r'[\d.,]');

/// Dates and phone numbers (2026-07-04, 0917-555-1234) look like
/// subtraction; two or more unspaced hyphens between digit groups is never
/// money math, so those clusters become a word marker before evaluation.
final RegExp _identifierRe = RegExp(r'\d[\d,.]*(?:-[\d,.]+){2,}');

/// Trailing math must start right after a space (or the line start), so
/// store names like 7-11 never half-match into 7 minus 11.
final RegExp _trailingMathRe =
    RegExp(r'(?:^|\s)([-+]?[\d.(][\d,.()%+*/\s-]*)$');
final RegExp _trailingNumberRe = RegExp(r'(?:^|\s)([-+]?\d[\d,.]*%?)\s*$');
final RegExp _bareRe = RegExp(r'^[\d,.]+$');
final RegExp _digitRe = RegExp(r'\d');

class _Token {
  final String type; // 'num', '+', '-', '*', '/', '(', ')'
  final double value;
  _Token(this.type, [this.value = 0]);
}

List<_Token>? _tokenize(String text) {
  final tokens = <_Token>[];
  var i = 0;
  while (i < text.length) {
    final ch = text[i];
    if (ch == ' ' || ch == '\t') {
      i += 1;
      continue;
    }
    if ('+-*/()'.contains(ch)) {
      tokens.add(_Token(ch));
      i += 1;
      continue;
    }
    if ((ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) || ch == '.') {
      var raw = '';
      while (i < text.length && _digitCommaDotRe.hasMatch(text[i])) {
        raw += text[i];
        i += 1;
      }
      final plain = raw.replaceAll(',', '');
      if (!_numberSanityRe.hasMatch(plain)) return null;
      var value = double.parse(plain);
      var j = i;
      while (j < text.length && text[j] == ' ') {
        j += 1;
      }
      if (j < text.length && text[j] == '%') {
        value = value / 100;
        i = j + 1;
      }
      tokens.add(_Token('num', value));
      continue;
    }
    return null;
  }
  return tokens;
}

class _Parser {
  final List<_Token> tokens;
  int pos = 0;
  _Parser(this.tokens);

  _Token? get _peek => pos < tokens.length ? tokens[pos] : null;
  _Token _next() => tokens[pos++];

  double parseExpr() {
    var left = parseTerm();
    while (_peek != null && (_peek!.type == '+' || _peek!.type == '-')) {
      final op = _next().type;
      final right = parseTerm();
      left = op == '+' ? left + right : left - right;
    }
    return left;
  }

  double parseTerm() {
    var left = parseFactor();
    while (_peek != null && (_peek!.type == '*' || _peek!.type == '/')) {
      final op = _next().type;
      final right = parseFactor();
      if (op == '/') {
        if (right == 0) throw const FormatException('divide by zero');
        left = left / right;
      } else {
        left = left * right;
      }
    }
    return left;
  }

  double parseFactor() {
    final t = _peek;
    if (t == null) throw const FormatException('unexpected end');
    if (t.type == '+') {
      _next();
      return parseFactor();
    }
    if (t.type == '-') {
      _next();
      return -parseFactor();
    }
    if (t.type == 'num') {
      _next();
      return t.value;
    }
    if (t.type == '(') {
      _next();
      final inner = parseExpr();
      if (_peek == null || _peek!.type != ')') {
        throw const FormatException('missing close paren');
      }
      _next();
      return inner;
    }
    throw const FormatException('unexpected token');
  }
}

/// Evaluate one candidate string. Returns a finite number, or null.
double? evaluateMath(String text) {
  final tokens = _tokenize(text);
  if (tokens == null || tokens.isEmpty) return null;
  try {
    final parser = _Parser(tokens);
    final value = parser.parseExpr();
    if (parser.pos != tokens.length) {
      throw const FormatException('leftover tokens');
    }
    if (!value.isFinite || value.abs() > _maxResult) return null;
    return value;
  } on FormatException {
    return null;
  }
}

/// Look at one line and decide what it is worth. Returns (value, bare):
/// value is the computed number or null; bare is true for one plain number.
({double? value, bool bare}) analyzeLine(String rawLine) {
  final line = rawLine
      .replaceAll(_currencyRe, '')
      .trim()
      .replaceAll(_identifierRe, '#');
  if (line.isEmpty || !_digitRe.hasMatch(line)) {
    return (value: null, bare: false);
  }

  final whole = evaluateMath(line);
  if (whole != null) {
    return (value: whole, bare: _bareRe.hasMatch(line));
  }

  final tail = _trailingMathRe.firstMatch(line);
  if (tail != null) {
    final value = evaluateMath(tail.group(1)!);
    if (value != null) return (value: value, bare: false);
  }

  final bareTail = _trailingNumberRe.firstMatch(line);
  if (bareTail != null) {
    final value = evaluateMath(bareTail.group(1)!);
    if (value != null) return (value: value, bare: false);
  }
  return (value: null, bare: false);
}

/// Break a note into calculator rows: { rows: [{label, value}], total,
/// hasMath }. The panel shows when at least one line did real math, or two
/// or more plain numbers are worth adding; one lonely bare number stays
/// quiet.
Map<String, dynamic> computeCalc(dynamic text) {
  final lines = (text ?? '').toString().split('\n');
  final rows = <Map<String, dynamic>>[];
  var total = 0.0;
  var counted = 0;
  for (final raw in lines) {
    final r = analyzeLine(raw);
    if (r.value == null) continue;
    total += r.value!;
    counted += 1;
    if (!r.bare) {
      final trimmed = raw.trim();
      final label = trimmed.length > 26
          ? '${trimmed.substring(0, 25)}…'
          : trimmed;
      rows.add({'label': label, 'value': r.value});
    }
  }
  final hasMath = rows.isNotEmpty || counted >= 2;
  return {'rows': rows, 'total': total, 'hasMath': hasMath};
}
