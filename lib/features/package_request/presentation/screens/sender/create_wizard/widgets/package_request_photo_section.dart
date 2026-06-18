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
                  GestureDetector(
                    key: const Key('pr-add-photo'),
                    onTap: () => _showSourceSheet(context),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        border: Border.all(color: cs.primary, width: 1.5),
                      ),
                      child: Icon(Icons.add_rounded, color: cs.primary),
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
            child: upload.remoteUrl != null && upload.localPath.isEmpty
                ? CachedNetworkImage(
                    imageUrl: upload.remoteUrl!,
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
          Positioned(
            top: -18,
            right: -18,
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
        ],
      ),
    );
  }
}
