import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';

class PaymentScreen extends StatelessWidget {
  final BidModel bid;

  const PaymentScreen({super.key, required this.bid});

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
        return _PaymentSummaryView(bid: bid, state: state);
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

  const _PaymentSummaryView({required this.bid, required this.state});

  double get _amount => bid.weightKg * (bid.pricePerKg ?? 0);
  double get _commission => _amount * 0.12;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = state is PaymentLoading;
    final error = state is PaymentError ? (state as PaymentError).message : null;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Payer mon envoi'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(bid: bid, amount: _amount, commission: _commission),
            const SizedBox(height: DonySpacing.lg),
            _EscrowInfoBanner(),
            const SizedBox(height: DonySpacing.xl),
            if (error != null) ...[
              _ErrorBanner(message: error, cs: cs),
              const SizedBox(height: DonySpacing.lg),
            ],
            DonyButton(
              label: 'Payer ${_amount.toStringAsFixed(2)} €',
              onPressed: isLoading
                  ? null
                  : () => context
                      .read<PaymentBloc>()
                      .add(PaymentInitiated(bid.id)),
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
  }
}

class _SummaryCard extends StatelessWidget {
  final BidModel bid;
  final double amount;
  final double commission;

  const _SummaryCard({
    required this.bid,
    required this.amount,
    required this.commission,
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
                DonyInfoRow(
                  label: 'Poids',
                  value: '${bid.weightKg.toStringAsFixed(1)} kg',
                ),
                const DonyInfoRow.divider(),
                DonyInfoRow(
                  label: 'Prix/kg',
                  value: '${(bid.pricePerKg ?? 0).toStringAsFixed(2)} €/kg',
                ),
                const DonyInfoRow.divider(),
                DonyInfoRow(
                  label: 'Montant',
                  value: '${amount.toStringAsFixed(2)} €',
                ),
                const DonyInfoRow.divider(),
                DonyInfoRow(
                  label: 'Commission dony (12%)',
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

class _EscrowInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: cs.primary, size: 20),
          const SizedBox(width: DonySpacing.sm + 2),
          Expanded(
            child: Text(
              'Votre paiement est sécurisé — libéré uniquement après confirmation de livraison par le destinataire.',
              style: tt.bodySmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final ColorScheme cs;
  const _ErrorBanner({required this.message, required this.cs});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
          const SizedBox(width: DonySpacing.sm + 2),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w500,
              ),
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.xl, 0, DonySpacing.xl, DonySpacing.huge,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: cs.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: cs.success, size: 48),
            ),
            const SizedBox(height: DonySpacing.xl),
            Text(
              'Envoi réservé !',
              style: tt.displayLarge,
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
  }
}
