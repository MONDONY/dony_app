import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
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
          return _EscrowConfirmedView(amount: state.amount);
        }
        return BlocBuilder<ConfigBloc, ConfigState>(
          builder: (context, configState) {
            final commissionRate = configState is ConfigLoaded
                ? configState.commissionRate
                : 0.12; // Fallback to 12% while loading or on error
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
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'dony',
          paymentIntentClientSecret: state.clientSecret,
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      if (context.mounted) {
        context.read<PaymentBloc>().add(const PaymentSheetCompleted());
      }
    } on StripeException catch (e) {
      if (context.mounted && e.error.code != FailureCode.Canceled) {
        context.read<PaymentBloc>().add(
            PaymentFailed(e.error.localizedMessage ?? 'Paiement refusé'));
      }
    } catch (_) {
      if (context.mounted) {
        context
            .read<PaymentBloc>()
            .add(const PaymentFailed('Erreur lors du paiement'));
      }
    }
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

  double get _amount => bid.totalAmountEur ?? (bid.weightKg ?? 0) * (bid.pricePerKg ?? 0);
  double get _commission => _amount * commissionRate;

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
        message: 'Authentification requise pour effectuer le paiement',
        type: DonySnackbarType.error,
      );
      return;
    }
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
                _SummaryCard(
                  bid: bid,
                  amount: _amount,
                  commission: _commission,
                  commissionRate: commissionRate,
                ),
                const SizedBox(height: DonySpacing.lg),
                const DonyStatusBanner(
                  type: DonyStatusBannerType.info,
                  icon: Icons.lock_rounded,
                  message:
                      'Votre paiement est sécurisé — libéré uniquement après confirmation de livraison par le destinataire.',
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
                  label: 'Payer ${_amount.toStringAsFixed(2)} €',
                  onPressed: isLoading ? null : () => _pay(context),
                  isLoading: isLoading,
                  icon: Icons.lock_rounded,
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
  final double commissionRate;

  const _SummaryCard({
    required this.bid,
    required this.amount,
    required this.commission,
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
                    value: bid.weightKg != null ? '${bid.weightKg!.toStringAsFixed(1)} kg' : '—',
                  ),
                  const DonyInfoRow.divider(),
                  DonyInfoRow(
                    label: 'Prix/kg',
                    value: bid.pricePerKg != null ? '${bid.pricePerKg!.toStringAsFixed(2)} €/kg' : '—',
                  ),
                  const DonyInfoRow.divider(),
                ],
                if (bid.pricingMode == BidPricingMode.grid) ...[
                  DonyInfoRow(
                    label: 'Type',
                    value: 'Forfait articles',
                  ),
                  const DonyInfoRow.divider(),
                ],
                DonyInfoRow(
                  label: 'Montant',
                  value: '${amount.toStringAsFixed(2)} €',
                ),
                const DonyInfoRow.divider(),
                DonyInfoRow(
                  label: 'Commission dony (${(commissionRate * 100).toStringAsFixed(0)}%)',
                  value: '− ${commission.toStringAsFixed(2)} €',
                  valueStyle: DonyInfoRowValueStyle.muted,
                ),
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
                  '${amount.toStringAsFixed(2)} €',
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
  const _EscrowConfirmedView({required this.amount});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(
        title: 'Paiement confirmé',
        showBackButton: false,
      ),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.huge),
          child: DonyLayout.constrained(
            context,
            Column(
              children: [
                const SizedBox(height: DonySpacing.xxl),
                const DonyMascotteAnimated(
                  type: DonyMascotteType.securise,
                  size: DonyMascotteSize.lg,
                  withGlow: true,
                ),
                const SizedBox(height: DonySpacing.xl),
                Text(
                  'Envoi réservé !',
                  style: tt.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.md),
                Text(
                  '${amount.toStringAsFixed(2)} € sont retenus en escrow et seront versés au voyageur après confirmation de livraison par le destinataire.',
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxl),
                DonyButton(
                  label: 'Voir mes envois',
                  onPressed: () => context.go('/home'),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutCubic),
          ),
        );
      }),
    );
  }
}
