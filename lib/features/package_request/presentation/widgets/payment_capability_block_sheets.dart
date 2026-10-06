import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
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

/// Ce qui empêche le voyageur d'encaisser par carte, quand on le sait.
///
/// Trois situations très différentes derrière le même 422, chacune avec sa
/// propre consigne : une activation à faire, un pays de profil à renseigner,
/// ou un pays que Stripe ne couvre pas.
enum CardCapabilityGap {
  /// Stripe couvre le pays : il suffit d'activer le paiement carte.
  activatable,

  /// Aucun pays de résidence au profil : le serveur ne peut pas savoir si
  /// Stripe le couvre (`StripeConnectCountries.isSupported(null)` est faux).
  /// Dire « pas disponible dans ton pays » serait faux : il faut le renseigner.
  countryMissing,

  /// Pays renseigné, mais Stripe n'y ouvre pas de compte connecté.
  countryUnsupported,
}

/// Le colis n'accepte-t-il que la carte ?
///
/// Miroir de `NegotiationService.assertNonEmptyOrThrow` côté serveur : seuls
/// la carte, l'espèce et le mobile money comptent comme rails. Les rails
/// retirés (Wave, Orange Money) ne sont jamais fournissables et ne sauvent
/// donc pas un colis « carte seule ».
bool acceptsCardOnly(Set<PaymentMethod> accepted) =>
    accepted.contains(PaymentMethod.stripe) &&
    !accepted.contains(PaymentMethod.cash) &&
    !accepted.contains(PaymentMethod.mobileMoney);

CardCapabilityGap _gapFor({
  required bool connectAvailableInCountry,
  required String? profileCountry,
}) {
  if (connectAvailableInCountry) {
    return CardCapabilityGap.activatable;
  }
  return (profileCountry == null || profileCountry.trim().isEmpty)
      ? CardCapabilityGap.countryMissing
      : CardCapabilityGap.countryUnsupported;
}

/// Blocage carte **avéré**, pour prévenir le voyageur avant qu'il remplisse
/// un formulaire que le serveur refusera (FLUTTER-E9).
///
/// `null` quand le voyageur peut encaisser par carte, ou quand on ne le sait
/// pas (statut en cours de chargement, en erreur, jamais chargé) : dans ce
/// cas on ne bloque rien, le 422 du serveur reste le garde-fou.
CardCapabilityGap? knownCardCapabilityGap(
  StripeAccountState stripeState, {
  required String? profileCountry,
}) => switch (stripeState) {
  StripeAccountReady(:final accountStatus) when !accountStatus.isComplete =>
    _gapFor(
      connectAvailableInCountry: accountStatus.connectAvailableInCountry,
      profileCountry: profileCountry,
    ),
  _ => null,
};

/// `payment-method/card-capability-required` : le colis n'accepte que la
/// carte et le voyageur n'a pas encore activé les paiements par carte
/// (onboarding Stripe Connect). Réutilise le flux d'onboarding existant
/// (`/connect/onboarding/intro`, cf. `announcement_detail_body.dart`).
///
/// Ouverte à deux moments : en amont, depuis la fiche du colis, et en filet
/// de sécurité quand le serveur renvoie le 422 à l'envoi.
Future<void> showCardCapabilityRequiredSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final l = context.l10n;
  final stripeBloc = context.read<StripeAccountBloc>();

  // Le pays n'est lu que s'il sert : quand Stripe couvre le pays, la consigne
  // est la même quel qu'il soit.
  final connectAvailable = stripeBloc.state.connectAvailableInCountry;
  final profileCountry = connectAvailable
      ? null
      : context.read<BusinessPrefsBloc>().state.country;
  final gap = _gapFor(
    connectAvailableInCountry: connectAvailable,
    profileCountry: profileCountry,
  );

  void close() => Navigator.of(context, rootNavigator: true).pop();

  // Le statut Connect dépend du pays du profil (côté serveur) : au retour des
  // préférences, on le redemande pour que la fiche et cette feuille reflètent
  // le nouveau pays sans attendre un redémarrage.
  void openCountryPrefs() {
    close();
    unawaited(
      context.push<void>('/settings/preferences').whenComplete(() {
        if (!stripeBloc.isClosed) {
          stripeBloc.add(const StripeAccountStatusRefreshed());
        }
      }),
    );
  }

  final bodyStyle = tt.bodyMedium?.copyWith(color: cs.onSurface);

  final (String title, Widget child, Widget stickyBottom) = switch (gap) {
    CardCapabilityGap.activatable => (
      l.negotiationCardCapabilityRequiredTitle,
      Text(l.negotiationCardCapabilityRequiredBody, style: bodyStyle),
      DonyButton(
        key: const Key('activate-card-payment-cta'),
        label: l.negotiationCardCapabilityActivateButton,
        onPressed: () {
          close();
          context.push('/connect/onboarding/intro');
        },
      ),
    ),
    CardCapabilityGap.countryMissing => (
      l.negotiationCardCapabilityRequiredTitle,
      Text(
        l.negotiationCardCapabilityCountryMissingBody,
        key: const Key('card-capability-country-missing'),
        style: bodyStyle,
      ),
      DonyButton(
        key: const Key('card-capability-set-country'),
        label: l.negotiationCardCapabilitySetCountryButton,
        onPressed: openCountryPrefs,
      ),
    ),
    CardCapabilityGap.countryUnsupported => (
      l.negotiationCardCapabilityUnavailableTitle,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.negotiationCardCapabilityUnavailableBody, style: bodyStyle),
          const SizedBox(height: DonySpacing.md),
          Row(
            children: [
              DonyIcon('globe', size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  l.negotiationCardCapabilityProfileCountry(
                    countryName(l, profileCountry!.trim().toUpperCase()),
                  ),
                  key: const Key('card-capability-profile-country'),
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            key: const Key('card-capability-unavailable-close'),
            label: l.negotiationCardCapabilityUnderstoodButton,
            onPressed: close,
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            key: const Key('card-capability-change-country'),
            label: l.negotiationCardCapabilityChangeCountryButton,
            variant: DonyButtonVariant.ghost,
            onPressed: openCountryPrefs,
          ),
        ],
      ),
    ),
  };

  await DonyBottomSheet.show<void>(
    context,
    title: title,
    child: child,
    stickyBottom: stickyBottom,
  );
}
