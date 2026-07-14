import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AcceptOfferBottomSheet {
  const AcceptOfferBottomSheet._();

  /// Sender accepts a thread. Biometric/PIN required before triggering the
  /// accept action (project rule: any payment-bound action requires bio).
  ///
  /// Stripe integration is currently a placeholder client_secret on the back —
  /// when the real PaymentIntent flow lands (see `TRACKING_INTEGRATION_DEFERRED.md`
  /// + `NegotiationService.accept` TODO), wire `Stripe.instance.confirmPayment`
  /// here using the `paymentIntentClientSecret` from the response.
  static Future<void> show(
    BuildContext context, {
    required NegotiationBloc bloc,
    required String threadId,
    required double priceEur,
    double? grossPriceEur,
    /// Whether the current viewer is the traveler (receives net).
    /// Sender (isTraveler=false) sees gross price they pay.
    bool isTraveler = false,
    /// If true, this is the FINAL payment step (status was AWAITING_PAYMENT).
    /// If false, this is the initial price acceptance (status was OPEN → AWAITING_TRIP).
    bool isCheckout = false,
    /// Whether the thread already has a traveler trip linked. Drives the
    /// success-screen copy: a traveler accepting with a linked trip skips the
    /// AWAITING_TRIP step (backend goes straight to AWAITING_PAYMENT).
    bool hasLinkedTrip = false,
  }) async {
    // Garde anti-double-tap : le bouton n'était pas désactivé pendant le flux
    // asynchrone (auth + Stripe), donc un 2e tap relançait l'action (double
    // accept, ou double ouverture de la sheet Stripe en checkout). `processing`
    // désactive le bouton dès le 1er tap et rend `onPressed` ré-entrant.
    final processing = ValueNotifier<bool>(false);

    await DonyBottomSheet.show<void>(
      context,
      title: isCheckout ? 'Payer en escrow' : 'Accepter l\'offre',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: processing,
        builder: (ctx0, busy, _) =>
            BlocBuilder<NegotiationBloc, NegotiationState>(
          bloc: bloc,
          builder: (ctx, state) {
            final loading = busy ||
                state is NegotiationActionInProgress ||
                state is NegotiationLoading;
            final displayPrice = isTraveler
                ? priceEur
                : (grossPriceEur ?? PriceDisplay.grossFromNet(priceEur));
            return DonyButton(
              label: loading
                  ? 'Traitement…'
                  : isCheckout
                      ? 'Payer (${PriceDisplay.eur(displayPrice)})'
                      : 'Confirmer (${PriceDisplay.eur(displayPrice)})',
              isLoading: loading,
              onPressed: loading
                  ? null
                  : () async {
                      if (processing.value) return;
                      processing.value = true;
                      final authenticated = await requirePaymentAuth(
                        ctx,
                        authService: getIt<LocalAuthService>(),
                        userPrefs: getIt<HiveService>().userPrefs,
                      );
                      if (!ctx.mounted) return;
                      if (!authenticated) {
                        processing.value = false;
                        DonySnackbar.show(
                          ctx,
                          message: 'Authentification requise pour effectuer le paiement',
                          type: DonySnackbarType.warning,
                        );
                        return;
                      }
                      try {
                        if (isCheckout) {
                          // Stripe escrow flow :
                          //  1. Backend crée le PaymentIntent (clientSecret).
                          //  2. DonyPaymentSheet collecte le paiement, confirme le PI.
                          //  3. Le webhook payment_intent.amount_capturable_updated
                          //     finalise le thread server-side (NegotiationPaymentListener).
                          //  4. onSuccess appelle aussi /checkout en synchrone (filet de
                          //     sécurité) pour que l'utilisateur voie ACCEPTED sans
                          //     dépendre de la latence webhook.
                          final init = await getIt<NegotiationRepository>()
                              .initiatePayment(threadId);
                          await DonyPaymentSheet.show(
                            ctx,
                            config: PaymentSheetConfig(
                              clientSecret: init.clientSecret,
                              amountEur: init.amountEur,
                              paymentMethodTypes: init.paymentMethodTypes,
                            ),
                            contextLabel: isTraveler
                                ? 'Paiement de l\'offre acceptée'
                                : 'Paiement de votre offre',
                            onSuccess: () {
                              bloc.add(NegotiationCheckoutRequested(
                                threadId: threadId,
                                paymentIntentId: init.paymentIntentId,
                              ));
                              if (ctx.mounted) {
                                Navigator.of(ctx, rootNavigator: true).pop();
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (routeContext) => DonySuccessScreen(
                                    mascotteType: DonyMascotteType.securise,
                                    title: 'Offre acceptée et payée !',
                                    subtitle:
                                        'Ton argent est bloqué en escrow sécurisé, le voyageur ne le reçoit qu\'après confirmation de la livraison. Suis ton colis depuis le fil.',
                                    ctaLabel: 'Voir le suivi',
                                    onCta: () => routeContext
                                        .go('/negotiations/$threadId'),
                                    analyticsContext: 'negotiation_payment',
                                  ),
                                ));
                              }
                            },
                          );
                          // Sheet fermée sans paiement (swipe) → réarmer le bouton.
                          processing.value = false;
                        } else {
                          bloc.add(NegotiationAcceptRequested(threadId: threadId));
                          // Copy selon le rôle et l'étape suivante réelle : le
                          // moyen de paiement n'est choisi qu'au moment de
                          // finaliser les détails, donc aucune mention
                          // d'espèces ou d'escrow ici.
                          final String subtitle;
                          if (!isTraveler) {
                            subtitle =
                                'Vous êtes d\'accord sur le prix. Le voyageur va confirmer son trajet, puis tu finaliseras les détails de l\'envoi et le règlement depuis le fil.';
                          } else if (hasLinkedTrip) {
                            subtitle =
                                'Vous êtes d\'accord sur le prix. L\'expéditeur va finaliser les détails de l\'envoi et le règlement, tu seras notifié à chaque étape.';
                          } else {
                            subtitle =
                                'Vous êtes d\'accord sur le prix. Prochaine étape : lie ou crée un trajet pour cette offre afin que l\'expéditeur puisse finaliser le règlement.';
                          }
                          if (ctx.mounted) {
                            Navigator.of(ctx, rootNavigator: true).pop();
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (routeContext) => DonySuccessScreen(
                                mascotteType: DonyMascotteType.donneColis,
                                title: 'Accord confirmé !',
                                subtitle: subtitle,
                                ctaLabel: 'Voir le suivi',
                                onCta: () =>
                                    routeContext.go('/negotiations/$threadId'),
                                analyticsContext: 'negotiation_agreement',
                              ),
                            ));
                          }
                        }
                      } catch (e) {
                        processing.value = false;
                        if (ctx.mounted) {
                          DonySnackbar.show(
                            ctx,
                            message: 'Une erreur est survenue. Veuillez réessayer.',
                            type: DonySnackbarType.error,
                          );
                        }
                      }
                    },
            );
          },
        ),
      ),
      child: Builder(
        builder: (context) {
          final displayPrice = isTraveler
              ? priceEur
              : (grossPriceEur ?? PriceDisplay.grossFromNet(priceEur));
          final priceLabel = PriceDisplay.threadPriceLabel(
            priceEur,
            grossPriceEur,
            isTraveler,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(DonySpacing.base),
                decoration: BoxDecoration(
                  color: kGreenLight,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTraveler ? 'Tu reçois' : 'Montant à régler',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 13,
                        color: kGreenDark,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: kGreenPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              Text(
                isTraveler
                    ? 'En acceptant, l\'expéditeur effectuera le paiement. Tu recevras ${PriceDisplay.eur(displayPrice)} à la livraison validée.'
                    : 'En confirmant, le paiement est mis en escrow. Le voyageur reçoit le montant à la livraison validée.',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 13,
                  color: kTextSecondary,
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    ).whenComplete(processing.dispose);
  }
}
