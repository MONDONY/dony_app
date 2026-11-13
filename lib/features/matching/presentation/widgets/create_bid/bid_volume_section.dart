import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_volume.dart';
import 'package:dony/features/package_request/data/parcel_dimensions.dart';
import 'package:dony/features/package_request/presentation/widgets/parcel_dimension_field.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Dimensions du colis d'une réservation sur un trajet vendu au m³ (bateau) :
/// trois champs en centimètres, le volume qui en découle, et le volume qu'il
/// reste sur le trajet. Obligatoires : sans elles, aucun prix ne se calcule.
///
/// Le volume affiché n'est qu'un aperçu, le serveur le recalcule. Les
/// contrôleurs vivent dans le `State` de l'écran (jamais disposés ici).
class BidVolumeSection extends StatelessWidget {
  const BidVolumeSection({
    super.key,
    required this.lengthCtrl,
    required this.widthCtrl,
    required this.heightCtrl,
    required this.volumeM3,
    required this.availableVolumeM3,
  });

  final TextEditingController lengthCtrl;
  final TextEditingController widthCtrl;
  final TextEditingController heightCtrl;

  /// Aperçu du volume du colis, `null` sans trois dimensions valides.
  final double? volumeM3;

  /// Volume restant sur le trajet, `null` s'il n'est pas connu (aucun
  /// contrôle local alors).
  final double? availableVolumeM3;

  /// Le colis ne tient pas dans ce qu'il reste : message local, avant tout
  /// appel au serveur.
  static bool exceeds(double? volumeM3, double? availableVolumeM3) =>
      volumeM3 != null &&
      availableVolumeM3 != null &&
      volumeM3 > availableVolumeM3;

  String? _validate(BuildContext context, String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return context.l10n.requestCreateDimensionRequired;
    return ParcelDimensions.isValidCm(int.tryParse(text))
        ? null
        : context.l10n.requestCreateDimensionInvalid;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final volume = volumeM3;
    final available = availableVolumeM3;
    final tooLarge = exceeds(volume, available);
    String? validator(String? raw) => _validate(context, raw);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.requestCreateDimensionsLabel,
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l10n.requestCreateDimensionsHelpBoat,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ParcelDimensionField(
                fieldKey: const Key('bid-dimension-length'),
                label: l10n.requestCreateDimensionLength,
                controller: lengthCtrl,
                validator: validator,
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: ParcelDimensionField(
                fieldKey: const Key('bid-dimension-width'),
                label: l10n.requestCreateDimensionWidth,
                controller: widthCtrl,
                validator: validator,
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: ParcelDimensionField(
                fieldKey: const Key('bid-dimension-height'),
                label: l10n.requestCreateDimensionHeight,
                controller: heightCtrl,
                validator: validator,
              ),
            ),
          ],
        ),
        if (volume != null)
          Padding(
            padding: const EdgeInsets.only(top: DonySpacing.sm),
            child: Text(
              l10n.requestCreateVolumeLine(formatParcelVolumeM3(l10n, volume)),
              key: const Key('bid-volume-preview'),
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
        if (available != null)
          Padding(
            padding: const EdgeInsets.only(top: DonySpacing.xs),
            child: Text(
              l10n.bidCreateVolumeAvailableLine(
                formatParcelVolumeM3(l10n, available),
              ),
              key: const Key('bid-volume-available'),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        if (tooLarge)
          Padding(
            padding: const EdgeInsets.only(top: DonySpacing.sm),
            child: Text(
              l10n.bidCreateVolumeTooLarge(
                formatParcelVolumeM3(l10n, volume!),
                formatParcelVolumeM3(l10n, available!),
              ),
              key: const Key('bid-volume-too-large'),
              style: tt.bodySmall?.copyWith(
                color: DonyColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
