import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Couleurs et libellé d'un badge d'état de colis.
typedef ParcelStatusBadge = ({Color bg, Color fg, String label});

/// Badge d'état d'un colis à partir du statut brut du bid, partagé par la
/// carte « Mes envois » et la liste des conversations (FLUTTER-EZ).
///
/// Couleur sémantique du design system : attente (warning), en route (info),
/// livré (success), clos (neutre). [returnPending] — colis annulé après remise,
/// pas encore rendu à l'expéditeur — prime sur le statut : c'est la seule
/// chose qui reste à faire.
///
/// `null` pour un statut sans badge (négociation, statut inconnu d'un back
/// plus récent) : l'appelant choisit son repli.
ParcelStatusBadge? parcelStatusBadge(
  ColorScheme cs,
  AppLocalizations l,
  String? status, {
  bool returnPending = false,
}) {
  if (returnPending) {
    return (
      bg: cs.warningLight,
      fg: cs.warning,
      label: l.shipmentBadgeReturnPending,
    );
  }
  ParcelStatusBadge closed(String label) =>
      (bg: DonyColors.neutral100, fg: cs.onSurfaceVariant, label: label);
  return switch (status) {
    'IN_TRANSIT' => (
      bg: cs.infoLight,
      fg: cs.info,
      label: l.shipmentBadgeInTransit,
    ),
    'ARRIVED' => (bg: cs.infoLight, fg: cs.info, label: l.shipmentBadgeArrived),
    'HANDED_OVER' => (
      bg: cs.infoLight,
      fg: cs.info,
      label: l.shipmentBadgeHandedOver,
    ),
    'ACCEPTED' => (
      bg: cs.warningLight,
      fg: cs.warning,
      label: l.shipmentBadgeToHandOver,
    ),
    'PENDING' || 'AWAITING_PAYMENT' || 'PAYMENT_ESCROWED' => (
      bg: cs.warningLight,
      fg: cs.warning,
      label: l.shipmentBadgeWaiting,
    ),
    'COMPLETED' => (
      bg: cs.successLight,
      fg: cs.success,
      label: l.shipmentBadgeDelivered,
    ),
    // Le motif réel plutôt qu'un « TERMINÉ » générique, qui ne disait pas
    // ce qui s'était passé. Vocabulaire aligné sur la feuille de filtre.
    'CANCELLED' => closed(l.shipmentBadgeCancelled),
    'REJECTED' => closed(l.shipmentBadgeRejected),
    'NO_SHOW' => closed(l.shipmentBadgeNoShow),
    'EXPIRED' => closed(l.shipmentBadgeExpired),
    'PARCEL_REFUSED' => closed(l.shipmentBadgeParcelRefused),
    _ => null,
  };
}

/// Pastille d'état (point + libellé). [compact] la resserre pour une ligne
/// de liste dense, comme la tuile de conversation.
class ParcelStatusPill extends StatelessWidget {
  const ParcelStatusPill({
    super.key,
    required this.badge,
    this.compact = false,
  });

  final ParcelStatusBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dot = compact ? 5.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : DonySpacing.sm,
        vertical: compact ? 2 : DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badge.bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: badge.fg, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            badge.label,
            maxLines: 1,
            style: (compact ? tt.labelSmall : tt.labelMedium)?.copyWith(
              color: badge.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
