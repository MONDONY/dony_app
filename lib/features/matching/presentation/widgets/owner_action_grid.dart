import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/trip_reschedule_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Grille 2×2 d'actions propriétaire pour l'écran détail d'un trajet.
///
/// Grille = source de vérité du gating propriétaire (Demandes / Colis /
/// Modifier / Supprimer) :
/// - **Demandes** → écran « À traiter » (PendingBidsScreen). Désactivé s'il n'y
///   a aucune demande en attente.
/// - **Colis** → écran des colis (BidListScreen). Désactivé s'il n'y a aucun
///   colis embarqué.
/// - **Modifier** → édition (uniquement si 0 demande, sinon désactivé).
/// - **Supprimer** (si supprimable) ou **Annuler** (si ACTIVE non supprimable).
class OwnerActionGrid extends StatelessWidget {
  const OwnerActionGrid({super.key, required this.a, required this.isOwner});

  /// Trajet affiché.
  final AnnouncementModel a;

  /// `true` si l'utilisateur courant est le voyageur propriétaire.
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    // Sécurité non-propriétaire : aucune action ne doit fuiter.
    if (!isOwner) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    // Compteurs « demandes à traiter » et « colis embarqués » : source de
    // vérité = BidBloc (chargé pour la section colis) ; repli sur le modèle
    // tant que la liste n'a pas répondu. `watch` → réactive les tuiles dès que
    // les bids arrivent.
    final bidState = context.watch<BidBloc>().state;
    final loadedBids = bidState is BidListLoaded ? bidState.bids : null;
    final pendingCount = loadedBids != null
        ? loadedBids.where(isPendingBid).length
        : a.pendingBidCount;
    final colisCount = loadedBids != null
        ? loadedBids.where(isAcceptedTabBid).length
        : a.confirmedParcelCount;
    final hasPending = pendingCount > 0;
    final hasColis = colisCount > 0;

    // Le trajet engage-t-il quelqu'un ? `bidsCount` du back ne compte que les
    // demandes en attente : un trajet dont tous les colis sont acceptés y vaut
    // 0, et passait pour vide (« Modifier » et « Supprimer » ouverts, refusés
    // ensuite par le back ; « Reporter » caché). Les colis acceptés comptent.
    final hasBids = (a.bidsCount ?? 0) > 0 || hasPending || hasColis;

    // Gating édition / suppression — un brouillon (DRAFT) est modifiable ET
    // supprimable au même titre qu'un trajet ACTIF sans demande (le backend
    // autorise désormais la suppression d'un DRAFT).
    final canEdit = (a.status == 'ACTIVE' || a.status == 'DRAFT') && !hasBids;
    final isCancelled = a.status == 'CANCELLED';
    final canDelete = canEdit || isCancelled;
    final isActive = a.status == 'ACTIVE';
    // Report (vol annulé, voyage repoussé) : là où « Modifier » est bloqué par
    // des demandes ou des colis, sur un trajet encore à venir ou passé « en
    // cours » à tort.
    final canReschedule =
        hasBids && const {'ACTIVE', 'FULL', 'IN_PROGRESS'}.contains(a.status);
    // Un colis en route, arrivé ou livré : le voyage a eu lieu, le report est
    // verrouillé (FLUTTER-BD). Même règle que le back
    // (`TripRescheduleRules.BLOCKING_STATUSES`), qui refuse de toute façon.
    final parcelOnTheWay =
        loadedBids?.any(
          (b) => _rescheduleBlockingStatuses.contains(b.status),
        ) ??
        false;

