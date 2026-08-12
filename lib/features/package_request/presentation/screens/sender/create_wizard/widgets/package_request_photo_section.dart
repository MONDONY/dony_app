import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/package_request/bloc/package_request_photo_upload.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Section « Photos du colis » (max 4) du wizard de demande. Lit
/// [PackageRequestPhotosCubit] depuis le provider ambiant. Les photos sont
/// uploadées immédiatement et propagées au bid quand un trajet est lié.
class PackageRequestPhotoSection extends StatelessWidget {
  const PackageRequestPhotoSection({super.key});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final cubit = context.read<PackageRequestPhotosCubit>();
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
    return BlocBuilder<
      PackageRequestPhotosCubit,
      List<PackageRequestPhotoUpload>
    >(
      builder: (context, photos) {
        final canAdd = photos.length < PackageRequestPhotosCubit.maxPhotos;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Photos du colis',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${photos.length} / ${PackageRequestPhotosCubit.maxPhotos}',
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Visibles par les voyageurs. Ajoutées à l\'offre quand un trajet est lié.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: DonySpacing.sm),
            // Vide : un seul CTA plein largeur — c'est la première chose que
            // l'expéditeur doit remarquer sur cette étape, pas une case parmi
            // d'autres qu'on peut manquer si on ne fait pas attention.
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
                      onRemove: () => context
                          .read<PackageRequestPhotosCubit>()
                          .remove(p.localId),
                      onTapFailed: () => DonySnackbar.show(
                        context,
                        message: p.error == null
                            ? 'Échec de l\'upload de la photo'
                            : 'Échec : ${p.error}',
                        type: DonySnackbarType.error,
                      ),
                    ),
                  if (canAdd)
                    Semantics(
                      button: true,
                      container: true,
                      excludeSemantics: true,
                      label: 'Ajouter une photo du colis',
                      child: GestureDetector(
                        key: const Key('pr-add-photo'),
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

/// CTA plein largeur affiché tant qu'aucune photo n'est ajoutée — plus visible
/// qu'une case de 64 px perdue au milieu de l'étape.
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
        key: const Key('pr-add-photo'),
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
  const _PhotoThumb({
    required this.upload,
    required this.onRemove,
    this.onTapFailed,
  });
  final PackageRequestPhotoUpload upload;
  final VoidCallback onRemove;
  final VoidCallback? onTapFailed;

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
            child: upload.isRemote
                ? CachedNetworkImage(
                    imageUrl: upload.remoteUrl!,
                    cacheKey: DonyImage.stableCacheKey(upload.remoteUrl!),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        ColoredBox(color: cs.surfaceContainerHighest),
                    errorWidget: (_, _, _) => ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: cs.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                  )
                : Image.file(
                    File(upload.localPath),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
          ),
          if (upload.status == PackageRequestPhotoUploadStatus.uploading)
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
          if (upload.status == PackageRequestPhotoUploadStatus.failed)
            Positioned.fill(
              child: Semantics(
                button: true,
                container: true,
                excludeSemantics: true,
                label: "Réessayer l'envoi de la photo",
                child: GestureDetector(
                  onTap: onTapFailed,
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
              ),
            ),
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
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: cs.surface,
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
