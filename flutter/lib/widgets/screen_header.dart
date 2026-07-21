// The one header every tab uses, so the screens read as one app: a big Jakarta
// wordmark title, an optional muted subtitle, an optional trailing action, and
// fixed spacing above and below. Home keeps its own branded wordmark plus
// search; this is for the other tabs. Titles stay Jakarta (Fraunces is reserved
// for peso amounts).

import 'package:flutter/material.dart';

import '../theme.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// The gap above the title. Defaults to 12; the whole header carries a fixed
  /// 20 gap below so content starts at the same place on every tab.
  final double topGap;

  // NOT const on purpose: the header reads mutable Barako palette getters in
  // build(), so a const call site would be canonicalized and freeze its colors
  // on a theme or light/dark switch. A non-const constructor makes that
  // mistake impossible. The analyzer wants const on an all-final widget, but
  // that is exactly the footgun we are avoiding, so we opt out here.
  // ignore: prefer_const_constructors_in_immutables
  ScreenHeader(this.title,
      {super.key, this.subtitle, this.trailing, this.topGap = 12});

  @override
  Widget build(BuildContext context) {
    final titleText = Text(title,
        style: TextStyle(
            color: Barako.text,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 3));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topGap),
        if (trailing != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Flexible(child: titleText), trailing!],
          )
        else
          titleText,
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: TextStyle(color: Barako.muted, fontSize: 13, height: 1.3)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}
