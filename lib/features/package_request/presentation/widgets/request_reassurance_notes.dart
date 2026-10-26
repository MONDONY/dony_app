import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Une ou deux lignes de réassurance sous le bouton fixe de la fiche d'une
/// demande, pour le voyageur qui hésite à faire une offre.
///
/// - « Paiement sécurisé : versé après la livraison » seulement quand le colis
///   ne peut pas se régler en espèces : l'argent passe alors par Yadony, qui ne
///   le verse qu'à la livraison confirmée. Avec l'espèce, l'argent change de
///   main hors de l'app : la phrase serait fausse.
/// - « Vous proposez votre prix, l'expéditeur répond » pour une demande
///   négociable.
///
/// Aucun montant, brut ou net : la fiche n'affiche jamais les deux côte à côte
/// (ils révéleraient la commission par soustraction, FLUTTER-56).
class RequestReassuranceNotes extends StatelessWidget {
  const RequestReassuranceNotes({required this.request, super.key});

  final PackageRequest request;

  /// Paiement hors espèces uniquement. Aucun moyen connu (ancienne donnée) :
  /// on ne promet rien.
  static bool securedPayment(PackageRequest request) =>
      request.acceptedPaymentMethods.isNotEmpty &&
      !request.acceptedPaymentMethods.contains(PaymentMethod.cash);

  /// Nombre de lignes affichées, pour réserver la place sous le contenu défilant
  /// (la barre du bas grandit d'autant).
  static int lineCount(PackageRequest request) =>
      (securedPayment(request) ? 1 : 0) + (request.negotiable ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurface);
    final lines = <({String icon, String text})>[
      if (securedPayment(request))
        (icon: 'shield-check', text: l.requestPublicReassureSecured),
      if (request.negotiable)
        (icon: 'tag', text: l.requestPublicReassureNegotiable),
    ];
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('request-reassurance'),
      padding: const EdgeInsets.only(top: DonySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: DonyIcon(line.icon, size: 16, color: cs.primary),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(child: Text(line.text, style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
