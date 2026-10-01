import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/core/utils/phone_dialer.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Canal par lequel le voyageur joint le destinataire d'un colis.
enum RecipientContactChannel { whatsapp, sms, call }

/// Premier mot d'un nom affiché (« Awa D. » → « Awa »), `null` si vide.
String? _firstName(String? name) {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed.split(RegExp(r'\s+')).first;
}

/// Message pré-rempli que le voyageur envoie au destinataire de [bid].
///
/// - colis arrivé (`ARRIVED`) : arrivée en ville, instructions de retrait
///   (quand il y en a) et rappel du code de retrait à 6 chiffres ;
/// - colis en route (`HANDED_OVER`, `IN_TRANSIT`) : en route, « je vous
///   recontacte à mon arrivée » ;
/// - autres statuts : simple présentation du voyageur.
///
/// [instructions] prime sur celles copiées dans le bid à l'acceptation :
/// l'écran trajet connaît la version à jour. Le voyageur peut toujours
/// retoucher le texte dans WhatsApp ou la messagerie avant l'envoi.
String travelerRecipientMessage(
  AppLocalizations l,
  BidModel bid, {
  String? instructions,
}) {
  final recipient = bid.recipientName?.trim();
  final greeting = (recipient == null || recipient.isEmpty)
      ? l.recipientNotifyGreetingAnonymous
      : l.recipientNotifyGreeting(recipient);
  final traveler = _firstName(bid.travelerName);
  final intro = traveler == null
      ? l.travelerContactIntroAnonymous
      : l.travelerContactIntro(traveler);
  final head = '$greeting $intro';

  final sender = _firstName(bid.senderName);
  final parcel = sender == null
      ? l.travelerContactParcel
      : l.travelerContactParcelFrom(sender);
  final rawCity = bid.arrivalCity?.trim();
  final city = (rawCity == null || rawCity.isEmpty)
      ? l.travelerContactCityFallback
      : rawCity;

  switch (bid.status) {
    case 'ARRIVED':
      final parts = <String>[head, l.travelerContactArrived(parcel, city)];
      final pickup = _cleanInstructions(
        instructions ?? bid.arrivalInstructions,
      );
      if (pickup != null) {
        parts.add(l.travelerContactPickup(pickup));
      }
      parts.add(l.travelerContactCodeReminder);
      return parts.join(' ');
    case 'HANDED_OVER':
    case 'IN_TRANSIT':
      return '$head ${l.travelerContactOnTheWay(parcel, city)}';
    default:
      return head;
  }
}

/// Instructions sans le point final (la phrase « Retrait : … . » le remet),
/// `null` si vides.
String? _cleanInstructions(String? raw) {
  var text = raw?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  while (text!.endsWith('.')) {
    text = text.substring(0, text.length - 1).trimRight();
  }
  return text.isEmpty ? null : text;
}

/// Contacte le destinataire de [bid] par [channel].
///
/// WhatsApp et SMS ouvrent l'application avec le message pré-rempli
/// ([travelerRecipientMessage]) ; si elle ne s'ouvre pas (numéro sans
/// indicatif pour WhatsApp, appli absente), le message est copié et un
/// snackbar invite à le coller. L'appel passe par [dialPhoneNumber], qui a
/// son propre repli.
///
/// Trace `recipient_contacted` à l'intention : canal, statut du colis et
/// présence du destinataire dans Yadony, jamais son nom ni son numéro.
Future<void> contactRecipient(
  BuildContext context,
  BidModel bid,
  RecipientContactChannel channel, {
  String? instructions,
  ContactLinkLauncher? launcher,
  TargetPlatform? platform,
}) async {
  unawaited(
    getItSafe<AnalyticsService>()?.logEvent(
      AnalyticsEvents.recipientContacted,
      properties: {
        'channel': channel.name,
        'status': bid.status,
        'in_app': bid.recipientAppStatus == 'CONFIRMED',
      },
    ),
  );

  final phone = bid.recipientPhone;
  if (channel == RecipientContactChannel.call) {
    await dialPhoneNumber(context, phone);
    return;
  }

  final l = context.l10n;
  final text = travelerRecipientMessage(l, bid, instructions: instructions);
  final uri = channel == RecipientContactChannel.whatsapp
      ? whatsAppChatUri(phone, text)
      : smsUri(phone, text, platform: platform);
  final opener = launcher ?? ContactLinkLauncher();
  final opened = uri != null && await opener.open(uri);
  if (opened) {
    return;
  }

  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  DonySnackbar.show(context, message: l.travelerContactMessageCopied);
}

/// Trois boutons WhatsApp / SMS / Appeler vers le destinataire de [bid].
///
/// Partagé par la feuille « Prévenir les destinataires » (écran trajet) et
/// la vue voyageur d'un envoi.
class RecipientContactActions extends StatelessWidget {
  const RecipientContactActions({
    super.key,
    required this.bid,
    this.instructions,
    this.launcher,
  });

  final BidModel bid;

  /// Instructions de retrait à jour (écran trajet), sinon celles du bid.
  final String? instructions;

  /// Injecté en test ; sinon le lanceur de la plateforme.
  final ContactLinkLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget button(RecipientContactChannel channel, String icon, String label) =>
        Expanded(
          child: _ContactButton(
            key: Key('recipient-contact-${channel.name}-${bid.id}'),
            iconAsset: icon,
            label: label,
            onTap: () => contactRecipient(
              context,
              bid,
              channel,
              instructions: instructions,
              launcher: launcher,
            ),
          ),
        );

    return Row(
      children: [
        button(
          RecipientContactChannel.whatsapp,
          'message-circle',
          l.travelerContactWhatsApp,
        ),
        const SizedBox(width: DonySpacing.sm),
        button(
          RecipientContactChannel.sms,
          'messages-square',
          l.travelerContactSms,
        ),
        const SizedBox(width: DonySpacing.sm),
        button(RecipientContactChannel.call, 'phone', l.travelerContactCall),
      ],
    );
  }
}

/// Bouton compact (icône + libellé) d'une rangée d'actions de contact.
class _ContactButton extends StatelessWidget {
  const _ContactButton({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.xs,
                vertical: DonySpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DonyIcon(iconAsset, size: 16, color: cs.primary),
                  const SizedBox(width: DonySpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte « Contacter le destinataire » de la vue voyageur d'un envoi, posée
/// sous la carte « Colis & destinataire ».
class TravelerRecipientContactCard extends StatelessWidget {
  const TravelerRecipientContactCard({
    super.key,
    required this.bid,
    this.launcher,
  });

  final BidModel bid;

  /// Injecté en test ; sinon le lanceur de la plateforme.
  final ContactLinkLauncher? launcher;

  /// Visible une fois la demande acceptée ([bidAllowsContact]) et le numéro
  /// du destinataire connu.
  static bool shouldShow(BidModel bid) =>
      bidAllowsContact(bid.status) &&
      (bid.recipientPhone?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: context.l10n.travelerContactCardTitle,
      child: RecipientContactActions(bid: bid, launcher: launcher),
    );
  }
}
