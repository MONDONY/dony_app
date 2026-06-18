import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:flutter/material.dart';

/// Chip statut réel d'une demande d'envoi (piloté par [PackageRequestStatus]).
/// Réutilisé par la carte (feed) et l'écran détail.
Widget packageStatusChip(BuildContext context, PackageRequestStatus status) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final (String label, Color bg, Color fg) = switch (status) {
    PackageRequestStatus.open => ('Ouverte', cs.successLight, cs.success),
    PackageRequestStatus.negotiating =>
      ('En négociation', cs.warningLight, cs.warning),
    PackageRequestStatus.accepted => ('Acceptée', cs.infoLight, cs.info),
    PackageRequestStatus.expired =>
      ('Expirée', cs.surfaceContainerHighest, cs.onSurfaceVariant),
    PackageRequestStatus.cancelled => ('Annulée', cs.errorLight, cs.error),
    PackageRequestStatus.completed => ('Livrée', cs.successLight, cs.success),
  };
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(DonyRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
        ),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: fg,
            letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );
}