    // Tuiles présentes selon le statut. Construites dans une liste pour éviter
    // les demi-tuiles vides (ex. trajet COMPLETED/FULL n'a ni Demandes ni
    // Supprimer → la grille se réduit proprement aux tuiles réelles).
    final tiles = <Widget>[
      // ── Publier (brouillon uniquement) — toujours en première position ──
      if (a.status == 'DRAFT')
        _tile(
          iconAsset: 'send',
          label: l.tripOwnerPublishTile,
          accent: cs.primary,
          onTap: () => context.read<AnnouncementBloc>().add(
            AnnouncementPublishRequested(a.id),
          ),
        ),
      // ── Affiche partageable — uniquement tant qu'il reste de la place ──
      // Une affiche n'a de sens que sur un trajet encore remplissable : la
      // poster sur un trajet complet ferait venir des expéditeurs pour rien.
      if (canShareTripPoster(a))
        _tile(
          iconAsset: 'share-2',
          label: l.tripOwnerPosterTile,
          accent: cs.primary,
          onTap: () => openTripPoster(context, a),
        ),
      if (isActive && !hasBids)
        _tile(
          iconAsset: 'eye-off',
          label: l.tripOwnerUnpublishTile,
          accent: cs.onSurface,
          onTap: () async {
            final confirmed = await DonyDialog.show(
              context,
              title: l.tripOwnerUnpublishDialogTitle,
              message: l.tripOwnerUnpublishDialogMessage,
              confirmLabel: l.tripOwnerUnpublishTile,
              iconAsset: 'eye-off',
            );
            if (confirmed == true && context.mounted) {
              context.read<AnnouncementBloc>().add(
                AnnouncementUnpublishRequested(a.id),
              );
            }
          },
        ),
      // ── Demandes → écran « À traiter » ; désactivé si rien en attente ──
      _tile(
        iconAsset: 'package',
        label: l.tripOwnerRequestsTile,
        accent: cs.primary,
        badgeCount: pendingCount,
        onTap: hasPending
            ? () => context.push('/announcements/${a.id}/bids/pending')
            : null,
        disabledMessage: l.tripOwnerRequestsDisabledMessage,
      ),
      // ── Colis → écran des colis ; désactivé si aucun colis embarqué ──
      _tile(
        // `inbox` = convention « colis » de la feature matching (pas de `box.svg`).
        iconAsset: 'inbox',
        label: l.tripOwnerParcelsTile,
        accent: cs.primary,
        badgeCount: a.confirmedParcelCount,
        onTap: hasColis
            ? () => context.push(
                '/announcements/${a.id}/bids',
                extra: <String, dynamic>{'title': l.tripOwnerParcelsTile},
              )
            : null,
        disabledMessage: l.tripOwnerNoParcelsMessage,
      ),
      // ── Modifier (désactivée tant qu'une demande existe) ──
      _tile(
        iconAsset: 'square-pen',
        label: l.commonEdit,
        accent: cs.onSurface,
        onTap: canEdit
            ? () async {
                final bloc = context.read<AnnouncementBloc>();
                final changed = await context.push<bool>(
                  '/trips/create',
                  extra: CreateTripArgs(announcement: a),
                );
                if ((changed ?? false) && context.mounted) {
                  bloc.add(AnnouncementDetailRequested(a.id));
                }
              }
            : null,
        disabledMessage: l.tripOwnerEditDisabledMessage,
      ),
      if (canReschedule)
        _tile(
          iconAsset: 'calendar-sync',
          label: l.tripRescheduleTile,
          accent: cs.primary,
          onTap: parcelOnTheWay || a.remainingReschedules == 0
              ? null
              : () => TripRescheduleBottomSheet.show(context, announcement: a),
          disabledMessage: parcelOnTheWay
              ? l.tripRescheduleParcelOnTheWayMessage
              : l.tripRescheduleLimitReachedMessage,
        ),
      // ── Supprimer (si supprimable) ou Annuler (si ACTIVE non supprimable) ──
      if (canDelete)
        _tile(
          iconAsset: 'trash-2',
          label: l.commonDelete,
          accent: cs.error,
          onTap: () async {
            final confirmed = await DonyDialog.show(
              context,
              title: l.tripOwnerDeleteDialogTitle,
              message: isCancelled
                  ? l.tripOwnerDeleteCancelledMessage
                  : l.tripOwnerDeleteActiveMessage,
              confirmLabel: l.commonDelete,
              variant: DonyDialogVariant.destructive,
              iconAsset: 'trash-2',
            );
            if (confirmed == true && context.mounted) {
              final following = await askCancelFollowingLegs(context, a.id);
              if (!context.mounted || following == null) return;
              context.read<AnnouncementBloc>().add(
                AnnouncementDeleteRequested(a.id, followingLegIds: following),
              );
            }
          },
        )
      else if (isActive)
        _tile(
          iconAsset: 'circle-x',
          label: l.tripOwnerCancelTile,
          accent: cs.error,
          onTap: () =>
              CancellationBottomSheet.show(context, announcementId: a.id),
        ),
    ];

