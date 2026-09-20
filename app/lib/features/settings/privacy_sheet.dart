import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/sheet_scaffold.dart';

/// The privacy receipt, behind the badge beside the wordmark and behind a row
/// in Settings.
///
/// Ported in spirit from the prototype's own panel
/// (`src/components/SettingsModal.tsx`), and CORRECTED. Its version is headed
/// "Privacy Receipt and Offline Guarantee" and lists four claims, three of
/// which are true of this app. The fourth is the omission: one request does
/// leave the phone, and a receipt with a missing line item is worse than no
/// receipt at all. It is named here, first, by name.
///
/// ## Words that may never appear on this screen
///
/// "100% offline", "zero network", "no internet", "Offline Guarantee": all
/// false as of `fx_service.dart`. "Encrypted backup", "bank grade", "military
/// grade": the export is `JsonEncoder.withIndent('  ')`, which is plain
/// readable text. The prototype's knowledge base tells people they can
/// "export an encrypted JSON backup file"; that string is not ported, and a
/// person emailing themselves a file they believe is protected is exactly the
/// harm a false security claim causes.
class PrivacySheet extends StatelessWidget {
  const PrivacySheet({super.key, required this.palette});

  final Palette palette;

  static Future<void> show(BuildContext context, Palette palette) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) => PrivacySheet(palette: palette),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      palette: palette,
      icon: Icons.verified_user_outlined,
      title: 'What stays on this phone',
      subtitle: 'Every line, including the one thing that leaves',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Line(
            palette: palette,
            icon: Icons.person_off_outlined,
            title: 'No account, and nothing to sign in to',
            body:
                'There is no email, no phone number, no password and no '
                'profile. Salapify has no server, so there is nothing of '
                'yours anywhere for anybody to reach.',
          ),
          _Line(
            palette: palette,
            icon: Icons.folder_outlined,
            title: 'Your figures live in one file here',
            body:
                'Everything you type goes into a file in Salapify\'s own '
                'private storage on this phone. Android does not let other '
                'apps read that folder.',
          ),
          // ADDED when Pan started keeping a conversation, 2026-09-20. A
          // receipt that lists six files and not the seventh is not a
          // receipt, and this is the one holding sentences somebody typed in
          // their own words, which is a different kind of private from a
          // balance.
          _Line(
            palette: palette,
            icon: Icons.chat_bubble_outline,
            title: 'What you ask Pan is kept, in its own file',
            body:
                'Your last two dozen messages with Pan stay on this phone so '
                'the conversation is still there next time you open it. They '
                'are in a separate file from your figures, so a problem with '
                'one can never affect the other. Start fresh, at the top of '
                'the chat, deletes them, and so does Delete everything.',
          ),
          _Line(
            palette: palette,
            icon: Icons.analytics_outlined,
            title: 'No analytics, no crash reporting, no ads',
            body:
                'Nothing counts your taps and nothing follows you. There is '
                'no advertising ID in this app.',
          ),
          _Line(
            palette: palette,
            icon: Icons.cloud_off_outlined,
            title: 'Google Drive backup is switched off on purpose',
            body:
                'Android would normally copy an app\'s data to your Google '
                'account. Salapify turns that off, so no copy of your money '
                'exists in a cloud we cannot see, check or delete. Setting up '
                'a new phone by copying directly from this one still brings '
                'Salapify across, with no server in between.',
          ),
          _Line(
            palette: palette,
            icon: Icons.language,
            title: 'One thing does leave this phone',
            accent: true,
            body:
                'When you open the currency converter, Salapify asks a public '
                'exchange rate service for today\'s rates. It sends a currency '
                'code, for example PHP. It never sends your balances, your '
                'entries, the names you have saved, or anything that '
                'identifies you. If you never open the converter, Salapify '
                'makes no internet request at all.',
          ),
          _Line(
            palette: palette,
            icon: Icons.description_outlined,
            title: 'A backup you export is plain readable text',
            accent: true,
            body:
                'It is not encrypted and we do not claim it is. It holds your '
                'salary, your balances and the names of people in your debt '
                'records, so anyone who opens the file can read all of it. '
                'Keep it somewhere you trust.',
          ),
          _Line(
            palette: palette,
            icon: Icons.group_outlined,
            title: 'Names you type belong to other people',
            body:
                'A debt asks who it is with. That name sits in your file like '
                'everything else and is never sent anywhere. If you are '
                'tracking customers rather than family, the ordinary duty of '
                'care under the Data Privacy Act is yours, not ours. '
                'Salapify is a notebook.',
          ),
          const SizedBox(height: Spacing.sm),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Text(
              'Because nothing is in a cloud, a lost or wiped phone loses '
              'your Salapify records unless you exported a backup yourself. '
              'That is the cost of the rest of this page, and it is worth '
              'knowing before it matters.',
              style: AppType.body(palette),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.palette,
    required this.icon,
    required this.title,
    required this.body,
    this.accent = false,
  });

  final Palette palette;
  final IconData icon;
  final String title;
  final String body;

  /// The two lines somebody could be caught out by. Marked, not buried.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent ? palette.warningSoft : palette.iconTile,
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Icon(
              icon,
              size: 17,
              color: accent ? palette.textPrimary : palette.accent,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppType.rowTitle(palette)),
                const SizedBox(height: 2),
                Text(body, style: AppType.body(palette)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
