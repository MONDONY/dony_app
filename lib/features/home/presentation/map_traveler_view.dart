import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/widgets/near_me_package_request_carousel.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Traveler-side home view: map + draggable sheet listing nearby package
/// requests to make offers on. Mirrors the sender's `_MapSenderView` UX but
/// with a single "Demandes" focus (no tabs — the traveler comes here to find
/// requests, not announcements).
class MapTravelerView extends StatelessWidget {
  const MapTravelerView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PackageRequestSearchBloc>(
      create: (_) => getIt<PackageRequestSearchBloc>()
        ..add(const SearchFiltersChanged()),
      child: const _MapTravelerViewContent(),
    );
  }
}

class _MapTravelerViewContent extends StatefulWidget {
  const _MapTravelerViewContent();

  @override
  State<_MapTravelerViewContent> createState() =>
      _MapTravelerViewContentState();
}

class _MapTravelerViewContentState extends State<_MapTravelerViewContent> {
  final _sheetController = DraggableScrollableController();
  double _sheetSize = 0.30;

  LatLng? _userPosition;
  double? _radiusKm;
  String? _selectedRequestId;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      if (!mounted) return;
      final newSize = _sheetController.size;
      if ((newSize - _sheetSize).abs() > 0.02) {
        setState(() => _sheetSize = newSize);
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _activateNearMe() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Accès localisation refusé — active-le pour voir les demandes près de toi'),
      ));
      return;
    }
    if (!mounted) return;
    final selectedRadius = await NearMeRadiusSheet.show(context);
    if (selectedRadius == null) return;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    if (!mounted) return;
    setState(() {
      _userPosition = LatLng(position.latitude, position.longitude);
      _radiusKm = selectedRadius;
    });
    context.read<PackageRequestSearchBloc>().add(SearchFiltersChanged(
          userLat: position.latitude,
          userLng: position.longitude,
          radiusKm: selectedRadius,
        ));
  }

  void _deactivateNearMe() {
    setState(() {
      _userPosition = null;
      _radiusKm = null;
    });
    context.read<PackageRequestSearchBloc>().add(const SearchFiltersChanged());
  }

  Set<Marker> _markersFor(List<PackageRequestSearchItem> items) {
    return items
        .where((it) => it.departureLat != null && it.departureLng != null)
        .map((it) {
      return Marker(
        markerId: MarkerId('pr_${it.id}'),
        position: LatLng(it.departureLat!, it.departureLng!),
        infoWindow: InfoWindow(
          title: '${it.departureCity} → ${it.arrivalCity}',
          snippet: it.targetPriceEur != null
              ? '${it.targetPriceEur!.toStringAsFixed(0)} €'
              : 'Libre',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _selectedRequestId == it.id
              ? BitmapDescriptor.hueAzure
              : BitmapDescriptor.hueRed,
        ),
        onTap: () => setState(() => _selectedRequestId = it.id),
      );
    }).toSet();
  }

  void _openPreview(BuildContext context, PackageRequestSearchItem item) {
    PackageRequestPreviewBottomSheet.show(context, item: item);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<PackageRequestSearchBloc, PackageRequestSearchState>(
      builder: (context, state) {
        final markers = _markersFor(state.results);
        final isNearMe = _userPosition != null;
        return Scaffold(
          backgroundColor: cs.surface,
          body: Stack(
            children: [
              AnnouncementMapView(
                announcements: const [],
                extraMarkers: markers,
                isNearMeActive: isNearMe,
                activeRadiusKm: _radiusKm,
                userPosition: _userPosition,
                fabBottomPadding: MediaQuery.of(context).size.height * _sheetSize,
                mapStyle: null,
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: _TravelerHeader(
                  count: state.results.length,
                  isNearMe: isNearMe,
                  onToggleNearMe: () =>
                      isNearMe ? _deactivateNearMe() : _activateNearMe(),
                ),
              ),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.30,
                minChildSize: 0.18,
                maxChildSize: 0.95,
                snap: true,
                snapSizes: const [0.18, 0.45, 0.95],
                builder: (ctx, scrollCtrl) => _TravelerSheet(
                  scrollController: scrollCtrl,
                  state: state,
                  isNearMe: isNearMe,
                  userPosition: _userPosition,
                  selectedRequestId: _selectedRequestId,
                  onCardChanged: (id) =>
                      setState(() => _selectedRequestId = id),
                  onSeeAll: () => _sheetController.animateTo(
                    0.95,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  ),
                  onTapItem: (it) => _openPreview(ctx, it),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TravelerHeader extends StatelessWidget {
  const _TravelerHeader({
    required this.count,
    required this.isNearMe,
    required this.onToggleNearMe,
  });

  final int count;
  final bool isNearMe;
  final VoidCallback onToggleNearMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.inbox_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demandes à transporter',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      isNearMe
                          ? '$count près de toi'
                          : count > 0
                              ? '$count demandes ouvertes'
                              : 'Aucune demande ouverte',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _NearMeChip(active: isNearMe, onTap: onToggleNearMe),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: -0.1);
  }
}

class _NearMeChip extends StatelessWidget {
  const _NearMeChip({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? cs.primary : cs.surfaceContainerHigh;
    final textColor = active ? cs.onPrimary : cs.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  size: 14, color: textColor),
              const SizedBox(width: 6),
              Text(
                'Près de moi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelerSheet extends StatelessWidget {
  const _TravelerSheet({
    required this.scrollController,
    required this.state,
    required this.isNearMe,
    required this.userPosition,
    required this.selectedRequestId,
    required this.onCardChanged,
    required this.onSeeAll,
    required this.onTapItem,
  });

  final ScrollController scrollController;
  final PackageRequestSearchState state;
  final bool isNearMe;
  final LatLng? userPosition;
  final String? selectedRequestId;
  final ValueChanged<String> onCardChanged;
  final VoidCallback onSeeAll;
  final ValueChanged<PackageRequestSearchItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(child: _SheetHandle()),
          SliverToBoxAdapter(child: _SheetTitle(count: state.results.length)),
          if (isNearMe)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: NearMePackageRequestCarousel(
                  items: state.results,
                  userPosition: userPosition == null
                      ? null
                      : (lat: userPosition!.latitude, lng: userPosition!.longitude),
                  selectedRequestId: selectedRequestId,
                  onCardChanged: onCardChanged,
                  onSeeAll: onSeeAll,
                  onTapCard: onTapItem,
                ),
              ),
            ),
          if (state.status == SearchStatus.loading && state.results.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(isNearMe: isNearMe),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              sliver: SliverList.separated(
                itemCount: state.results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final item = state.results[i];
                  return PackageRequestListCard(
                    item: item,
                    onTap: () => onTapItem(item),
                    onMakeOffer: () => onTapItem(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: cs.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Text(
            'Demandes',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 10),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isNearMe});
  final bool isNearMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, color: cs.onSurfaceVariant, size: 40),
          const SizedBox(height: 12),
          Text(
            isNearMe ? 'Aucune demande dans ce rayon' : 'Aucune demande pour le moment',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isNearMe
                ? 'Élargis ta zone ou désactive “Près de moi”'
                : 'Reviens dans un instant — de nouvelles demandes sont publiées chaque jour',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
