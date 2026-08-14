import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Section optionnelle « Photos du colis » du formulaire de création de bid.
/// Lit [BidPhotosCubit] depuis le provider ambiant. Max 4 photos.
class PhotoSection extends StatelessWidget {
  const PhotoSection({super.key});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final cubit = context.read<BidPhotosCubit>();
    try {
      final file = await getIt<DonyMediaService>().pick(source: source);
      if (file != null) {
        await cubit.add(file.path);
      }
    } catch (_) {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message: 'Image non supportée ou trop volumineuse',
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocBuilder<BidPhotosCubit, List<BidPhotoUpload>>(
      builder: (context, photos) {
        final canAdd = photos.length < BidPhotosCubit.maxPhotos;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Visibles par le voyageur, elles rassurent sur le contenu.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  '${photos.length} / ${BidPhotosCubit.maxPhotos}',
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),
            // Vide : un seul CTA plein largeur, comme le wizard de demande
            // d'envoi. Une case de 64 px se rate quand on fait défiler vite.
            if (photos.isEmpty)
              _AddPhotoCta(onTap: () => _showSourceSheet(context))
            else
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  for (final p in photos)
                    _PhotoThumb(
                      upload: p,
                      onRemove: () =>
                          context.read<BidPhotosCubit>().remove(p.localId),
                    ),
                  if (canAdd)
                    Semantics(
                      button: true,
                      container: true,
                      excludeSemantics: true,
                      label: 'Ajouter une photo du colis',
                      child: GestureDetector(
                        key: const Key('bid-add-photo'),
                        onTap: () => _showSourceSheet(context),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(DonyRadius.md),
                            border: Border.all(color: cs.primary, width: 2),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: cs.primary,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// CTA plein largeur affiché tant qu'aucune photo n'est ajoutée — même
/// traitement que le wizard « demande d'envoi ».
class _AddPhotoCta extends StatelessWidget {
  const _AddPhotoCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Ajouter une photo du colis',
      child: GestureDetector(
        key: const Key('bid-add-photo'),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.primary, width: 2),
          ),
          child: Column(
            children: [
              Icon(Icons.add_a_photo_rounded, color: cs.primary, size: 30),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Ajouter une photo',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Fortement recommandé, rassure le voyageur',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.upload, required this.onRemove});
  final BidPhotoUpload upload;
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
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: Image.file(
              File(upload.localPath),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          if (upload.status == BidPhotoUploadStatus.uploading)
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
          if (upload.status == BidPhotoUploadStatus.failed)
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
          // Visuel 20×20 mais zone tap 44×44 (HIG) : box centré, décalé pour
          // garder le cercle à ~top:-6/right:-6 du thumbnail.
          Positioned(
            top: -18,
            right: -18,
            child: Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              label: 'Supprimer cette photo',
              child: GestureDetector(
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