    // Disposition 2 colonnes ; seul un éventuel dernier rang impair laisse un
    // espace (jamais de demi-tuile vide en milieu de grille).
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

/// `true` si le trajet peut être partagé par son affiche : uniquement tant
/// qu'il reste de la place (ACTIVE). Même règle pour la tuile « Affiche » et
/// l'icône de partage de l'en-tête du détail.
bool canShareTripPoster(AnnouncementModel a) => a.status == 'ACTIVE';

/// Ouvre l'affiche partageable du trajet (lien, légende, image), action
/// commune à la tuile « Affiche » et à l'icône de partage de l'en-tête.
void openTripPoster(BuildContext context, AnnouncementModel a) {
  context.push('/announcements/${a.id}/affiche', extra: a);
}

/// Statuts de colis qui interdisent de reporter le trajet.
const _rescheduleBlockingStatuses = {'IN_TRANSIT', 'ARRIVED', 'COMPLETED'};

/// Construit une tuile d'action. Quand [onTap] est `null` et [disabledMessage]
/// fourni, la tuile est grisée (opacity 0.4) + tooltip et n'est plus tappable.
Widget _tile({
  required String iconAsset,
  required String label,
  required Color accent,
  VoidCallback? onTap,
  int badgeCount = 0,
  String? disabledMessage,
}) {
  if (onTap == null && disabledMessage != null) {
    return Tooltip(
      message: disabledMessage,
      child: Opacity(
        opacity: 0.4,
        child: _ActionTile(
          iconAsset: iconAsset,
          label: label,
          accent: accent,
          badgeCount: badgeCount,
        ),
      ),
    );
  }
  return _ActionTile(
    iconAsset: iconAsset,
    label: label,
    accent: accent,
    badgeCount: badgeCount,
    onTap: onTap,
  );
}

/// Tuile d'action : carte tappable avec icône, label et badge compteur optionnel.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.iconAsset,
    required this.label,
    required this.accent,
    this.onTap,
    this.badgeCount = 0,
  });

  final String iconAsset;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final int badgeCount;

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
              _IconCircle(iconAsset: iconAsset, accent: accent),
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
              if (badgeCount > 0) ...[
                const SizedBox(width: DonySpacing.xs),
                _CountPill(count: badgeCount, accent: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cercle coloré contenant l'icône — reprend le look du `_IconActionBtn` du sheet.
class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.iconAsset, required this.accent});

  final String iconAsset;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(child: DonyIcon(iconAsset, size: 20, color: accent)),
    );
  }
}

/// Petite pastille de compteur.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.accent});

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

/// Voyage à plusieurs étapes (FLUTTER-4D) : avant d'annuler une étape,
/// propose d'annuler aussi les suivantes encore ouvertes.
///
/// Rend les identifiants à annuler en plus (vide : les garder), ou `null` si
/// le voyageur a fermé la question sans choisir. Sans [TripGroupCubit] dans
/// l'arbre, ou pour un trajet isolé, rend une liste vide sans rien demander.
@visibleForTesting
Future<List<String>?> askCancelFollowingLegs(
  BuildContext context,
  String announcementId,
) async {
  TripGroupCubit? cubit;
  try {
    cubit = context.read<TripGroupCubit>();
  } on ProviderNotFoundException {
    cubit = null;
  }
  final following = cubit?.state.info.openLegsAfter(announcementId) ?? const [];
  if (following.isEmpty) return const [];
  final l = context.l10n;
  final cancelThem = await DonyDialog.show(
    context,
    title: l.tripLegsCancelFollowingTitle,
    message: l.tripLegsCancelFollowingMessage(following.length),
    confirmLabel: l.tripLegsCancelFollowingConfirm,
    cancelLabel: l.tripLegsCancelFollowingKeep,
    variant: DonyDialogVariant.destructive,
    icon: Icons.alt_route_rounded,
  );
  if (cancelThem == null) return null;
  return cancelThem ? following.map((leg) => leg.id).toList() : const [];
}
