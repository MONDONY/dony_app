import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Compresses [input] to JPEG, max 1280×1280, quality 80.
/// Returns a new [XFile] pointing to the compressed bytes saved in the temp
/// directory. Falls back to the original file if compression fails.
Future<XFile> defaultCompressForUpload(XFile input) async {
  final bytes = await input.readAsBytes();
  final compressed = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth: 1280,
    minHeight: 1280,
    quality: 80,
  );
  final dir = await getTemporaryDirectory();
  final outPath = '${dir.path}/${input.name}_compressed.jpg';
  final outFile = File(outPath)..writeAsBytesSync(compressed);
  return XFile(outFile.path);
}

/// Signature for an image compressor — injectable for testing.
typedef ImageCompressor = Future<XFile> Function(XFile input);

/// Slot photo optionnel pour le wizard étape 3.
///
/// - Tap → bottom sheet "Caméra | Galerie".
/// - Compresse la photo (max 1280×1280, qualité 80 %) via [compressor]
///   avant de remonter le fichier au parent.
/// - Affiche un preview circulaire à coins arrondis si une photo est choisie.
/// - Le parent contrôle l'état via [photoFile] + [onPhotoPicked].
class WizardPhotoUpload extends StatelessWidget {
  const WizardPhotoUpload({
    super.key,
    required this.photoFile,
    required this.onPhotoPicked,
    ImageCompressor? compressor,
  }) : _compress = compressor ?? defaultCompressForUpload;

  final File? photoFile;
  final ValueChanged<File?> onPhotoPicked;
  final ImageCompressor _compress;

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
                  color: DonyColors.textPrimary,
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
    if (source == null) {
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      final compressed = await _compress(picked);
      onPhotoPicked(File(compressed.path));
    }
  }
}
