import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/widgets/near_me_package_request_carousel.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Traveler-side home view: map + draggable sheet listing nearby package
/// requests to make offers on. Mirrors the sender's `_MapSenderView` UX but
/// with a single "Demandes" focus (no tabs — the traveler comes here to find
/// requests, not announcements).
class MapTravelerView extends StatelessWidget {
  const MapTravelerView({super.key});

  @override
  Widget build(BuildContext context) {
    // `!hasRealSession` et non `isAnonymous` : est visiteur aussi bien celui
    // qui porte une session anonyme que celui qui n'a aucune session (arrivée
    // par lien profond avant tout démarrage). `isAnonymous` déclarerait ce
    // dernier inscrit, et il repartirait sur l'endpoint authentifié pour un
    // 401 et une liste vide au lieu des résultats publics.
    final isGuest = !getIt<FirebaseSessionProbe>().hasRealSession;
    return BlocProvider<PackageRequestSearchBloc>(
      create: (_) =>
          getIt<PackageRequestSearchBloc>()
            ..add(SearchFiltersChanged(publicAccess: isGuest)),
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
    const locationService = GeolocatorLocationService();
    final access = await requestLocationAccess(locationService);
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      await LocationDeniedSheet.show(context, access: access);
      return;
    }
    final selectedRadius = await NearMeRadiusSheet.show(context);
    if (selectedRadius == null) return;
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
    } catch (_) {
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Impossible de te localiser. Réessaie.',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _userPosition = LatLng(position.latitude, position.longitude);
      _radiusKm = selectedRadius;
    });
    context.read<PackageRequestSearchBloc>().add(
      SearchFiltersChanged(
        userLat: position.latitude,
        userLng: position.longitude,
        radiusKm: selectedRadius,
        publicAccess: !getIt<FirebaseSessionProbe>().hasRealSession,
      ),
    );
  }

  void _deactivateNearMe() {
    setState(() {
      _userPosition = null;
      _radiusKm = null;
    });
    context.read<PackageRequestSearchBloc>().add(
      SearchFiltersChanged(
        publicAccess: !getIt<FirebaseSessionProbe>().hasRealSession,
      ),
    );
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
                  ? formatPriceIn(it.targetPriceEur!, it.currency)
                  : 'Libre',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _selectedRequestId == it.id
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueRed,
            ),
            onTap: () => setState(() => _selectedRequestId = it.id),
          );
        })
        .toSet();
  }

  void _openPreview(BuildContext context, PackageRequestSearchItem item) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : null;
    if (currentUserId != null && item.sender.id == currentUserId) return;
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
                onNearMeToggle: () =>
                    isNearMe ? _deactivateNearMe() : _activateNearMe(),
                fabBottomPadding:
                    MediaQuery.of(context).size.height * _sheetSize,
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      : (
                          lat: userPosition!.latitude,
                          lng: userPosition!.longitude,
                        ),
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
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.md,
                DonySpacing.lg,
                40,
              ),
              sliver: SliverList.separated(
                itemCount: state.results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final item = state.results[i];
                  final authState = context.read<AuthBloc>().state;
                  final uid = authState is AuthAuthenticated
                      ? authState.user.id
                      : null;
                  final isOwn = uid != null && item.sender.id == uid;
                  return PackageRequestListCard(
                    item: item,
                    isOwnRequest: isOwn,
                    showFavorite: !isOwn,
                    onTap: () => onTapItem(item),
                    onMakeOffer: isOwn ? null : () => onTapItem(item),
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
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            'Demandes',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 10),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
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
    return Padding(
      padding: const EdgeInsets.all(28),
      child: DonyEmptyState(
        title: isNearMe
            ? 'Aucune demande dans ce rayon'
            : 'Aucune demande pour le moment',
        description: isNearMe
            ? 'Élargis ta zone ou désactive “Près de moi”'
            : 'Reviens dans un instant, de nouvelles demandes sont publiées chaque jour',
        mascotte: DonyMascotteType.aucunResultat,
      ),
    );
  }
}
