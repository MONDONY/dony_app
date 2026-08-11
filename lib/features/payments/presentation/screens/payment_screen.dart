import 'dart:async';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

class PaymentScreen extends StatelessWidget {
  final BidModel bid;
  final LocalAuthService? localAuthService;
  @visibleForTesting final Box? userPrefs;

  const PaymentScreen({
    super.key,
    required this.bid,
    @visibleForTesting this.localAuthService,
    @visibleForTesting this.userPrefs,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentBloc, PaymentState>(
      listener: (context, state) async {
        if (state is PaymentSheetReady) {
          await _presentPaymentSheet(context, state);
        }
      },
      builder: (context, state) {
        if (state is PaymentEscrowPending) {
          return _EscrowConfirmedView(amount: state.amount, currency: bid.currency);
        }
        return BlocBuilder<ConfigBloc, ConfigState>(
          builder: (context, configState) {
            final commissionRate = configState is ConfigLoaded
                ? configState.commissionRate
                // Repli sur le taux par défaut pendant le chargement / en erreur.
                : donyCommissionRate;
            return _PaymentSummaryView(
              bid: bid,
              state: state,
              commissionRate: commissionRate,
              localAuthService: localAuthService ?? getIt<LocalAuthService>(),
              userPrefs: userPrefs ?? getIt<HiveService>().userPrefs,
            );
          },
        );
      },
    );
  }

  Future<void> _presentPaymentSheet(
      BuildContext context, PaymentSheetReady state) async {
    final total = state.amount + state.commissionAmount;
    await DonyPaymentSheet.show(
      context,
      config: PaymentSheetConfig(
        clientSecret: state.clientSecret,
        amountEur: total,
        currencyCode: state.currencyCode,
        paymentMethodTypes: state.paymentMethodTypes,
      ),
      contextLabel: 'Envoi de ${bid.recipientName ?? 'votre colis'}',
      onSuccess: () {
        if (!context.mounted) return;
        context.read<PaymentBloc>().add(const PaymentSheetCompleted());
      },
    );
  }
}

// ── Vue récapitulatif paiement ────────────────────────────────────────────────

class _PaymentSummaryView extends StatelessWidget {
  final BidModel bid;
  final PaymentState state;
  final LocalAuthService localAuthService;
  final double commissionRate;
  final Box userPrefs;

  const _PaymentSummaryView({
    required this.bid,
    required this.state,
    required this.localAuthService,
    required this.commissionRate,
    required this.userPrefs,
  });

  // _amount = NET du voyageur (totalNetAmountEur côté backend). L'expéditeur paie
  // ce net + la commission Yadony : _total = net × (1 + taux), aligné sur le montant
  // réellement facturé par le backend (PaymentService : amount = net × (1 + taux)).
  double get _amount => bid.totalAmountEur ?? (bid.weightKg ?? 0) * (bid.pricePerKg ?? 0);
  double get _commission => _amount * commissionRate;
  // Total payé par l'expéditeur = BRUT fourni par le backend (qui ne renvoie
  // jamais le net au sender) ; repli sur la dérivation net × (1 + taux).
  double get _total => bid.totalSenderAmountEur ?? (_amount + _commission);

  Future<void> _pay(BuildContext context) async {
    final authenticated = await requirePaymentAuth(
      context,
      authService: localAuthService,
      userPrefs: userPrefs,
    );
    if (!context.mounted) return;
    if (!authenticated) {
      DonySnackbar.show(
        context,
        message: 'Paiement non confirmé, réessayez',
        type: DonySnackbarType.error,
      );
      return;
    }
    unawaited(getIt<AnalyticsService>().logEvent(
      AnalyticsEvents.paymentInitiated,
      properties: {'method': 'card', 'amount': _total},
    ));
    context.read<PaymentBloc>().add(PaymentInitiated(bid.id));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = state is PaymentLoading;
    final error = state is PaymentError
        ? ErrorPresenter.resolve((state as PaymentError).error).message
        : null;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Payer mon envoi'),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(h, DonySpacing.xl, h, DonySpacing.huge),
          child: DonyLayout.constrained(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ContextualTutorialCard(
                  context: TutorialContext.payment,
                ),
                const SizedBox(height: DonySpacing.lg),
                _SummaryCard(
                  bid: bid,
                  amount: _amount,
                  commission: _commission,
                  total: _total,
                  commissionRate: commissionRate,
                ),
                const SizedBox(height: DonySpacing.lg),
                const DonyStatusBanner(
                  type: DonyStatusBannerType.info,
                  iconAsset: 'lock',
                  message:
                      'Votre paiement est sécurisé, libéré uniquement après confirmation de livraison par le destinataire.',
                ),
                const SizedBox(height: DonySpacing.xl),
                if (error != null) ...[
                  DonyStatusBanner(
                    type: DonyStatusBannerType.error,
                    message: error,
                  ),
                  const SizedBox(height: DonySpacing.lg),
                ],
                DonyButton(
                  label: 'Payer ${formatPriceIn(_total, bid.currency)}',
                  onPressed: isLoading ? null : () => _pay(context),
                  isLoading: isLoading,
                  iconAsset: 'lock',
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        );
      }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final BidModel bid;
  final double amount;
  final double commission;
  final double total;
  final double commissionRate;

  const _SummaryCard({
    required this.bid,
    required this.amount,
    required this.commission,
    required this.total,
    required this.commissionRate,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base, DonySpacing.base, DonySpacing.base, DonySpacing.md,
            ),
            child: Text(
              'Récapitulatif',
              style: tt.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base, vertical: DonySpacing.xs,
            ),
            child: Column(
              children: [
                if (bid.pricingMode == BidPricingMode.kg || bid.pricingMode == BidPricingMode.mixed) ...[
                  DonyInfoRow(
                    label: 'Poids',
                    value: bid.weightKg != null ? '${bid.weightKg!.toStringAsFixed(1)} kg' : '-',
                  ),
                  const DonyInfoRow.divider(),
                  DonyInfoRow(
                    label: 'Prix/kg',
                    // Tarif BRUT (net + commission). Le backend ne renvoie
                    // jamais le tarif net à l'expéditeur.
                    value: bid.senderPricePerKg != null
                        ? '${formatPriceIn(bid.senderPricePerKg!, bid.currency)}/kg'
                        : '-',
                  ),
                ] else if (bid.pricingMode == BidPricingMode.grid) ...[
                  DonyInfoRow(
                    label: 'Type',
                    value: 'Forfait articles',
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vous payez',
                  style: tt.titleMedium,
                ),
                Text(
                  formatPriceIn(total, bid.currency),
                  style: tt.headlineMedium?.copyWith(color: cs.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vue confirmation escrow ───────────────────────────────────────────────────

class _EscrowConfirmedView extends StatelessWidget {
  final double amount;
  final String currency;
  const _EscrowConfirmedView({required this.amount, required this.currency});

  @override
  Widget build(BuildContext context) {
    return DonySuccessScreen(
      mascotteType: DonyMascotteType.securise,
      title: 'Envoi réservé !',
      subtitle:
          '${formatPriceIn(amount, currency)} sont bloqués et sécurisés, puis libérés après confirmation de livraison par le destinataire.',
      ctaLabel: 'Voir mes envois',
      onCta: () => context.go('/home'),
      analyticsContext: 'escrow_payment',
    );
  }
}
