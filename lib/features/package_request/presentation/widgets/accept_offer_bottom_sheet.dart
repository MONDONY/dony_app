import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:local_auth/local_auth.dart';

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
    /// If true, this is the FINAL payment step (status was AWAITING_PAYMENT).
    /// If false, this is the initial price acceptance (status was OPEN → AWAITING_TRIP).
    bool isCheckout = false,
  }) async {
    await DonyBottomSheet.show<void>(
      context,
      title: isCheckout ? 'Payer en escrow' : 'Accepter l\'offre',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: BlocBuilder<NegotiationBloc, NegotiationState>(
        bloc: bloc,
        builder: (ctx, state) {
          final loading = state is NegotiationActionInProgress ||
              state is NegotiationLoading;
          return DonyButton(
            label: loading
                ? 'Traitement…'
                : isCheckout
                    ? 'Payer (${priceEur.toStringAsFixed(0)} €)'
                    : 'Confirmer (${priceEur.toStringAsFixed(0)} €)',
            isLoading: loading,
            onPressed: () async {
              final auth = LocalAuthentication();
              try {
                final canCheck = await auth.canCheckBiometrics ||
                    await auth.isDeviceSupported();
                if (canCheck) {
                  final ok = await auth.authenticate(
                    localizedReason: isCheckout
                        ? 'Confirmez votre identité pour valider le paiement'
                        : 'Confirmez votre identité pour accepter l\'offre',
                    options: const AuthenticationOptions(
                      biometricOnly: false,
                      stickyAuth: true,
                    ),
                  );
                  if (!ok) return;
                }
                if (isCheckout) {
                  // Stripe escrow flow:
                  //  1. Backend creates the PaymentIntent and returns clientSecret.
                  //  2. PaymentSheet collects the card, confirms the PI client-side.
                  //  3. The Stripe webhook payment_intent.amount_capturable_updated
                  //     fires server-side → NegotiationPaymentListener finalizes thread.
                  //  4. We also call /checkout sync as a safety-net so the user sees
                  //     ACCEPTED immediately without depending on webhook latency.
                  try {
                    final init = await getIt<NegotiationRepository>()
                        .initiatePayment(threadId);
                    await Stripe.instance.initPaymentSheet(
                      paymentSheetParameters: SetupPaymentSheetParameters(
                        paymentIntentClientSecret: init.clientSecret,
                        merchantDisplayName: 'Dony',
                      ),
                    );
                    await Stripe.instance.presentPaymentSheet();
                    bloc.add(NegotiationCheckoutRequested(
                      threadId: threadId,
                      paymentIntentId: init.paymentIntentId,
                    ));
                  } on StripeException catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(e.error.code == FailureCode.Canceled
                            ? 'Paiement annulé'
                            : 'Erreur paiement : ${e.error.message ?? ""}'),
                        backgroundColor: kError,
                      ));
                    }
                    return;
                  }
                } else {
                  bloc.add(NegotiationAcceptRequested(threadId: threadId));
                }
                if (ctx.mounted) {
                  Navigator.of(ctx, rootNavigator: true).pop();
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: kError),
                  );
                }
              }
            },
          );
        },
      ),
      child: Column(
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
                  'Montant à régler',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 13,
                    color: kGreenDark,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  '${priceEur.toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: kGreenPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            'En confirmant, le paiement est mis en escrow. Le voyageur reçoit le montant à la livraison validée.',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13,
              color: kTextSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
