import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Slot photo optionnel pour le wizard étape 3.
///
/// - Tap → bottom sheet "Caméra | Galerie".
/// - Affiche un preview circulaire à coins arrondis si une photo est choisie.
/// - Le parent contrôle l'état via [photoFile] + [onPhotoPicked].
class WizardPhotoUpload extends StatelessWidget {
  const WizardPhotoUpload({
    super.key,
    required this.photoFile,
    required this.onPhotoPicked,
  });

  final File? photoFile;
  final ValueChanged<File?> onPhotoPicked;

  @override
  Widget build(BuildContext context) {
    return DonyCard(
            padding: const EdgeInsets.all(DonySpacing.md),
      child: photoFile == null ? _empty(context) : _preview(context),
    );
  }

  Widget _empty(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                size: 28,
                color: DonyColors.textPrimary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Ajouter une photo (optionnel)',
                style: tt.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DonyColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Aide les voyageurs à se projeter',
                style: tt.bodySmall?.copyWith(
                  fontSize: 11,
                  color: DonyColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
                  color: DonyColors.textPrimary,
                ),
          ),
        ),
        IconButton(
          tooltip: 'Retirer la photo',
          icon: const Icon(Icons.close_rounded),
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
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      onPhotoPicked(File(picked.path));
    }
  }
}
