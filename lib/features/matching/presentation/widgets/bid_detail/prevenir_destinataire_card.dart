import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Lien `wa.me` qui ouvre la conversation WhatsApp avec [phone], message
/// [text] pré-rempli.
///
/// Rend `null` quand le numéro n'est pas au format international (`+…` ou
/// `00…`) : sans indicatif pays, `wa.me` ouvrirait la conversation d'un
/// inconnu, voire d'un numéro d'un autre pays.
Uri? whatsAppChatUri(String? phone, String text) {
  if (phone == null) {
    return null;
  }
  final trimmed = phone.trim();
  if (!trimmed.startsWith('+') && !trimmed.startsWith('00')) {
    return null;
  }
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.length < 8) {
    return null;
  }
  return Uri.https('wa.me', '/$digits', {'text': text});
}

/// Message que l'expéditeur envoie au destinataire : lien de suivi, code de
/// retrait quand il existe ([withCode]), invitation à installer Yadony.
String recipientNotifyMessage(
  AppLocalizations l,
  BidModel bid, {
  required bool withCode,
}) {
  final name = bid.recipientName?.trim();
  final greeting = (name == null || name.isEmpty)
      ? l.recipientNotifyGreetingAnonymous
      : l.recipientNotifyGreeting(name);
  final from = bid.departureCity;
  final to = bid.arrivalCity;
  final route = (from != null && to != null)
      ? l.recipientNotifyRoute(from, to)
      : '';
  final url = trackingPublicUrl(bid.trackingToken!);
  final body = withCode
      ? l.recipientNotifyMessageCode(route, bid.confirmationCode!, url)
      : l.recipientNotifyMessageLink(route, url);
  return '$greeting $body\n\n${l.recipientNotifyMessageInvite}';
}

/// Signature du repli de partage, injectable pour les tests.
typedef RecipientShareFallback =
    Future<void> Function(String text, Rect? sharePositionOrigin);

/// Encart « Prévenir le destinataire » (vue expéditeur).
///
/// Le destinataire ne reçoit rien de Yadony : aucun SMS (trop cher vers
/// l'Afrique), et il n'a pas forcément l'app. C'est donc l'expéditeur qui le
/// prévient, depuis son propre WhatsApp, avec un message déjà rédigé.
///
/// Deux temps, sur la même carte :
/// - demande acceptée : lien de suivi public + invitation à installer l'app ;
/// - code de retrait généré (scan DEPART) : le code s'ajoute au message, pour
///   que le destinataire l'ait en main à la remise.
///
/// Sans numéro international ou si WhatsApp ne s'ouvre pas, on retombe sur la
/// feuille de partage du système avec le même texte.
class PrevenirDestinataireCard extends StatelessWidget {
  const PrevenirDestinataireCard({
    super.key,
    required this.bid,
    this.launcher,
    this.shareFallback,
  });

  final BidModel bid;

  /// Injecté en test ; sinon l'instance du conteneur.
  final ExternalUrlLauncher? launcher;

  /// Injecté en test ; sinon `Share.share`.
  final RecipientShareFallback? shareFallback;

  static const _statuses = <String>{
    'ACCEPTED',
    'HANDED_OVER',
    'IN_TRANSIT',
    'ARRIVED',
  };

  static const _codeStatuses = <String>{'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED'};

  /// Visible tant que le colis n'est pas remis et que le lien de suivi existe.
  static bool shouldShow(BidModel bid) =>
      bid.trackingToken != null && _statuses.contains(bid.status);

  /// Le code ne part qu'une fois le colis confié au voyageur.
  static bool withCode(BidModel bid) =>
      bid.confirmationCode != null && _codeStatuses.contains(bid.status);

  Future<void> _notify(BuildContext context) async {
    final l = context.l10n;
    final hasCode = withCode(bid);
    final text = recipientNotifyMessage(l, bid, withCode: hasCode);
    final origin = sharePositionOriginFor(context);

    final uri = whatsAppChatUri(bid.recipientPhone, text);
    final opener =
        launcher ?? getItSafe<ExternalUrlLauncher>() ?? ExternalUrlLauncher();
    final opened = uri != null && await opener.open(uri);

    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.recipientNotified,
        properties: {
          'with_code': hasCode,
          'channel': opened ? 'whatsapp' : 'share',
          'status': bid.status,
        },
      ),
    );

    if (opened) {
      return;
    }
    final share =
        shareFallback ??
        (String t, Rect? o) => Share.share(t, sharePositionOrigin: o);
    await share(text, origin);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rawName = bid.recipientName?.trim();
    final name = (rawName == null || rawName.isEmpty)
        ? l.recipientNotifyFallbackName
        : rawName;
    final hasCode = withCode(bid);

    return DetailCard(
      title: l.recipientNotifyTitle(name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasCode
                ? l.recipientNotifyBodyCode(name)
                : l.recipientNotifyBodyLink(name),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: hasCode
                ? l.recipientNotifyButtonCode
                : l.recipientNotifyButtonLink,
            iconAsset: 'message-circle',
            variant: DonyButtonVariant.secondary,
            onPressed: () => _notify(context),
          ),
        ],
      ),
    );
  }
}
