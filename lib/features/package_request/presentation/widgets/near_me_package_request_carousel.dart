import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_compact_card.dart';
import 'package:flutter/material.dart';

/// Carousel near-me pour les demandes (côté voyageur, tab "Demandes" + filtre
/// "Près de moi" activé).
///
/// Symétrique de `NearMeCarousel` (announcements) mais pour des
/// `PackageRequestSearchItem`. PageView horizontal avec viewportFraction 0.85
/// affichant des `PackageRequestCompactCard`. Bouton "Voir les N demandes"
/// en bas → `onSeeAll`.
class NearMePackageRequestCarousel extends StatefulWidget {
  const NearMePackageRequestCarousel({
    super.key,
    required this.items,
    required this.userPosition,
    required this.onSeeAll,
    this.selectedRequestId,
    this.onCardChanged,
    this.onTapCard,
    this.onMakeOffer,
  });

  final List<PackageRequestSearchItem> items;
  final ({double lat, double lng})? userPosition;
  final VoidCallback onSeeAll;
  final String? selectedRequestId;
  final void Function(String id)? onCardChanged;
  final void Function(PackageRequestSearchItem)? onTapCard;
  final void Function(PackageRequestSearchItem)? onMakeOffer;

  @override
  State<NearMePackageRequestCarousel> createState() =>
      _NearMePackageRequestCarouselState();
}

class _NearMePackageRequestCarouselState
    extends State<NearMePackageRequestCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final foundIdx = widget.selectedRequestId != null
        ? widget.items.indexWhere((it) => it.id == widget.selectedRequestId)
        : 0;
    final initialIndex = foundIdx < 0
        ? 0
        : foundIdx > widget.items.length - 1
            ? math.max(0, widget.items.length - 1)
            : foundIdx;
    _currentIndex = initialIndex;
    _controller = PageController(
      viewportFraction: 0.85,
      initialPage: initialIndex,
    );
  }

  @override
  void didUpdateWidget(covariant NearMePackageRequestCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRequestId != oldWidget.selectedRequestId &&
        widget.selectedRequestId != null) {
      final idx =
          widget.items.indexWhere((it) => it.id == widget.selectedRequestId);
      if (idx >= 0 && idx != _currentIndex && _controller.hasClients) {
        _controller.animateToPage(
          idx,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDistance(PackageRequestSearchItem item) {
    if (widget.userPosition == null ||
        item.departureLat == null ||
        item.departureLng == null) {
      return '—';
    }
    final km = _haversineKm(
      widget.userPosition!.lat,
      widget.userPosition!.lng,
      item.departureLat!,
      item.departureLng!,
    );
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.items.isEmpty) {
      return _EmptyState(onSeeAll: widget.onSeeAll);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            padEnds: true,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              widget.onCardChanged?.call(widget.items[i].id);
            },
            itemBuilder: (_, i) {
              final item = widget.items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: DonySpacing.sm),
                child: PackageRequestCompactCard(
                  item: item,
                  distanceLabel: _formatDistance(item),
                  onTap: widget.onTapCard != null
                      ? () => widget.onTapCard!(item)
                      : null,
                  onMakeOffer: widget.onMakeOffer != null
                      ? () => widget.onMakeOffer!(item)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        GestureDetector(
          onTap: widget.onSeeAll,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: DonySpacing.base, vertical: DonySpacing.sm),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.xl),
            ),
            child: Text(
              'Voir les ${widget.items.length} demandes',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_searching_rounded,
                color: cs.onSurfaceVariant, size: 32),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Aucune demande à proximité',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'Élargir la zone',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180);
