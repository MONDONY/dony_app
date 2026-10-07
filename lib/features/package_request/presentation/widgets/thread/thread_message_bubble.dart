import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Bulle d'un message du thread de négociation.
///
/// Match maquettes v3 `20-44-27`, `20-44-40`, `20-44-48` :
/// - `mine = true`  → fond primary blue solide, texte blanc, coin BR cassé
/// - `mine = false` → fond surface (card avec border outline), texte sombre,
///   coin BL cassé. Si `kind == proposal` venant de l'autre partie avec un
///   prix : badge "NOUVEAU" overlay top-right (rendu côté écran via flag).
///
/// Affiche : label CAPS (PROPOSITION / CONTRE-OFFRE / ACCEPTÉ / REJETÉ) +
/// prix prominent + body optionnel italique + timestamp HH:mm.
class ThreadMessageBubble extends StatelessWidget {
  const ThreadMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.highlight = false,
    required this.isTraveler,
    this.currency = 'EUR',
  });

  final NegotiationMessage message;
  final bool mine;

  /// Affiche un cadre coloré "NOUVEAU" autour de la bulle (cas dernière
  /// proposition reçue côté sender quand pas encore lue).
  final bool highlight;

  /// Whether the current viewer is the traveler.
  /// - Traveler sees "Tu reçois X €" (net)
  /// - Sender sees "Tu paies X €" (gross)
  ///
  /// Le brut se dérive toujours du prix DU MESSAGE
  /// ([NegotiationMessage.proposedPriceEur]) via [PriceDisplay.grossFromNet],
  /// même calcul que le serveur (net × taux global). La bulle recevait
  /// auparavant le brut du prix courant du fil : côté expéditeur, toutes les
  /// bulles affichaient alors le montant de la dernière offre.
  final bool isTraveler;

  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonyNegoBubble(
      kindLabel: _kindLabel(l, message.kind),
      mine: mine,
      highlight: highlight,
      priceText: message.proposedPriceEur == null
          ? null
          : threadPriceLabel(
              l,
              message.proposedPriceEur!,
              null,
              isTraveler,
              currency,
            ),
      body: message.body,
      sentAt: message.createdAt,
    );
  }

  String _kindLabel(AppLocalizations l, NegotiationMessageKind k) =>
      switch (k) {
        NegotiationMessageKind.proposal =>
          l.negotiationMessageKindProposalBadge,
        NegotiationMessageKind.counter => l.negotiationMessageKindCounterBadge,
        // Même texte tout capitales que la pastille de statut « ACCEPTÉE »
        // du hero card et de `_StatusPill` : une seule clé pour les trois.
        NegotiationMessageKind.accept => l.negotiationStatusBadgeAccepted,
        NegotiationMessageKind.reject => l.negotiationMessageKindRejectedBadge,
      };
}
