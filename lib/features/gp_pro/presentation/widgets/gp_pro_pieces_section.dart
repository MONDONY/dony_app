import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_state.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Justificatifs d'une demande GP Pro : liste, ajout (type puis source),
/// retrait et phrase RGPD. Facultatifs : la section le dit, sans jamais les
/// présenter comme un manque. Lit [GpProCubit] depuis le provider ambiant.
class GpProPiecesSection extends StatelessWidget {
  const GpProPiecesSection({super.key});

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<GpProCubit>();
    final l = context.l10n;
    final type = await DonyBottomSheet.show<GpProDocType>(
      context,
      title: l.gpProPieceTypeTitle,
      child: const _ChoiceList<GpProDocType>(
        values: GpProDocType.values,
        icon: _docTypeIcon,
      ),
    );
    if (type == null || !context.mounted) return;
    final source = await DonyBottomSheet.show<ImageSource>(
      context,
      title: l.gpProPieceSourceTitle,
      child: const _ChoiceList<ImageSource>(
        values: [ImageSource.camera, ImageSource.gallery],
        icon: _sourceIcon,
      ),
    );
    if (source == null || !context.mounted) return;
    try {
      final file = await getIt<DonyMediaService>().pick(source: source);
      if (file != null) await cubit.addPiece(filePath: file.path, type: type);
    } on MediaFileTooLargeException {
      if (context.mounted) _error(context, l.commonImageUnsupported);
    } on UnsupportedMediaTypeException {
      if (context.mounted) _error(context, l.commonImageUnsupported);
    } catch (_) {
      if (context.mounted) _error(context, l.gpProErrorGeneric);
    }
  }

  static void _error(BuildContext context, String message) => DonySnackbar.show(
    context,
    message: message,
    type: DonySnackbarType.error,
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<GpProCubit, GpProCubitState>(
      buildWhen: (p, c) => p.pieces != c.pieces || p.submitting != c.submitting,
      builder: (context, state) {
        final canAdd = state.canAddPiece && !state.submitting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.gpProPiecesTitle,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${state.pieces.length}/${GpProCubitState.maxPieces}',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.xxs),
            Text(
              l.gpProPiecesHint,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.md),
            for (final piece in state.pieces) ...[
              _PieceRow(
                piece: piece,
                onRemove: () =>
                    context.read<GpProCubit>().removePiece(piece.localId),
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            if (canAdd) _AddTile(onTap: () => _add(context)),
            const SizedBox(height: DonySpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: DonyIcon(
                    'shield-check',
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    l.gpProPiecesPrivacy,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

String _docTypeIcon(Object value) => switch (value as GpProDocType) {
  GpProDocType.businessRegistration => 'building-2',
  GpProDocType.travelProof => 'luggage',
  GpProDocType.socialProfile => 'share-2',
  GpProDocType.other => 'file-text',
};

String _sourceIcon(Object value) =>
    value == ImageSource.camera ? 'camera' : 'image';

/// Liste de choix d'une feuille : chaque ligne rend sa valeur à l'appelant.
class _ChoiceList<T extends Object> extends StatelessWidget {
  const _ChoiceList({required this.values, required this.icon});

  final List<T> values;
  final String Function(Object) icon;

  String _label(AppLocalizations l, T value) => switch (value) {
    final GpProDocType t => l.gpProDocType(t),
    ImageSource.camera => l.commonTakePhoto,
    _ => l.commonPickFromGallery,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 52,
              leading: DonyIconContainer(
                iconAsset: icon(value),
                size: DonyIconContainerSize.sm,
                backgroundColor: cs.primaryContainer,
                iconColor: cs.primary,
              ),
              title: Text(_label(l, value)),
              onTap: () => Navigator.of(context).pop(value),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('plus', size: 18, color: cs.primary),
              const SizedBox(width: DonySpacing.sm),
              Text(
                context.l10n.gpProAddPiece,
                style: tt.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.piece, required this.onRemove});

  final GpProPiece piece;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final failed = piece.status == GpProUploadStatus.failed;
    final uploading = piece.status == GpProUploadStatus.uploading;
    final path = piece.localPath;

    final (statusText, statusColor) = switch (piece.status) {
      GpProUploadStatus.uploading => (
        l.gpProPieceUploading,
        cs.onSurfaceVariant,
      ),
      GpProUploadStatus.failed => (l.gpProPieceFailed, cs.error),
      GpProUploadStatus.ready => (l.gpProPieceReady, cs.success),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.sm,
        DonySpacing.sm,
        0,
        DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: failed ? cs.errorLight : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(
          color: failed ? cs.error.withValues(alpha: 0.4) : cs.outline,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            // Rayon concentrique : 12 (ligne) − 8 (marge intérieure).
            borderRadius: BorderRadius.circular(DonyRadius.xs),
            child: SizedBox(
              width: 44,
              height: 44,
              child: path != null
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 132,
                      errorBuilder: (_, _, _) => _placeholder(cs),
                    )
                  : _placeholder(cs),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.gpProDocType(piece.type),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  statusText,
                  style: tt.bodySmall?.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          if (uploading)
            SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
              ),
            )
          else
            Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              label: l.gpProRemovePiece,
              onTap: onRemove,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: DonyIcon('x', size: 18, color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => ColoredBox(
    color: cs.primaryContainer,
    child: Center(child: DonyIcon('file-text', size: 20, color: cs.primary)),
  );
}
