import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
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
  }) async {
    await DonyBottomSheet.show<void>(
      context,
      title: 'Accepter l\'offre',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: BlocBuilder<NegotiationBloc, NegotiationState>(
        bloc: bloc,
        builder: (ctx, state) {
          final loading = state is NegotiationActionInProgress ||
              state is NegotiationLoading;
          return DonyButton(
            label: loading
                ? 'Traitement…'
                : 'Confirmer (${priceEur.toStringAsFixed(0)} €)',
            isLoading: loading,
            onPressed: () async {
              final auth = LocalAuthentication();
              try {
                final canCheck = await auth.canCheckBiometrics ||
                    await auth.isDeviceSupported();
                if (canCheck) {
                  final ok = await auth.authenticate(
                    localizedReason:
                        'Confirmez votre identité pour valider le paiement',
                    options: const AuthenticationOptions(
                      biometricOnly: false,
                      stickyAuth: true,
                    ),
                  );
                  if (!ok) return;
                }
                // TODO(stripe-integration): use paymentIntentClientSecret from
                // NegotiationLoaded to trigger Stripe.instance.confirmPayment(...)
                // when the real Stripe flow is wired (V60 + PaymentService extension).
                bloc.add(NegotiationAcceptRequested(threadId: threadId));
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kGreenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Montant à régler',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: kGreenDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${priceEur.toStringAsFixed(2)} €',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: kGreenPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'En confirmant, le paiement est mis en escrow. Le voyageur reçoit le montant à la livraison validée.',
            style: GoogleFonts.plusJakartaSans(
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
