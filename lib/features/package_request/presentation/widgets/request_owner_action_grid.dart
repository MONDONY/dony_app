import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:flutter/material.dart';

/// Grille 2×2 d'actions propriétaire pour l'écran « Ma demande ».
///
/// Miroir de `OwnerActionGrid` (trajet) : chaque tuile porte une conséquence
/// nommée plutôt que d'être cachée derrière un menu `…`.
class RequestOwnerActionGrid extends StatelessWidget {
  const RequestOwnerActionGrid({
    super.key,
    required this.request,
    required this.hasOffers,
    required this.onEdit,
    required this.onPublish,
    required this.onUnpublish,
    required this.onCancel,
  });

  final PackageRequest request;

  /// Lu depuis les threads déjà chargés par l'écran appelant — pas un champ
  /// du modèle. Le backend reste l'autorité : il renvoie 409 `has-offers`
  /// si l'état a changé entre le chargement et le tap.
  final bool hasOffers;

  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onCancel;

  bool get _canEdit =>
      request.status == PackageRequestStatus.draft ||
      request.status == PackageRequestStatus.open ||
      request.status == PackageRequestStatus.negotiating;

  bool get _canUnpublish =>
      request.status == PackageRequestStatus.open && !hasOffers;

  bool get _canCancel =>
      request.status == PackageRequestStatus.open ||
      request.status == PackageRequestStatus.negotiating;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tiles = <Widget>[
      if (request.status == PackageRequestStatus.draft)
        _tile(
          iconAsset: 'send',
          label: 'Publier',
          accent: cs.primary,
          onTap: onPublish,
        ),
      _tile(
        iconAsset: 'square-pen',
        label: 'Modifier',
        accent: cs.onSurface,
        onTap: _canEdit ? onEdit : null,
        disabledMessage: 'Modification indisponible pour ce statut',
      ),
      if (request.status == PackageRequestStatus.open)
        _tile(
          iconAsset: 'eye-off',
          label: 'Dépublier',
          accent: cs.onSurface,
          onTap: _canUnpublish ? onUnpublish : null,
          disabledMessage:
              'Dépublier n\'est possible qu\'avant la première offre',
        ),
      if (_canCancel)
        _tile(
          iconAsset: 'circle-x',
          label: 'Annuler',
          accent: cs.error,
          onTap: onCancel,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: DonySpacing.sm),
          Row(
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: i + 1 < tiles.length
                    ? tiles[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

Widget _tile({
  required String iconAsset,
  required String label,
  required Color accent,
  VoidCallback? onTap,
  String? disabledMessage,
}) {
  if (onTap == null && disabledMessage != null) {
    return Tooltip(
      message: disabledMessage,
      child: Opacity(
        opacity: 0.4,
        child: _ActionTile(iconAsset: iconAsset, label: label, accent: accent),
      ),
    );
  }
  return _ActionTile(
    iconAsset: iconAsset,
    label: label,
    accent: accent,
    onTap: onTap,
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.iconAsset,
    required this.label,
    required this.accent,
    this.onTap,
  });

  final String iconAsset;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(child: DonyIcon(iconAsset, size: 20, color: accent)),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
