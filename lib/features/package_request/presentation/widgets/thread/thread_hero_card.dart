import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Variante visuelle du hero card selon le statut négociation.
///
/// Match maquettes v3 :
/// - `open`           → ink-900 (bleu nuit · maquette 20-44-27)
/// - `awaitingTrip`   → amber  (ambre   · maquette 20-44-57)
/// - `awaitingPayment`→ violet (critique· maquette 20-45-03)
/// - `accepted`       → green  (success · maquette 20-45-14)
/// - `terminal`       → grey   (rejected / expired / auto-rejected)
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

  Color get tint => switch (this) {
        open => const Color(0xFF0E1B2E), // ink-900 navy
        awaitingTrip => const Color(0xFFB5781E), // amber strong
        awaitingPayment => const Color(0xFF5B21B6), // violet strong
        accepted => const Color(0xFF15803D), // green strong
        terminal => const Color(0xFF6B7280), // neutral grey
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

/// Hero card du thread de négociation — prix actuel, status badge, progress
/// du round (X/5 en dots colorés).
///
/// Couleur de fond selon `statusVariant.tint` (5 couleurs).
class ThreadHeroCard extends StatelessWidget {
  const ThreadHeroCard({
    super.key,
    required this.thread,
    required this.statusVariant,
  });

  final NegotiationThread thread;
  final ThreadStatusVariant statusVariant;

  @override
  Widget build(BuildContext context) {
    final tint = statusVariant.tint;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusVariant.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusVariant.priceLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${thread.currentPriceEur.toStringAsFixed(0)} €',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
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
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Indicator visuel du round (X/5) — N dots remplis (active), (5-N) dots
/// faibles. Le compteur "Round X/5" est affiché à gauche.
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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (int i = 0; i < max; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: 20,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < n
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
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

