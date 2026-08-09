import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart'
    as dony;
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Placeholder paymentIntentId sent to the backend when the sender confirms a
/// CASH agreement. There is no online PaymentIntent for cash — the backend
/// `/checkout` endpoint only requires a non-blank marker (the commission is
/// collected from the traveler separately).
const String kCashPaymentSentinel = 'CASH';

/// Detailed payment recap bottom sheet for the AWAITING_PAYMENT step.
///
/// Shows an itemized fee breakdown:
/// - STRIPE: traveler net + service fee + total → CTA "Payer X €"
/// - CASH:   amount to hand over + note on fee covered by traveler → CTA "Confirmer l'accord"
///
/// Rule: [DonyButton] is always in [stickyBottom], never in the scrollable child.
class PaymentRecapBottomSheet {
  const PaymentRecapBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required NegotiationBloc bloc,
    required NegotiationThread thread,
    dony.PaymentMethod? paymentMethod,
  }) async {
    final double net = thread.currentPriceEur;
    final double gross =
        thread.grossPriceEur ?? PriceDisplay.grossFromNet(net);
    final double fee = gross - net;
    // Mode finalisé par l'expéditeur (s'il a choisi à l'étape complétion),
    // sinon celui déjà porté par le thread, sinon Stripe par défaut.
    final dony.PaymentMethod method =
        paymentMethod ?? thread.paymentMethod ?? dony.PaymentMethod.stripe;
    final bool isCash = method == dony.PaymentMethod.cash;

    // Garde anti-double-tap : le flux Stripe (initiatePayment → présentation de
    // la sheet) est asynchrone et ne change pas l'état du BLoC avant son terme,
    // donc le bouton resterait tappable et un second tap ouvrirait la sheet
    // Stripe une 2e fois (+ un escrow orphelin). `processing` désactive le
    // bouton dès le 1er tap et rend `onPressed` ré-entrant.
    final processing = ValueNotifier<bool>(false);

    await DonyBottomSheet.show<void>(
      context,
      title: isCash ? 'Confirmer l\'accord' : 'Payer en toute sécurité',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: processing,
        builder: (ctx0, busy, _) =>
            BlocBuilder<NegotiationBloc, NegotiationState>(
          bloc: bloc,
          builder: (ctx, state) {
            final isLoading = busy ||
                state is NegotiationActionInProgress ||
                state is NegotiationLoading;
            return DonyButton(
              label: isLoading
                  ? 'Traitement…'
                  : isCash
                      ? 'Confirmer l\'accord'
                      : 'Payer ${PriceDisplay.eur(gross)}',
              isLoading: isLoading,
              onPressed: isLoading
                  ? null
                  : () async {
                      // Ré-entrance : si un tap est déjà en cours, ignorer.
                      if (processing.value) return;
                      processing.value = true;
                      if (!isCash) {
                        // Stripe: require biometric/PIN before payment
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
                          final init = await getIt<NegotiationRepository>()
                              .initiatePayment(thread.id);
                          if (!ctx.mounted) return;
                          await DonyPaymentSheet.show(
                            ctx,
                            config: PaymentSheetConfig(
                              clientSecret: init.clientSecret,
                              amountEur: init.amountEur,
                              currencyCode: init.currencyCode,
                              paymentMethodTypes: init.paymentMethodTypes,
                            ),
                            contextLabel: isCash
                                ? 'Confirmation de l\'accord'
                                : 'Paiement sécurisé',
                            onSuccess: () {
                              bloc.add(NegotiationCheckoutRequested(
                                threadId: thread.id,
                                paymentIntentId: init.paymentIntentId,
                                paymentMethod: method,
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
                                        .go('/negotiations/${thread.id}'),
                                    analyticsContext: 'negotiation_payment',
                                  ),
                                ));
                              }
                            },
                          );
                          // Sheet fermée sans paiement (swipe) → réarmer le bouton.
                          processing.value = false;
                        } catch (_) {
                          processing.value = false;
                          if (ctx.mounted) {
                            DonySnackbar.show(
                              ctx,
                              message: 'Une erreur est survenue. Veuillez réessayer.',
                              type: DonySnackbarType.error,
                            );
                          }
                        }
                      } else {
                        // Cash: no online payment. The agreement is settled in
                        // person and Yadony collects its commission from the
                        // traveler separately. We finalize the AWAITING_PAYMENT
                        // thread via /checkout (idempotent placeholder), NOT
                        // /accept — the thread is already past OPEN, so calling
                        // accept here returns `thread/already-finalized`.
                        bloc.add(NegotiationCheckoutRequested(
                          threadId: thread.id,
                          paymentIntentId: kCashPaymentSentinel,
                          paymentMethod: method,
                        ));
                        if (ctx.mounted) {
                          Navigator.of(ctx, rootNavigator: true).pop();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (routeContext) => DonySuccessScreen(
                              mascotteType: DonyMascotteType.succes,
                              title: 'Accord confirmé !',
                              subtitle:
                                  'Paiement en espèces : tu remets le montant au voyageur en main propre, à la remise du colis. En cas d\'annulation après la remise, Yadony ne peut pas te rembourser immédiatement mais s\'assurera que le voyageur te restitue ton argent.',
                              ctaLabel: 'Voir le suivi',
                              onCta: () => routeContext
                                  .go('/negotiations/${thread.id}'),
                              analyticsContext: 'negotiation_cash_agreement',
                            ),
                          ));
                        }
                      }
                    },
            );
          },
        ),
      ),
      child: PaymentRecapContent(
        net: net,
        gross: gross,
        fee: fee,
        isCash: isCash,
      ),
    ).whenComplete(processing.dispose);
  }
}

