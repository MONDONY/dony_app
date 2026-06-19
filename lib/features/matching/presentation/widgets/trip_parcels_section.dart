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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Section « Colis dans le trajet » de l'écran détail trajet (propriétaire).
///
/// Consomme le [BidBloc] fourni par la route (`BidListRequested(announcementId)`).
/// Filtre les offres réellement embarquées via [isAcceptedTabBid] (source de
/// vérité du projet : ACCEPTED / HANDED_OVER / IN_TRANSIT / COMPLETED, moins les
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

  void _logOnce(int count) {
    if (_logged) {
      return;
    }
    _logged = true;
    unawaited(getIt<AnalyticsService>().logEvent(
      AnalyticsEvents.tripParcelsViewed,
      properties: {'count': count},
    ));
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
              return Padding(
                padding: const EdgeInsets.all(DonySpacing.lg),
                child: Center(
                  child: CircularProgressIndicator(color: cs.primary),
                ),
              );
            }
            if (state is BidListLoaded) {
              final filtered =
                  state.bids.where(isAcceptedTabBid).toList(growable: false);

              // Premier rendu de la liste chargée → tir analytics unique.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _logOnce(filtered.length);
              });

              if (filtered.isEmpty) {
                return const DonyEmptyState(
                  iconAsset: 'inbox',
                  title: 'Aucun colis embarqué',
                  description: 'Les colis acceptés apparaîtront ici.',
                  padding: EdgeInsets.symmetric(vertical: DonySpacing.xl),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < filtered.length; i++) ...[
                    if (i > 0) const SizedBox(height: DonySpacing.sm),
                    _ColisRow(bid: filtered[i]),
                  ],
                ],
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
    final sender = bid.senderName ?? 'Expéditeur';
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

/// Petit chip de statut traduit en français pour un colis embarqué.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'ACCEPTED' => ('Accepté', cs.primary),
      'HANDED_OVER' => ('Remis', cs.warning),
      'IN_TRANSIT' => ('En transit', cs.info),
      'COMPLETED' => ('Livré', cs.success),
      'NO_SHOW' => ('Absent', cs.error),
      'PARCEL_REFUSED' => ('Refusé', cs.error),
      'CANCELLED' => ('Annulé', cs.error),
      _ => (status, cs.onSurfaceVariant),
    };
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
