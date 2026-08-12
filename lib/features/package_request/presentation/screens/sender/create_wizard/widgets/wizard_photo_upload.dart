import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Slot photo optionnel pour le wizard étape 3.
///
/// - Tap → bottom sheet "Caméra | Galerie".
/// - Compresse la photo via [DonyMediaService] avant de remonter le fichier.
/// - Affiche un preview à coins arrondis si une photo est choisie.
/// - [mediaService] est injectable pour les tests.
class WizardPhotoUpload extends StatelessWidget {
  const WizardPhotoUpload({
    super.key,
    required this.photoFile,
    required this.onPhotoPicked,
    DonyMediaService? mediaService,
  }) : _mediaService = mediaService;

  final File? photoFile;
  final ValueChanged<File?> onPhotoPicked;
  final DonyMediaService? _mediaService;

  DonyMediaService get _service => _mediaService ?? getIt<DonyMediaService>();

  @override
  Widget build(BuildContext context) {
    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.md),
      child: photoFile == null ? _empty(context) : _preview(context),
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(DonyRadius.lg),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon(
                'image-plus',
                size: 28,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Ajouter une photo (optionnel)',
                style: tt.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Aide les voyageurs à se projeter',
                style: tt.bodySmall?.copyWith(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: Image.file(
            photoFile!,
            width: 76,
            height: 76,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Text(
            'Photo ajoutée',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Retirer la photo',
          icon: const DonyIcon('x', color: DonyColors.error),
          color: DonyColors.error,
          onPressed: () => onPhotoPicked(null),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const DonyIcon('camera'),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const DonyIcon('image'),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await _service.pick(source: source);
      if (picked != null) onPhotoPicked(File(picked.path));
    } on UnsupportedMediaTypeException {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message: 'Seules les images sont acceptées (pas de vidéo).',
          type: DonySnackbarType.error,
        );
      }
    } on MediaFileTooLargeException catch (e) {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message: 'Photo trop lourde (max ${e.maxMb} Mo).',
          type: DonySnackbarType.error,
        );
      }
    }
  }
}
