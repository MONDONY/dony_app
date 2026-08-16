import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Variante visuelle du hero card selon le statut négociation.
enum ThreadStatusVariant {
  open,
  awaitingTrip,
  awaitingPayment,
  awaitingCommission,
  accepted,
  terminal;

  static ThreadStatusVariant fromThread(NegotiationThreadStatus s) =>
      switch (s) {
        NegotiationThreadStatus.open => open,
        NegotiationThreadStatus.awaitingTrip => awaitingTrip,
        NegotiationThreadStatus.awaitingPayment => awaitingPayment,
        NegotiationThreadStatus.awaitingCommission => awaitingCommission,
        NegotiationThreadStatus.accepted => accepted,
        NegotiationThreadStatus.rejected ||
        NegotiationThreadStatus.autoRejected ||
        NegotiationThreadStatus.expired ||
        NegotiationThreadStatus.cancelled => terminal,
      };

  /// Couleur du bas de la shadow et du glow
  Color get shadowColor => switch (this) {
    open => const Color(0xFF0B5FFF),
    awaitingTrip => DonyColors.threadStatusAmber,
    awaitingPayment => DonyColors.threadStatusViolet,
    awaitingCommission => DonyColors.threadStatusOrange,
    accepted => DonyColors.threadStatusGreen,
    terminal => const Color(0xFF374151),
  };

  LinearGradient get gradient => switch (this) {
    open => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A2540), Color(0xFF1A3A6B)],
    ),
    awaitingTrip => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF78350F), Color(0xFFB5781E)],
    ),
    awaitingPayment => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4C1D95), Color(0xFF5B21B6)],
    ),
    // Accord en espèces conclu mais rien n'est scellé : distinct du violet
    // « paiement carte » pour ne pas laisser croire que l'affaire est faite.
    awaitingCommission => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C2D12), Color(0xFFC2410C)],
    ),
    accepted => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF14532D), Color(0xFF15803D)],
    ),
    terminal => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F2937), Color(0xFF6B7280)],
    ),
  };

  String get badge => switch (this) {
    open => 'EN COURS',
    awaitingTrip => 'ATT. TRAJET',
    awaitingPayment => 'PAIEMENT',
    awaitingCommission => 'COMMISSION',
    accepted => 'ACCEPTÉE',
    terminal => 'TERMINÉ',
  };

  String get priceLabel => switch (this) {
    open => 'PRIX ACTUEL',
    awaitingTrip => 'ACCORD TROUVÉ',
    awaitingPayment => 'À RÉGLER',
    awaitingCommission => 'COMMISSION DUE',
    accepted => 'DEMANDE ACCEPTÉE',
    terminal => 'PRIX FINAL',
  };

  String get iconAsset => switch (this) {
    open => 'handshake',
    awaitingTrip => 'hourglass',
    awaitingPayment => 'credit-card',
    awaitingCommission => 'banknote',
    accepted => 'circle-check',
    terminal => 'circle-x',
  };
}

/// Hero card du thread de négociation — gradient status, prix, badge, progress.
class ThreadHeroCard extends StatelessWidget {
  const ThreadHeroCard({
    super.key,
    required this.thread,
    required this.statusVariant,
    required this.isTraveler,
  });

  final NegotiationThread thread;
  final ThreadStatusVariant statusVariant;

  /// Whether the current viewer is the traveler.
  /// - Traveler sees "Tu reçois X €" (net = currentPriceEur)
  /// - Sender sees "Tu paies X €" (gross = grossPriceEur or computed)
  final bool isTraveler;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.md,
        DonySpacing.base,
        DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: statusVariant.gradient,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        boxShadow: [
          BoxShadow(
            color: statusVariant.shadowColor.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Glow circle décoration top-right
          Positioned(
            top: -24,
            right: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Contenu
          Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DonySpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DonyIcon(
                        statusVariant.iconAsset,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusVariant.priceLabel,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.70),
                                  letterSpacing: 0.8,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            PriceDisplay.threadPriceLabel(
                              thread.currentPriceEur,
                              thread.grossPriceEur,
                              isTraveler,
                              thread.currency,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(label: statusVariant.badge),
                  ],
                ),
                const SizedBox(height: 14),
                _RoundProgress(roundsCount: thread.roundsCount, max: 5),
                if (thread.roundsRemaining == 0 &&
                    thread.status == NegotiationThreadStatus.open) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.20),
                      // Concentric with parent card (DonyRadius.card - padding)
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚠ Dernier round : Accepter ou Refuser uniquement',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade200,
                        // Tabular numbers for any numeric context
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RoundProgress extends StatelessWidget {
  const _RoundProgress({required this.roundsCount, required this.max});
  final int roundsCount;
  final int max;

  @override
  Widget build(BuildContext context) {
    final n = roundsCount.clamp(0, max);
    return Row(
      children: [
        Text(
          'Round $n/$max',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (int i = 0; i < max; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < n
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
