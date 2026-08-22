import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Maps the 422 reason the back-end returns from `submit-trip` /
/// `create-dedicated-trip` when the traveler cannot honor the payment method
/// the sender accepted, to the block-specific UX the calling screen must
/// show.
///
/// The traveler never picks a payment method: the sender declares what they
/// accept on their package request, and the back-end computes the SET of
/// methods the traveler can actually provide. Only one capability can be
/// missing today, the card: without a Stripe Connect account the traveler
/// cannot be paid at all. Cash is never gated here, the wallet balance is a
/// settlement detail checked at payment time (and topped up then if short),
/// not a capability.
///
/// Shared by both `LinkTripScreen` (existing announcement) and
/// `CreateTripScreen` (dedicated trip creation) so the traveler gets the
/// exact same UX regardless of which flow triggered the 422.
enum PaymentCapabilityBlock {
  /// Colis is card-only; the traveler has no Stripe Connect onboarding.
  cardCapabilityRequired;

  static const Map<String, PaymentCapabilityBlock> _byCode = {
    'payment-method/card-capability-required':
        PaymentCapabilityBlock.cardCapabilityRequired,
  };

  /// Returns `null` when [code] isn't one of the trip-linking capability
  /// block reasons above (e.g. a network error, or an unrelated business
  /// error) — the caller must fall back to a generic error message.
  static PaymentCapabilityBlock? fromErrorCode(String? code) =>
      code == null ? null : _byCode[code];
}

/// `payment-method/card-capability-required` : le colis n'accepte que la
/// carte et le voyageur n'a pas encore activé les paiements par carte
/// (onboarding Stripe Connect). Réutilise le flux d'onboarding existant
/// (`/connect/onboarding/intro`, cf. `announcement_detail_body.dart`).
Future<void> showCardCapabilityRequiredSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;

  // Deux blocages très différents derrière le même 422 : une activation à
  // faire, ou un pays que Stripe ne couvre pas. Dans le second cas, « active
  // les paiements par carte » est une consigne que le voyageur ne peut pas
  // suivre — il faut le dire, pas le renvoyer vers un parcours sans issue.
  final connectAvailable = context
      .read<StripeAccountBloc>()
      .state
      .connectAvailableInCountry;

  await DonyBottomSheet.show<void>(
    context,
    title: connectAvailable ? 'Paiement carte requis' : 'Colis indisponible',
    child: Text(
      connectAvailable
          ? 'L\'expéditeur n\'accepte que le paiement par carte pour ce colis. '
                'Active les paiements par carte pour pouvoir lier ce trajet.'
          : 'L\'expéditeur n\'accepte que le paiement par carte pour ce colis, '
                'et Stripe ne permet pas encore d\'ouvrir un compte de paiement '
                'depuis ton pays. Tu peux lier les colis payés en espèces.',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
    ),
    stickyBottom: connectAvailable
        ? DonyButton(
            key: const Key('activate-card-payment-cta'),
            label: 'Activer le paiement carte',
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.push('/connect/onboarding/intro');
            },
          )
        : DonyButton(
            key: const Key('card-capability-unavailable-close'),
            label: 'J\'ai compris',
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
  );
}
