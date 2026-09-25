import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> _messages(String path) {
  final arb = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in arb.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

/// Extrait les paramètres ICU d'un message : les `{nom}` simples — y compris
/// ceux imbriqués dans une branche de pluriel/select — et le nom de variable
/// d'un `{nom, plural, ...}` / `{nom, select, ...}` / `{nom, selectordinal,
/// ...}`.
///
/// Exclusion structurelle (pas une heuristique sur la casse) : le texte
/// d'une branche (`=0{…}`, `zero{…}`, `one{…}`, `few{…}`, `many{…}`,
/// `other{…}`, ou un cas de `select`) n'est jamais un paramètre — seul son
/// contenu est réanalysé pour d'éventuels paramètres imbriqués. Avant cette
/// exclusion structurelle, une branche à un seul mot sans espace
/// (`=0{Rechercher}`) était prise pour un placeholder nommé "Rechercher".
Set<String> _placeholders(String message) {
  final result = <String>{};
  _scanIcuMessage(message, result);
  return result;
}

/// Repère chaque `{...}` de plus haut niveau dans [text] : son contenu est
/// soit `nom`, soit `nom, type, style`. Le nom est ajouté ; si le type est
/// `plural`, `select` ou `selectordinal`, le style est délégué à
/// [_scanIcuBranches] plutôt que traité comme un message ordinaire.
void _scanIcuMessage(String text, Set<String> result) {
  var i = 0;
  while (i < text.length) {
    if (text[i] != '{') {
      i++;
      continue;
    }
    final end = _matchingBrace(text, i);
    if (end == -1) break;
    final body = text.substring(i + 1, end);
    final commaIndex = body.indexOf(',');
    if (commaIndex == -1) {
      final name = body.trim();
      if (RegExp(r'^\w+$').hasMatch(name)) result.add(name);
    } else {
      final name = body.substring(0, commaIndex).trim();
      if (RegExp(r'^\w+$').hasMatch(name)) result.add(name);
      final rest = body.substring(commaIndex + 1);
      final typeMatch = RegExp(
        r'^\s*(plural|select|selectordinal)\s*,(.*)$',
        dotAll: true,
      ).firstMatch(rest);
      if (typeMatch != null) {
        _scanIcuBranches(typeMatch.group(2)!, result);
      } else {
        // Format number/date avec un skeleton : pas de branches à parcourir,
        // mais un skeleton ne contient normalement pas de paramètre imbriqué.
        _scanIcuMessage(rest, result);
      }
    }
    i = end + 1;
  }
}

/// Parcourt une suite de branches `selecteur{message}` (`=0{…}`, `zero{…}`,
/// `one{…}`, `few{…}`, `many{…}`, `other{…}`, ou un cas de `select`). Le
/// sélecteur lui-même n'est jamais un paramètre ; seul le contenu de chaque
/// `{message}` est réanalysé via [_scanIcuMessage] pour ses éventuels
/// paramètres imbriqués.
void _scanIcuBranches(String text, Set<String> result) {
  var i = 0;
  while (i < text.length) {
    if (text[i].trim().isEmpty) {
      i++;
      continue;
    }
    final braceIdx = text.indexOf('{', i);
    if (braceIdx == -1) break;
    final end = _matchingBrace(text, braceIdx);
    if (end == -1) break;
    _scanIcuMessage(text.substring(braceIdx + 1, end), result);
    i = end + 1;
  }
}

/// Index de la `}` qui referme la `{` à [openIndex], en tenant compte des
/// accolades imbriquées. `-1` si le message est malformé.
int _matchingBrace(String text, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < text.length; i++) {
    if (text[i] == '{') depth++;
    if (text[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Clés dont l'anglais est volontairement identique au français.
/// Toute nouvelle entrée doit être justifiée en commentaire.
const _sameInBothLanguages = <String>{
  'commonOk', // « OK » se dit pareil
  'authEmailStepLabel', // « Email » se dit pareil
  'authOnboardingDestinationsEyebrow', // « Destinations » se dit pareil
  // Noms propres identiques en français et en anglais.
  'countryNameFr',
  'countryNameLu',
  'countryNamePt',
  'countryNameCa',
  'countryNameBf',
  'countryNameCi',
  'countryNameMl',
  'countryNameNe',
  'countryNameTg',
  'countryNameCg',
  'countryNameGa',
  'countryZoneEurope',
  'shellTabMessages', // « Messages » se dit pareil
  'shellPlaceholderAdmin', // « Admin » se dit pareil
  'homeFilterChipsDate', // « Date » se dit pareil
  'homeFilterChipsUrgent', // « 🔥 Urgent » se dit pareil
  'homeFilterFieldsTransport', // « TRANSPORT » se dit pareil
  'homeFilterFieldsDate', // « DATE » se dit pareil
  'tripTransportTrain', // « Train » se dit pareil
  'tripTransportBus', // « Bus » se dit pareil
  'paymentMethodMobileMoney', // « Mobile money » se dit pareil
  'requestCreateDateFieldLabel', // « Date » se dit pareil
  'requestDetailMessageCta', // « Message » se dit pareil
  'requestDescriptionLabel', // « Description » se dit pareil
  'requestPublicBudget', // « Budget » se dit pareil
  'requestPublicZonesLabel', // « Zones » se dit pareil
  'requestSearchBudgetLine', // gabarit identique, seul {amount} varie
  'requestMatchingBudgetPerKg', // gabarit identique, seul {amount} varie
  'requestPreviewPhotos', // gabarit identique, seul le pluriel ICU varie
  'requestPreviewPhotosLabel', // « Photos » se dit pareil
  'requestCreateRecapTransport', // « Transport » se dit pareil
  'listingProBadge', // « PRO » se dit pareil
  'listingRowLabelNote', // « Note » se dit pareil
  'listingKiloProChip', // nom de fonctionnalité, identique en anglais
  'listingRowLabelDate', // « Date » se dit pareil
  'bidCreateMobileMoneySubtitle', // « Orange Money, Wave, MTN » : noms de marque
  'bidCreateTotalLabel', // « Total » se dit pareil
  'bidCreatePromoBadge', // « Promo » se dit pareil
  'negotiationRoundCounter', // « Round » déjà utilisé tel quel en français
  'negotiationMakeOfferMessageLabel', // « MESSAGE » se dit pareil
  'negotiationPriceBreakdownPromoBadge', // « Promo » se dit pareil
  'negotiationCounterOfferSubtitle', // gabarit identique, « Round » déjà utilisé tel quel en français
  'bidDetailFallbackDestination', // « destination » se dit pareil
  'bidDetailGainMobileMoneyPill', // « Mobile money » se dit pareil
  'bidDetailOptionsTitle', // « Options » se dit pareil (tâche D2)
  'bidDetailMobileMoneyBadge', // « MOBILE MONEY » se dit pareil (tâche D2)
  'bidDetailCashBadge', // « CASH » se dit pareil (tâche D2)
  'bidDetailDescriptionLabel', // « Description » se dit pareil (tâche D2, correction R40)
  'ticketMiniStatCategoryLabel', // « TYPE » se dit pareil (tâche D3)
  'shipmentDestinationFallback', // « destination » se dit pareil (tâche D3, clé dédiée : duplique bidDetailFallbackDestination d'un autre préfixe, R40)
  'tripOwnerSurplusKgValidatorMin', // « Minimum 1 kg » : chiffre + unité, se dit pareil (tâche D4)
  'tripOwnerArrivalFieldLabel', // « Instructions » se dit pareil (tâche D4)
  'activityRevenueMobileMoney', // « Mobile money » se dit pareil (tâche D5)
  'activityMenuButtonTooltip', // « Menu » se dit pareil (tâche D5)
  'bidCreateMaxWeightLabel', // « max » se dit pareil (vague finale D, I5/M12)
  'currencyNameEur', // « Euro » se dit pareil (tâche E1)
  'paymentSummaryTypeLabel', // « Type » se dit pareil (tâche E1)
  'walletTopupMethodCardSubtitle', // « Via Stripe · Visa, Mastercard » : noms de marques (tâche E3)
  'walletTopupMethodMobileMoneySubtitle', // « Orange Money, Wave, MTN MoMo » : noms de marques (tâche E3)
  'walletTopupBelowMinimum', // « Minimum » se dit pareil (tâche E3)
  'connectOnboardingBenefitTimeTitle', // « 5 minutes » se dit pareil (tâche E4)
  'walletActiveCurrencyBadge', // « active » se dit pareil (vague finale E, mineur 5)
  'chatPreviewPhoto', // « 📷 Photo » se dit pareil (tâche F1)
  'chatUnknownConversationLabel', // « Conversation » se dit pareil (tâche F1)
  'conversationListTitle', // « Messages » se dit pareil (tâche F1)
  'archivedConversationsTitle', // « Archives » se dit pareil (tâche F1)
  'trackingStepTransit', // « Transit » se dit pareil (tâche F2)
  'scanPhotoWordLabel', // « Photo » se dit pareil (tâche F2)
  'scanColisRowScanBadge', // « Scan » se dit pareil (tâche F2)
  'scanOfflineEventTransitLabel', // « transit » se dit pareil (tâche F2)
  'receptionConfirmTitle', // « Confirmation » se dit pareil (tâche F3)
  'receptionCodeOptionLabel', // « OPTION »/« CODE » se disent pareil (tâche F3)
  'profileFieldPhotoShort', // « Photo » se dit pareil (tâche G2)
  'profileFieldEmailShort', // « Email » se dit pareil (tâche G2)
  'profileChipEmailVerified', // « Email ✓ » se dit pareil (tâche G2)
  'profileMenuButtonTooltip', // « Menu » se dit pareil (tâche G2)
  'profileFooterVersion', // pied de page déjà en anglais dans le fr d'origine (tâche G2)
  'profileFieldEmailAllCaps', // « EMAIL » se dit pareil (tâche G2)
  'profileLanguageWolof', // « Wolof » se dit pareil (tâche G2)
  'profileLanguageBambara', // « Bambara » se dit pareil (tâche G2)
  'profilePublicBadgesSectionLabel', // « BADGES » se dit pareil (tâche G3)
  'settingsThemeAuto', // « Auto » se dit pareil (tâche H1)
  'settingsDestinationsLabel', // « Destinations » se dit pareil (tâche H1)
  'settingsNotificationsLabel', // « Notifications » se dit pareil (tâche H1)
  'diagnosticsTitle', // « Diagnostics » se dit pareil (tâche H1)
  'securitySectionApplication', // « APPLICATION » se dit pareil (tâche H1)
  'securitySectionSession', // « SESSION » se dit pareil (tâche H1)
  'diagnosticsSectionApplication', // « APPLICATION » se dit pareil (tâche H1)
  'diagnosticsVersionLabel', // « Version » se dit pareil (tâche H1)
  'diagnosticsSectionSupport', // « SUPPORT » se dit pareil (tâche H1)
  'a11yPreviewUrgentLabel', // « Urgent » se dit pareil (tâche H2)
  'notificationSettingsTitle', // « Notifications » se dit pareil (tâche H2)
  'notificationSettingsMessagesLabel', // « Messages » se dit pareil (tâche H2)
  'prefsContactModeMessage', // « Message » se dit pareil (tâche H2)
};

void main() {
  final fr = _messages('lib/l10n/app_fr.arb');
  final en = _messages('lib/l10n/app_en.arb');

  test('les deux fichiers ont exactement les mêmes clés', () {
    expect(en.keys.toSet(), fr.keys.toSet());
  });

  test('chaque traduction garde les mêmes paramètres', () {
    for (final key in fr.keys) {
      expect(_placeholders(en[key]!), _placeholders(fr[key]!), reason: key);
    }
  });

  test('aucun texte vide', () {
    for (final entry in [...fr.entries, ...en.entries]) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('aucun tiret cadratin', () {
    for (final entry in [...fr.entries, ...en.entries]) {
      expect(entry.value.contains('—'), isFalse, reason: entry.key);
    }
  });

  test('la marque affichée est Yadony, jamais Dony', () {
    final dony = RegExp(r'(?<![A-Za-z])Dony\b');
    for (final entry in [...fr.entries, ...en.entries]) {
      expect(dony.hasMatch(entry.value), isFalse, reason: entry.key);
    }
  });

  test("l'anglais est traduit (pas une copie du français)", () {
    for (final key in fr.keys) {
      if (_sameInBothLanguages.contains(key)) continue;
      expect(en[key], isNot(fr[key]), reason: key);
    }
  });

  group('_placeholders (extraction ICU)', () {
    test('pluriel : le texte des branches n\'est pas un paramètre', () {
      expect(
        _placeholders(
          '{count, plural, =0{aucun} =1{{count} colis} other{{count} colis}}',
        ),
        {'count'},
      );
    });

    test('placeholder simple imbriqué dans du texte', () {
      expect(_placeholders('Bonjour {name}'), {'name'});
    });

    test('select : seule sa variable est un paramètre, jamais ses cas', () {
      expect(
        _placeholders('{gender, select, male{He} female{She} other{They}}'),
        {'gender'},
      );
    });

    test('aucun placeholder dans un texte fixe', () {
      expect(_placeholders('Faire une demande'), isEmpty);
    });

    test('plusieurs paramètres distincts, y compris imbriqués', () {
      expect(
        _placeholders(
          '{first} et {rest, plural, =1{{rest} autre} other{{rest} autres}}',
        ),
        {'first', 'rest'},
      );
    });
  });
}
