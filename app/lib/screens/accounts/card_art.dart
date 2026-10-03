import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';

/// The parts of a card that are drawn rather than written: the EMV chip, the
/// contactless mark, and the scheme logos.
///
/// Painted rather than shipped as images, because these are the one set of
/// marks Salapify can draw exactly: a chip is six gold contacts, contactless
/// is three arcs, and the schemes are simple geometry. Bundling four more
/// bitmaps to say "Visa" would cost APK size and gain nothing.

/// The EMV contact plate.
///
/// Real chips are a gold rectangle, slightly wider than tall, with the contact
/// pads separated by fine dark lines into a recognisable pattern. Drawing the
/// pattern is what separates "a card" from "a gold rectangle", and it is the
/// single cheapest cue that this is a piece of plastic.
class EmvChip extends StatelessWidget {
  const EmvChip({super.key, this.width = 38, this.dark = false});

  final double width;

  /// True on a pale card, where the usual bright gold washes out.
  final bool dark;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 0.78,
    child: CustomPaint(painter: _ChipPainter(dark: dark)),
  );
}

class _ChipPainter extends CustomPainter {
  const _ChipPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect plate = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height * 0.2),
    );

    canvas.drawRRect(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const <Color>[Color(0xFFD4AF37), Color(0xFF8C6D1F)]
              : const <Color>[Color(0xFFF5DFA0), Color(0xFFC9A227)],
        ).createShader(Offset.zero & size),
    );

    final Paint line = Paint()
      ..color = const Color(0xFF6B5410).withValues(alpha: 0.55)
      ..strokeWidth = math.max(0.8, size.width * 0.028)
      ..style = PaintingStyle.stroke;

    // The contact pattern: one horizontal split, and two verticals that stop
    // short of the middle band. This is the shape people recognise without
    // ever having looked at one closely.
    final double midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), line);

    final double x1 = size.width * 0.32;
    final double x2 = size.width * 0.68;
    for (final double x in <double>[x1, x2]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.34), line);
      canvas.drawLine(
        Offset(x, size.height * 0.66),
        Offset(x, size.height),
        line,
      );
    }

    // The inner pad outline, which is what makes it read as recessed.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.32,
          size.height * 0.28,
          size.width * 0.36,
          size.height * 0.44,
        ),
        Radius.circular(size.height * 0.1),
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter old) => old.dark != dark;
}

/// The contactless mark: four arcs growing to the right.
class ContactlessMark extends StatelessWidget {
  const ContactlessMark({super.key, required this.ink, this.size = 16});

  final Color ink;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 0.8,
    height: size,
    child: CustomPaint(painter: _ContactlessPainter(ink: ink)),
  );
}

class _ContactlessPainter extends CustomPainter {
  const _ContactlessPainter({required this.ink});

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height * 0.09;

    final Offset centre = Offset(-size.width * 0.35, size.height / 2);
    for (int i = 1; i <= 4; i++) {
      final double r = size.height * 0.18 * i;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: r),
        -math.pi / 4,
        math.pi / 2,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_ContactlessPainter old) => old.ink != ink;
}

/// The scheme mark, drawn to each network's own shape.
///
/// These are the marks a person uses to tell two cards apart at a glance in a
/// wallet, so a generic label would defeat the point of drawing a card at all.
class SchemeMark extends StatelessWidget {
  const SchemeMark({
    super.key,
    required this.network,
    required this.ink,
    this.height = 22,
  });

  final CardNetwork network;

  /// The card's own ink, used only where the scheme has no fixed colour of
  /// its own on plastic.
  final Color ink;
  final double height;

  @override
  Widget build(BuildContext context) {
    switch (network) {
      case CardNetwork.none:
        return const SizedBox.shrink();

      case CardNetwork.visa:
        // The wordmark, in Visa's own italic, drawn in the card's ink because
        // Visa prints it in whatever contrasts with the card.
        return Text(
          'VISA',
          style: TextStyle(
            fontSize: height * 0.82,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: height * 0.06,
            color: ink,
            height: 1,
          ),
        );

      case CardNetwork.mastercard:
        return SizedBox(
          width: height * 1.55,
          height: height,
          child: CustomPaint(painter: const _MastercardPainter()),
        );

      case CardNetwork.amex:
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: height * 0.22,
            vertical: height * 0.12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF006FCF),
            borderRadius: BorderRadius.circular(height * 0.12),
          ),
          child: Text(
            'AMEX',
            style: TextStyle(
              fontSize: height * 0.5,
              fontWeight: FontWeight.w900,
              letterSpacing: height * 0.04,
              color: Colors.white,
              height: 1,
            ),
          ),
        );

      case CardNetwork.jcb:
        // JCB's three stacked bars, blue, red and green.
        return SizedBox(
          width: height * 1.3,
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final Color c in const <Color>[
                Color(0xFF0E4C96),
                Color(0xFFD0021B),
                Color(0xFF00A650),
              ])
                Container(
                  width: height * 0.4,
                  height: height,
                  margin: EdgeInsets.only(right: height * 0.03),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(height * 0.08),
                  ),
                ),
            ],
          ),
        );
    }
  }
}

/// Mastercard's two interlocking circles, red and amber, with the overlap
/// drawn in the blend of the two.
class _MastercardPainter extends CustomPainter {
  const _MastercardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.height / 2;
    final Offset left = Offset(r, r);
    final Offset right = Offset(size.width - r, r);

    canvas.drawCircle(left, r, Paint()..color = const Color(0xFFEB001B));
    canvas.drawCircle(right, r, Paint()..color = const Color(0xFFF79E1B));

    // The intersection, which on the real mark is a distinct darker orange.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: left, radius: r)));
    canvas.drawCircle(right, r, Paint()..color = const Color(0xFFFF5F00));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MastercardPainter old) => false;
}
