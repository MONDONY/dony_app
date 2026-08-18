import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Enveloppe un skeleton statique d'un pulse animé en boucle.
///
/// Un seul contrôleur d'animation par card (posé ici, pas sur chaque
/// [DonySkeletonBox]) — sinon une liste de skeletons instancie des dizaines
/// de tickers simultanés. `AnimationController` manuel plutôt que
/// `flutter_animate` : son `.animate()` programme toujours son premier
/// `_play()` via `Future.delayed`, ce qui laisse un `Timer` réel en attente
/// tant que ce délai n'a pas été purgé — un piège pour tout test qui ne fait
/// qu'un `pump()` unique sur un écran en état de chargement. Démarrer le
/// `repeat()` directement dans `didChangeDependencies` évite tout Timer.
class DonyShimmer extends StatefulWidget {
  const DonyShimmer({super.key, required this.child, this.color});

  final Widget child;

  /// Couleur du reflet qui balaie le child. Par défaut `cs.onSurface` à
  /// faible alpha — à surcharger (ex: blanc) sur fond coloré/dégradé, où le
  /// reflet sombre par défaut resterait quasi invisible.
  final Color? color;

  @override
  State<DonyShimmer> createState() => _DonyShimmerState();
}

class _DonyShimmerState extends State<DonyShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    final highlight =
        widget.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.14);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.transparent, highlight, Colors.transparent],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradientTransform(
              dx: bounds.width * (_controller.value * 3 - 1),
            ),
          ).createShader(bounds),
          child: child,
        ),
      ),
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform({required this.dx});

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Placeholder rectangulaire — remplace une ligne de texte ou un bloc de
/// contenu en cours de chargement.
class DonySkeletonBox extends StatelessWidget {
  const DonySkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = DonyRadius.sm,
    this.color,
  });

  final double? width;
  final double height;
  final double radius;

  /// Couleur du bloc. Par défaut `cs.onSurface` à faible alpha — à surcharger
  /// (ex: blanc) sur fond coloré/dégradé.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? cs.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder circulaire — remplace un [DonyAvatar] en cours de chargement.
class DonySkeletonCircle extends StatelessWidget {
  const DonySkeletonCircle({super.key, this.diameter = 44, this.color});

