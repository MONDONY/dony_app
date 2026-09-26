import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Compteur indisponible : tiret court, jamais de tiret cadratin dans l'UI.
const _kUnavailable = '-';

/// Tuile principale du hub : l'un des deux rôles, voyager ou envoyer.
///
/// Carte blanche surélevée, plus haute que les tuiles secondaires, qui porte
/// son propre bouton d'action : un bêta testeur ne trouvait pas « Publier un
/// trajet » quand il n'était qu'une ligne de texte colorée au-dessus du titre.
/// La couleur du rôle (bleu pour voyager, terracotta pour envoyer) ne teinte
/// que l'icône et le bouton, jamais toute la carte.
///
/// À zéro, la tuile devient une invitation : [emptyLabel] et [emptySubtitle]
/// remplacent le titre et le sous-titre, le compteur disparaît. Un « 0 » nu ne
/// dit rien à un nouvel utilisateur.
class ActivityHeroTile extends StatelessWidget {
  const ActivityHeroTile({
    super.key,
    required this.iconName,
    required this.color,
    required this.value,
    required this.label,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
    required this.onCtaTap,
    this.ctaKey,
    this.emptyLabel,
    this.emptySubtitle,
    this.isLoading = false,
    this.hasError = false,
    this.showNotificationDot = false,
  });

  /// Nom du SVG dans `assets/icons/`, sans extension.
  final String iconName;

  /// Couleur du rôle : teinte la pastille d'icône et remplit le bouton.
  final Color color;

  /// Valeur affichée. Ignorée si [isLoading] ou [hasError].
  final int value;
  final String label;
  final String subtitle;

  final String ctaLabel;
  final Key? ctaKey;

  /// Ouvre la liste du domaine (tap sur la carte).
  final VoidCallback onTap;

  /// Lance la publication (tap sur le bouton).
  final VoidCallback onCtaTap;

  final String? emptyLabel;
  final String? emptySubtitle;
  final bool isLoading;
  final bool hasError;

  /// Point rouge à côté du compteur : une action attend l'utilisateur dans
  /// cette liste (une discussion de prix non lue sur un colis, par exemple).
  final bool showNotificationDot;

  bool get _isEmpty =>
      !isLoading && !hasError && value == 0 && emptyLabel != null;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final empty = _isEmpty;

    return DonyCard(
      onTap: onTap,
      elevated: true,
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIconContainer(
                iconAsset: iconName,
                backgroundColor: color.withValues(alpha: 0.12),
                iconColor: color,
                borderRadius: DonyRadius.iconBtn,
              ),
              const Spacer(),
              if (showNotificationDot)
                Padding(
                  padding: const EdgeInsets.only(
                    top: DonySpacing.sm,
                    right: DonySpacing.xs,
                  ),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (!empty)
                _HeroValue(
                  value: value,
                  isLoading: isLoading,
                  hasError: hasError,
                ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            empty ? emptyLabel! : label,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            empty ? (emptySubtitle ?? subtitle) : subtitle,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Pousse le bouton en bas : les deux tuiles d'une rangée ont la même
          // hauteur, leurs boutons restent alignés même si un sous-titre passe
          // sur deux lignes.
          const Spacer(),
          const SizedBox(height: DonySpacing.md),
          FilledButton.icon(
            key: ctaKey,
            onPressed: onCtaTap,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: DonyColors.textOnBrand,
              minimumSize: const Size.fromHeight(kDonyMinTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
            ),
            icon: const DonyIcon(
              'plus',
              size: 16,
              color: DonyColors.textOnBrand,
            ),
            // Sur un écran de 360 dp la tuile ne fait que ~150 px : le libellé
            // rétrécit plutôt que de passer sur deux lignes.
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(ctaLabel, maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({
    required this.value,
    required this.isLoading,
    required this.hasError,
  });

  final int value;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return const DonyShimmer(
        child: DonySkeletonBox(width: 32, height: 28, radius: DonyRadius.xs),
      );
    }
    return Text(
      hasError ? _kUnavailable : '$value',
      style: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1,
        color: hasError ? cs.onSurfaceVariant : cs.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Tuile secondaire du hub (Demandes reçues, Discussions de prix).
///
/// Plate, sur le fond sable : elle s'efface derrière les deux tuiles
/// principales tant qu'elle n'a rien à dire. Dès que son compteur dépasse
/// zéro, une pastille rouge chiffrée la fait ressortir : c'est le seul rouge
/// de l'écran, réservé à ce qui attend une réponse.
///
/// Le compteur peut être en chargement ou indisponible, mais la tuile reste
/// toujours cliquable : c'est l'écran de destination qui gère son propre état
/// d'erreur, pas le hub.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.iconName,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.emptyHint,
    this.isLoading = false,
    this.hasError = false,
  });

  /// Nom du SVG dans `assets/icons/`, sans extension.
  final String iconName;

  /// Couleur du rôle, portée par l'icône seule.
  final Color color;

  /// Valeur affichée dans la pastille. Ignorée si [isLoading] ou [hasError].
  final int value;
  final String label;

  /// Explique le domaine quand il y a quelque chose à traiter.
  final String? subtitle;

  /// Remplace le sous-titre à zéro (« Aucune pour l'instant »).
  final String? emptyHint;

  final VoidCallback onTap;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    final pending = !isLoading && !hasError && value > 0;
    final line = pending || emptyHint == null ? subtitle : emptyHint;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIconContainer(
                    iconAsset: iconName,
                    size: DonyIconContainerSize.sm,
                    backgroundColor: cs.surface,
                    iconColor: color,
                    borderRadius: DonyRadius.iconBtn,
                  ),
                  const Spacer(),
                  _SecondaryTrailing(
                    value: value,
                    isLoading: isLoading,
                    hasError: hasError,
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.md),
              Text(
                label,
                style: tt.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (line != null) ...[
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  line,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: pending ? FontWeight.w600 : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille rouge chiffrée, tiret si le compteur est indisponible, chevron
/// discret sinon.
class _SecondaryTrailing extends StatelessWidget {
  const _SecondaryTrailing({
    required this.value,
    required this.isLoading,
    required this.hasError,
  });

  final int value;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return const DonyShimmer(
        child: DonySkeletonBox(width: 24, height: 24, radius: DonyRadius.xs),
      );
    }
    if (hasError) {
      return Text(
        _kUnavailable,
        style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    if (value > 0) {
      return Container(
        key: const Key('activity-tile-badge'),
        constraints: const BoxConstraints(minWidth: 24),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Text(
          '$value',
          style: tt.labelMedium?.copyWith(
            color: cs.onError,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
    return DonyIcon('chevron-right', size: 16, color: cs.onSurfaceVariant);
  }
}
