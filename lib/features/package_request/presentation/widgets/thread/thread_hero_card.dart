import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter/material.dart';

/// Variante visuelle du hero card selon le statut négociation.
enum ThreadStatusVariant {
  open,
  awaitingTrip,
  awaitingPayment,
  accepted,
  terminal;

  static ThreadStatusVariant fromThread(NegotiationThreadStatus s) =>
      switch (s) {
        NegotiationThreadStatus.open => open,
        NegotiationThreadStatus.awaitingTrip => awaitingTrip,
        NegotiationThreadStatus.awaitingPayment => awaitingPayment,
        NegotiationThreadStatus.accepted => accepted,
        NegotiationThreadStatus.rejected ||
        NegotiationThreadStatus.autoRejected ||
        NegotiationThreadStatus.expired =>
          terminal,
      };

  /// Couleur du bas de la shadow et du glow
  Color get shadowColor => switch (this) {
        open => const Color(0xFF0B5FFF),
        awaitingTrip => DonyColors.threadStatusAmber,
        awaitingPayment => DonyColors.threadStatusViolet,
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
        accepted => 'ACCEPTÉE',
        terminal => 'TERMINÉ',
      };

  String get priceLabel => switch (this) {
        open => 'PRIX ACTUEL',
        awaitingTrip => 'ACCORD TROUVÉ',
        awaitingPayment => 'À RÉGLER',
        accepted => 'DEMANDE ACCEPTÉE',
        terminal => 'PRIX FINAL',
      };

  IconData get icon => switch (this) {
        open => Icons.handshake_rounded,
        awaitingTrip => Icons.hourglass_top_rounded,
        awaitingPayment => Icons.credit_card_rounded,
        accepted => Icons.check_circle_rounded,
        terminal => Icons.cancel_outlined,
      };
}

/// Hero card du thread de négociation — gradient status, prix, badge, progress.
class ThreadHeroCard extends StatelessWidget {
  const ThreadHeroCard({
    super.key,
    required this.thread,
    required this.statusVariant,
    this.onTap,
  });

  final NegotiationThread thread;
  final ThreadStatusVariant statusVariant;

  /// Si non null, le card devient cliquable et affiche une affordance
  /// « Voir le trajet lié » en bas.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.fromLTRB(
          DonySpacing.base, DonySpacing.md, DonySpacing.base, DonySpacing.sm),
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
                      child: Icon(statusVariant.icon,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusVariant.priceLabel,
                            style:
                                Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.70),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${thread.currentPriceEur.toStringAsFixed(0)} €',
                            style:
                                Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
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
                if (onTap != null) ...[
                  const SizedBox(height: 12),
                  const _ViewTripHint(),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }
    return GestureDetector(onTap: onTap, child: card);
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

class _ViewTripHint extends StatelessWidget {
  const _ViewTripHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 15, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            'Voir le trajet lié',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: Colors.white.withValues(alpha: 0.85)),
        ],
      ),
    );
  }
}
