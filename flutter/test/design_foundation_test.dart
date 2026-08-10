// The Phase 1 design foundation is a contract, so it gets tests.
//
// Three things guarded here. That Motion.of makes reduce-motion the system's
// default rather than a per-screen memory (both halves proven: it passes the
// duration through normally AND collapses to zero under the setting, because
// an alarm that only proves one half cries wolf or sleeps through the fire).
// That salapifyTheme actually carries the authoritative sub-themes screens
// will lean on as their private styling is deleted. And that the token
// ladders hold the approved audit values, so a drive-by "adjust" shows up as
// a red test instead of a quiet fork.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/typography.dart';

void main() {
  group('Motion', () {
    test('the vocabulary holds the approved values', () {
      expect(Motion.tap, const Duration(milliseconds: 120));
      expect(Motion.state, const Duration(milliseconds: 160));
      expect(Motion.move, const Duration(milliseconds: 240));
      expect(Motion.reveal, const Duration(milliseconds: 420));
      expect(Motion.celebrate, const Duration(milliseconds: 1400));
      expect(Motion.curve, Curves.easeOut);
    });

    testWidgets('of() passes the duration through when motion is allowed', (
      tester,
    ) async {
      // The silent half: normal settings must NOT zero the animation, or
      // every transition in the app dies the day screens adopt the helper.
      Duration? seen;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              seen = Motion.of(context, Motion.move);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, Motion.move);
    });

    testWidgets('of() returns zero under reduced motion', (tester) async {
      Duration? seen;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              seen = Motion.of(context, Motion.reveal);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, Duration.zero);
    });

    test('of() outside any MediaQuery animates rather than freezes', () {
      // maybeOf is null in a bare context (tests, early build). The safe
      // default is to animate, matching every existing reduce-motion site.
      expect(Motion.of(_FakeContext(), Motion.tap), Motion.tap);
    });
  });

  group('the theme carries the authoritative sub-themes', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      test('every palette builds a complete ${b.name} theme', () {
        for (final t in barakoThemes) {
          final p = t.resolve(b);
          final theme = salapifyTheme(p);
          expect(theme.brightness, b, reason: t.key);

          // AppBar: the trio thirty screens used to repeat.
          expect(theme.appBarTheme.backgroundColor, p.background);
          expect(theme.appBarTheme.foregroundColor, p.text);
          expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w800);
          expect(theme.appBarTheme.titleTextStyle?.fontSize, TypeScale.title);
          expect(theme.appBarTheme.scrolledUnderElevation, 0);

          // Bottom sheet: one doorway, Radii.sheet top corners, card
          // surface, the palette's own scrim.
          final sheetShape =
              theme.bottomSheetTheme.shape as RoundedRectangleBorder;
          expect(
            sheetShape.borderRadius,
            const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
          );
          expect(theme.bottomSheetTheme.modalBackgroundColor, p.card);
          expect(theme.bottomSheetTheme.modalBarrierColor, p.overlay);

          // Inputs: filled on the card surface, field corners, a real error
          // and disabled state so private _decor helpers have nothing the
          // theme lacks.
          expect(theme.inputDecorationTheme.filled, isTrue);
          expect(theme.inputDecorationTheme.fillColor, p.card);
          expect(theme.inputDecorationTheme.errorBorder, isNotNull);
          expect(theme.inputDecorationTheme.disabledBorder, isNotNull);
          expect(theme.inputDecorationTheme.focusedErrorBorder, isNotNull);

          // Chips: accent selected fill, and a PLAIN labelStyle that carries
          // the family. The chip framework merges the theme style under a
          // chip's own (labelStyle.merge(widget.labelStyle)), and a
          // WidgetStateTextStyle loses every field in that merge, so the
          // family fell off and labels widened in the fallback face. This
          // pins the shape so that regression cannot come back quietly.
          expect(theme.chipTheme.selectedColor, p.primary);
          final label = theme.chipTheme.labelStyle;
          expect(label, isNot(isA<WidgetStateTextStyle>()));
          expect(label?.fontFamily, 'Jakarta');
          expect(label?.fontSize, 14);
          // The color field alone is per-state (the framework resolves a
          // WidgetStateColor inside a merged style, unlike a whole
          // WidgetStateTextStyle): secondary ink at rest, onPrimary when a
          // bare chip is selected onto the primary fill.
          expect(
            WidgetStateProperty.resolveAs<Color?>(label?.color, const {}),
            p.textSecondary,
          );
          expect(
            WidgetStateProperty.resolveAs<Color?>(label?.color, {
              WidgetState.selected,
            }),
            p.onPrimary,
          );

          // Cards stay borders-not-shadows.
          expect(theme.cardTheme.elevation, 0);
        }
      });
    }
  });

  group('the token ladders hold the approved values', () {
    test('radii', () {
      expect(Radii.control, 12);
      expect(Radii.field, 14);
      expect(Radii.card, 20);
      expect(Radii.sheet, 24);
      expect(Radii.hero, 26);
      expect(Radii.pill, 999);
    });

    test('the legacy Radii aliases are gone and stay gone', () {
      // Phase 2 converted every sm/md/lg/xl call site to a semantic rung and
      // deleted the aliases. This is the durable guard: referencing a deleted
      // static would already fail to compile, but the drift this class exists
      // to prevent is one number carrying two names, so scan the source and
      // fail if any of the four aliases is redeclared or used again.
      //
      // Proven to fail: re-add `static const double md = field;` to the Radii
      // class in theme.dart and this test goes red on
      // 'lib/theme.dart declares a legacy Radii alias (md)'.
      final legacy = RegExp(r'\bRadii\.(sm|md|lg|xl)\b');
      final decl = RegExp(r'static\s+const\s+double\s+(sm|md|lg|xl)\s*=');
      final libDir = Directory('lib');
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        final usage = legacy.firstMatch(src);
        expect(
          usage,
          isNull,
          reason:
              '${entity.path} uses a legacy Radii alias '
              '(${usage?.group(1)}). Use the semantic rung instead: '
              'control, field, card or hero.',
        );
        if (entity.path.endsWith('theme.dart')) {
          // Scope the redeclaration scan to the Radii class body, since Gap
          // legitimately owns its own sm/md/lg spacing names.
          final radiiBody =
              RegExp(r'class Radii \{[\s\S]*?\n\}').firstMatch(src)?.group(0) ??
              '';
          final redeclared = decl.firstMatch(radiiBody);
          expect(
            redeclared,
            isNull,
            reason:
                'lib/theme.dart declares a legacy Radii alias '
                '(${redeclared?.group(1)}). The aliases were deleted in '
                'Phase 2; do not bring them back.',
          );
        }
      }
    });

    test('every haptic goes through the Haptics vocabulary', () {
      // The vocabulary (select, moneyWritten, milestone) only means something
      // if it is the ONLY path: one grep has to be able to audit and retune
      // every buzz in the app. Phase 2 routed the raw calls through it, so
      // this guard fails if a raw HapticFeedback.* call comes back anywhere
      // outside theme.dart, which is the one file allowed to name it (the
      // Haptics class is the wrapper).
      //
      // Proven to fail: put `HapticFeedback.selectionClick();` back into any
      // screen and this goes red on 'lib/screens/....dart calls HapticFeedback
      // directly'.
      final raw = RegExp(r'\bHapticFeedback\.');
      final libDir = Directory('lib');
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('theme.dart')) {
          continue; // the wrapper lives here
        }
        final match = raw.firstMatch(entity.readAsStringSync());
        expect(
          match,
          isNull,
          reason:
              '${entity.path} calls HapticFeedback directly. Use the '
              'Haptics vocabulary instead: Haptics.select() for a choice, '
              'Haptics.moneyWritten() for a financial write, '
              'Haptics.milestone() for a celebration.',
        );
      }
    });

    test('pushed AppBars do not re-set the theme-owned chrome', () {
      // appBarTheme owns background, foreground and the title style, so a
      // pushed screen's AppBar is correct with just a title. Phase 2 stripped
      // the 41 copies that re-set background and foreground inline. This guard
      // fails if that exact redundancy comes back directly under an AppBar(,
      // so a theme change keeps reaching every screen's chrome.
      //
      // Proven to fail: put `backgroundColor: Barako.background,` back under
      // any AppBar( and this goes red.
      final redundant = RegExp(
        r'AppBar\(\s*\n\s*(backgroundColor: Barako\.background|'
        r'foregroundColor: Barako\.text),',
      );
      final libDir = Directory('lib');
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        expect(
          redundant.hasMatch(entity.readAsStringSync()),
          isFalse,
          reason:
              '${entity.path} re-sets an AppBar property the theme already '
              'owns (background or foreground). A bare AppBar(title: ...) '
              'inherits it; let appBarTheme own the chrome.',
        );
      }
    });

    test('spacing and the gutter', () {
      expect(Gap.gutter, 20);
      expect(Insets.card, const EdgeInsets.all(16));
      expect(Insets.hero, const EdgeInsets.all(20));
      expect(Insets.screen.left, Gap.gutter);
      expect(Insets.tabScreen.bottom, 96);
    });

    test('the alpha ladder', () {
      expect(BarakoAlpha.wash, 0.06);
      expect(BarakoAlpha.tint, 0.12);
      expect(BarakoAlpha.hint, 0.24);
    });

    test('icon sizes', () {
      expect(IconSizes.dense, 16);
      expect(IconSizes.inline, 20);
      expect(IconSizes.nav, 22);
      expect(IconSizes.disc, 40);
    });

    test('the two new type rungs', () {
      expect(AppText.titleLg.fontSize, 24);
      expect(AppText.titleLg.fontWeight, TypeWeight.heavy);
      expect(AppText.hero.fontSize, 30);
      expect(AppText.hero.fontWeight, TypeWeight.heavy);
      // hero is prose, not money: no tabular features, unlike amountLg at
      // the same size.
      expect(AppText.hero.fontFeatures, isNull);
      expect(AppText.amountLg.fontSize, 30);
    });

    test('the reference money face', () {
      // Subordinate money: same body size as amountRow, one weight lighter,
      // secondary ink, and still tabular so a column of reference figures
      // lines up. Pinned so a drift shows up here rather than as a quiet fork.
      expect(AppText.amountReference.fontSize, TypeScale.body);
      expect(AppText.amountReference.fontWeight, TypeWeight.medium);
      expect(AppText.amountReference.color, Barako.textSecondary);
      expect(AppText.amountReference.fontFeatures, isNotNull);
      expect(AppText.amountReference.fontFeatures, isNotEmpty);
    });
  });

  group('money presentation goes through AmountText', () {
    // Phase 2B consolidated monetary DISPLAY around the AmountText widget, so
    // a money figure on a screen names the ROLE it plays (hero, lg, card,
    // metric, row) and one file decides how it draws. This is the durable
    // floor: a screen that has adopted AmountText must keep using it, so a
    // later edit cannot quietly rip a hero or a row back out to a hand-rolled
    // `Text(formatMoney(...), style: AppText.amountLg...)` fork, which is the
    // exact five-ways-in-five-screens drift the widget was built to end.
    //
    // Grow this list as screens adopt; NEVER shrink it (same rule as
    // amount_face_test.dart's cleanFiles).
    //
    // This is deliberately NOT "formatMoney must never appear in a screen".
    // formatMoney legitimately stays for whole documented exception classes
    // that AmountText cannot or should not replace:
    //   - COMPOSITE text: a figure interpolated into a sentence, a legend
    //     label, a Text.rich span, a SnackBar receipt (AmountText is a whole
    //     widget, not a substring).
    //   - ACCESSIBILITY strings: formatMoney inside a Semantics(label:), where
    //     the visible figure is already an AmountText and the spoken sentence
    //     carries the same number as text.
    //   - EXPORT / generated text: home-widget headlines, share and recap
    //     lines, milestone copy (pure Dart, no Flutter, no widget at all).
    //   - FOREIGN currency: accounts render converted values through
    //     formatConverted, which AmountText (base-currency formatMoney only)
    //     cannot express.
    //   - WHOLE-PESO screens: accounts and cashflow display through
    //     formatMoneyText (round-up, no centavos) on purpose; routing them
    //     through AmountText would change the shown value, a money decision,
    //     not a presentation one.
    //   - STATEMENT helpers and REFERENCE amounts: a secondary supporting
    //     figure deliberately quieter than a transaction row (Reports' _line,
    //     account_detail's _stat), whose size/weight IS the hierarchy.
    //
    // Proven to fail: drop a file with no AmountText (e.g. goals.dart) into
    // the list, or delete the AmountText call from an adopter, and this goes
    // red naming the file.
    const amountTextAdopters = [
      'lib/screens/overview.dart',
      'lib/screens/history.dart',
      'lib/screens/budget.dart',
      'lib/screens/edit_sheet.dart',
      'lib/screens/salary_calculator.dart',
      // Phase 2B: heroes and row amounts consolidated onto AmountText.
      'lib/screens/utang.dart',
      'lib/screens/debts.dart',
      'lib/screens/insights.dart',
      'lib/screens/notes.dart',
      // Phase 2B, this session's account/detail batch plus the reference role:
      // the debt-picker and quick-add supporting amounts and the account
      // detail overview figures now route through AmountText.
      'lib/screens/account_detail.dart',
      'lib/screens/goal_create.dart',
      'lib/screens/quick_add_editor.dart',
    ];

    test('every adopter still routes a money figure through AmountText', () {
      final offenders = <String>[];
      for (final path in amountTextAdopters) {
        final file = File(path);
        if (!file.existsSync()) {
          offenders.add('$path no longer exists; update amountTextAdopters');
          continue;
        }
        if (!file.readAsStringSync().contains('AmountText(')) {
          offenders.add(
            '$path adopted AmountText but no longer uses it; a money figure '
            'was reverted to a hand-rolled fork. Use AmountText(role: ...).',
          );
        }
      }
      expect(offenders, isEmpty);
    });
  });
}

/// A context with no MediaQuery above it, for the maybeOf fallback test.
class _FakeContext extends Fake implements BuildContext {
  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>({
    Object? aspect,
  }) => null;

  @override
  InheritedElement?
  getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() => null;
}
