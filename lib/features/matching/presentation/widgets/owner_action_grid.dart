import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
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

    // Gating édition / suppression — un brouillon (DRAFT) est modifiable ET
    // supprimable au même titre qu'un trajet ACTIF sans demande (le backend
    // autorise désormais la suppression d'un DRAFT).
    final canEdit =
        (a.status == 'ACTIVE' || a.status == 'DRAFT') &&
        (a.bidsCount ?? 0) == 0;
    final isCancelled = a.status == 'CANCELLED';
    final canDelete =
        ((a.status == 'ACTIVE' || a.status == 'DRAFT') &&
            (a.bidsCount ?? 0) == 0) ||
        isCancelled;
    final isActive = a.status == 'ACTIVE';

    // Tuiles présentes selon le statut. Construites dans une liste pour éviter
    // les demi-tuiles vides (ex. trajet COMPLETED/FULL n'a ni Demandes ni
    // Supprimer → la grille se réduit proprement aux tuiles réelles).
    final tiles = <Widget>[
      // ── Publier (brouillon uniquement) — toujours en première position ──
      if (a.status == 'DRAFT')
        _tile(
          iconAsset: 'send',
          label: 'Publier',
          accent: cs.primary,
          onTap: () => context.read<AnnouncementBloc>().add(
            AnnouncementPublishRequested(a.id),
          ),
        ),
      if (isActive && (a.bidsCount ?? 0) == 0)
        _tile(
          iconAsset: 'eye-off',
          label: 'Dépublier',
          accent: cs.onSurface,
          onTap: () async {
            final confirmed = await DonyDialog.show(
              context,
              title: 'Dépublier ce trajet ?',
              message:
                  'Le trajet ne sera plus visible et restera dans vos brouillons.',
              confirmLabel: 'Dépublier',
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
        label: 'Demandes',
        accent: cs.primary,
        badgeCount: pendingCount,
        onTap: hasPending
            ? () => context.push('/announcements/${a.id}/bids/pending')
            : null,
        disabledMessage: 'Aucune demande à traiter',
      ),
      // ── Colis → écran des colis ; désactivé si aucun colis embarqué ──
      _tile(
        // `inbox` = convention « colis » de la feature matching (pas de `box.svg`).
        iconAsset: 'inbox',
        label: 'Colis',
        accent: cs.primary,
        badgeCount: a.confirmedParcelCount,
        onTap: hasColis
            ? () => context.push(
                '/announcements/${a.id}/bids',
                extra: const <String, dynamic>{'title': 'Colis'},
              )
            : null,
        disabledMessage: 'Aucun colis embarqué',
      ),
      // ── Modifier (désactivée tant qu'une demande existe) ──
      _tile(
        iconAsset: 'square-pen',
        label: 'Modifier',
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
        disabledMessage: 'Modifiable tant qu\'aucune demande',
      ),
      // ── Supprimer (si supprimable) ou Annuler (si ACTIVE non supprimable) ──
      if (canDelete)
        _tile(
          iconAsset: 'trash-2',
          label: 'Supprimer',
          accent: cs.error,
          onTap: () async {
            final confirmed = await DonyDialog.show(
              context,
              title: 'Supprimer ce trajet ?',
              message: isCancelled
                  ? 'Cette action est irréversible. Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.'
                  : 'Cette action est irréversible. Le trajet ne sera plus visible pour les expéditeurs.',
              confirmLabel: 'Supprimer',
              variant: DonyDialogVariant.destructive,
              iconAsset: 'trash-2',
            );
            if (confirmed == true && context.mounted) {
              context.read<AnnouncementBloc>().add(
                AnnouncementDeleteRequested(a.id),
              );
            }
          },
        )
      else if (isActive)
        _tile(
          iconAsset: 'circle-x',
          label: 'Annuler',
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
