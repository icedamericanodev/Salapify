// Salapify Flutter preview. This is the from-scratch Flutter rebuild the
// founder chose, growing next to the live React Native app in mobile/ until
// it reaches parity. Every push that touches flutter/ builds an APK on the
// free GitHub runners and lands on the founder's phone through the fixed
// "flutter-preview" release link. UPDATE_STAMP below bumps on every push so
// the phone build is verifiable, same discipline as the RN app.

import 'package:flutter/material.dart';
import 'theme.dart';

/// Bump on EVERY push that touches flutter/, so the founder can confirm on
/// the phone which build arrived. Format: `f<major>.<counter>`.
const String updateStamp =
    'f0.02 · Money engine part 1: PH tax and 13th month ported, 85 golden vectors matching the current app';

void main() {
  runApp(const SalapifyApp());
}

class SalapifyApp extends StatelessWidget {
  const SalapifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salapify Preview',
      theme: barakoDarkTheme(),
      debugShowCheckedModeBanner: false,
      home: const PreviewHome(),
    );
  }
}

class PreviewHome extends StatelessWidget {
  const PreviewHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            const Row(
              children: [
                Text(
                  '₱',
                  style: TextStyle(
                    color: Barako.primary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'SALAPIFY',
                  style: TextStyle(
                    color: Barako.text,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'FLUTTER PREVIEW',
              style: TextStyle(
                color: Barako.celebrate,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 28),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHAT THIS BUILD IS',
                      style: TextStyle(
                        color: Barako.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'The from-scratch Flutter rebuild of Salapify. It grows '
                      'feature by feature next to the current app, money math '
                      'first, and every update lands here for you to check. '
                      'Your data will import from a Salapify backup file when '
                      'the storage layer arrives.',
                      style: TextStyle(
                        color: Barako.textSecondary,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update stamp',
                      style: TextStyle(color: Barako.text, fontSize: 15),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        updateStamp,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Barako.muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
