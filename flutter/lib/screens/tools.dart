// Tools and More: the hub for the calculators and helpers being adapted
// one by one from the RN app. Each row opens a tool; the coming-soon list
// keeps the founder's roadmap visible in-app so testers know what is next.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import 'loan_calculator.dart';
import 'notes.dart';

class ToolsScreen extends StatelessWidget {
  final SalapifyStore store;
  const ToolsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Tools',
            style:
                TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _tool(
              context,
              icon: Icons.percent,
              title: 'Loan calculator',
              blurb:
                  'The real monthly payment and the TRUE rate hiding behind an add-on quote.',
              open: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LoanCalculatorScreen())),
            ),
            _tool(
              context,
              icon: Icons.sticky_note_2_outlined,
              title: 'Notes',
              blurb:
                  'Lines with amounts add themselves up, like a receipt.',
              open: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NotesScreen(store: store))),
            ),
            const SizedBox(height: 16),
            Text('ON THE WAY',
                style: TextStyle(
                    color: Barako.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
            const SizedBox(height: 6),
            Text(
                'BNPL checker, take-home pay, 13th month, income tax, SSS PhilHealth Pag-IBIG, currency converter, learn, and mindset are being adapted from the React Salapify one by one.',
                style: TextStyle(
                    color: Barako.muted, fontSize: 12, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _tool(BuildContext context,
      {required IconData icon,
      required String title,
      required String blurb,
      required VoidCallback open}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Barako.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(blurb,
                          style: TextStyle(
                              color: Barako.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Barako.faint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
