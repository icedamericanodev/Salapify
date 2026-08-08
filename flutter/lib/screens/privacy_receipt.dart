// The Privacy receipt: the trust surface, in plain words, with proof. Cloud
// money apps make privacy promises; this screen shows a checkable fact. It
// lists every connection this app can ever make (there are two), every Android
// permission and why it exists, and a real log of the app's own rate fetches,
// then invites the user to verify it all with airplane mode.
//
// Standing rule: any future dependency that talks to the network must be added
// to this receipt, or it does not ship.

import 'package:flutter/material.dart';

import '../data/fx_service.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/section.dart';
import '../widgets/salapify_icon.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A fetch timestamp as 'Jul 24 2026, 9:14 AM' in local time. The year stays
/// in on purpose: a light converter user's ten entries can span years, and a
/// trust surface must never let last July read as this July. parseFxLog has
/// already range-checked the value, so this cannot throw on stored junk.
String fxLogWhen(int atMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(atMs);
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final min = d.minute.toString().padLeft(2, '0');
  final ap = d.hour < 12 ? 'AM' : 'PM';
  return '${_months[d.month - 1]} ${d.day} ${d.year}, $h12:$min $ap';
}

class PrivacyReceiptScreen extends StatefulWidget {
  /// Injectable for tests; the real screen reads the live log.
  final FxService fx;
  PrivacyReceiptScreen({super.key, FxService? fx}) : fx = fx ?? FxService();

  @override
  State<PrivacyReceiptScreen> createState() => _PrivacyReceiptScreenState();
}

class _PrivacyReceiptScreenState extends State<PrivacyReceiptScreen> {
  // Read once when the screen opens; a theme flip or any other rebuild must
  // not re-read prefs and flicker the log card back to its loading state.
  late final Future<List<Map<String, dynamic>>> _log;