/// Public widget exposed for widget testing.
///
/// Use [PaymentRecapBottomSheet.show] in production code.
/// In tests, pump [PaymentRecapContent] directly to verify the fee breakdown.
class PaymentRecapContent extends StatelessWidget {
  const PaymentRecapContent({
    super.key,
    required this.net,
    required this.gross,
    required this.fee,
    required this.isCash,
  });

  /// Convenience factory used in tests for named clarity.
  factory PaymentRecapContent.testable({
    required double net,
    required double gross,
    required double fee,
    required bool isCash,
  }) =>
      PaymentRecapContent(
        net: net,
        gross: gross,
        fee: fee,
        isCash: isCash,
      );

  final double net;
  final double gross;
  final double fee;
  final bool isCash;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trust banner
        _TrustBanner(isCash: isCash),
        const SizedBox(height: DonySpacing.base),

        // Fee table
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            children: isCash
                ? [
                    _FeeRow(
                      label: 'À remettre au voyageur (en espèces)',
                      amount: PriceDisplay.eur(gross),
                      isTotal: false,
                    ),
                    const _Divider(),
                    _FeeRow(
                      label: 'dont frais Yadony (réglés par le voyageur)',
                      amount: PriceDisplay.eur(fee),
                      isTotal: false,
                      isSubNote: true,
                    ),
                    const _Divider(),
                    _FeeRow(
                      label: 'Le voyageur garde net',
                      amount: PriceDisplay.eur(net),
                      isTotal: true,
                    ),
                  ]
                : [
                    _FeeRow(
                      label: 'Le voyageur touche',
                      amount: PriceDisplay.eur(net),
                      isTotal: false,
                    ),
                    const _Divider(),
                    _FeeRow(
                      label: 'Frais de service Yadony',
                      amount: PriceDisplay.eur(fee),
                      isTotal: false,
                    ),
                    const _Divider(isTotal: true),
                    _FeeRow(
                      label: 'Total à payer',
                      amount: PriceDisplay.eur(gross),
                      isTotal: true,
                    ),
                  ],
          ),
        ),
        const SizedBox(height: DonySpacing.base),

        // Explanatory note
        Text(
          isCash
              ? 'Remettez le montant total en espèces au voyageur lors de la remise du colis. Le voyageur déduira ses frais Yadony de ce montant.'
              : 'Le montant est bloqué et sécurisé. Le voyageur le reçoit uniquement après confirmation de la livraison.',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _TrustBanner extends StatelessWidget {
  const _TrustBanner({required this.isCash});

  final bool isCash;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color bgColor = isCash ? cs.warningLight : cs.infoLight;
    final Color iconColor = isCash ? DonyColors.warning500 : DonyColors.info500;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        children: [
          DonyIcon(
            isCash ? 'banknote' : 'lock',
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              isCash
                  ? 'Paiement en main propre à la remise'
                  : 'Sécurisé · bloqué jusqu\'à la livraison',
              style: tt.bodySmall?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.label,
    required this.amount,
    required this.isTotal,
    this.isSubNote = false,
  });

  final String label;
  final String amount;
  final bool isTotal;
  final bool isSubNote;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final labelStyle = isSubNote
        ? tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          )
        : isTotal
            ? tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              )
            : tt.bodyMedium?.copyWith(
                color: cs.onSurface,
              );

    final amountStyle = isTotal
        ? tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          )
        : tt.bodyMedium?.copyWith(
            color: isSubNote ? cs.onSurfaceVariant : cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: labelStyle),
          ),
          const SizedBox(width: DonySpacing.sm),
          Text(amount, style: amountStyle),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({this.isTotal = false});

  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: isTotal ? 1.5 : 1,
      color: isTotal
          ? cs.outline.withValues(alpha: 0.7)
          : cs.outline.withValues(alpha: 0.4),
    );
  }
}
