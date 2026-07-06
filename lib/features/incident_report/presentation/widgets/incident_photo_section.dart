import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/incident_report/bloc/incident_photo_upload.dart';
import 'package:dony/features/incident_report/bloc/incident_photos_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Section « Captures d'écran » du formulaire de signalement.
/// Lit [IncidentPhotosCubit] depuis le provider ambiant. Max 4.
class IncidentPhotoSection extends StatelessWidget {
  const IncidentPhotoSection({super.key});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final cubit = context.read<IncidentPhotosCubit>();
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
    return BlocBuilder<IncidentPhotosCubit, List<IncidentPhotoUpload>>(
      builder: (context, photos) {
        final canAdd = photos.length < IncidentPhotosCubit.maxPhotos;
        return Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final p in photos)
              _PhotoThumb(
                upload: p,
                onRemove: () => context.read<IncidentPhotosCubit>().remove(p.localId),
              ),
            if (canAdd)
              GestureDetector(
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
        );
      },
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.upload, required this.onRemove});
  final IncidentPhotoUpload upload;
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
          if (upload.status == IncidentPhotoUploadStatus.uploading)
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
          if (upload.status == IncidentPhotoUploadStatus.failed)
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
          // Visuel 20×20 mais zone tap 44×44 (HIG).
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
