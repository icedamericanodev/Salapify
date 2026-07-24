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
            _kicker('EVERY CONNECTION THIS APP CAN MAKE'),
            const SizedBox(height: 8),
            _connectionCard(
              Icons.currency_exchange,
              'Live exchange rates',
              'Only when you use the currency converter, the app asks a public '
                  'rate service for the day\'s rates. The request carries one '
                  'thing: a currency code, like PHP or USD. Never an amount, '
                  'never a name, never your data.',
            ),
            const SizedBox(height: 10),
            _connectionCard(
              Icons.system_update_alt,
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
            _kicker('EVERY PERMISSION, AND WHY'),
            const SizedBox(height: 8),
            _permissionsCard(),
            const SizedBox(height: 20),
            _kicker('RECENT RATE FETCHES'),
            const SizedBox(height: 8),
            _fetchLogCard(),
            const SizedBox(height: 20),
            _challengeCard(),
          ],
        ),
      ),
    );
  }

  Widget _kicker(String text) => Text(
    text,
    style: TextStyle(
      color: Barako.muted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    ),
  );

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
                  Icons.verified_user_outlined,
                  color: Barako.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your money data lives on this phone',
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
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
              style: TextStyle(color: Barako.muted, fontSize: 13, height: 1.45),
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
                  Text(
                    title,
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: Barako.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
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
            Icon(Icons.check_circle_outline, color: Barako.celebrate, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'That is the whole list. Two connections, neither carrying '
                'your money data. There is no third.',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
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
              Text(
                title,
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  color: Barako.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
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
              Icons.wifi,
              'Internet',
              'Exists only for the two connections above: rate lookups and '
                  'app code updates.',
            ),
            const Divider(height: 22),
            row(
              Icons.fingerprint,
              'Fingerprint or face',
              'Powers App lock. Your phone does the checking and only tells '
                  'the app yes or no; the app never sees or stores your '
                  'biometrics.',
            ),
            const Divider(height: 22),
            row(
              Icons.notifications_none,
              'Notifications',
              'Your reminders (log nudge, payday, bills, utang) are built and '
                  'shown on the phone itself. Nothing is sent to a server to '
                  'send them back to you.',
            ),
            const Divider(height: 22),
            row(
              Icons.restart_alt,
              'Run after restart',
              'Lets your scheduled reminders survive a phone reboot. That is '
                  'all it does.',
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
                style: TextStyle(
                  color: Barako.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The most recent times this app asked for exchange rates, '
                  'newest first. Each request carried only the currency code '
                  'shown.',
                  style: TextStyle(
                    color: Barako.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                for (final e in entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          e['ok'] == true
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
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
                            style: TextStyle(color: Barako.text, fontSize: 12),
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
                Icon(
                  Icons.airplanemode_active,
                  color: Barako.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Do not take our word for it',
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
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
              style: TextStyle(color: Barako.muted, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
