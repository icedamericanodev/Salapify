// Card skins: a cosmetic finish a user can put on an account's card.
//
// A "skin" is nothing more exotic than a seed COLOUR. Every bank card in the
// app already builds its gradient from a seed through bankCardGradient (see
// widgets/bank_card.dart), which darkens the seed until opaque white text clears
// WCAG AA on both gradient stops. So a skin overrides which seed feeds that same
// path, and inherits the exact same contrast guarantee for free: there is no new
// colour maths here and no way for a skin to make the card's text unreadable.
// The names (Obsidian, Emerald, Gold, Platinum) are the metal each seed reads as
// AFTER that AA darkening, not a bright fill that would fail white text.
//
// WHERE THE CHOICE LIVES, and where it does NOT. The chosen skin is a per device
// visual preference, so it is stored in SharedPreferences keyed by account id,
// NOT in the Salapify backup blob. That is deliberate: the backup is the money
// record, parity locked to the RN engine by goldens, and a decorative card
// finish has no business changing its shape or its key set. The cost is honest
// and small: a skin does not travel when a backup is restored onto a new phone,
// exactly like the app lock latch and the live FX rates, which are local for the
// same reason. Nothing about a skin is money, so nothing about it is backed up.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One selectable finish. [seed] feeds bankCardGradient exactly like a bank's
/// brand colour, so the card stays AA safe by construction.
@immutable
class CardSkin {
  final String id;
  final String label;

  /// A one line description for the picker, plain English.
  final String blurb;

  /// The gradient seed. Chosen so that, after bankCardGradient's AA darkening,
  /// the card still reads as the metal it is named for.
  final Color seed;

  const CardSkin({
    required this.id,
    required this.label,
    required this.blurb,
    required this.seed,
  });
}

/// The registry. A typed list, iterated by the picker and asserted whole by the
/// skins test, so adding a fifth finish is one entry and the test proves the app
/// still sees all of them (the palette registry uses the same shape).
const List<CardSkin> cardSkins = [
  CardSkin(
    id: 'obsidian',
    label: 'Obsidian',
    blurb: 'A deep graphite black.',
    seed: Color(0xFF2B2F36),
  ),
  CardSkin(
    id: 'emerald',
    label: 'Emerald',
    blurb: 'A rich green.',
    seed: Color(0xFF0E7C5A),
  ),
  CardSkin(
    id: 'gold',
    label: 'Gold',
    blurb: 'A warm bronze gold.',
    seed: Color(0xFFB8891F),
  ),
  CardSkin(
    id: 'platinum',
    label: 'Platinum',
    blurb: 'A cool silver slate.',
    seed: Color(0xFF6B7480),
  ),
];

/// The skin with this id, or null. Null means "no skin", which the card renders
/// as its normal brand colour, so an unknown or cleared id is always safe.
CardSkin? skinById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final s in cardSkins) {
    if (s.id == id) return s;
  }
  return null;
}

/// The per account skin choices, held in memory and mirrored to
/// SharedPreferences. A ChangeNotifier so a card can repaint the instant a skin
/// is picked. This is NOT part of the backup (see the file header).
class CardSkinStore extends ChangeNotifier {
  CardSkinStore();

  /// The app wide instance the screens read. Tests build their own with mock
  /// preferences instead of touching this one.
  static final CardSkinStore instance = CardSkinStore();

  static const String _prefsKey = 'card_skins_v1';

  Map<String, String> _byAccount = {};

  /// Load saved choices. Safe to call more than once; a bad or missing store
  /// simply leaves every card on its brand colour. Never throws.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _byAccount = {
            for (final e in decoded.entries)
              // Drop any value that is not a skin we still ship, so a renamed or
              // removed finish can never strand a card on an id nothing draws.
              if (e.value is String && skinById(e.value as String) != null)
                '${e.key}': e.value as String,
          };
        }
      }
    } catch (_) {
      // Cosmetic preference: a corrupt store is not worth surfacing. Leave the
      // cards on their brand colours and carry on.
      _byAccount = {};
    }
    notifyListeners();
  }

  /// The chosen skin id for an account, or null if none.
  String? skinIdFor(String accountId) => _byAccount[accountId];

  /// The chosen skin for an account, or null.
  CardSkin? skinFor(String accountId) => skinById(_byAccount[accountId]);

  /// The gradient seed to feed the card, or null to keep its brand colour.
  Color? seedFor(String accountId) => skinFor(accountId)?.seed;

  /// Set (or, with a null or unknown id, clear) the skin for one account and
  /// persist it. Notifies listeners immediately so the card repaints before the
  /// write completes; the write itself is fire and forget safe.
  Future<void> setSkin(String accountId, String? skinId) async {
    final resolved = skinById(skinId);
    if (resolved == null) {
      if (_byAccount.remove(accountId) == null) return;
    } else {
      if (_byAccount[accountId] == resolved.id) return;
      _byAccount[accountId] = resolved.id;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_byAccount.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, jsonEncode(_byAccount));
      }
    } catch (_) {
      // The in memory choice already applied; a failed write just means it does
      // not survive a restart, which for a cosmetic preference is acceptable.
    }
  }
}
