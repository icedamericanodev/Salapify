import 'package:flutter/material.dart';

import 'design/app_theme.dart';
import 'design/scroll_behavior.dart';
import 'design/tokens.dart';
import 'shell/app_shell.dart';
import 'state/financial_state.dart';

void main() {
  runApp(const SalapifyApp());
}

/// Salapify, rebuilt in Flutter from the Google AI Studio prototype in src/.
///
/// Everything stays on the device. There is no account, no server and no
/// network call anywhere in this app.
class SalapifyApp extends StatefulWidget {
  const SalapifyApp({super.key});

  @override
  State<SalapifyApp> createState() => _SalapifyAppState();
}

class _SalapifyAppState extends State<SalapifyApp> {
  final FinancialState _state = FinancialState();

  @override
  void initState() {
    super.initState();
    // One store, one listener: a change anywhere redraws the shell.
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(_state.theme);

    return MaterialApp(
      title: 'Salapify',
      debugShowCheckedModeBanner: false,
      // Drops Android's stretch overscroll. See scroll_behavior.dart for why.
      scrollBehavior: const SalapifyScrollBehavior(),
      theme: salapifyTheme(palette, _state.theme),
      home: AppShell(state: _state),
    );
  }
}