  final double diameter;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color ?? cs.onSurface.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton calqué sur [DonyTripCard] — mêmes dimensions et paddings pour
/// qu'aucun saut de layout n'apparaisse au remplacement par la vraie card.
class DonyTripCardSkeleton extends StatelessWidget {
  const DonyTripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DonyShimmer(
      child: DonyCard(
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                DonySkeletonCircle(),
                SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonySkeletonBox(width: 120, height: 14),
                      SizedBox(height: DonySpacing.xs),
                      DonySkeletonBox(width: 60, height: 11),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.base),
            Container(height: 1, color: cs.outline),
            const SizedBox(height: DonySpacing.base),
            const Row(
              children: [
                Expanded(child: DonySkeletonBox(height: 20)),
                SizedBox(width: DonySpacing.sm),
                DonySkeletonBox(width: 32, height: 1.5, radius: 0),
                SizedBox(width: DonySpacing.sm),
                Expanded(child: DonySkeletonBox(height: 20)),
              ],
            ),
            const SizedBox(height: DonySpacing.base),
            Container(height: 1, color: cs.outline),
            const SizedBox(height: DonySpacing.base),
            const Row(
              children: [
                DonySkeletonBox(width: 90, height: 11),
                Spacer(),
                DonySkeletonBox(width: 56, height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton calqué sur `PackageRequestListCard` (variante « ticket ») — bande
/// latérale, photo colis 76×76, titre + méta + budget, pied expéditeur.
class DonyTicketCardSkeleton extends StatelessWidget {
  const DonyTicketCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DonyShimmer(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(DonyRadius.card),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DonySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          DonySkeletonBox(width: 90, height: 11),
                          Spacer(),
                          DonySkeletonBox(width: 44, height: 18),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                DonyRadius.md,
                              ),
                            ),
                          ),
                          const SizedBox(width: DonySpacing.md),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DonySkeletonBox(width: 130, height: 14),
                                SizedBox(height: DonySpacing.xs),
                                DonySkeletonBox(width: 100, height: 11),
                                SizedBox(height: DonySpacing.xs),
                                DonySkeletonBox(width: 70, height: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      Divider(height: 1, color: cs.outlineVariant),
                      const SizedBox(height: DonySpacing.xs),
                      const Row(
                        children: [
                          DonySkeletonCircle(diameter: 20),
                          SizedBox(width: DonySpacing.xs),
                          DonySkeletonBox(width: 100, height: 11),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton générique pour un écran détail (annonce, colis, profil…) — bloc
/// identité, bloc hero et lignes d'info. Une approximation volontairement
/// large : les écrans détail ont chacun leur mise en page propre, viser le
/// pixel-perfect coûterait un skeleton dédié par écran pour un gain marginal.
class DonyDetailSkeleton extends StatelessWidget {
  const DonyDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DonyShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.xl,
          DonySpacing.lg,
          DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                DonySkeletonCircle(),
                SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonySkeletonBox(width: 140, height: 15),
                      SizedBox(height: DonySpacing.xs),
                      DonySkeletonBox(width: 90, height: 11),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.xl),
            const DonySkeletonBox(
              width: double.infinity,
              height: 140,
              radius: DonyRadius.card,
            ),
            const SizedBox(height: DonySpacing.xl),
            for (var i = 0; i < 3; i++) ...[
              const Row(
                children: [
                  DonySkeletonBox(width: 90),
                  Spacer(),
                  DonySkeletonBox(width: 70),
                ],
              ),
              const SizedBox(height: DonySpacing.md),
            ],
            Container(height: 1, color: cs.outline),
            const SizedBox(height: DonySpacing.xl),
            const DonySkeletonBox(width: double.infinity, height: 52),
          ],
        ),
      ),
    );
  }
}

/// Skeleton calqué sur `ConversationTile` (liste des messages) — avatar,
/// ligne nom + heure, ligne d'aperçu. Pas de `DonyCard` : la vraie tuile
/// n'a ni bordure ni fond distinct, juste un padding sur toute la largeur.
class DonyConversationTileSkeleton extends StatelessWidget {
  const DonyConversationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DonyShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: 12,
        ),
        child: Row(
          children: [
            const DonySkeletonCircle(),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      DonySkeletonBox(width: 120, height: 14),
                      Spacer(),
                      DonySkeletonBox(width: 36, height: 11),
                    ],
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  DonySkeletonBox(
                    width: MediaQuery.sizeOf(context).width * 0.4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton d'une conversation en cours de chargement — bulles alternées,
/// approximant la disposition envoyé/reçu sans calquer un message précis.
class DonyChatSkeleton extends StatelessWidget {
  const DonyChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const widths = [0.55, 0.4, 0.62, 0.35, 0.48];
    return DonyShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.lg,
        ),
        child: Column(
          children: [
            for (var i = 0; i < widths.length; i++) ...[
              Align(
                alignment: i.isEven
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: DonySkeletonBox(
                  width: MediaQuery.sizeOf(context).width * widths[i],
                  height: 40,
                  radius: DonyRadius.card,
                ),
              ),
              const SizedBox(height: DonySpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton calqué sur [DonyPriceTag] — silhouette d'étiquette (coin gauche
/// droit, coins droits arrondis) conservée, contenu remplacé par des blocs.
class DonyPriceTagSkeleton extends StatelessWidget {
  const DonyPriceTagSkeleton({super.key});

  static const _shape = BorderRadius.horizontal(
    left: Radius.circular(DonyRadius.xs + 1),
    right: Radius.circular(DonyRadius.card),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DonyShimmer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          28,
          DonySpacing.md,
          DonySpacing.base,
          DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: _shape,
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            const DonySkeletonBox(width: 19, height: 19),
            const SizedBox(width: DonySpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DonySkeletonBox(width: 130, height: 16),
                  const SizedBox(height: DonySpacing.xs),
                  DonySkeletonBox(
                    width: MediaQuery.sizeOf(context).width * 0.3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            const DonySkeletonBox(width: 56, height: 32),
          ],
        ),
      ),
    );
  }
}

/// Skeleton pour une carte texte seule (pas d'avatar ni de photo) — titre +
/// pastille de statut, puis 2-3 lignes de détail. Calqué sur `DisputeCard`,
/// réutilisable pour toute carte de la même famille (statut + métadonnées).
class DonyListCardSkeleton extends StatelessWidget {
  const DonyListCardSkeleton({super.key, this.detailLines = 2});

  final int detailLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final widths = [0.55, 0.4, 0.3];

    return DonyShimmer(
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DonySkeletonBox(width: 140, height: 15),
                DonySkeletonBox(width: 64, height: 22, radius: DonyRadius.full),
              ],
            ),
            for (var i = 0; i < detailLines; i++) ...[
              const SizedBox(height: DonySpacing.sm),
              DonySkeletonBox(
                width:
                    MediaQuery.sizeOf(context).width *
                    widths[i % widths.length],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton calqué sur [DonyUserCard] — avatar + nom + sous-titre + chevron.
class DonyUserCardSkeleton extends StatelessWidget {
  const DonyUserCardSkeleton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DonyShimmer(
      child: DonyCard(
        padding: EdgeInsets.all(compact ? DonySpacing.md : DonySpacing.base),
        child: Row(
          children: [
            DonySkeletonCircle(diameter: compact ? 32 : 44),
            const SizedBox(width: DonySpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonySkeletonBox(width: 140, height: 14),
                  SizedBox(height: DonySpacing.xs),
                  DonySkeletonBox(width: 90, height: 11),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            const DonySkeletonBox(width: 20, height: 20),
          ],
        ),
      ),
    );
  }
}
