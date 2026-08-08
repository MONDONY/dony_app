import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_quote.dart';
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

    // Devis serveur (net/commission/total réels, promo déjà appliqué s'il y en
    // a un — saisi par l'expéditeur à la publication de sa demande, jamais
    // resaisi ici, cf. step_3_recap_budget.dart). Chargé uniquement à l'étape
    // de paiement réel côté expéditeur : c'est le seul moment où la précision
    // (overrides, promo) compte plus qu'une estimation locale instantanée.
    final quoteNotifier = ValueNotifier<NegotiationQuote?>(null);

    Future<void> loadQuote() async {
      try {
        quoteNotifier.value =
            await getIt<NegotiationRepository>().quote(threadId);
      } catch (_) {
        // Silencieux : échec réseau → l'UI retombe sur l'estimation locale.
      }
    }

    if (!isTraveler && isCheckout) {
      unawaited(loadQuote());
    }

    await DonyBottomSheet.show<void>(
      context,
      title: isCheckout ? 'Payer en toute sécurité' : 'Accepter l\'offre',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ListenableBuilder(
        // `quoteNotifier` doit aussi déclencher ce rebuild : sans lui, le
        // label du bouton restait figé sur l'estimation locale après
        // application d'un code promo (le total réel n'apparaissait qu'à
        // l'ouverture de la sheet Stripe, jamais dans le libellé "Payer (…)").
        listenable: Listenable.merge([processing, quoteNotifier]),
        builder: (ctx0, _) =>
            BlocBuilder<NegotiationBloc, NegotiationState>(
          bloc: bloc,
          builder: (ctx, state) {
            final busy = processing.value;
            final loading = busy ||
                state is NegotiationActionInProgress ||
                state is NegotiationLoading;
            final quote = quoteNotifier.value;
            final displayPrice = isTraveler
                ? priceEur
                : (quote?.totalEur ??
                    (grossPriceEur ?? PriceDisplay.grossFromNet(priceEur)));
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
                          message: 'Paiement non confirmé, réessayez',
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
                          // Le promo (s'il y en a un) a déjà été validé côté
                          // backend et porté par le thread depuis la publication
                          // de la demande — appliqué automatiquement, rien à
                          // transmettre ici.
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
                                        'Ton argent est bloqué et sécurisé, le voyageur ne le reçoit qu\'après confirmation de la livraison. Suis ton colis depuis le fil.',
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
                                mascotteType: DonyMascotteType.succes,
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: quoteNotifier,
                builder: (context, _) {
                  final quote = quoteNotifier.value;
                  final fallbackGross =
                      grossPriceEur ?? PriceDisplay.grossFromNet(priceEur);
                  final netEur = quote?.netEur ?? priceEur;
                  final rate = quote?.rate ?? PriceDisplay.previewRate;
                  final commissionEur =
                      quote?.commissionEur ?? (fallbackGross - priceEur);
                  final totalEur = quote?.totalEur ?? fallbackGross;
                  final promoApplied = quote?.promoApplied ?? false;
                  return _NegotiationPriceBreakdown(
                    isTraveler: isTraveler,
                    netEur: netEur,
                    rate: rate,
                    commissionEur: commissionEur,
                    totalEur: totalEur,
                    promoApplied: promoApplied,
                    originalTotal: promoApplied ? netEur + commissionEur : null,
                  );
                },
              ),
              const SizedBox(height: DonySpacing.base),
              Text(
                isTraveler
                    ? 'En acceptant, l\'expéditeur effectuera le paiement. Tu recevras ${PriceDisplay.eur(priceEur)} à la livraison validée, quel que soit un éventuel code promo utilisé par l\'expéditeur.'
                    : 'En confirmant, le paiement est bloqué et sécurisé. Le voyageur reçoit le montant à la livraison validée.',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      processing.dispose();
      quoteNotifier.dispose();
    });
  }
}

/// Devis transparent : d'un côté le voyageur touche le net négocié, de
/// l'autre l'expéditeur règle net + commission Yadony. Les deux rôles voient
/// la MÊME décomposition, lue dans l'ordre qui les concerne : le voyageur part
/// du prix payé par l'expéditeur et voit la commission retranchée jusqu'à son
/// net ; l'expéditeur part du net voyageur et voit la commission ajoutée
/// jusqu'à son total (promo déduit s'il y en a un).
class _NegotiationPriceBreakdown extends StatelessWidget {
  const _NegotiationPriceBreakdown({
    required this.isTraveler,
    required this.netEur,
    required this.rate,
    required this.commissionEur,
    required this.totalEur,
    required this.promoApplied,
    this.originalTotal,
  });

  final bool isTraveler;
  final double netEur;
  final double rate;
  final double commissionEur;
  final double totalEur;
  final bool promoApplied;
  final double? originalTotal;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Une remise n'est réelle que si le total avec promo est strictement
    // inférieur au total sans promo — un promo au même taux que le taux
    // courant ne ferait gagner aucune remise réelle (cf. régression WELCOME05).
    final savings =
        (promoApplied && originalTotal != null) ? originalTotal! - totalEur : 0.0;
    final hasRealSavings = savings > 0.005;
    final ratePct = _ratePercentLabel(rate);

    final rows = <Widget>[];
    if (isTraveler) {
      rows.add(_line(tt, cs, 'Prix payé par l\'expéditeur', PriceDisplay.eur(totalEur)));
      rows.add(_line(tt, cs, 'Commission Yadony ($ratePct %)',
          '−${PriceDisplay.eur(commissionEur)}'));
    } else {
      rows.add(_line(tt, cs, 'Net voyageur', PriceDisplay.eur(netEur)));
      rows.add(
          _line(tt, cs, 'Commission Yadony ($ratePct %)', PriceDisplay.eur(commissionEur)));
      if (hasRealSavings) {
        rows.add(_line(tt, cs, 'Réduction code promo', '−${PriceDisplay.eur(savings)}',
            valueColor: const Color(0xFF16A34A)));
      }
    }

    final totalLabel = isTraveler ? 'Tu reçois' : 'Total à régler';
    final totalValue = isTraveler ? netEur : totalEur;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: kGreenLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows) ...[r, const SizedBox(height: DonySpacing.xs)],
          Divider(color: kGreenDark.withValues(alpha: 0.2)),
          const SizedBox(height: DonySpacing.xs),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              runSpacing: DonySpacing.xs,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(totalLabel,
                        style: tt.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: kGreenDark,
                        )),
                    if (!isTraveler && hasRealSavings) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Promo',
                          style: tt.labelSmall?.copyWith(
                            color: const Color(0xFF16A34A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isTraveler && hasRealSavings) ...[
                      Text(
                        PriceDisplay.eur(originalTotal!),
                        style: tt.bodySmall?.copyWith(
                          color: kGreenDark.withValues(alpha: 0.6),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      PriceDisplay.eur(totalValue),
                      style: tt.bodyMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: kGreenPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(TextTheme tt, ColorScheme cs, String label, String value,
          {Color? valueColor}) =>
      Row(
        children: [
          Expanded(
              child: Text(label,
                  style: tt.bodyMedium?.copyWith(color: kGreenDark))),
          const SizedBox(width: DonySpacing.sm),
          Text(value,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? kGreenDark,
              )),
        ],
      );

  /// Libellé pourcentage : entier si rond, sinon 1 décimale virgule FR.
  String _ratePercentLabel(double rate) {
    final pct = rate * 100;
    return pct % 1 == 0
        ? pct.toStringAsFixed(0)
        : pct.toStringAsFixed(1).replaceFirst('.', ',');
  }
}
