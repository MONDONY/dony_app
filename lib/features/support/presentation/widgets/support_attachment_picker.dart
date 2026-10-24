import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Choix des images jointes à un ticket (« + » et appareil photo de la barre de
/// saisie).
///
/// - Réutilise [DonyMediaService] (même chemin que les photos de demande :
///   compression JPEG 85 %, max 1920 × 1080, plafond 50 Mo).
/// - Max [max] images : au quatrième, « + » et l'appareil photo sont grisés.
/// - La sélection émet [SupportAttachmentPickRequested] ; le retrait (vignette)
///   émet [SupportAttachmentRemoved]. Tout l'état vit dans le BLoC.
abstract final class SupportAttachmentActions {
  static const int max = 4;

  /// Une prise est en cours : un second tap la ferait échouer côté
  /// `image_picker` (multiple_request) avec un message d'erreur à tort.
  static bool _picking = false;

  static Future<void> pick(BuildContext context, ImageSource source) async {
    if (_picking) return;
    _picking = true;
    try {
      final file = await getIt<DonyMediaService>().pick(source: source);
      if (file != null && context.mounted) {
        context.read<SupportBloc>().add(
          SupportAttachmentPickRequested(file.path),
        );
      }
    } catch (_) {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message: context.l10n.commonImageUnsupported,
          type: DonySnackbarType.error,
        );
      }
    } finally {
      _picking = false;
    }
  }

  static void showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) {
        final l = context.l10n;
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_rounded, color: cs.primary),
                title: Text(l.commonTakePhoto),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  pick(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: cs.primary),
                title: Text(l.commonPickFromGallery),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  pick(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rangée de vignettes d'images en attente, au-dessus de la barre de saisie.
/// Rien quand aucune image n'est en attente.
///
/// Ne jamais instancier depuis un ticket résolu : `_TicketThread` n'affiche la
/// barre de saisie que quand `!ticket.isResolved`.
class SupportAttachmentStrip extends StatelessWidget {
  const SupportAttachmentStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      buildWhen: (prev, curr) =>
          prev.pendingAttachments != curr.pendingAttachments,
      builder: (context, state) {
        final attachments = state.pendingAttachments;
        if (attachments.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              for (final att in attachments)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _AttachmentThumb(
                    upload: att,
                    onRemove: () => context.read<SupportBloc>().add(
                      SupportAttachmentRemoved(att.localId),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Vignette d'une image en attente d'envoi.
///
/// - `uploading` : indicateur de progression par-dessus l'image locale.
/// - `ready`    : image locale avec pastille de retrait.
/// - `failed`   : overlay rouge + icone d'erreur + pastille de retrait.
class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.upload, required this.onRemove});

  final SupportAttachmentUpload upload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Image locale
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: Image.file(
              File(upload.localPath),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 64,
                height: 64,
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ),
          // Overlay uploading
          if (upload.status == SupportUploadStatus.uploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          // Overlay failed
          if (upload.status == SupportUploadStatus.failed)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: cs.error,
                  size: 18,
                ),
              ),
            ),
          // Bouton de retrait (zone de tap 44 × 44, visuel 20 × 20).
          // Positionné à top: 0 / right: 0 pour rester dans les bornes du Stack
          // de 64 × 64 : Clip.none n'affecte que la peinture, pas le hit-test,
          // et un bouton à -18/-18 réduit la zone tapable à ~26 × 26.
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              label: context.l10n.supportRemoveAttachmentLabel,
              child: GestureDetector(
                key: Key('remove-attachment-${upload.localId}'),
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: cs.onSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
