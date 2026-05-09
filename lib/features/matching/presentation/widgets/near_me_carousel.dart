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
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

/// Returns a formatted badge like "CDG · 3 km" or null when unavailable.
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
    required this.scrollController,
    required this.onSeeAll,
    this.selectedAnnouncementId,
    this.onCardChanged,
    this.onTapCard,
  });

  final List<AnnouncementModel> announcements;
  final ({double lat, double lng})? userPosition;
  final ScrollController scrollController;
  final VoidCallback onSeeAll;
  final String? selectedAnnouncementId;
  final void Function(String id)? onCardChanged;
  /// Custom tap handler. When null, defaults to [showTravelerAnnouncementSheet].
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
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (widget.announcements.isEmpty) {
      return CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(DonySpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: DonyColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.near_me_rounded,
                        color: DonyColors.primary, size: 26),
                  ),
                  const SizedBox(height: DonySpacing.md),
                  Text(
                    'Aucun voyageur à proximité',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    'Essaie d\'augmenter le rayon ou de changer de date.',
                    style:
                        tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
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
                    final currentUserId = authState is AuthAuthenticated
                        ? authState.user.id
                        : null;
                    final isOwn = currentUserId != null &&
                        a.travelerId == currentUserId;
                    return BlocBuilder<BidBloc, BidState>(
                      buildWhen: (prev, curr) =>
                          curr is BidListLoaded || prev is BidListLoaded,
                      builder: (context, bidState) {
                        final existingBid =
                            bidState.activeBidsByAnnouncement()[a.id];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.sm),
                          child: TravelerCard(
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
                                          showTravelerAnnouncementSheet(context,
                                              announcement: a);
                                        }
                                      },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.md,
                    DonySpacing.lg, bottomPad + DonySpacing.md),
                child: GestureDetector(
                  onTap: widget.onSeeAll,
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: DonySpacing.md),
                    decoration: BoxDecoration(
                      color: DonyColors.primarySoft,
                      borderRadius:
                          BorderRadius.circular(DonyRadius.card),
                      border: Border.all(
                          color:
                              DonyColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Voir les ${widget.announcements.length} annonce${widget.announcements.length > 1 ? 's' : ''}',
                          style: tt.labelLarge?.copyWith(
                              color: DonyColors.primary,
                              fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: DonySpacing.xxs),
                        Text(
                          'Tirez vers le haut pour la liste',
                          style: tt.bodySmall
                              ?.copyWith(color: DonyColors.primary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
