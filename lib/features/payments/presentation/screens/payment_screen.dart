import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final isLoading = state is PaymentLoading;
    final error = state is PaymentError ? (state as PaymentError).message : null;

    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          'Payer mon envoi',
          style: GoogleFonts.sora(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: DonyColors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(bid: bid, amount: _amount, commission: _commission),
            const SizedBox(height: 20),
            _EscrowInfoBanner(),
            const SizedBox(height: 24),
            if (error != null) ...[
              _ErrorBanner(message: error),
              const SizedBox(height: 20),
            ],
            _PayButton(amount: _amount, bidId: bid.id, isLoading: isLoading),
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
    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Récapitulatif',
              style: GoogleFonts.sora(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: DonyColors.ink900),
            ),
          ),
          const Divider(height: 1),
          _SummaryRow('Poids', '${bid.weightKg.toStringAsFixed(1)} kg'),
          const Divider(height: 1, indent: 16),
          _SummaryRow(
              'Prix/kg', '${(bid.pricePerKg ?? 0).toStringAsFixed(2)} €/kg'),
          const Divider(height: 1, indent: 16),
          _SummaryRow(
            'Montant',
            '${amount.toStringAsFixed(2)} €',
            valueStyle: GoogleFonts.sora(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: DonyColors.ink900),
          ),
          const Divider(height: 1, indent: 16),
          _SummaryRow(
            'Commission dony (12%)',
            '− ${commission.toStringAsFixed(2)} €',
            subtitle: 'Déduite du paiement voyageur',
            valueStyle: GoogleFonts.sora(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: DonyColors.grey400),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vous payez',
                  style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: DonyColors.ink900),
                ),
                Text(
                  '${amount.toStringAsFixed(2)} €',
                  style: GoogleFonts.sora(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: DonyColors.green400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final TextStyle? valueStyle;

  const _SummaryRow(this.label, this.value, {this.subtitle, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.sora(
                        fontSize: 14, color: DonyColors.grey400)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: GoogleFonts.sora(
                          fontSize: 11, color: DonyColors.grey200)),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: valueStyle ??
                GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: DonyColors.ink900),
          ),
        ],
      ),
    );
  }
}

class _EscrowInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DonyColors.green100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DonyColors.green400.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: DonyColors.green400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre paiement est sécurisé — libéré uniquement après confirmation de livraison par le destinataire.',
              style: GoogleFonts.sora(
                  fontSize: 13,
                  color: DonyColors.green600,
                  fontWeight: FontWeight.w500,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final double amount;
  final String bidId;
  final bool isLoading;

  const _PayButton({
    required this.amount,
    required this.bidId,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () =>
                context.read<PaymentBloc>().add(PaymentInitiated(bidId)),
        style: ElevatedButton.styleFrom(
          backgroundColor: DonyColors.green400,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                'Payer ${amount.toStringAsFixed(2)} €',
                style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DonyColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DonyColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: DonyColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.sora(
                  fontSize: 13,
                  color: DonyColors.error,
                  fontWeight: FontWeight.w500),
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
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text('Paiement confirmé',
            style: GoogleFonts.sora(
                fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: DonyColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: DonyColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: DonyColors.success, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Envoi réservé !',
              style: GoogleFonts.sora(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: DonyColors.ink900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${amount.toStringAsFixed(2)} € sont retenus en escrow et seront versés au voyageur après confirmation de livraison par le destinataire.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                  fontSize: 15, color: DonyColors.grey400, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DonyColors.green400,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Voir mes envois',
                  style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
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
