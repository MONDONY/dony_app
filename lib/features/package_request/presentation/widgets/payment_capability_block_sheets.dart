import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/payments/cash/data/repositories/commission_method_repository.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Maps the 422 reasons the back-end returns from `submit-trip` /
/// `create-dedicated-trip` when the traveler cannot honor any payment method
/// the sender accepted, to the block-specific UX the calling screen must
/// show.
///
/// The traveler no longer picks a payment method at trip-linking (nor at
/// dedicated-trip creation): the back-end computes the SET of methods it can
/// actually provide, and only rejects (422) when that set is empty. Each
/// reason maps to exactly one contextual CTA — never a dead-end error
/// message. Shared by both `LinkTripScreen` (existing announcement) and
/// `CreateTripScreen` (dedicated trip creation) so the traveler gets the
/// exact same UX regardless of which flow triggered the 422.
enum PaymentCapabilityBlock {
  /// Colis is card-only; the traveler has no Stripe Connect onboarding.
  cardCapabilityRequired,

  /// Colis is cash-only; the traveler lacks wallet funds AND card consent.
  cashFundsRequired,

  /// Both methods are accepted by the sender, neither is possible for the
  /// traveler.
  noneAvailable;

  static const Map<String, PaymentCapabilityBlock> _byCode = {
    'payment-method/card-capability-required':
        PaymentCapabilityBlock.cardCapabilityRequired,
    'payment-method/cash-funds-required':
        PaymentCapabilityBlock.cashFundsRequired,
    'payment-method/none-available': PaymentCapabilityBlock.noneAvailable,
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
  await DonyBottomSheet.show<void>(
    context,
    title: 'Paiement carte requis',
    child: Text(
      'L\'expéditeur n\'accepte que le paiement par carte pour ce colis. '
      'Active les paiements par carte pour pouvoir lier ce trajet.',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
    ),
    stickyBottom: DonyButton(
      key: const Key('activate-card-payment-cta'),
      label: 'Activer le paiement carte',
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop();
        context.push('/connect/onboarding/intro');
      },
    ),
  );
}

/// Commission cash « wallet d'abord » : si le solde est insuffisant, on propose
/// de recharger le wallet OU de consentir au prélèvement sur la carte (effectué
/// au finalize, wallet puis carte). Reprend le pattern de l'acceptation de bid.
///
/// [onResubmit] is called with `useCard: false` after a successful wallet
/// top-up, or `useCard: true` once the traveler consents to (or just added) a
/// commission card — the caller re-dispatches whatever request it had just
/// submitted (submit-trip or create-dedicated-trip) with that consent.
Future<void> showCashInsufficientSheet(
  BuildContext context, {
  required double netPriceEur,
  double? grossPriceEur,
  String? currency,
  required void Function({required bool useCard}) onResubmit,
}) async {
  final net = netPriceEur;
  final gross = grossPriceEur ?? PriceDisplay.grossFromNet(net);
  final commission = gross - net;

  double balance = 0;
  bool hasCard = false;
  try {
    balance = (await getIt<WalletRepository>().getBalance()).balance;
  } catch (_) {}
  try {
    hasCard = (await getIt<CommissionMethodRepository>().load()) != null;
  } catch (_) {}
  if (!context.mounted) return;

  final cs = Theme.of(context).colorScheme;
  await DonyBottomSheet.show<void>(
    context,
    title: 'Solde insuffisant',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commission à régler : ${formatPriceIn(commission, currency)}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'Solde du portefeuille : ${formatPriceIn(balance, currency)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Recharge ton portefeuille, ou accepte que la commission soit prélevée sur '
          'ta carte à la remise du colis.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    ),
    stickyBottom: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          label: 'Recharger mon portefeuille',
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            final recharged = await context.push<bool>(
              '/payments/wallet/topup/method',
            );
            if ((recharged ?? false) && context.mounted) {
              onResubmit(useCard: false);
            }
          },
        ),
        const SizedBox(height: DonySpacing.sm),
        if (hasCard)
          DonyButton(
            label: 'Payer la commission par carte',
            variant: DonyButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              onResubmit(useCard: true);
            },
          )
        else
          DonyButton(
            label: 'Ajouter une carte',
            variant: DonyButtonVariant.secondary,
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              await context.push('/payments/commission-method');
              if (context.mounted) onResubmit(useCard: true);
            },
          ),
      ],
    ),
  );
}

/// `payment-method/none-available` : le colis accepte carte ET espèces,
/// mais le voyageur ne peut honorer ni l'une ni l'autre. On propose les
/// deux chemins de déblocage.
Future<void> showNoPaymentMethodAvailableSheet(
  BuildContext context, {
  required double netPriceEur,
  double? grossPriceEur,
  String? currency,
  required void Function({required bool useCard}) onResubmit,
}) async {
  final cs = Theme.of(context).colorScheme;
  await DonyBottomSheet.show<void>(
    context,
    title: 'Aucun moyen de paiement disponible',
    child: Text(
      'Tu ne peux pas encore honorer la carte ni les espèces pour ce colis. '
      'Active le paiement carte, ou débloque le paiement en espèces.',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
    ),
    stickyBottom: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          key: const Key('activate-card-payment-cta'),
          label: 'Activer le paiement carte',
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            context.push('/connect/onboarding/intro');
          },
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('unlock-cash-payment-cta'),
          label: 'Débloquer le paiement en espèces',
          variant: DonyButtonVariant.secondary,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            showCashInsufficientSheet(
              context,
              netPriceEur: netPriceEur,
              grossPriceEur: grossPriceEur,
              currency: currency,
              onResubmit: onResubmit,
            );
          },
        ),
      ],
    ),
  );
}
