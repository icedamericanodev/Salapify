import 'dart:convert';
import 'dart:io';
import 'package:salapify/money/loan.dart';

void main(List<String> argv) {
  final cases = jsonDecode(File(argv[0]).readAsStringSync()) as Map<String, dynamic>;
  final res = {
    'summaries': [
      for (final a in cases['summaries'] as List)
        loanSummary(a[0], a[1], a[2], method: a[3] as String, rateBasis: a[4] as String)
    ],
    'payoffs': [
      for (final a in cases['payoffs'] as List) payoffSaving(a[0], a[1], a[2], a[3])
    ],
    'rates': [
      for (final a in cases['rates'] as List) effectiveMonthlyRate(a[0], a[1], a[2])
    ],
  };
  File(argv[1]).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(res));
}
