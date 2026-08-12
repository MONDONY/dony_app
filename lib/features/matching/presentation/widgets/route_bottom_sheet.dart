import 'package:dony/core/constants/cities.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// ── Filtre scellé ─────────────────────────────────────────────────────────────

sealed class TripFilter {
  const TripFilter();
}

class DepartureCityFilter extends TripFilter {
  final City city;
  const DepartureCityFilter(this.city);
}

class ArrivalCityFilter extends TripFilter {
  final City city;
  const ArrivalCityFilter(this.city);
}

class ExactRouteFilter extends TripFilter {
  final City from;
  final City to;
  const ExactRouteFilter(this.from, this.to);
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class RouteBottomSheet extends StatelessWidget {
  final List<AnnouncementModel> announcements;
  final TripFilter filter;

  const RouteBottomSheet({
    super.key,
    required this.announcements,
    required this.filter,
  });

  String get _title => switch (filter) {
    ExactRouteFilter(from: final f, to: final t) =>
      '${f.displayName} → ${t.displayName}',
    DepartureCityFilter(city: final c) => 'Départs depuis ${c.displayName}',
    ArrivalCityFilter(city: final c) => 'Arrivées à ${c.displayName}',
  };

  List<AnnouncementModel> get _filtered => switch (filter) {
    ExactRouteFilter(from: final f, to: final t) =>
      announcements
          .where(
            (a) =>
                a.departureCity == f.displayName &&
                a.arrivalCity == t.displayName,
          )
          .toList(),
    DepartureCityFilter(city: final c) =>
      announcements.where((a) => a.departureCity == c.displayName).toList(),
    ArrivalCityFilter(city: final c) =>
      announcements.where((a) => a.arrivalCity == c.displayName).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final items = _filtered;
    final auth = context.read<AuthBloc>().state;
    final currentUserId = auth.currentUserId;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DonyRadius.sheet),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
              child: Row(
                children: [
                  Expanded(child: Text(_title, style: tt.titleLarge)),
                  Text(
                    '${items.length} trajet${items.length != 1 ? 's' : ''}',
                    style: tt.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            // List or empty state
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun trajet disponible sur cette route',
                        style: tt.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : BlocBuilder<BidBloc, BidState>(
                      buildWhen: (prev, curr) =>
                          curr is BidListLoaded || prev is BidListLoaded,
                      builder: (context, bidState) {
                        final activeBids = bidState.activeBidsByAnnouncement();
                        return ListView.separated(
                          controller: scrollCtrl,
                          // Liste courte (trajets d'une même route) : on
                          // construit largement hors écran pour que les cartes
                          // soient prêtes au scroll (pas de carte blanche).
                          cacheExtent: 1200,
                          padding: const EdgeInsets.fromLTRB(
                            DonySpacing.base,
                            0,
                            DonySpacing.base,
                            DonySpacing.huge,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: DonySpacing.md),
                          itemBuilder: (_, i) {
                            final ann = items[i];
                            final isOwn =
                                currentUserId != null &&
                                ann.travelerId == currentUserId;
                            final existingBid = activeBids[ann.id];
                            return TravelerCard(
                              key: Key('traveler-card-${ann.id}'),
                              announcement: ann,
                              index: i,
                              isOwnAnnouncement: isOwn,
                              showFavorite: !isOwn,
                              existingBidStatus: existingBid?.status,
                              onTap: existingBid != null
                                  ? () {
                                      ctx.pop();
                                      context.push(
                                        '/bids/${existingBid.id}',
                                        extra: existingBid,
                                      );
                                    }
                                  : () {
                                      ctx.pop();
                                      showTravelerAnnouncementSheet(
                                        context,
                                        announcement: ann,
                                        existingBidStatus: existingBid?.status,
                                      );
                                    },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