  @override
  void initState() {
    super.initState();
    _log = widget.fx.fetchLog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Privacy receipt',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _promiseCard(),
            const SizedBox(height: 20),
            Kicker('EVERY CONNECTION THIS APP CAN MAKE'),
            const SizedBox(height: 8),
            _connectionCard(
              salapifyIcon('exchange'),
              'Live exchange rates',
              'Only when you use the currency converter, the app asks a public '
                  'rate service for the day\'s rates. The request carries one '
                  'thing: a currency code, like PHP or USD. Never an amount, '
                  'never a name, never your data.',
            ),
            const SizedBox(height: 10),
            _connectionCard(
              salapifyIcon('install'),
              'App updates',
              'On launch, and when you tap Check for updates in the Menu, '
                  'the app checks for an updated version of its own code so '
                  'fixes reach you without a store download. The check is '
                  'about the app, not about you; your money data is not part '
                  'of it.',
            ),
            const SizedBox(height: 10),
            _wholeListCard(),
            const SizedBox(height: 20),
            Kicker('EVERY PERMISSION, AND WHY'),
            const SizedBox(height: 8),
            _permissionsCard(),
            const SizedBox(height: 20),
            Kicker('IF YOUR PHONE IS LOST OR SHARED'),
            const SizedBox(height: 8),
            _protectionsCard(),
            const SizedBox(height: 20),
            Kicker('RECENT RATE FETCHES'),
            const SizedBox(height: 8),
            _fetchLogCard(),
            const SizedBox(height: 20),
            _challengeCard(),
          ],
        ),
      ),
    );
  }

  Widget _promiseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  salapifyIcon('protected'),
                  color: Barako.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your money data lives on this phone',
                    style: AppText.bodyLg.w8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'No account, no cloud, no analytics, no trackers, no ads. '
              'Everything you enter is stored on your phone and nowhere else. '
              'A backup or export leaves only when you save or share it '
              'yourself. Most apps ask you to trust their privacy policy. '
              'This page is different: it is the complete list of what this '
              'app can do on the internet, and you can check it.',
              style: AppText.small.tint(Barako.muted).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionCard(IconData icon, String title, String body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Barako.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.bodyStrong),
                  const SizedBox(height: 4),
                  Text(body, style: AppText.caption.copyWith(height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wholeListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(salapifyIcon('done'), color: Barako.celebrate, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'That is the whole list. Two connections, neither carrying '
                'your money data. There is no third.',
                style: AppText.small.w6.tint(Barako.text).copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionsCard() {
    Widget row(IconData icon, String title, String body) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Barako.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.label.w7),
              const SizedBox(height: 2),
              Text(body, style: AppText.caption.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(
              salapifyIcon('network'),
              'Internet',
              'Exists only for the two connections above: rate lookups and '
                  'app code updates.',
            ),
            const Divider(height: 22),
            row(
              salapifyIcon('biometric'),
              'Fingerprint or face',
              'Powers App lock. Your phone does the checking and only tells '
                  'the app yes or no; the app never sees or stores your '
                  'biometrics.',
            ),
            const Divider(height: 22),
            row(
              salapifyIcon('notifications'),
              'Notifications',
              'Your reminders (log nudge, payday, bills, IOUs) are built and '
                  'shown on the phone itself. Nothing is sent to a server to '
                  'send them back to you.',
            ),
            const Divider(height: 22),
            row(
              salapifyIcon('startOver'),
              'Run after restart',
              'Lets your scheduled reminders survive a phone reboot. That is '
                  'all it does.',
            ),
            const Divider(height: 22),
            row(
              salapifyIcon('vibration'),
              'Vibrate',
              'The small buzz when a button is pressed or a reminder arrives. '
                  'It reads nothing.',
            ),
            const Divider(height: 22),
            // The four below arrive with the home screen widget's plumbing.
            // A launch audit found this screen listed four permissions while
            // the app actually shipped six, and this release adds three more.
            // The card above it promises "the complete list of what this app
            // can do", so a list that is short by five is not a small
            // omission, it is the one claim on the screen being false.
            row(
              salapifyIcon('widgets'),
              'Keep the phone awake briefly, and check if there is a network',
              'Both come with the home screen widget plumbing. Salapify uses '
                  'neither to move your money data anywhere. They are the '
                  'ordinary background machinery Android widgets are built '
                  'on, and neither can be seen or refused in your phone '
                  'settings because Android treats them as harmless.',
            ),
            const Divider(height: 22),
            row(
              salapifyIcon('play'),
              'Run a short task in the foreground',
              'Also widget plumbing, and also unused by Salapify. Listed '
                  'because this card claims to be the complete list, and a '
                  'complete list has to include the boring ones.',
            ),
          ],
        ),
      ),
    );
  }

  // On-device protections, not network claims: what keeps your data safe on the
  // phone itself. Every line here is a behavior the app actually ships and a
  // test guards, so this card can be checked the same way the connection list
  // can. Backups: allowBackup=false plus the two backup-rules XML resources
  // exclude every domain from Android cloud backup AND device-to-device
  // transfer (backup_posture_test.dart). Secure screen: FLAG_SECURE is set when
  // App lock is on (secure_window.dart, MainActivity.kt). Generic reminders:
  // names and amounts are kept off the lock screen unless detailed reminders
  // are opted in (notification_visibility_test.dart).
  Widget _protectionsCard() {
    Widget row(IconData icon, String title, String body) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Barako.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.label.w7),
              const SizedBox(height: 2),
              Text(body, style: AppText.caption.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(
              salapifyIcon('offline'),
              'Automatic backup is off',
              'Android can copy an app\'s data to Google Drive, and to a new '
                  'phone during setup. Both are turned off for Salapify, so '
                  'your ledger is never uploaded or transferred behind your '
                  'back. A backup exists only when you make one yourself.',
            ),
            const Divider(height: 22),
            row(
              salapifyIcon('screen'),
              'The screen hides when App lock is on',
              'With App lock on, the app marks its screens secure, so your '
                  'balances do not show in the app switcher preview and cannot '
                  'be screenshotted while the app is locked.',
            ),
            const Divider(height: 22),
            row(
              salapifyIcon('notificationsOff'),
              'Lock-screen reminders stay generic',
              'A reminder on your lock screen says only that something is due, '
                  'never the amount or the name. Turning on detailed reminders '
                  'in the Menu adds those, but only in the notification shade '
                  'after you unlock, never on the lock screen itself.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _fetchLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _log,
          builder: (context, snap) {
            final entries = snap.data ?? const <Map<String, dynamic>>[];
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 20);
            }
            if (entries.isEmpty) {
              return Text(
                'No rate fetches yet. The app has not reached out for rates '
                'on this phone; the log will fill in only when you use the '
                'currency converter with live rates.',
                style: AppText.caption.copyWith(height: 1.4),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The most recent times this app asked for exchange rates, '
                  'newest first. Each request carried only the currency code '
                  'shown.',
                  style: AppText.caption.copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
                for (final e in entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          e['ok'] == true
                              ? salapifyIcon('backedUp')
                              : salapifyIcon('offline'),
                          size: 16,
                          color: e['ok'] == true
                              ? Barako.celebrate
                              : Barako.faint,
                          semanticLabel: e['ok'] == true
                              ? 'Fetched'
                              : 'No connection',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${fxLogWhen(e['at'] as int)} '
                            '${(e['base'] as String).isEmpty ? '' : 'rates for ${e['base']}'}'
                            '${e['ok'] == true ? '' : ', no connection'}',
                            style: AppText.caption.tint(Barako.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _challengeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(salapifyIcon('travel'), color: Barako.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Do not take our word for it',
                    style: AppText.body.w8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Turn on airplane mode and use the whole app. Log, budget, '
              'split a bill, check your reports, ask Pan. Everything works, '
              'because everything is already on your phone. An app that '
              'needs the cloud cannot pass that test.',
              style: AppText.small.tint(Barako.muted).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
