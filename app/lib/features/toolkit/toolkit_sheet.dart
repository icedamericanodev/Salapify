import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import '../categories/category_manager_sheet.dart';
import '../fx/fx_sheet.dart';
import '../shared/sheet_scaffold.dart';
import '../tax/business_tax_sheet.dart';
import '../tax/tax_calculator_sheet.dart';

/// The Philippine Financial Toolkit, the header's sparkle button.
///
/// The prototype puts several tools behind one entry point rather than giving
/// each its own button, and that is right: these are things somebody opens
/// occasionally and deliberately, not every day. A row of five header icons
/// for five calculators would crowd the one thing the header is for.
class ToolkitSheet extends StatelessWidget {
  const ToolkitSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => ToolkitSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(state.theme);

    return SheetScaffold(
      palette: p,
      icon: Icons.auto_awesome_outlined,
      title: 'Philippine Toolkit',
      subtitle: 'Calculators built on BIR and BSP rules',
      child: Column(
        children: <Widget>[
          _tool(
            context,
            p,
            icon: Icons.public_outlined,
            title: 'Foreign exchange',
            subtitle: 'Live rates between the peso and four major currencies',
            onTap: () {
              Navigator.of(context).pop();
              FxSheet.show(context, p);
            },
          ),
          _tool(
            context,
            p,
            icon: Icons.calculate_outlined,
            title: 'Tax Calculator',
            subtitle: 'Take-home pay, 13th month, and the freelancer 8% choice',
            onTap: () {
              Navigator.of(context).pop();
              TaxCalculatorSheet.show(context, p);
            },
          ),
          _tool(
            context,
            p,
            icon: Icons.storefront_outlined,
            title: 'Business Tax Simulator',
            subtitle: 'Compare every BIR regime on your own numbers',
            onTap: () {
              Navigator.of(context).pop();
              BusinessTaxSheet.show(context, p);
            },
          ),
          _tool(
            context,
            p,
            icon: Icons.sell_outlined,
            title: 'Categories',
            subtitle: 'The categories and sub-categories your entries use',
            onTap: () {
              Navigator.of(context).pop();
              CategoryManagerSheet.show(context, state);
            },
          ),
        ],
      ),
    );
  }

  Widget _tool(
    BuildContext context,
    Palette p, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Semantics(
        button: true,
        child: Material(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.control),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(Radii.tile),
                    ),
                    child: Icon(icon, size: 18, color: p.accent),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: AppType.rowTitle(p)),
                        Text(subtitle, style: AppType.rowMeta(p)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: p.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
