import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Étapes de ces colis parties sans leur photo, disparue du téléphone
/// pendant l'attente dans la file hors ligne (FLUTTER-MJ). Le back accepte
/// l'étape sans photo : elle est enregistrée, l'utilisateur en est prévenu
/// jusqu'à ce qu'il ferme le message.
class SuiviLostPhotosBanner extends StatelessWidget {
  const SuiviLostPhotosBanner({super.key, required this.bidIds, this.sync});

  final Set<String> bidIds;

  /// Injecté en test ; sinon celui de l'app.
  final OfflineSyncService? sync;

  @override
  Widget build(BuildContext context) {
    final service = sync ?? getIt<OfflineSyncService>();
    return ListenableBuilder(
      listenable: service.lostPhotoChanges,
      builder: (context, _) {
        final lost = service.lostPhotosFor(bidIds);
        if (lost.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final photo in lost)
              _LostPhotoNotice(
                lost: photo,
                onDismiss: () => service.dismissLostPhoto(photo),
              ),
          ],
        );
      },
    );
  }
}

class _LostPhotoNotice extends StatelessWidget {
  const _LostPhotoNotice({required this.lost, required this.onDismiss});

  final LostTrackingPhoto lost;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Material(
        key: Key('suivi-lost-photo-${lost.bidId}-${lost.eventType}'),
        color: cs.surfaceWarm,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        child: Padding(
          padding: const EdgeInsets.only(
            left: DonySpacing.md,
            top: DonySpacing.xs,
            bottom: DonySpacing.xs,
          ),
          child: Row(
            children: [
              DonyIcon('image-off', size: 18, color: cs.onSurface),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  l.suiviPhotoLost(trackingStepLabel(l, lost.eventType)),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                ),
              ),
              IconButton(
                tooltip: l.suiviPhotoLostDismiss,
                onPressed: onDismiss,
                icon: DonyIcon('x', size: 16, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
