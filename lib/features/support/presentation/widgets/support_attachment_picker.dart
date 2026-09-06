import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Rangée de vignettes d'images en attente + bouton trombone.
///
/// - Réutilise [DonyMediaService] (même chemin que les photos de demande :
///   compression JPEG 85 %, max 1920 × 1080, plafond 50 Mo).
/// - Max 4 images. Le trombone est désactivé au quatrième.
/// - La sélection émet [SupportAttachmentPickRequested] ; le retrait émet
///   [SupportAttachmentRemoved]. Tout l'état vit dans le BLoC.
/// - Ne jamais appeler depuis un ticket résolu : [_TicketThread] ne l'instancie
///   que quand `!ticket.isResolved`.
class SupportAttachmentPicker extends StatelessWidget {
  const SupportAttachmentPicker({required this.ticketId, super.key});

  final String ticketId;

  static const int _maxAttachments = 4;

  Future<void> _pick(BuildContext context, ImageSource source) async {
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
          message: 'Image non supportee ou trop volumineuse',
          type: DonySnackbarType.error,
        );
      }
    }
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_rounded, color: cs.primary),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pick(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: cs.primary),
                title: const Text('Choisir dans la galerie'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pick(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      buildWhen: (prev, curr) =>
          prev.pendingAttachments != curr.pendingAttachments,
      builder: (context, state) {
        final attachments = state.pendingAttachments;
        final canAdd = attachments.length < _maxAttachments;

        if (attachments.isEmpty) {
          return IconButton(
            tooltip: 'Joindre une image',
            onPressed: canAdd ? () => _showSourceSheet(context) : null,
            icon: const Icon(Icons.attach_file_rounded),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rangée de vignettes
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
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
                  // Bouton d'ajout inline quand la liste n'est pas pleine
                  if (canAdd)
                    IconButton(
                      tooltip: 'Joindre une image',
                      onPressed: () => _showSourceSheet(context),
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                ],
              ),
            ),
          ],
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
          // Bouton de retrait (44 × 44 tap target, visuel 20 × 20)
          Positioned(
            top: -18,
            right: -18,
            child: Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              label: 'Retirer cette image',
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
