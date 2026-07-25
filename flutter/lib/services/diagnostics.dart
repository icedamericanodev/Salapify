// What went wrong on the phone, in a form the founder can paste to Claude.
//
// The gap this closes: when something misbehaves on a real phone there is no
// way to get the details off it. The founder can describe what they saw, and
// a screenshot shows the symptom, but the error and the stack trace, the two
// things that actually locate a bug, stay on the device and are lost when the
// app restarts. Every diagnosis so far has been reasoning backwards from a
// screenshot.
//
// The alternative was a full Android toolchain on the founder's machine to
// read `adb logcat`. That is 15 to 20GB and a second environment to keep in
// step with CI, to read a log. This is a few hundred lines that ship over the
// air.
//
// THE PRIVACY RULE, which is the whole design and not a footnote.
//
// Salapify is an offline money app. Its promise is that the numbers never
// leave the phone. A diagnostics dump is the one feature that deliberately
// takes data OFF the device, so it must never carry money. No amounts, no
// account names, no category names, no notes, no people's names, no dates of
// individual entries. Counts and shapes only: "42 transactions", never "42
// transactions totalling 18,000 pesos" and never "Jollibee".
//
// This is enforced by a test that builds a report over deliberately
// incriminating data and fails if any of it appears. Without that test the
// rule is a comment, and a comment cannot stop the next person adding a field
// that looked harmless.
//
// Errors are stored under their OWN SharedPreferences key, never inside
// salapify_data_v2. A crash handler writing into the same blob as the user's
// ledger is a way to lose the ledger, and the ledger is irreplaceable.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Separate from salapify_data_v2 ON PURPOSE. See the note above.
const String diagnosticsKey = 'salapify_diagnostics_v1';

/// How many recent errors to keep. Enough to show a pattern, small enough
/// that the paste stays readable and the write stays cheap.
const int maxRecordedErrors = 15;

/// One recorded failure, already trimmed to what is useful.
class DiagnosticEntry {
  final String when;
  final String message;
  final String where;

  const DiagnosticEntry({
    required this.when,
    required this.message,
    required this.where,
  });

  Map<String, dynamic> toJson() => {'t': when, 'm': message, 'w': where};

  static DiagnosticEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = raw['m'];
    if (m is! String || m.isEmpty) return null;
    return DiagnosticEntry(
      when: raw['t'] is String ? raw['t'] as String : '',
      message: m,
      where: raw['w'] is String ? raw['w'] as String : '',
    );
  }
}

class Diagnostics {
  Diagnostics._();

  static final List<DiagnosticEntry> _recent = [];

  /// Loaded from disk once at startup so errors survive the restart that a
  /// crash causes. An error the user cannot report after rebooting is an
  /// error that may as well not have been recorded.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(diagnosticsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _recent
        ..clear()
        ..addAll(decoded.map(DiagnosticEntry.fromJson).nonNulls);
    } catch (_) {
      // Diagnostics failing must never take the app down. That would be a
      // crash reporter causing crashes, which is worse than no reporter.
    }
  }

  /// Catch what Flutter and the platform would otherwise print to a console
  /// nobody can read. Call once, before runApp.
  static void install() {
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exceptionAsString(), details.stack?.toString());
      previousFlutterHandler?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error.toString(), stack.toString());
      // false means "not handled", so the default logging still happens.
      return false;
    };
  }

  /// Record one failure. Trimmed hard: a full stack trace is thousands of
  /// characters and the useful part is the first few frames of OUR code.
  static void record(String message, String? stack) {
    final entry = DiagnosticEntry(
      when: DateTime.now().toUtc().toIso8601String().substring(0, 19),
      message: _trim(message, 240),
      where: _topFrames(stack),
    );
    _recent.add(entry);
    while (_recent.length > maxRecordedErrors) {
      _recent.removeAt(0);
    }
    unawaited(_persist());
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        diagnosticsKey,
        jsonEncode(_recent.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Same reason as load: never let the reporter break the app.
    }
  }

  /// Wipe the recorded errors. Offered next to the copy button so the founder
  /// can clear old noise and reproduce a bug cleanly.
  static Future<void> clear() async {
    _recent.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(diagnosticsKey);
    } catch (_) {}
  }

  static List<DiagnosticEntry> get recent => List.unmodifiable(_recent);

  /// The pasteable report.
  ///
  /// [data] is the store's blob. ONLY counts are read from it. If you are
  /// adding a line here, the question to ask is not "is this useful" but
  /// "could this identify a person, a place, or an amount". If yes, it does
  /// not go in, however useful it would be.
  static String report({
    required String stamp,
    int? patch,
    dynamic data,
    String? platform,
  }) {
    final b = StringBuffer();
    b.writeln('Salapify diagnostics');
    // Just the version marker, not the whole stamp sentence. The stamp
    // carries a line of release notes for the founder, which is right on the
    // Update stamp row and pure noise here: three wrapped lines before the
    // reader reaches anything diagnostic.
    b.writeln('Build: ${_versionOf(stamp)}');
    b.writeln('Patch: ${patch ?? 'none (running the base build)'}');
    b.writeln('Platform: ${platform ?? _platform()}');
    b.writeln('Taken: ${DateTime.now().toUtc().toIso8601String().substring(0, 19)} UTC');
    b.writeln();

    b.writeln('How much is stored (counts only, no amounts or names):');
    for (final entry in _counts(data).entries) {
      b.writeln('  ${entry.key}: ${entry.value}');
    }
    b.writeln();

    if (_recent.isEmpty) {
      b.writeln('Recent errors: none recorded.');
    } else {
      b.writeln('Recent errors, newest last (${_recent.length}):');
      for (final e in _recent) {
        b.writeln('  [${e.when}] ${e.message}');
        if (e.where.isNotEmpty) b.writeln('      at ${e.where}');
      }
    }
    return b.toString();
  }

  /// Counts of things, never their contents. The key names are deliberately
  /// generic so that adding a field to the store cannot leak a label here.
  static Map<String, int> _counts(dynamic data) {
    int n(String key) {
      final v = data is Map ? data[key] : null;
      return v is List ? v.length : 0;
    }

    return {
      'transactions': n('transactions'),
      'accounts': n('accounts'),
      'debts': n('debts'),
      'goals': n('goals'),
      'utang entries': n('utang'),
      'recurring items': n('recurring'),
      'categories': n('categories'),
    };
  }

  /// The `f2.38` part of a stamp, or the whole thing if it is not in that
  /// shape, because an unrecognised stamp is still better than a blank.
  static String _versionOf(String stamp) =>
      RegExp(r'^f\d+\.\d+').firstMatch(stamp)?.group(0) ?? stamp;

  static String _platform() {
    if (kIsWeb) return 'web';
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown';
    }
  }

  static String _trim(String s, int max) {
    final one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= max ? one : '${one.substring(0, max)}...';
  }

  /// The first frames that mention Salapify, falling back to the first frames
  /// of anything. A stack that is all framework tells us nothing about where
  /// OUR code went wrong.
  static String _topFrames(String? stack) {
    if (stack == null || stack.isEmpty) return '';
    final lines = stack
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final ours = lines.where((l) => l.contains('package:salapify/')).take(3);
    final chosen = ours.isNotEmpty ? ours : lines.take(2);
    return _trim(chosen.join(' <- '), 300);
  }
}
