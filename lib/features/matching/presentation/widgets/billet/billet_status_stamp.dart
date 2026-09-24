import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Tampon de statut incliné affiché dans l'en-tête du billet.
class BilletStatusStamp extends StatelessWidget {
  final String status;

  /// Rôle du lecteur — déjà porté par `ColisBillet`, simplement transmis
  /// ici. Seul AWAITING_PAYMENT en dépend : côté expéditeur c'est lui qui
  /// doit payer (« À payer ») ; côté voyageur, rien à faire, juste attendre
  /// (« Paiement en attente ») — afficher « À payer » au voyageur n'a pas de
  /// sens (régression staging).
  final bool isSender;

  const BilletStatusStamp({
    super.key,
    required this.status,
    required this.isSender,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    final (Color color, String label) = switch (status) {
      'AWAITING_PAYMENT' => (
        cs.warning,
        isSender
            ? l.ticketStatusAwaitingPaymentSenderLabel
            : l.ticketStatusAwaitingPaymentTravelerLabel,
      ),
      'PENDING' ||
      'PAYMENT_ESCROWED' => (cs.warning, l.ticketStatusPendingLabel),
      'ACCEPTED' => (cs.success, l.ticketStatusAcceptedLabel),
      'HANDED_OVER' => (cs.primary, l.ticketStatusHandedOverLabel),
      'IN_TRANSIT' => (cs.primary, l.ticketStatusInTransitLabel),
      'ARRIVED' => (cs.primary, l.ticketStatusArrivedLabel),
      'COMPLETED' || 'DELIVERED' => (cs.success, l.ticketStatusDeliveredLabel),
      'REJECTED' => (cs.error, l.ticketStatusRejectedLabel),
      'CANCELLED' => (cs.onSurfaceVariant, l.ticketStatusCancelledLabel),
      // Statuts terminaux back-end (BidStatus) — libellés alignés sur
      // bid_list_screen / shipment_status_filter_sheet.
      'NO_SHOW' => (cs.warning, l.ticketStatusNoShowLabel),
      'PARCEL_REFUSED' => (cs.error, l.ticketStatusParcelRefusedLabel),
      'EXPIRED' => (cs.onSurfaceVariant, l.ticketStatusExpiredLabel),
      _ => (cs.onSurfaceVariant, status),
    };

    return Transform.rotate(
      angle: -0.087, // −5° en radians
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
