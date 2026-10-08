import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Variante visuelle du hero card selon le statut négociation.
enum ThreadStatusVariant {
  open,
  awaitingTrip,
  awaitingPayment,
  awaitingCommission,
  awaitingDeposit,
  accepted,
  terminal;

  static ThreadStatusVariant fromThread(NegotiationThreadStatus s) =>
      switch (s) {
        NegotiationThreadStatus.open => open,
        NegotiationThreadStatus.awaitingTrip => awaitingTrip,
        NegotiationThreadStatus.awaitingPayment => awaitingPayment,
        NegotiationThreadStatus.awaitingCommission => awaitingCommission,
        NegotiationThreadStatus.awaitingDeposit => awaitingDeposit,
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
    // Le dépôt mobile money est une étape du paiement : même violet.
    awaitingPayment || awaitingDeposit => DonyColors.threadStatusViolet,
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
    awaitingPayment || awaitingDeposit => const LinearGradient(
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

  String get iconAsset => switch (this) {
    open => 'handshake',
    awaitingTrip => 'hourglass',
    awaitingPayment => 'credit-card',
    awaitingCommission => 'banknote',
    awaitingDeposit => 'smartphone',
    accepted => 'circle-check',
    terminal => 'circle-x',
  };
}

/// Libellés traduits de [ThreadStatusVariant] : pastille de statut et
/// libellé au-dessus du prix. Repris tels quels par `_StatusPill`
/// (my_negotiations_screen.dart) — même texte, même clé.
extension ThreadStatusVariantL10n on ThreadStatusVariant {
  String badge(AppLocalizations l) => switch (this) {
    ThreadStatusVariant.open => l.negotiationStatusBadgeOpen,
    ThreadStatusVariant.awaitingTrip => l.negotiationStatusBadgeAwaitingTrip,
    ThreadStatusVariant.awaitingPayment =>
      l.negotiationStatusBadgeAwaitingPayment,
    ThreadStatusVariant.awaitingCommission =>
      l.negotiationStatusBadgeAwaitingCommission,
    ThreadStatusVariant.awaitingDeposit =>
      l.negotiationStatusBadgeAwaitingDeposit,
    ThreadStatusVariant.accepted => l.negotiationStatusBadgeAccepted,
    ThreadStatusVariant.terminal => l.negotiationStatusBadgeTerminal,
  };

  String priceLabel(AppLocalizations l) => switch (this) {
    ThreadStatusVariant.open => l.negotiationStatusPriceLabelOpen,
    ThreadStatusVariant.awaitingTrip =>
      l.negotiationStatusPriceLabelAwaitingTrip,
    ThreadStatusVariant.awaitingPayment =>
      l.negotiationStatusPriceLabelAwaitingPayment,
    ThreadStatusVariant.awaitingCommission =>
      l.negotiationStatusPriceLabelAwaitingCommission,
    ThreadStatusVariant.awaitingDeposit =>
      l.negotiationStatusPriceLabelAwaitingDeposit,
    ThreadStatusVariant.accepted => l.negotiationStatusPriceLabelAccepted,
    ThreadStatusVariant.terminal => l.negotiationStatusPriceLabelTerminal,
  };
}

/// Hero card du thread de négociation — gradient status, prix, badge, progress.
///
/// Adaptateur du fil « demande de colis » sur [DonyNegoHeroCard], partagé avec
/// le fil de prix d'un trajet.
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

  static const _maxRounds = 5;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonyNegoHeroCard(
      gradient: statusVariant.gradient,
      shadowColor: statusVariant.shadowColor,
      iconAsset: statusVariant.iconAsset,
      caption: statusVariant.priceLabel(l),
      amount: threadPriceLabel(
        l,
        thread.currentPriceEur,
        thread.grossPriceEur,
        isTraveler,
        thread.currency,
      ),
      badgeLabel: statusVariant.badge(l),
      roundLabel: l.negotiationRoundCounter(
        thread.roundsCount.clamp(0, _maxRounds),
        _maxRounds,
      ),
      roundsCount: thread.roundsCount,
      maxRounds: _maxRounds,
      warning:
          thread.roundsRemaining == 0 &&
              thread.status == NegotiationThreadStatus.open
          ? l.negotiationLastRoundWarning
          : null,
    );
  }
}
