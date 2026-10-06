import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/recipient_change_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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

  /// Visible tant que le colis n'est pas remis et que le lien de suivi existe,
  /// ou dès que le destinataire a refusé alors qu'il peut encore être changé :
  /// l'encart devient alors « Destinataire à remplacer ».
  static bool shouldShow(BidModel bid) =>
      (bid.trackingToken != null && _statuses.contains(bid.status)) ||
      _declinedActionable(bid);

  /// Destinataire en refus ou retiré (FLUTTER-E8) et colis encore modifiable.
  static bool _declinedActionable(BidModel bid) =>
      bid.isRecipientDeclinedForSender && bid.canChangeRecipient;

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
    final appStatus = bid.recipientAppStatus;

    // Le destinataire a refusé le colis ou s'en est retiré (FLUTTER-E8) :
    // renvoyer le lien et le code au même numéro n'aurait pas de sens. Le
    // bouton WhatsApp cède la place à « Désigner un autre destinataire ».
    if (appStatus == 'DECLINED') {
      return _DeclinedRecipientCard(bid: bid);
    }

    return DetailCard(
      title: l.recipientNotifyTitle(name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (appStatus == 'CONFIRMED') ...[
            _RecipientAppNotice(
              key: const Key('recipient-app-confirmed'),
              iconAsset: 'badge-check',
              color: cs.success,
              text: (rawName == null || rawName.isEmpty)
                  ? l.recipientAppConfirmedAnonymous
                  : l.recipientAppConfirmed(rawName),
            ),
            const SizedBox(height: DonySpacing.md),
          ],
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

/// Encart « Destinataire à remplacer » (vue expéditeur) : le destinataire a
/// refusé le colis ou s'en est retiré (`recipientAppStatus == DECLINED`). Le
/// bandeau orange reste neutre (« Ce destinataire a refusé le colis. »), dit
/// si le voyageur demande un autre destinataire
/// (`recipientReplacementRequestedAt`), et l'action principale ouvre la
/// feuille « Modifier le destinataire », comme le bouton « Modifier » de la
/// carte « Colis & destinataire ».
class _DeclinedRecipientCard extends StatelessWidget {
  const _DeclinedRecipientCard({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final requested = bid.recipientReplacementRequestedAt != null;

    return DetailCard(
      key: const Key('recipient-declined-sender'),
      title: l.recipientDeclinedSenderTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecipientAppNotice(
            key: const Key('recipient-app-declined'),
            iconAsset: 'triangle-alert',
            color: cs.warning,
            text: l.recipientAppDeclined,
            detail: requested ? l.recipientReplacementRequestedSender : null,
            detailKey: const Key('recipient-replacement-requested'),
          ),
          if (bid.canChangeRecipient) ...[
            const SizedBox(height: DonySpacing.md),
            Text(
              l.recipientDeclinedSenderBody,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('recipient-declined-change'),
              label: l.recipientDeclinedSenderButton,
              iconAsset: 'user-plus',
              onPressed: () => openRecipientChangeSheet(context, bid),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne d'état du destinataire dans Yadony (lot 2) : il suit le colis
/// (`CONFIRMED`), ou il a refusé le colis ou s'en est retiré (`DECLINED`,
/// [_DeclinedRecipientCard], avec la demande du voyageur en [detail]).
class _RecipientAppNotice extends StatelessWidget {
  const _RecipientAppNotice({
    super.key,
    required this.iconAsset,
    required this.color,
    required this.text,
    this.detail,
    this.detailKey,
  });

  final String iconAsset;
  final Color color;
  final String text;

  /// Seconde ligne, plus discrète (demande du voyageur).
  final String? detail;
  final Key? detailKey;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon(iconAsset, size: 18, color: color),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    key: detailKey,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
