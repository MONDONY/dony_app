import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_bottom_sheet.dart';
import 'package:dony/features/profile/bloc/open_listings_cubit.dart';
import 'package:dony/features/profile/data/models/open_listing.dart';
import 'package:dony/features/subscriptions/presentation/widgets/subscription_recency.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Section « En cours » du profil d'un autre membre : ses trajets et ses
/// demandes d'envoi ouverts, mélangés, du plus récent au plus ancien selon la
/// date de publication. Les cartes sont celles de l'onglet Recherche.
///
/// Se masque sans bruit quand l'[OpenListingsCubit] n'est pas fourni ou que la
/// lecture échoue (back pas encore déployé, réseau) : le reste du profil ne
/// dépend jamais de cette section.
class OpenListingsSection extends StatelessWidget {
  const OpenListingsSection({super.key});

  static OpenListingsCubit? _cubitOrNull(BuildContext context) {
    try {
      return context.read<OpenListingsCubit>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubitOrNull(context);
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<OpenListingsCubit, OpenListingsState>(
      bloc: cubit,
      builder: (context, state) => switch (state) {
        OpenListingsInitial() ||
        OpenListingsFailed() => const SizedBox.shrink(),
        OpenListingsLoading() => const _Frame(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: DonySpacing.base),
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
        OpenListingsLoaded() => _Frame(
          count: state.items.length,
          child: _Loaded(state: state, cubit: cubit),
        ),
      },
    );
  }
}

/// Filet fin, marges et titre, comme les autres sections du profil public.
class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.count});

  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.6)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l.openListingsTitle.toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: DonySpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: 1,
                      ),
                      child: Text(
                        '$count',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state, required this.cubit});

  final OpenListingsLoaded state;
  final OpenListingsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (state.items.isEmpty) {
      return Text(
        l.openListingsEmpty,
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    final visible = state.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Un seul type d'annonce : le filtre n'a rien à trier.
        if (state.tripCount > 0 && state.requestCount > 0) ...[
          DonySegmentedControl<OpenListingsFilter>(
            selected: state.filter,
            onSelect: cubit.selectFilter,
            segments: [
              DonySegment(
                value: OpenListingsFilter.all,
                label: l.openListingsFilterAll,
              ),
              DonySegment(
                value: OpenListingsFilter.trips,
                label: l.openListingsFilterTrips,
                count: state.tripCount,
                countStyle: DonySegmentCountStyle.neutral,
              ),
              DonySegment(
                value: OpenListingsFilter.requests,
                label: l.openListingsFilterRequests,
                count: state.requestCount,
                countStyle: DonySegmentCountStyle.neutral,
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
        ],
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: DonySpacing.base),
          _PostedAgo(publishedAt: visible[i].publishedAt),
          const SizedBox(height: DonySpacing.xs),
          switch (visible[i]) {
            OpenTripListing(:final announcement) => TravelerCard(
              announcement: announcement,
              index: i,
              compact: true,
              isOwnAnnouncement: false,
              onTap: () {
                cubit.trackOpened('trip');
                showTravelerAnnouncementSheet(
                  context,
                  announcement: announcement,
                );
              },
            ),
            OpenRequestListing(:final item) => PackageRequestListCard(
              item: item,
              index: i,
              compact: true,
              onTap: () {
                cubit.trackOpened('request');
                PackageRequestPreviewBottomSheet.show(context, item: item);
              },
            ),
          },
        ],
      ],
    );
  }
}

/// « En ligne hier » : repère de date devant chaque carte, puisque la liste est
/// rangée par date de publication et que les cartes n'affichent que le départ.
class _PostedAgo extends StatelessWidget {
  const _PostedAgo({required this.publishedAt});

  final DateTime publishedAt;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Text(
      l.openListingsPostedAgo(subscriptionRecencyLabel(l, publishedAt)),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
