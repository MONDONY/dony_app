import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Section « Colis dans le trajet » de l'écran détail trajet (propriétaire).
///
/// Consomme le [BidBloc] fourni par la route (`BidListRequested(announcementId)`).
/// Filtre les offres réellement embarquées via [isAcceptedTabBid] (source de
/// vérité du projet : ACCEPTED / HANDED_OVER / IN_TRANSIT / ARRIVED / COMPLETED,
/// moins les
/// auto-annulés). Émet une fois l'event analytics `trip_parcels_viewed` au
/// premier chargement de la liste (compteur uniquement, aucune PII).
class TripParcelsSection extends StatefulWidget {
  const TripParcelsSection({super.key});

  @override
  State<TripParcelsSection> createState() => _TripParcelsSectionState();
}

class _TripParcelsSectionState extends State<TripParcelsSection> {
  /// Garde l'event analytics à un seul tir (pas à chaque rebuild). Mutée hors
  /// `setState` — elle ne déclenche aucun rendu, juste l'idempotence du log.
  bool _logged = false;

  /// Filtre statut courant (`null` = « Tous »). Mutation via `ValueNotifier`
  /// (pas de `setState`) — seul le contenu de la liste se reconstruit.
  final ValueNotifier<String?> _statusFilter = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _statusFilter.dispose();
    super.dispose();
  }

  void _logOnce(int count) {
    if (_logged) {
      return;
    }
    _logged = true;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.tripParcelsViewed,
        properties: {'count': count},
      ),
    );
  }

  void _onFilter(String? status) {
    if (_statusFilter.value == status) {
      return;
    }
    _statusFilter.value = status;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.tripParcelsFiltered,
        properties: {'status': status ?? 'all'},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Colis dans le trajet',
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        BlocBuilder<BidBloc, BidState>(
          builder: (context, state) {
            if (state is BidInitial || state is BidLoading) {
              return const Column(
                children: [
                  DonyUserCardSkeleton(),
                  SizedBox(height: DonySpacing.sm),
                  DonyUserCardSkeleton(),
                ],
              );
            }
            if (state is BidListLoaded) {
              final embarked = state.bids
                  .where(isAcceptedTabBid)
                  .toList(growable: false);

              // Premier rendu de la liste chargée → tir analytics unique.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _logOnce(embarked.length);
              });

              if (embarked.isEmpty) {
                return const DonyEmptyState(
                  iconAsset: 'inbox',
                  title: 'Aucun colis embarqué',
                  description: 'Les colis acceptés apparaîtront ici.',
                  padding: EdgeInsets.symmetric(vertical: DonySpacing.xl),
                );
              }

              // Compteur par statut + statuts présents (ordre métier fixe).
              final counts = <String, int>{};
              for (final b in embarked) {
                counts[b.status] = (counts[b.status] ?? 0) + 1;
              }
              final present = <String>[
                for (final st in _kStatusOrder)
                  if (counts.containsKey(st)) st,
                for (final st in counts.keys)
                  if (!_kStatusOrder.contains(st)) st,
              ];

              return ValueListenableBuilder<String?>(
                valueListenable: _statusFilter,
                builder: (context, filter, _) {
                  // Filtre actif disparu (liste rechargée) → repli sur « Tous ».
                  final active = (filter != null && counts.containsKey(filter))
                      ? filter
                      : null;
                  final visible = active == null
                      ? embarked
                      : embarked
                            .where((b) => b.status == active)
                            .toList(growable: false);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Filtre rapide : seulement si ≥ 2 statuts distincts.
                      if (present.length >= 2) ...[
                        StatusChipsRow<String?>(
                          selected: active,
                          onSelected: _onFilter,
                          chips: [
                            StatusChipData<String?>(
                              label: 'Tous',
                              value: null,
                              count: embarked.length,
                            ),
                            for (final st in present)
                              _statusFilterChip(st, counts[st]!, cs),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.md),
                      ],
                      for (var i = 0; i < visible.length; i++) ...[
                        if (i > 0) const SizedBox(height: DonySpacing.sm),
                        _ColisRow(bid: visible[i]),
                      ],
                    ],
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

/// Ligne compacte d'un colis embarqué : miniature optionnelle, contenu, poids,
/// expéditeur et chip de statut. Tap → détail de l'offre (`/bids/:bidId`).
class _ColisRow extends StatelessWidget {
  const _ColisRow({required this.bid});

  final BidModel bid;

  String? get _weightLabel {
    final w = bid.weightKg;
    if (w == null) {
      return null;
    }
    return '${w.toStringAsFixed(w % 1 == 0 ? 0 : 1)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final content = bid.contentCategory ?? bid.description ?? 'Colis';
    final sender = bid.resolvedSenderName;
    final weight = _weightLabel;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: () => context.push('/bids/${bid.id}'),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              if (bid.photos.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: CachedNetworkImage(
                      imageUrl: bid.photos.first.url,
                      cacheKey: DonyImage.stableCacheKey(bid.photos.first.url),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          ColoredBox(color: cs.surfaceContainerHighest),
                      errorWidget: (_, _, _) => ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weight != null ? '$sender · $weight' : sender,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              _StatusChip(status: bid.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ordre d'affichage métier des statuts dans le filtre rapide.
const _kStatusOrder = <String>[
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
  'NO_SHOW',
  'PARCEL_REFUSED',
  'CANCELLED',
];

/// Libellé FR + couleur d'un statut de colis embarqué.
(String, Color) _statusMeta(String status, ColorScheme cs) => switch (status) {
  'ACCEPTED' => ('Accepté', cs.primary),
  'HANDED_OVER' => ('Remis', cs.warning),
  'IN_TRANSIT' => ('En transit', cs.info),
  // Même libellé/couleur que le _StatusDot de bid_card.dart.
  'ARRIVED' => ('Arrivé', cs.info),
  'COMPLETED' => ('Livré', cs.success),
  'NO_SHOW' => ('Absent', cs.error),
  'PARCEL_REFUSED' => ('Refusé', cs.error),
  'CANCELLED' => ('Annulé', cs.error),
  _ => (status, cs.onSurfaceVariant),
};

/// Chip de filtre d'un statut : libellé FR + compteur + pastille colorée.
StatusChipData<String?> _statusFilterChip(
  String status,
  int count,
  ColorScheme cs,
) {
  final (label, color) = _statusMeta(status, cs);
  return StatusChipData<String?>(
    label: label,
    value: status,
    count: count,
    dotColor: color,
  );
}

/// Petit chip de statut traduit en français pour un colis embarqué.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = _statusMeta(status, cs);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
