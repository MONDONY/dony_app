import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

/// Retourne un badge formaté "CDG · 3 km" ou null si indisponible.
String? buildDistanceBadge(
  AnnouncementModel announcement,
  ({double lat, double lng})? userPos,
) {
  if (userPos == null) return null;
  final pickup = announcement.pickupAddress;
  if (pickup == null) return null;

  final distanceM = Geolocator.distanceBetween(
      userPos.lat, userPos.lng, pickup.lat, pickup.lng);
  final distanceKm = (distanceM / 1000).round();

  final allMatches = RegExp(r'\b([A-Z]{3})\b').allMatches(pickup.label);
  final locationCode = allMatches.isNotEmpty
      ? allMatches.last.group(1)!
      : pickup.label.split(' ').first;

  final distanceLabel = distanceKm == 0 ? '< 1 km' : '$distanceKm km';
  return '$locationCode · $distanceLabel';
}

class NearMeCarousel extends StatefulWidget {
  const NearMeCarousel({
    super.key,
    required this.announcements,
    required this.userPosition,
    required this.onSeeAll,
    this.selectedAnnouncementId,
    this.onCardChanged,
    this.onTapCard,
  });

  final List<AnnouncementModel> announcements;
  final ({double lat, double lng})? userPosition;
  final VoidCallback onSeeAll;
  final String? selectedAnnouncementId;
  final void Function(String id)? onCardChanged;
  /// Gestionnaire de tap custom. Si null, ouvre [showTravelerAnnouncementSheet].
  final void Function(AnnouncementModel)? onTapCard;

  @override
  State<NearMeCarousel> createState() => _NearMeCarouselState();
}

class _NearMeCarouselState extends State<NearMeCarousel> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: _pageForId(widget.selectedAnnouncementId),
    );
  }

  @override
  void didUpdateWidget(covariant NearMeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAnnouncementId != widget.selectedAnnouncementId &&
        widget.selectedAnnouncementId != null) {
      final page = _pageForId(widget.selectedAnnouncementId);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  int _pageForId(String? id) {
    if (id == null) return 0;
    final i = widget.announcements.indexWhere((a) => a.id == id);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (widget.announcements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Builder(
                builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: DonyIcon('navigation',
                        color: cs.primary, size: 26),
                  );
                },
              ),
              const SizedBox(height: DonySpacing.md),
              Text(
                'Aucun voyageur à proximité',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DonySpacing.xs),
              Builder(
                builder: (context) => Text(
                  "Essaie d'augmenter le rayon ou de changer de date.",
                  style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.announcements.length,
            onPageChanged: (i) {
              widget.onCardChanged?.call(widget.announcements[i].id);
            },
            itemBuilder: (context, i) {
              final a = widget.announcements[i];
              final badge = buildDistanceBadge(a, widget.userPosition);
              final authState = context.read<AuthBloc>().state;
              final currentUserId =
                  authState is AuthAuthenticated ? authState.user.id : null;
              final isOwn =
                  currentUserId != null && a.travelerId == currentUserId;
              return BlocBuilder<BidBloc, BidState>(
                buildWhen: (prev, curr) =>
                    curr is BidListLoaded || prev is BidListLoaded,
                builder: (context, bidState) {
                  final existingBid =
                      bidState.activeBidsByAnnouncement()[a.id];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: TravelerCard(
                      key: Key('near-me-card-${a.id}'),
                      announcement: a,
                      index: i,
                      isOwnAnnouncement: isOwn,
                      distanceBadge: badge,
                      existingBidStatus: existingBid?.status,
                      onTap: isOwn
                          ? null
                          : existingBid != null
                              ? () => context.push(
                                    '/bids/${existingBid.id}',
                                    extra: existingBid,
                                  )
                              : () {
                                  if (widget.onTapCard != null) {
                                    widget.onTapCard!(a);
                                  } else {
                                    showTravelerAnnouncementSheet(
                                      context,
                                      announcement: a,
                                      existingBidStatus: existingBid?.status,
                                    );
                                  }
                                },
                    ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg, DonySpacing.md, DonySpacing.lg, DonySpacing.md),
          child: GestureDetector(
            onTap: widget.onSeeAll,
            child: Container(
              key: const Key('near-me-see-all-btn'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                widget.announcements.length == 1
                    ? 'Voir l\'annonce'
                    : 'Voir les ${widget.announcements.length} annonces',
                style: tt.labelLarge?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
