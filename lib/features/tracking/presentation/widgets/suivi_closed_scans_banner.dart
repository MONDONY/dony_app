import 'package:dony/core/di/injection.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_lost_photos_banner.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Remises scannées hors ligne puis refusées à la synchronisation : le colis
/// a été clos entre-temps (absence de l'expéditeur confirmée, annulation),
/// le back a répondu 422 `bid-not-accepted` et prévenu l'équipe. L'étape a
/// quitté la file ; le voyageur en est prévenu jusqu'à ce qu'il ferme le
/// message.
class SuiviClosedScansBanner extends StatelessWidget {
  const SuiviClosedScansBanner({super.key, required this.bidIds, this.sync});

  /// Colis du trajet, clos compris : un colis clos ne figure plus parmi les
  /// colis à valider.
  final Set<String> bidIds;

  /// Injecté en test ; sinon celui de l'app.
  final OfflineSyncService? sync;

  @override
  Widget build(BuildContext context) {
    final service = sync ?? getIt<OfflineSyncService>();
    final l = context.l10n;
    return ListenableBuilder(
      listenable: service.closedScanChanges,
      builder: (context, _) {
        final closed = service.closedScansFor(bidIds);
        if (closed.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final bidId in closed)
              SuiviSyncNotice(
                key: Key('suivi-closed-scan-$bidId'),
                iconAsset: 'circle-alert',
                message: l.suiviScanClosedBeforeSync,
                dismissTooltip: l.suiviScanClosedBeforeSyncDismiss,
                onDismiss: () => service.dismissClosedScan(bidId),
              ),
          ],
        );
      },
    );
  }
}
