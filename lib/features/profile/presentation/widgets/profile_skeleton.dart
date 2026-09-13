import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Squelette de l'écran « Moi », rendu tant que le profil n'est pas connu.
///
/// Au démarrage, `AuthCheckRequested` charge le profil en arrière-plan sans
/// retenir la navigation (voir `app.dart`) : l'onglet Moi peut donc s'ouvrir
/// pendant `AuthLoading`, ou après un `AuthError` quand le téléphone est hors
/// ligne. Avant ce squelette, l'écran se construisait alors avec des valeurs
/// de repli (« Utilisateur », « Email manquant », « Vérifiez votre identité
/// pour activer »…) : une page fausse, prise pour le vrai compte.
///
/// Calqué sur la page réelle (en-tête, puis sections « carte » de deux ou
/// trois lignes) pour qu'aucun saut de mise en page n'apparaisse quand le
/// profil la remplace. Un seul [DonyShimmer] pour toute la page : un
/// contrôleur d'animation, pas un par bloc.
class ProfileScreenSkeleton extends StatelessWidget {
  const ProfileScreenSkeleton({super.key, this.hasError = false, this.onRetry});

  /// Le dernier chargement a échoué : la silhouette reste, mais sans reflet
  /// (rien ne charge plus) et coiffée d'une carte « Réessayer ». Un reflet
  /// qui tournerait indéfiniment ressemblerait à un blocage.
  final bool hasError;

  /// Relance le chargement du profil. Sans effet tant que [hasError] est
  /// faux : la carte qui le porte n'est pas affichée.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderSkeleton(topPadding: MediaQuery.paddingOf(context).top),
        Padding(
          padding: const EdgeInsets.all(DonySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasError) ...[
                _RetryCard(onRetry: onRetry),
                const SizedBox(height: DonySpacing.lg),
              ],
              const _SectionSkeleton(rows: 2),
              const SizedBox(height: DonySpacing.lg),
              const _SectionSkeleton(rows: 3, hero: true),
              const SizedBox(height: DonySpacing.lg),
              const _SectionSkeleton(rows: 2),
            ],
          ),
        ),
      ],
    );

    // Jamais de défilement : rien à faire défiler dans un squelette, mais un
    // écran court ne doit pas déborder pour autant (même parade que
    // l'en-tête de l'écran réel).
    if (hasError) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: page,
      );
    }
    return Semantics(
      label: 'Chargement du profil',
      excludeSemantics: true,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: DonyShimmer(child: page),
      ),
    );
  }
}

// ── En-tête ───────────────────────────────────────────────────────────────────

/// Mêmes retraits que `ProfileHeader` : avatar xl, nom, rangée de chips.
class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton({required this.topPadding});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        topPadding + DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.sm,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Même diamètre que DonyAvatarSize.xl.
          DonySkeletonCircle(diameter: 72),
          SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: DonySpacing.xs),
                DonySkeletonBox(width: 160, height: 22),
                SizedBox(height: DonySpacing.sm + DonySpacing.xs),
                Row(
                  children: [
                    DonySkeletonBox(
                      width: 64,
                      height: 20,
                      radius: DonyRadius.full,
                    ),
                    SizedBox(width: DonySpacing.xs),
                    DonySkeletonBox(
                      width: 96,
                      height: 20,
                      radius: DonyRadius.full,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Un libellé de section, puis une carte de [rows] lignes, comme
/// `ProfileSectionLabel` + `ProfileListSection`. [hero] ajoute, entre les
/// deux, le bloc plein de la carte « Solde » de la section ARGENT.
class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.rows, this.hero = false});

  final int rows;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            DonySpacing.xs,
            0,
            DonySpacing.xs,
            DonySpacing.sm,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: DonySkeletonBox(width: 96),
          ),
        ),
        if (hero) ...[
          const DonySkeletonBox(
            width: double.infinity,
            height: 148,
            radius: DonyRadius.card,
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows; i++)
                _RowSkeleton(showDivider: i < rows - 1),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une ligne de carte, aux mêmes retraits que `DonyListTile` : pastille
/// d'icône, libellé, chevron.
class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton({required this.showDivider});

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DonySpacing.xs,
              vertical: DonySpacing.sm + 2,
            ),
            child: Row(
              children: [
                DonySkeletonBox(
                  width: DonySpacing.icon,
                  height: DonySpacing.icon,
                ),
                SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DonySkeletonBox(width: 150, height: 14),
                  ),
                ),
                SizedBox(width: DonySpacing.sm),
                DonySkeletonBox(width: 18, height: 18),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: DonySpacing.lg + DonySpacing.icon),
      ],
    );
  }
}

// ── Carte « Réessayer » ───────────────────────────────────────────────────────

class _RetryCard extends StatelessWidget {
  const _RetryCard({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DonyIconContainer(
                iconAsset: 'wifi-off',
                backgroundColor: cs.errorContainer,
                iconColor: cs.error,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profil indisponible',
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      'Impossible de charger votre compte. Vérifiez votre '
                      'connexion, puis réessayez.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'Réessayer',
            iconAsset: 'refresh-cw',
            variant: DonyButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
