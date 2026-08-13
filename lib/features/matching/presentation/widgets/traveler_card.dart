import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class TravelerCard extends StatelessWidget {
  const TravelerCard({
    super.key,
    required this.announcement,
    required this.index,
    required this.isOwnAnnouncement,
    required this.onTap,
    this.distanceBadge,
    this.existingBidStatus,
    this.showFavorite = false,
  });

  final AnnouncementModel announcement;
  final VoidCallback? onTap;
  final int index;
  final bool isOwnAnnouncement;
  final String? distanceBadge;

  /// Statut d'un bid actif (PENDING ou ACCEPTED) déjà déposé par l'expéditeur
  /// courant sur cette annonce. Si non null, la carte affiche un chip de
  /// statut + une bordure colorée pour rappeler à l'expéditeur qu'il a déjà
  /// une demande en cours sur ce trajet.
  final String? existingBidStatus;

  /// When true, renders a heart button in the top-right of the card header.
  /// Requires a [FavoriteIdsCubit] to be in the widget tree; if absent the
  /// heart is silently omitted (defensive read — never crashes).
  ///
  /// Caller is responsible for NOT passing true on items owned by the current
  /// user. The in-card heart has no owner guard; the backend returns 422 on an
  /// own-trip add, but the optimistic UI would flash before the error arrives.
  final bool showFavorite;

  /// Nombre de catégories affichées avant la pastille « +N ».
  ///
  /// Une seule : les libellés du catalogue sont longs (« Documents &
  /// administratif », « Médicaments traditionnels »), donc chacun occupait sa
  /// propre ligne et la carte s'étirait sur trois rangées de pastilles pour
  /// une information secondaire. Un libellé suivi de « +N » tient sur une
  /// ligne ; le détail complet reste sur l'écran du trajet.
  static const int _maxVisibleChips = 1;

  String get _displayName => announcement.traveler?.resolvedName ?? 'Voyageur';

  ({Color border, Color chipBg, Color chipFg, String label}) _bidStyle(
    ColorScheme cs,
  ) {
    switch (existingBidStatus) {
      case 'ACCEPTED':
        return (
          border: cs.success,
          chipBg: cs.successLight,
          chipFg: cs.success,
          label: 'Demande acceptée',
        );
      // Colis déjà en cours sur ce trajet (remis / en route / livré).
      case 'HANDED_OVER':
      case 'IN_TRANSIT':
      case 'COMPLETED':
        return (
          border: cs.primary,
          chipBg: cs.primaryContainer,
          chipFg: cs.primary,
          label: 'Colis sur ce trajet',
        );
      case 'PENDING':
      case 'AWAITING_PAYMENT':
      // Paiement séquestré : l'expéditeur a payé mais le voyageur n'a pas encore
      // accepté → toujours « en attente » (cohérent avec le détail et la liste).
      case 'PAYMENT_ESCROWED':
      default:
        return (
          border: cs.warning,
          chipBg: cs.warningLight,
          chipFg: DonyColors.amberDark,
          label: 'Demande en attente',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final totalTrips = traveler?.totalTrips;
    final isKiloPro = traveler?.kiloPro ?? false;
    final isProAccount = traveler?.isProAccount ?? false;
    final dateStr = DateFormat(
      'EEE d MMM',
      'fr',
    ).format(announcement.departureDate);
    final categories = announcement.acceptedContentTypes ?? [];
    final hasExistingBid = existingBidStatus != null;
    final bidStyle = _bidStyle(cs);

    // Bordure : un bid existant prime ; sinon, une annonce dont l'expéditeur
    // courant est le voyageur (« Votre trajet ») est surlignée en primaire pour
    // signaler qu'elle est cliquable (ouvre l'écran détail propriétaire).
    final Color borderColor = hasExistingBid
        ? bidStyle.border
        : (isOwnAnnouncement ? cs.primary : cs.outline);
    final double borderWidth = (hasExistingBid || isOwnAnnouncement) ? 1.5 : 1;

    // Préfère le drapeau résolu par le backend (n'importe quel pays), retombe
    // sur la map hardcodée locale, puis null (point bleu via _FlagEndpoint).
    final depFlag =
        announcement.departureFlag ?? cityFlag(announcement.departureCity);
    final arrFlag =
        announcement.arrivalFlag ?? cityFlag(announcement.arrivalCity);

    final priceLabel = announcement.pricingMode == 'MIXED'
        ? 'Grille tarifaire'
        : '${formatPriceIn(announcement.senderPricePerKg, announcement.currency)}/kg';

    return _PressableCard(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: const [
                BoxShadow(
                  color: DonyColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasExistingBid) ...[
                  _ExistingBidChip(
                    label: bidStyle.label,
                    bg: bidStyle.chipBg,
                    fg: bidStyle.chipFg,
                  ),
                  const SizedBox(height: DonySpacing.sm),
                ],
                if (distanceBadge != null) ...[
                  _DistanceBadge(label: distanceBadge!),
                  const SizedBox(height: DonySpacing.sm),
                ],

                // ── Zone 1 : trajet (hero) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _RouteHeader(
                        departureCity: announcement.departureCity,
                        arrivalCity: announcement.arrivalCity,
                        depFlag: depFlag,
                        arrFlag: arrFlag,
                        showChevron: isOwnAnnouncement,
                      ),
                    ),
                    // Pas de SizedBox : le padding interne du bouton (halo autour
                    // de l'icône) suffit à l'écarter du corridor. En ajouter un
                    // creusait un vide visible entre le signet et le trajet.
                    if (showFavorite)
                      _buildFavoriteHeart(context, announcement.id),
                  ],
                ),
                const SizedBox(height: DonySpacing.xs),
                Row(
                  children: [
                    DonyIcon('calendar', size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      dateStr,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: DonySpacing.md),
                Divider(height: 1, thickness: 1, color: cs.outline),
                const SizedBox(height: DonySpacing.md),

                // ── Zone 2 : voyageur + prix ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DonyAvatar(
                      name: _displayName,
                      imageUrl: traveler?.avatarUrl,
                      size: DonyAvatarSize.md,
                      verified: traveler?.kycVerified ?? false,
                      pro: isProAccount,
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: tt.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: DonySpacing.xxs),
                          // Note et trajets seuls ici ; les badges sont en dessous,
                          // pleine largeur (voir plus bas). Wrap et non Row : ne
                          // déborde jamais si l'espace manque.
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: DonySpacing.xxs,
                            children: [
                              DonyIcon('star', size: 13, color: cs.warning),
                              Text(
                                rating != null
                                    ? rating.toStringAsFixed(1)
                                    : '-',
                                style: tt.titleSmall?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              if (totalTrips != null)
                                Text(
                                  '· $totalTrips trajet${totalTrips > 1 ? 's' : ''}',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      priceLabel,
                      style: tt.titleLarge?.copyWith(
                        color: cs.success,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
                // Badges pleine largeur, hors de la colonne du voyageur : sinon ils
                // partageaient l'espace avec le prix et débordaient différemment
                // selon la largeur (liste vs carousel), donnant deux hauteurs. Ici
                // ils disposent de toute la largeur de la carte et s'alignent de
                // façon identique dans les deux vues.
                if (isKiloPro || isProAccount || announcement.isUrgent) ...[
                  const SizedBox(height: DonySpacing.sm),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: DonySpacing.xxs,
                    runSpacing: DonySpacing.xxs,
                    children: [
                      if (isKiloPro) const _KycBadge(),
                      if (isProAccount) const _ProBadge(),
                      if (announcement.isUrgent) const DonyUrgentBadge(),
                    ],
                  ),
                ],
                const SizedBox(height: DonySpacing.sm),
                Row(
                  children: [
                    const DonyEmoji.parcel(size: 13),
                    const SizedBox(width: DonySpacing.xxs),
                    Text(
                      announcement.capacityUnit == 'KG_FREE'
                          ? 'Kg libre'
                          : '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (isOwnAnnouncement) ...[
                      const Spacer(),
                      const _OwnTripPill(),
                    ],
                  ],
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: DonySpacing.sm),
                  _CategoryChips(
                    categories: categories,
                    maxVisible: _maxVisibleChips,
                  ),
                ],
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 60 * index))
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────
// Shared helper — defensive favorite heart
// ─────────────────────────────────────────────────────────────

/// Renders a [FavoriteHeartButton] driven by [FavoriteIdsCubit].
/// Silently returns [SizedBox.shrink] if no cubit is in the tree —
/// so the card never crashes when rendered outside a cubit provider.
Widget _buildFavoriteHeart(BuildContext context, String tripId) {
  FavoriteIdsCubit? cubit;
  try {
    cubit = context.read<FavoriteIdsCubit>();
  } catch (_) {
    // No FavoriteIdsCubit in the tree — render nothing.
    return const SizedBox.shrink();
  }
  final c = cubit;
  return BlocBuilder<FavoriteIdsCubit, FavoriteIdsState>(
    bloc: c,
    builder: (ctx, _) => FavoriteHeartButton(
      isFavorite: c.isTripFav(tripId),
      onToggle: () async {
        try {
          await c.toggleTrip(tripId);
        } catch (_) {
          if (ctx.mounted) {
            DonySnackbar.show(
              ctx,
              message: 'Action impossible, réessaie',
              type: DonySnackbarType.error,
            );
          }
        }
      },
    ),
  );
}

/// Carte tactile : applique un léger scale 0.97 pendant l'appui (feedback
/// premium). N'active le retour visuel que si [onTap] est fourni — les cartes
/// non cliquables (« Votre trajet ») restent statiques.
class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) {
      return;
    }
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// En-tête trajet : `drapeau · ville  ──✈──  ville · drapeau`.
/// Les villes sont non-flexibles (toujours affichées en entier) et le
/// connecteur occupe l'espace restant — la ligne s'étire entre les deux villes.
class _RouteHeader extends StatelessWidget {
  const _RouteHeader({
    required this.departureCity,
    required this.arrivalCity,
    required this.depFlag,
    required this.arrFlag,
    this.showChevron = false,
  });

  final String departureCity;
  final String arrivalCity;
  final String? depFlag;
  final String? arrFlag;

  /// Affiche un chevron `>` après le drapeau d'arrivée pour signaler que la
  /// carte est cliquable (cas « Votre trajet »).
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cityStyle = tt.headlineMedium?.copyWith(color: cs.onSurface);

    return Row(
      children: [
        _FlagEndpoint(flag: depFlag),
        const SizedBox(width: DonySpacing.xs),
        Flexible(
          child: Text(
            departureCity,
            style: cityStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        const Expanded(child: _RouteConnector()),
        const SizedBox(width: DonySpacing.sm),
        Flexible(
          child: Text(
            arrivalCity,
            style: cityStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: DonySpacing.xs),
        _FlagEndpoint(flag: arrFlag),
        if (showChevron) ...[
          const SizedBox(width: DonySpacing.xs),
          DonyIcon('chevron-right', size: 18, color: cs.primary),
        ],
      ],
    );
  }
}

/// Ligne pleine fine surmontée d'une icône avion (le fond surface « coupe » la
/// ligne autour de l'avion pour un rendu net).
class _RouteConnector extends StatelessWidget {
  const _RouteConnector();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                height: 1.5,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: DonyColors.blue200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Lucide 'plane' pointe en haut-à-gauche par défaut → quart de tour
          // pour le faire pointer vers la droite (sens du trajet).
          Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
            child: RotatedBox(
              quarterTurns: 1,
              child: DonyIcon('plane', size: 16, color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drapeau emoji du trajet, ou point bleu de repli si la ville est inconnue.
class _FlagEndpoint extends StatelessWidget {
  const _FlagEndpoint({required this.flag});

  final String? flag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (flag != null) {
      return Text(flag!, style: const TextStyle(fontSize: 18));
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
    );
  }
}

class _ExistingBidChip extends StatelessWidget {
  const _ExistingBidChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const Key('traveler-card-existing-bid-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('circle-check', size: 13, color: fg),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill « Votre trajet » : badge primaire plein affiché à droite de la ligne
/// capacité (kg) sur les annonces dont l'expéditeur courant est le voyageur.
class _OwnTripPill extends StatelessWidget {
  const _OwnTripPill();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('own-trip-pill'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: cs.onPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'Votre trajet',
            style: tt.labelSmall?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.onSurface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('map-pin', size: 11, color: cs.surface),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.surface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('star', size: 10, color: cs.warning),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'PRO',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.warning,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _KycBadge extends StatelessWidget {
  const _KycBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: cs.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'Identité',
            style: tt.labelSmall?.copyWith(
              color: cs.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.maxVisible});
  final List<String> categories;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(maxVisible).toList();
    final overflow = categories.length - maxVisible;
    return Wrap(
      spacing: DonySpacing.xs,
      runSpacing: DonySpacing.xs,
      children: [
        for (final label in visible) _CategoryChip(label: label),
        if (overflow > 0) _CategoryChip(label: '+$overflow'),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}
