import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/role_guidance_banner.dart';
import 'package:dony/core/widgets/role_mode_pill.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:dony/features/matching/presentation/widgets/search_form_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/profile/presentation/widgets/pro_stats_card.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

// ── Home-screen specific constants ────────────────────────────────────────────

enum _HomeTab { voyageurs, demandes }

enum _DatePreset { today, thisWeek, thisMonth, custom, none }

typedef _CorridorOpt = ({String label, String departure, String arrival});

// Fallback statique utilisé jusqu'à ce que l'API réponde
const _defaultCorridorOptions = <_CorridorOpt>[
  (label: 'Paris → Dakar',      departure: 'Paris',     arrival: 'Dakar'),
  (label: 'Paris → Abidjan',    departure: 'Paris',     arrival: 'Abidjan'),
  (label: 'Lyon → Abidjan',     departure: 'Lyon',      arrival: 'Abidjan'),
  (label: 'Paris → Bamako',     departure: 'Paris',     arrival: 'Bamako'),
  (label: 'Paris → Douala',     departure: 'Paris',     arrival: 'Douala'),
  (label: 'Marseille → Bamako', departure: 'Marseille', arrival: 'Bamako'),
];

// Accent clair sur fond ink pour le texte de mise en valeur (compatible design system)
const _kAccentOnDark = DonyColors.blue200;

// ── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveRoleCubit, ActiveRole>(
      builder: (context, activeRole) {
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final user = authState is AuthAuthenticated
                ? authState.user
                : authState is AuthProfileUpdated
                    ? authState.user
                    : null;

            if (activeRole == ActiveRole.traveler) {
              return _TravelerView(
                displayName: user?.displayName ?? 'Voyageur',
                isProAccount: user?.isProAccount ?? false,
              );
            }
            return const _MapSenderView();
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAP SENDER VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _MapSenderView extends StatefulWidget {
  const _MapSenderView();

  @override
  State<_MapSenderView> createState() => _MapSenderViewState();
}

class _MapSenderViewState extends State<_MapSenderView> {
  final _sheetController = DraggableScrollableController();
  double _sheetSize = 0.20;
  bool get _isMapHidden => _sheetSize > 0.92;

  _HomeTab _tab = _HomeTab.voyageurs;

  PendingSearchNotifier? _pendingSearchNotifier;

  // Liste mutable — initialisée avec le fallback statique, remplacée par l'API
  List<_CorridorOpt> _corridorOptions = List.of(_defaultCorridorOptions);
  _CorridorOpt _corridor = _defaultCorridorOptions.first;

  _DatePreset _datePreset = _DatePreset.thisWeek;
  DateTime? _customDate;
  bool _kiloProOnly = false;
  bool _allCorridors = true;

  bool _isNearMeActive = false;
  double? _nearMeRadiusKm;
  LatLng? _userPosition;

  String? _selectedAnnouncementId;

  double? _minRating;
  double? _weightMin;
  double? _weightMax;
  double? _maxPricePerKg;
  bool _weekendOnly = false;
  TransportMode? _transportMode;
  bool _kycVerifiedOnly = false;
  String? _contentType;
  UrgencyFilter? _urgencyFilter;

  int get _activeFilterCount {
    int n = 0;
    if (_kiloProOnly) n++;
    if (!_allCorridors) n++;
    if (_minRating != null) n++;
    if (_weightMin != null || _weightMax != null) n++;
    if (_maxPricePerKg != null) n++;
    if (_weekendOnly) n++;
    if (_transportMode != null) n++;
    if (_kycVerifiedOnly) n++;
    if (_contentType != null) n++;
    if (_isNearMeActive) n++;
    if (_datePreset != _DatePreset.thisWeek) n++;
    if (_urgencyFilter != null) n++;
    return n;
  }

  DateTime? get _dateFrom {
    final now = DateTime.now();
    switch (_datePreset) {
      case _DatePreset.today:
        return DateTime(now.year, now.month, now.day);
      case _DatePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case _DatePreset.thisMonth:
        return DateTime(now.year, now.month, 1);
      case _DatePreset.custom:
        return _customDate;
      case _DatePreset.none:
        return null;
    }
  }

  DateTime? get _dateTo {
    final now = DateTime.now();
    switch (_datePreset) {
      case _DatePreset.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case _DatePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final nextMonday = monday.add(const Duration(days: 7));
        return DateTime(nextMonday.year, nextMonday.month, nextMonday.day)
            .subtract(const Duration(seconds: 1));
      case _DatePreset.thisMonth:
        final m = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return m.subtract(const Duration(seconds: 1));
      case _DatePreset.custom:
        return null;
      case _DatePreset.none:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<PendingSearchNotifier>()) {
      _pendingSearchNotifier = getIt<PendingSearchNotifier>();
      _pendingSearchNotifier!.addListener(_consumePendingSearch);
    }
    _sheetController.addListener(_onSheetSizeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Si l'utilisateur arrive depuis Envoyer avec des params en attente,
      // les appliquer au lieu de la recherche par défaut.
      if (_pendingSearchNotifier?.params != null) {
        _consumePendingSearch();
      } else {
        _dispatchSearch();
      }
      _loadPopularCorridors();
      // Charger la liste des bids de l'expéditeur pour pouvoir indiquer sur
      // chaque carte de trajet s'il a déjà une demande active dessus.
      // Le BidBloc cache la liste, c'est silencieux si déjà chargée récemment.
      context.read<BidBloc>().add(BidMyListRequested());
    });
  }

  void _consumePendingSearch() {
    if (!mounted) return;
    final pending = _pendingSearchNotifier?.consume();
    if (pending == null) return;
    _applySearchParams(pending);
  }

  Future<void> _loadPopularCorridors() async {
    try {
      final corridors = await getIt<CityRepository>().getPopularCorridors();
      if (!mounted || corridors.isEmpty) return;
      setState(() {
        _corridorOptions = corridors
            .map((c) => (
                  label: '${c.departureCity} → ${c.arrivalCity}',
                  departure: c.departureCity,
                  arrival: c.arrivalCity,
                ))
            .toList();
        // Mettre à jour le corridor sélectionné si possible
        if (_corridorOptions.isNotEmpty) {
          _corridor = _corridorOptions.first;
        }
      });
    } catch (_) {
      // Échec silencieux — l'UI reste fonctionnelle avec le fallback statique
    }
  }

  void _onSheetSizeChanged() {
    if (!_sheetController.isAttached) return;
    final newSize = _sheetController.size;
    final wasHidden = _isMapHidden;
    _sheetSize = newSize;
    // Rebuild uniquement quand l'état caché/visible change, pas à chaque frame
    if (wasHidden != _isMapHidden) setState(() {});
  }

  @override
  void dispose() {
    _pendingSearchNotifier?.removeListener(_consumePendingSearch);
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    super.dispose();
  }

  void _dispatchSearch() {
    if (!mounted) return;
    // Near-me bypasses corridor: we want ALL travelers near the user
    final ignoreCorridor = _allCorridors || _isNearMeActive;
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
          departureCity:
              ignoreCorridor ? null : _corridor.departure.split(' ').first,
          arrivalCity:
              ignoreCorridor ? null : _corridor.arrival.split(' ').first,
          departureDateFrom: _dateFrom,
          departureDateTo: _dateTo,
          kiloProOnly: _kiloProOnly ? true : null,
          minRating: _minRating,
          weekendOnly: _weekendOnly ? true : null,
          minAvailableKg: _weightMin,
          maxAvailableKg: _weightMax,
          maxPricePerKg: _maxPricePerKg,
          transportMode: _transportMode,
          kycVerifiedOnly: _kycVerifiedOnly ? true : null,
          contentType: _contentType,
          userLat: _isNearMeActive ? _userPosition?.latitude : null,
          userLng: _isNearMeActive ? _userPosition?.longitude : null,
          radiusKm: _isNearMeActive ? _nearMeRadiusKm : null,
        ));
  }

  void _deactivateNearMe() {
    setState(() {
      _isNearMeActive = false;
      _nearMeRadiusKm = null;
      _userPosition = null;
      _selectedAnnouncementId = null;
    });
    _dispatchSearch();
  }

  Future<void> _activateNearMe() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) return;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    if (!mounted) return;

    final positionFuture = Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.low),
    );

    final radiusKm = await NearMeRadiusSheet.show(
      context,
      initialRadiusKm: _nearMeRadiusKm ?? 25,
    );

    if (radiusKm == null || !mounted) return;

    final pos = await positionFuture;
    if (!mounted) return;

    setState(() {
      _isNearMeActive = true;
      _nearMeRadiusKm = radiusKm;
      _userPosition = LatLng(pos.latitude, pos.longitude);
    });
    _dispatchSearch();
  }

  Future<void> _showDatePresetSheet() async {
    final result = await showModalBottomSheet<
        ({_DatePreset preset, DateTime? customDate})>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DatePresetSheet(
        currentPreset: _datePreset,
        customDate: _customDate,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _datePreset = result.preset;
        _customDate = result.customDate;
      });
      _dispatchSearch();
    }
  }

  Future<void> _showRatingSheet() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingFilterSheet(currentRating: _minRating),
    );
    if (result == null || !mounted) return;
    setState(() => _minRating = result < 0 ? null : result);
    _dispatchSearch();
  }

  Future<void> _showWeightSheet() async {
    final result = await showModalBottomSheet<({double min, double max})>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _WeightRangeSheet(currentMin: _weightMin, currentMax: _weightMax),
    );
    if (result == null || !mounted) return;
    setState(() {
      _weightMin = result.min <= 0 ? null : result.min;
      _weightMax = result.max <= 0 ? null : result.max;
    });
    _dispatchSearch();
  }

  Future<void> _showPriceSheet() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceFilterSheet(currentMaxPrice: _maxPricePerKg),
    );
    if (result == null || !mounted) return;
    setState(() => _maxPricePerKg = result < 0 ? null : result);
    _dispatchSearch();
  }

  void _exitNearMeAndShowList() {
    _deactivateNearMe();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onTravelerCardTap(BuildContext context, AnnouncementModel a) {
    final bidState = context.read<BidBloc>().state;
    final existingBid = bidState.activeBidsByAnnouncement()[a.id];
    if (existingBid != null) {
      context.push('/bids/${existingBid.id}', extra: existingBid);
    } else {
      showTravelerAnnouncementSheet(context, announcement: a);
    }
  }

  void _showMap() {
    _sheetController.animateTo(
      0.45,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showFilterSheet(BuildContext ctx) async {
    final initialParams = SearchParams(
      departureCity: _corridor.departure,
      arrivalCity: _corridor.arrival,
      date: _customDate,
      kiloProOnly: _kiloProOnly,
      ratingFilter: _minRating != null,
      priceFilter: _maxPricePerKg != null,
      maxPricePerKg: _maxPricePerKg ?? 25,
      transportMode: _transportMode,
      kycVerifiedOnly: _kycVerifiedOnly,
      contentType: _contentType,
      urgencyFilter: _urgencyFilter,
    );

    final result = await SearchFormBottomSheet.show(
      ctx,
      initialParams: initialParams,
      heightFraction: 0.80,
    );

    if (result == null || !mounted) return;
    _applySearchParams(result);
  }

  void _applySearchParams(SearchParams result) {
    if (!mounted) return;
    final dep = result.departureCity;
    final arr = result.arrivalCity;
    final matchedCorridor = _corridorOptions.firstWhere(
      (c) => c.departure == dep && c.arrival == arr,
      orElse: () => (
        label: '${dep.split(' ').first} → ${arr.split(' ').first}',
        departure: dep,
        arrival: arr,
      ),
    );

    setState(() {
      _corridor = matchedCorridor;
      _allCorridors = false;
      if (result.date != null) {
        _datePreset = _DatePreset.custom;
        _customDate = result.date;
      }
      _kiloProOnly = result.kiloProOnly;
      _minRating = result.ratingFilter ? 4.5 : null;
      _weekendOnly = result.weekendFilter;
      _maxPricePerKg = result.priceFilter ? result.maxPricePerKg : null;
      _transportMode = result.transportMode;
      _kycVerifiedOnly = result.kycVerifiedOnly;
      _contentType = result.contentType;
      _urgencyFilter = result.urgencyFilter;
      if (result.weightKg > 0) {
        _weightMin = result.weightKg;
        _weightMax = null;
      }
    });
    _dispatchSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          final raw = state is AnnouncementSearchLoaded
              ? state.results
              : <AnnouncementModel>[];
          final announcements = _urgencyFilter == null
              ? raw
              : raw.where((a) => _urgencyFilter!.matches(a.departureDate)).toList();

          return Stack(
            children: [
              Positioned.fill(
                child: AnnouncementMapView(
                  announcements:
                      _tab == _HomeTab.voyageurs ? announcements : const [],
                  isNearMeActive: _isNearMeActive,
                  activeRadiusKm: _nearMeRadiusKm,
                  userPosition: _userPosition,
                  onNearMeRequested: (lat, lng, radius) {
                    setState(() {
                      _isNearMeActive = true;
                      _nearMeRadiusKm = radius;
                      _userPosition = LatLng(lat, lng);
                    });
                    _dispatchSearch();
                  },
                  onNearMeDisabled: _deactivateNearMe,
                  fabBottomPadding: MediaQuery.of(context).size.height * 0.45,
                  selectedAnnouncementId: _selectedAnnouncementId,
                  onAnnouncementSelected: (id) =>
                      setState(() => _selectedAnnouncementId = id),
                ),
              ),

              // ── Top overlay (disparaît en plein écran ou mode Près de moi) ──
              Positioned(
                top: MediaQuery.of(context).padding.top + DonySpacing.sm,
                left: DonySpacing.md,
                right: DonySpacing.md,
                child: IgnorePointer(
                  ignoring: _isMapHidden || _isNearMeActive,
                  child: AnimatedOpacity(
                    opacity: (_isMapHidden || _isNearMeActive) ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const RoleModePill(),
                            const SizedBox(width: DonySpacing.sm),
                            Expanded(
                              child: _CorridorBar(
                                key: const Key('corridor-bar'),
                                label: _allCorridors
                                    ? 'Tous les corridors'
                                    : _corridor.label,
                                activeFilterCount: _activeFilterCount,
                                onTap: () => _showFilterSheet(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        Center(
                          child: _TabToggle(
                            tab: _tab,
                            voyageursCount: announcements.length,
                            onChanged: (t) => setState(() => _tab = t),
                          ),
                        ),
                        const SizedBox(height: DonySpacing.xs),
                        _HomeFilterChipsRow(
                          datePreset: _datePreset,
                          customDate: _customDate,
                          kiloProOnly: _kiloProOnly,
                          isNearMeActive: _isNearMeActive,
                          allCorridors: _allCorridors,
                          minRating: _minRating,
                          weightMin: _weightMin,
                          weightMax: _weightMax,
                          maxPricePerKg: _maxPricePerKg,
                          onDateTap: _showDatePresetSheet,
                          onRatingTap: _showRatingSheet,
                          onWeightTap: _showWeightSheet,
                          onNearMeTap: () {
                            if (_isNearMeActive) {
                              _deactivateNearMe();
                            } else {
                              _activateNearMe();
                            }
                          },
                          onPriceTap: _showPriceSheet,
                          onKiloProToggle: () {
                            setState(() => _kiloProOnly = !_kiloProOnly);
                            _dispatchSearch();
                          },
                          onAllCorridorsToggle: () {
                            setState(() => _allCorridors = !_allCorridors);
                            _dispatchSearch();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bouton retour mode Près de moi ────────────────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                top: _isNearMeActive
                    ? MediaQuery.of(context).padding.top + DonySpacing.sm
                    : MediaQuery.of(context).padding.top - 80,
                left: DonySpacing.md,
                child: AnimatedOpacity(
                  opacity: _isNearMeActive ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: IgnorePointer(
                    ignoring: !_isNearMeActive,
                    child: _NearMeBackButton(onTap: _deactivateNearMe),
                  ),
                ),
              ),

              // ── Liste ou Carousel selon le mode Près de moi ───────────────
              if (!_isNearMeActive)
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.20,
                  minChildSize: 0.15,
                  maxChildSize: 1.0,
                  snap: true,
                  snapSizes: const [0.20, 0.45, 1.0],
                  builder: (ctx, scrollCtrl) => _buildSheet(
                    ctx,
                    scrollCtrl,
                    announcements,
                    MediaQuery.of(context).padding.bottom,
                  ),
                )
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: SizedBox(
                      height: 280,
                      child: NearMeCarousel(
                        announcements: announcements,
                        userPosition: _userPosition != null
                            ? (
                                lat: _userPosition!.latitude,
                                lng: _userPosition!.longitude
                              )
                            : null,
                        selectedAnnouncementId: _selectedAnnouncementId,
                        onCardChanged: (id) =>
                            setState(() => _selectedAnnouncementId = id),
                        onSeeAll: _exitNearMeAndShowList,
                        onTapCard: (a) => _onTravelerCardTap(context, a),
                      )
                          .animate()
                          .fadeIn(duration: 250.ms)
                          .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                    ),
                  ),
                ),

              // ── FAB "Carte" (visible quand sheet plein écran) ─────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                bottom: _isMapHidden
                    ? MediaQuery.of(context).padding.bottom + DonySpacing.lg
                    : -80,
                left: 0,
                right: 0,
                child: Center(child: _HomeCarteFab(onTap: _showMap)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSheet(
    BuildContext ctx,
    ScrollController scrollCtrl,
    List<AnnouncementModel> announcements,
    double bottomPad,
  ) {
    final tt = Theme.of(ctx).textTheme;
    final cs = Theme.of(ctx).colorScheme;
    final count = announcements.length;

    final statusBarHeight = MediaQuery.of(ctx).padding.top;

    return Container(
      key: const Key('home-sheet'),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: _isMapHidden
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      child: Column(
        children: [
          // Padding status bar quand le sheet est en plein écran
          if (_isMapHidden) SizedBox(height: statusBarHeight),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xs,
              DonySpacing.lg,
              DonySpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tab == _HomeTab.voyageurs
                            ? 'VOYAGEURS DISPONIBLES'
                            : 'DEMANDES D\'ENVOI',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tab == _HomeTab.voyageurs
                            ? _isNearMeActive
                                ? '$count voyageur${count > 1 ? 's' : ''} à proximité'
                                : _allCorridors
                                    ? '$count résultat${count > 1 ? 's' : ''} · Tous les corridors'
                                    : '$count résultat${count > 1 ? 's' : ''} · ${_corridor.label}'
                            : _corridor.label,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (_tab == _HomeTab.voyageurs && count > 0)
                  GestureDetector(
                    onTap: () => _showFilterSheet(ctx),
                    child: Text(
                      'Trier',
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          Expanded(
            child: CustomScrollView(
              controller: scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: RoleGuidanceBanner(
                    role: ActiveRole.sender,
                    hiveService: getIt<HiveService>(),
                  ),
                ),
                if (_tab == _HomeTab.demandes)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DemandesPlaceholder(),
                  )
                else if (count == 0)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        _isNearMeActive
                            ? 'Aucun voyageur à proximité'
                            : 'Aucun voyageur sur ce corridor',
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      DonySpacing.base,
                      DonySpacing.sm,
                      DonySpacing.base,
                      bottomPad + DonySpacing.huge,
                    ),
                    sliver: BlocBuilder<BidBloc, BidState>(
                      buildWhen: (prev, curr) =>
                          curr is BidListLoaded || prev is BidListLoaded,
                      builder: (context, bidState) {
                        final myActiveBidsByAnnouncement =
                            bidState.activeBidsByAnnouncement();
                        return SliverList.separated(
                          itemCount: count,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: DonySpacing.md),
                          itemBuilder: (context, i) {
                            final a = announcements[i];
                            final authState = context.read<AuthBloc>().state;
                            final currentUserId = authState is AuthAuthenticated
                                ? authState.user.id
                                : null;
                            final isOwn = currentUserId != null &&
                                a.travelerId == currentUserId;
                            final badge = _isNearMeActive
                                ? buildDistanceBadge(
                                    a,
                                    _userPosition != null
                                        ? (
                                            lat: _userPosition!.latitude,
                                            lng: _userPosition!.longitude
                                          )
                                        : null,
                                  )
                                : null;
                            final existingBid =
                                myActiveBidsByAnnouncement[a.id];
                            return TravelerCard(
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
                                      : () => showTravelerAnnouncementSheet(
                                            context,
                                            announcement: a,
                                          ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
// TRAVELER VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _TravelerView extends StatefulWidget {
  const _TravelerView({required this.displayName, this.isProAccount = false});

  final String displayName;
  final bool isProAccount;

  @override
  State<_TravelerView> createState() => _TravelerViewState();
}

class _TravelerViewState extends State<_TravelerView> {
  final _scroll = ScrollController();

  static const double _kContentHeight = 76.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() => setState(() {});

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.of(context).padding.top;

    final expandedHeight = topPad + 56.0 + _kContentHeight;

    final offset = _scroll.hasClients
        ? _scroll.offset.clamp(0.0, double.infinity)
        : 0.0;
    final progress = (offset / _kContentHeight).clamp(0.0, 1.0);

    final headerBg = Color.lerp(DonyColors.ink800, cs.surface, progress)!;
    final iconColor = Color.lerp(DonyColors.white, cs.onSurface, progress)!;
    final titleColor = Color.lerp(
      DonyColors.white.withValues(alpha: 0.0),
      cs.onSurface,
      progress,
    )!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ── Collapsing header ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: expandedHeight,
            pinned: true,
            floating: false,
            backgroundColor: headerBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            automaticallyImplyLeading: false,
            leading: const Padding(
              padding: EdgeInsets.only(left: DonySpacing.sm),
              child: Center(child: RoleModePill()),
            ),
            leadingWidth: 96,
            // Titre (visible seulement quand collapsed)
            title: Text(
              widget.displayName,
              style: tt.titleMedium!.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, notifState) {
                  final unread = notifState is NotificationLoaded
                      ? notifState.unreadCount
                      : 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_outlined,
                            color: iconColor),
                        onPressed: () => showNotificationBottomSheet(context),
                        tooltip: 'Notifications',
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: _NotifBadge(count: unread),
                        ),
                    ],
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Opacity(
                opacity: progress,
                child: Divider(height: 1, color: cs.outline),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          DonyColors.ink800,
                          DonyColors.ink600,
                        ],
                      ),
                    ),
                  ),
                  // Cercle décoratif
                  Positioned(
                    right: -40,
                    top: topPad - 30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DonyColors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  // Profil : avatar + nom + rating
                  Positioned(
                    left: DonySpacing.lg,
                    right: DonySpacing.lg,
                    top: topPad + 56,
                    bottom: DonySpacing.md,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.displayName,
                                style: tt.headlineMedium!.copyWith(
                                  color: DonyColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ).animate().fadeIn(duration: 300.ms),
                              const SizedBox(height: DonySpacing.xxs),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: cs.warning, size: 14),
                                  const SizedBox(width: DonySpacing.xxs),
                                  Text(
                                    '4.9',
                                    style: tt.bodySmall!.copyWith(
                                      color: DonyColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: DonySpacing.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DonySpacing.sm,
                                      vertical: DonySpacing.xxs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DonyColors.white
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(DonyRadius.full),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 11,
                                          color: _kAccentOnDark,
                                        ),
                                        const SizedBox(width: DonySpacing.xxs),
                                        Text(
                                          'VTC vérifié',
                                          style: tt.labelSmall!.copyWith(
                                              color: DonyColors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn(delay: 60.ms, duration: 280.ms),
                            ],
                          ),
                        ),
                        DonyAvatar(
                          name: widget.displayName,
                          size: DonyAvatarSize.md,
                          verified: true,
                          pro: widget.isProAccount,
                        ).animate().fadeIn(delay: 80.ms, duration: 280.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenu scrollable ───────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                BlocBuilder<AnnouncementBloc, AnnouncementState>(
                  builder: (context, state) {
                    final hasItems = state is AnnouncementListLoaded &&
                        state.announcements.isNotEmpty;
                    return RoleGuidanceBanner(
                      role: ActiveRole.traveler,
                      hiveService: getIt<HiveService>(),
                      forceHide: hasItems,
                      onCtaTap: () =>
                          CreateAnnouncementBottomSheet.show(context),
                    );
                  },
                ),
                const SizedBox(height: DonySpacing.md),
                if (widget.isProAccount)
                  ProStatsCard.withBloc()
                      .animate()
                      .fadeIn(delay: 60.ms)
                      .slideY(begin: 0.03, curve: Curves.easeOutCubic),

                const SizedBox(height: DonySpacing.xxl),

                Text(
                  'MES TRAJETS ACTIFS',
                  style: tt.labelMedium!.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: DonySpacing.md),

                const _ActiveTripCard().animate().fadeIn(delay: 100.ms),

                const SizedBox(height: DonySpacing.xl),

                DonyButton(
                  label: 'Publier un trajet',
                  icon: Icons.send_rounded,
                  onPressed: () => CreateAnnouncementBottomSheet.show(context),
                ).animate().fadeIn(delay: 140.ms),

                const SizedBox(height: DonySpacing.xl),

                const _PayoutFooter().animate().fadeIn(delay: 180.ms),

                const SizedBox(height: DonySpacing.huge),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats card (dark greenDark background) ────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        color: DonyColors.ink800,  // intentional dark brand bg
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CE MOIS-CI',
            style: tt.labelSmall!.copyWith(
              color: DonyColors.white.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            '248,50 €',
            style: tt.displaySmall!.copyWith(color: DonyColors.white),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            '4 colis · paiement Wed',
            style: tt.bodySmall!.copyWith(
              color: DonyColors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: DonySpacing.base),
          const Row(
            children: [
              _StatPill(label: 'Trajets', value: '8'),
              SizedBox(width: DonySpacing.sm),
              _StatPill(label: 'Portés', value: '62kg'),
              SizedBox(width: DonySpacing.sm),
              _StatPill(label: 'Complétés', value: '100%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md, vertical: DonySpacing.sm),
      decoration: BoxDecoration(
        color: DonyColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: tt.titleSmall!
                .copyWith(color: DonyColors.white, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: tt.labelSmall!
                .copyWith(color: DonyColors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ── Active trip card ──────────────────────────────────────────────────────────

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const double reserved = 5;
    const double total = 15;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CDG → DSS',
                style: tt.titleLarge!.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
                decoration: BoxDecoration(
                  color: cs.successLight,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  'OUVERT',
                  style: tt.labelSmall!.copyWith(
                    color: cs.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Ven 18 · 14h05 · 5 kg réservés',
            style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.full),
            child: LinearProgressIndicator(
              value: reserved / total,
              minHeight: 6,
              color: cs.primary,
              backgroundColor: cs.outline,
            ),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${reserved.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} kg',
              style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification bell badge ────────────────────────────────────────────────────

class _NotifBadge extends StatelessWidget {
  final int count;
  const _NotifBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: const BorderRadius.all(Radius.circular(DonyRadius.sm)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: DonyColors.white,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Payout footer row ─────────────────────────────────────────────────────────

class _PayoutFooter extends StatelessWidget {
  const _PayoutFooter();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.access_time_rounded, color: cs.onSurfaceVariant, size: 16),
        const SizedBox(width: DonySpacing.xs),
        Text(
          'Prochain payout · mer. 23/04',
          style: tt.bodyMedium!.copyWith(color: cs.onSurface),
        ),
        const Spacer(),
        Text(
          '248,50 €',
          style: tt.titleMedium!.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
// ══════════════════════════════════════════════════════════════════════════════
// MAP SENDER — sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

// ── _CorridorBar ──────────────────────────────────────────────────────────────

class _CorridorBar extends StatelessWidget {
  const _CorridorBar({
    super.key,
    required this.label,
    required this.activeFilterCount,
    required this.onTap,
  });

  final String label;
  final int activeFilterCount;
  final VoidCallback onTap;

  bool get _hasActive => activeFilterCount > 0;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _hasActive ? cs.primary : Theme.of(context).scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: _hasActive ? cs.surface : cs.onSurface,
                  ),
                ),
                if (_hasActive)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: cs.error,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Text(
                        '$activeFilterCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: DonyColors.white,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── _TabToggle ────────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  const _TabToggle({
    required this.tab,
    required this.voyageursCount,
    required this.onChanged,
  });

  final _HomeTab tab;
  final int? voyageursCount;
  final void Function(_HomeTab) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabPill(
            label: voyageursCount != null
                ? 'Voyageurs · $voyageursCount'
                : 'Voyageurs',
            isActive: tab == _HomeTab.voyageurs,
            dotColor: cs.primary,
            onTap: () => onChanged(_HomeTab.voyageurs),
          ),
          const SizedBox(width: 2),
          _TabPill(
            label: 'Demandes',
            isActive: tab == _HomeTab.demandes,
            dotColor: cs.success,
            onTap: () => onChanged(_HomeTab.demandes),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.isActive,
    required this.dotColor,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isActive ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _DemandesPlaceholder ──────────────────────────────────────────────────────

class _DemandesPlaceholder extends StatelessWidget {
  const _DemandesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(DonySpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Icon(Icons.inbox_outlined, color: cs.primary, size: 28),
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Demandes bientôt disponibles',
            style: tt.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Tu pourras bientôt consulter les demandes d\'envoi postées par les expéditeurs.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── _HomeCarteFab ─────────────────────────────────────────────────────────────

class _HomeCarteFab extends StatelessWidget {
  const _HomeCarteFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: cs.onSurface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 16, color: cs.surface),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Carte',
              style: tt.labelMedium?.copyWith(
                color: cs.surface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _NearMeBackButton ─────────────────────────────────────────────────────────

class _NearMeBackButton extends StatelessWidget {
  const _NearMeBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
            decoration: BoxDecoration(
              color: isDark
                  ? cs.surface.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(DonyRadius.full),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 18, color: cs.onSurface),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  'Retour',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── _HomeFilterChipsRow ───────────────────────────────────────────────────────

class _HomeFilterChipsRow extends StatelessWidget {
  const _HomeFilterChipsRow({
    required this.datePreset,
    required this.customDate,
    required this.kiloProOnly,
    required this.isNearMeActive,
    required this.allCorridors,
    required this.onDateTap,
    required this.onRatingTap,
    required this.onWeightTap,
    required this.onNearMeTap,
    required this.onPriceTap,
    required this.onKiloProToggle,
    required this.onAllCorridorsToggle,
    this.minRating,
    this.weightMin,
    this.weightMax,
    this.maxPricePerKg,
  });

  final _DatePreset datePreset;
  final DateTime? customDate;
  final bool kiloProOnly;
  final bool isNearMeActive;
  final bool allCorridors;
  final double? minRating;
  final double? weightMin;
  final double? weightMax;
  final double? maxPricePerKg;
  final VoidCallback onDateTap;
  final VoidCallback onRatingTap;
  final VoidCallback onWeightTap;
  final VoidCallback onNearMeTap;
  final VoidCallback onPriceTap;
  final VoidCallback onKiloProToggle;
  final VoidCallback onAllCorridorsToggle;

  String get _dateLabel {
    switch (datePreset) {
      case _DatePreset.today:
        return 'Aujourd\'hui';
      case _DatePreset.thisWeek:
        return 'Cette semaine';
      case _DatePreset.thisMonth:
        return 'Ce mois-ci';
      case _DatePreset.custom:
        return customDate != null
            ? DateFormat('d MMM', 'fr').format(customDate!)
            : 'Date';
      case _DatePreset.none:
        return 'Toutes dates';
    }
  }

  String get _ratingLabel =>
      minRating != null ? '★ ${minRating!.toStringAsFixed(1)}+' : 'Note';

  String get _weightLabel {
    if (weightMin != null && weightMax != null) {
      return '${weightMin!.toInt()}–${weightMax!.toInt()} kg';
    }
    if (weightMin != null) return '≥ ${weightMin!.toInt()} kg';
    if (weightMax != null) return '≤ ${weightMax!.toInt()} kg';
    return 'Kilos';
  }

  String get _priceLabel => maxPricePerKg != null
      ? '≤ ${maxPricePerKg!.toStringAsFixed(0)} €/kg'
      : 'Prix';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SmallChip(
            label: _dateLabel,
            isActive: datePreset != _DatePreset.none,
            icon: Icons.calendar_today_rounded,
            onTap: onDateTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: _ratingLabel,
            isActive: minRating != null,
            icon: Icons.star_rounded,
            onTap: onRatingTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: _weightLabel,
            isActive: weightMin != null || weightMax != null,
            icon: Icons.fitness_center_rounded,
            onTap: onWeightTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: _priceLabel,
            isActive: maxPricePerKg != null,
            icon: Icons.euro_rounded,
            onTap: onPriceTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: 'Kilo Pro',
            isActive: kiloProOnly,
            onTap: onKiloProToggle,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: 'Tous corridors',
            isActive: allCorridors,
            onTap: onAllCorridorsToggle,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            key: const Key('chip-near-me'),
            label: 'Près de moi',
            isActive: isNearMeActive,
            icon: Icons.near_me_rounded,
            onTap: onNearMeTap,
          ),
        ],
      ),
    );
  }
}

// ── _SmallChip ────────────────────────────────────────────────────────────────

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isActive ? 0.20 : 0.08),
              blurRadius: isActive ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isActive ? Colors.white : cs.onSurfaceVariant,
              ),
              const SizedBox(width: DonySpacing.xxs),
            ],
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: isActive ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _UrgencyChip ──────────────────────────────────────────────────────────────

// ── _HomeCorridorSheet ────────────────────────────────────────────────────────

class _HomeCorridorSheet extends StatefulWidget {
  const _HomeCorridorSheet({
    required this.corridor,
    required this.onApply,
    required this.corridorOptions,
  });

  final _CorridorOpt corridor;
  final void Function(_CorridorOpt corridor) onApply;
  final List<_CorridorOpt> corridorOptions;

  @override
  State<_HomeCorridorSheet> createState() => _HomeCorridorSheetState();
}

class _HomeCorridorSheetState extends State<_HomeCorridorSheet> {
  late _CorridorOpt _corridor;

  @override
  void initState() {
    super.initState();
    _corridor = widget.corridor;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetCtx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                0,
                DonySpacing.lg,
                DonySpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Corridor',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Divider(height: 1, color: cs.outline),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(widget.corridorOptions.length, (i) {
                    final opt = widget.corridorOptions[i];
                    final isSelected = opt.label == _corridor.label;
                    return GestureDetector(
                      onTap: () => setState(() => _corridor = opt),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: DonySpacing.xs),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.base,
                          vertical: DonySpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer
                              : Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(DonyRadius.card),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : cs.outline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                opt.label,
                                style: tt.bodyMedium?.copyWith(
                                  color: isSelected
                                      ? cs.primary
                                      : cs.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: cs.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                MediaQuery.of(sheetCtx).padding.bottom + DonySpacing.base,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outline)),
              ),
              child: DonyButton(
                label: 'Appliquer',
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  widget.onApply(_corridor);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _DatePresetSheet ──────────────────────────────────────────────────────────

class _DatePresetSheet extends StatefulWidget {
  const _DatePresetSheet({
    required this.currentPreset,
    required this.customDate,
  });

  final _DatePreset currentPreset;
  final DateTime? customDate;

  @override
  State<_DatePresetSheet> createState() => _DatePresetSheetState();
}

class _DatePresetSheetState extends State<_DatePresetSheet> {
  late _DatePreset _selected;
  late DateTime? _customDate;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentPreset;
    _customDate = widget.customDate;
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr'),
    );
    if (picked != null && mounted) {
      setState(() {
        _selected = _DatePreset.custom;
        _customDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        bottomPad + DonySpacing.base,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Date de départ',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.md),
          _PresetOption(
            label: 'Aujourd\'hui',
            isSelected: _selected == _DatePreset.today,
            onTap: () => setState(() => _selected = _DatePreset.today),
          ),
          _PresetOption(
            label: 'Cette semaine',
            isSelected: _selected == _DatePreset.thisWeek,
            onTap: () => setState(() => _selected = _DatePreset.thisWeek),
          ),
          _PresetOption(
            label: 'Ce mois-ci',
            isSelected: _selected == _DatePreset.thisMonth,
            onTap: () => setState(() => _selected = _DatePreset.thisMonth),
          ),
          _PresetOption(
            label: _selected == _DatePreset.custom && _customDate != null
                ? DateFormat('EEE d MMM', 'fr').format(_customDate!)
                : 'Choisir une date',
            isSelected: _selected == _DatePreset.custom,
            onTap: _pickCustomDate,
          ),
          const SizedBox(height: DonySpacing.lg),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(
                    (preset: _DatePreset.none, customDate: null as DateTime?),
                  ),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DonyRadius.card),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Center(
                      child: Text(
                        'Effacer',
                        style: tt.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyButton(
                  label: 'Appliquer',
                  onPressed: () => Navigator.of(context).pop(
                    (preset: _selected, customDate: _customDate),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _PresetOption ─────────────────────────────────────────────────────────────

class _PresetOption extends StatelessWidget {
  const _PresetOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        margin: const EdgeInsets.only(bottom: DonySpacing.xs),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  color: isSelected ? cs.primary : cs.onSurface,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 18,
                color: cs.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ── _RatingFilterSheet ────────────────────────────────────────────────────────

class _RatingFilterSheet extends StatefulWidget {
  const _RatingFilterSheet({this.currentRating});
  final double? currentRating;

  @override
  State<_RatingFilterSheet> createState() => _RatingFilterSheetState();
}

class _RatingFilterSheetState extends State<_RatingFilterSheet> {
  double? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentRating;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    const ratings = [4.0, 4.5, 4.7, 5.0];
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(
          DonySpacing.lg, 0, DonySpacing.lg, bottomPad + DonySpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Note minimum',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: DonySpacing.md),
          for (final r in ratings)
            _PresetOption(
              label: r == 5.0
                  ? '★ 5.0 uniquement'
                  : '★ ${r.toStringAsFixed(1)} et plus',
              isSelected: _selected == r,
              onTap: () => setState(() => _selected = r),
            ),
          const SizedBox(height: DonySpacing.lg),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(-1.0),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DonyRadius.card),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Center(
                      child: Text('Effacer',
                          style: tt.labelLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyButton(
                  label: 'Appliquer',
                  onPressed: () =>
                      Navigator.of(context).pop(_selected ?? -1.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _WeightRangeSheet ─────────────────────────────────────────────────────────

class _WeightRangeSheet extends StatefulWidget {
  const _WeightRangeSheet({this.currentMin, this.currentMax});
  final double? currentMin;
  final double? currentMax;

  @override
  State<_WeightRangeSheet> createState() => _WeightRangeSheetState();
}

class _WeightRangeSheetState extends State<_WeightRangeSheet> {
  static const double _kMin = 1.0;
  static const double _kMax = 50.0;

  late double _min;
  late double _max;

  @override
  void initState() {
    super.initState();
    _min = widget.currentMin ?? _kMin;
    _max = widget.currentMax ?? _kMax;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(
          DonySpacing.lg, 0, DonySpacing.lg, bottomPad + DonySpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Capacité kilo',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: DonySpacing.xl),
          Center(
            child: Text(
              '${_min.toInt()} – ${_max.toInt()} kg',
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: cs.primary,
              thumbColor: cs.primary,
              overlayColor: cs.primaryContainer,
              inactiveTrackColor: cs.outline,
            ),
            child: RangeSlider(
              values: RangeValues(_min, _max),
              min: _kMin,
              max: _kMax,
              divisions: (_kMax - _kMin).toInt(),
              onChanged: (v) =>
                  setState(() {
                    _min = v.start;
                    _max = v.end;
                  }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 kg',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                Text('50 kg',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.lg),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context)
                      .pop((min: 0.0, max: 0.0)),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DonyRadius.card),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Center(
                      child: Text('Effacer',
                          style: tt.labelLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyButton(
                  label: 'Appliquer',
                  onPressed: () =>
                      Navigator.of(context).pop((min: _min, max: _max)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _PriceFilterSheet ─────────────────────────────────────────────────────────

class _PriceFilterSheet extends StatefulWidget {
  const _PriceFilterSheet({this.currentMaxPrice});
  final double? currentMaxPrice;

  @override
  State<_PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<_PriceFilterSheet> {
  static const double _kMin = 3.0;
  static const double _kMax = 25.0;

  late double _maxPrice;

  @override
  void initState() {
    super.initState();
    _maxPrice = widget.currentMaxPrice ?? _kMax;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isAtMax = _maxPrice >= _kMax;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(
          DonySpacing.lg, 0, DonySpacing.lg, bottomPad + DonySpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Prix maximum',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: DonySpacing.xl),
          Center(
            child: Text(
              isAtMax ? 'Tous les prix' : '≤ ${_maxPrice.toInt()} €/kg',
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isAtMax ? cs.onSurfaceVariant : cs.primary,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: cs.primary,
              thumbColor: cs.primary,
              overlayColor: cs.primaryContainer,
              inactiveTrackColor: cs.outline,
            ),
            child: Slider(
              value: _maxPrice,
              min: _kMin,
              max: _kMax,
              divisions: (_kMax - _kMin).toInt(),
              onChanged: (v) => setState(() => _maxPrice = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('3 €/kg',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                Text('25 €/kg',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.lg),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(-1.0),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DonyRadius.card),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Center(
                      child: Text('Effacer',
                          style: tt.labelLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyButton(
                  label: 'Appliquer',
                  onPressed: () =>
                      Navigator.of(context).pop(isAtMax ? -1.0 : _maxPrice),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
