import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/role_guidance_banner.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/home/presentation/home_map_focus.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/search_form_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/near_me_package_request_carousel.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

// ── Home-screen specific constants ────────────────────────────────────────────

enum _DatePreset { today, thisWeek, thisMonth, custom, none }

typedef _CorridorOpt = ({String label, String departure, String arrival});

// Fallback statique utilisé jusqu'à ce que l'API réponde
const _defaultCorridorOptions = <_CorridorOpt>[
  (label: 'Paris → Dakar', departure: 'Paris', arrival: 'Dakar'),
  (label: 'Paris → Abidjan', departure: 'Paris', arrival: 'Abidjan'),
  (label: 'Lyon → Abidjan', departure: 'Lyon', arrival: 'Abidjan'),
  (label: 'Paris → Bamako', departure: 'Paris', arrival: 'Bamako'),
  (label: 'Paris → Douala', departure: 'Paris', arrival: 'Douala'),
  (label: 'Marseille → Bamako', departure: 'Marseille', arrival: 'Bamako'),
];

// ── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PackageRequestSearchBloc>(
      create: (_) => getIt<PackageRequestSearchBloc>(),
      child: const _MapSenderView(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAP SENDER VIEW
// ══════════════════════════════════════════════════════════════════════════════

/// Marge basse réservée sous les listes pour que le dernier item dépasse la
/// bottom nav flottante (île ~62 + marge ~28) au lieu d'être caché dessous.
const double _kFloatingNavClearance = 96;

class _MapSenderView extends StatefulWidget {
  const _MapSenderView();

  @override
  State<_MapSenderView> createState() => _MapSenderViewState();
}

class _MapSenderViewState extends State<_MapSenderView> {
  final _sheetController = DraggableScrollableController();
  double _sheetSize = 0.20;
  bool get _isMapHidden => _sheetSize > 0.92;

  // Cached markers for package_requests (rebuilt when search results change).
  Set<Marker> _packageRequestMarkers = {};
  List<PackageRequestSearchItem> _lastBuiltRequests = const [];

  PendingSearchNotifier? _pendingSearchNotifier;

  // Liste mutable — initialisée avec le fallback statique, remplacée par l'API
  List<_CorridorOpt> _corridorOptions = List.of(_defaultCorridorOptions);
  _CorridorOpt _corridor = _defaultCorridorOptions.first;

  _DatePreset _datePreset = _DatePreset.none;
  DateTime? _customDate;
  bool _kiloProOnly = false;
  bool _allCorridors = true;

  bool _isNearMeActive = false;
  bool _nearMeShowList = false;
  double? _nearMeRadiusKm;
  LatLng? _userPosition;
  // True between the FAB tap and the position being acquired (FAB spinner).
  bool _isLocatingNearMe = false;

  String? _selectedAnnouncementId;

  // Focus de la carte additive — voyage uniquement (ignoré pour les expéditeurs purs)
  HomeMapFocus _mapFocus = HomeMapFocus.all;

  double? _minRating;
  double? _weightMin;
  double? _weightMax;
  double? _maxPricePerKg;
  bool _weekendOnly = false;
  TransportMode? _transportMode;
  bool _kycVerifiedOnly = false;
  String? _contentType;
  UrgencyFilter? _urgencyFilter;
  // Chip serveur « 🔥 Urgent » — combiné à l'onglet actif (Trajets/Colis/Tout),
  // s'applique aux deux recherches (announcements + package requests).
  bool _urgentOnly = false;

  // Package request filters (traveler role)
  String? _prDeparture;
  String? _prArrival;
  DateTime? _prDateFrom;
  DateTime? _prDateTo;
  double? _prMaxWeight;
  ParcelSize? _prParcelSize;

  int get _prActiveFilterCount {
    int n = 0;
    if (_prDeparture != null) n++;
    if (_prDateFrom != null) n++;
    if (_prMaxWeight != null) n++;
    if (_prParcelSize != null) n++;
    if (_isNearMeActive) n++;
    return n;
  }

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
    if (_datePreset != _DatePreset.none) n++;
    if (_urgencyFilter != null) n++;
    if (_urgentOnly) n++;
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
        return DateTime(
          nextMonday.year,
          nextMonday.month,
          nextMonday.day,
        ).subtract(const Duration(seconds: 1));
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
      // Charger aussi les demandes de colis si l'utilisateur est voyageur.
      if (_isTraveler) {
        _dispatchPackageRequestSearch();
      }
      _loadPopularCorridors();
      // Charger la liste des bids de l'expéditeur pour pouvoir indiquer sur
      // chaque carte de trajet s'il a déjà une demande active dessus.
      // AutoRefresh (non forcé) : silencieux si la liste est déjà en cache et
      // fraîche — BidMyListRequested émettrait BidLoading et écraserait l'état
      // partagé à chaque retour sur l'accueil.
      context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
      // Réaligne la carte d'onboarding « première publication » sur l'état réel
      // du serveur : si l'utilisateur a déjà un trajet ou une demande, la carte
      // ne doit plus s'afficher (le flag Hive local pouvait être absent —
      // trajet créé sur un autre appareil, avant ce mécanisme, ou après
      // réinstallation).
      unawaited(_syncGuidanceFlags());
    });
  }

  /// Synchronise les drapeaux d'onboarding avec l'état serveur. Non bloquant :
  /// en cas d'échec réseau la carte reste affichée (dégradation silencieuse).
  Future<void> _syncGuidanceFlags() async {
    final box = getIt<HiveService>().userPrefs;
    try {
      final trips = await getIt<AnnouncementRepository>().getMyAnnouncements();
      if (trips.totalElements > 0) {
        await box.put(HiveService.kHasPublishedAsTraveler, true);
      }
    } catch (_) {
      // silencieux
    }
    try {
      final requests = await getIt<PackageRequestRepository>().findMine();
      if (requests.totalElements > 0) {
        await box.put(HiveService.kHasPublishedAsSender, true);
      }
    } catch (_) {
      // silencieux
    }
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
            .map(
              (c) => (
                label: '${c.departureCity} → ${c.arrivalCity}',
                departure: c.departureCity,
                arrival: c.arrivalCity,
              ),
            )
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
    // Rebuild quand l'état plein écran change (swap indications / filtres).
    if (wasHidden != _isMapHidden) setState(() {});
  }

  /// Drag manuel de la poignée → pilote directement la taille du sheet (un
  /// DraggableScrollableSheet seul ne réagit qu'au scroll de sa liste interne,
  /// pas au drag sur le header).
  void _onHandleDrag(BuildContext context, DragUpdateDetails d) {
    if (!_sheetController.isAttached) return;
    final h = MediaQuery.of(context).size.height;
    final next = (_sheetController.size - d.primaryDelta! / h).clamp(0.30, 1.0);
    _sheetController.jumpTo(next);
  }

  /// Aimante le sheet au snap le plus proche au relâcher de la poignée.
  void _snapSheet() {
    if (!_sheetController.isAttached) return;
    const snaps = [0.30, 0.6, 1.0];
    final s = _sheetController.size;
    var best = snaps.first;
    for (final v in snaps) {
      if ((v - s).abs() < (best - s).abs()) best = v;
    }
    _sheetController.animateTo(
      best,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Indication de drag dans le header du sheet selon l'état : peek → « tirer
  /// pour voir les N résultats », plein écran → « tirer pour voir la carte ».
  Widget _pullHint(ColorScheme cs, {required bool down, required int count}) {
    final text = down
        ? 'Tirer vers le bas pour voir la carte'
        : 'Tirer pour voir les $count résultat${count > 1 ? 's' : ''}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_sheetController.isAttached) return;
        _sheetController.animateTo(
          down ? 0.30 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(
          left: DonySpacing.lg,
          right: DonySpacing.lg,
          bottom: DonySpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              down
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: cs.primary,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
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
    context.read<AnnouncementBloc>().add(
      AnnouncementSearchRequested(
        departureCity: ignoreCorridor
            ? null
            : _corridor.departure.split(' ').first,
        arrivalCity: ignoreCorridor ? null : _corridor.arrival.split(' ').first,
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
        urgent: _urgentOnly ? true : null,
      ),
    );
  }

  void _dispatchPackageRequestSearch() {
    context.read<PackageRequestSearchBloc>().add(
      SearchFiltersChanged(
        departure: _prDeparture,
        arrival: _prArrival,
        dateFrom: _prDateFrom,
        dateTo: _prDateTo,
        maxWeight: _prMaxWeight,
        parcelSize: _prParcelSize,
        userLat: _isNearMeActive ? _userPosition?.latitude : null,
        userLng: _isNearMeActive ? _userPosition?.longitude : null,
        radiusKm: _isNearMeActive ? _nearMeRadiusKm : null,
        urgent: _urgentOnly ? true : null,
      ),
    );
  }

  /// Capacité réelle de l'utilisateur (pas le rôle actif sélectionné).
  bool get _isTraveler {
    final s = context.read<AuthBloc>().state;
    return switch (s) {
      AuthAuthenticated a => a.user.isTraveler,
      AuthProfileUpdated a => a.user.isTraveler,
      _ => false,
    };
  }

  // Near-me touche les deux jeux de résultats si l'utilisateur est voyageur,
  // ou seulement les annonces s'il est expéditeur pur.
  void _dispatchForCapability() {
    _dispatchSearch();
    if (_isTraveler) {
      _dispatchPackageRequestSearch();
    }
  }

  // Conservé pour la rétrocompatibilité avec l'appel depuis `_changeNearMeRadius`.
  void _dispatchForActiveRole() => _dispatchForCapability();

  // Chip « 🔥 Urgent » : filtre serveur combiné à l'onglet actif — s'applique
  // aux deux recherches (announcements + package requests), comme near-me.
  void _onUrgentToggle() {
    setState(() => _urgentOnly = !_urgentOnly);
    _dispatchForCapability();
  }

  void _deactivateNearMe() {
    setState(() {
      _isNearMeActive = false;
      _nearMeShowList = false;
      _nearMeRadiusKm = null;
      _userPosition = null;
      _selectedAnnouncementId = null;
    });
    _dispatchForActiveRole();
  }

  void _openNearMeList() {
    setState(() => _nearMeShowList = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // Ajuste le rayon SANS couper le filtre : rouvre le slider pré-rempli au rayon
  // courant, puis met à jour et relance la recherche. `_isNearMeActive` et
  // `_userPosition` restent intacts ; la carte se recadre via didUpdateWidget.
  Future<void> _changeNearMeRadius() async {
    final radiusKm = await NearMeRadiusSheet.show(
      context,
      initialRadiusKm: _nearMeRadiusKm ?? 25,
      confirmLabel: 'Appliquer',
    );
    if (radiusKm == null || !mounted) return;
    setState(() => _nearMeRadiusKm = radiusKm);
    _dispatchForActiveRole();
  }

  Future<void> _activateNearMe() async {
    const locationService = GeolocatorLocationService();
    final access = await requestLocationAccess(locationService);
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      await LocationDeniedSheet.show(
        context,
        access: access,
        service: locationService,
      );
      return;
    }

    // Toggle simple : on active directement avec le rayon par défaut (ou le
    // dernier utilisé) sans ré-ouvrir le sélecteur. Le rayon se change ensuite
    // via la pastille _NearMeRadiusPill ; un 2e tap sur le FAB désactive.
    setState(() => _isLocatingNearMe = true);
    final Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isLocatingNearMe = false);
        DonySnackbar.show(
          context,
          message: 'Impossible de te localiser. Réessaie.',
        );
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      _isLocatingNearMe = false;
      _isNearMeActive = true;
      _nearMeRadiusKm = _nearMeRadiusKm ?? 25;
      _userPosition = LatLng(pos.latitude, pos.longitude);
    });
    _dispatchForActiveRole();
  }

  Future<void> _showDatePresetSheet() async {
    final result =
        await showModalBottomSheet<
          ({_DatePreset preset, DateTime? customDate})
        >(
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
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState.currentUserId;
    final isOwn = currentUserId != null && a.travelerId == currentUserId;
    if (isOwn) {
      unawaited(() async {
        final changed = await context.push<bool>(
          '/announcements/${a.id}/trip',
          extra: a,
        );
        if ((changed ?? false) && mounted) {
          _dispatchSearch();
        }
      }());
      return;
    }
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

  Future<void> _showPrFilterSheet(BuildContext ctx) async {
    final depCtrl = TextEditingController(text: _prDeparture ?? '');
    final arrCtrl = TextEditingController(text: _prArrival ?? '');
    await DonyBottomSheet.show(
      ctx,
      title: 'Filtrer les demandes',
      stickyBottom: DonyButton(
        label: 'Appliquer',
        onPressed: () {
          final dep = depCtrl.text.trim().isEmpty ? null : depCtrl.text.trim();
          final arr = arrCtrl.text.trim().isEmpty ? null : arrCtrl.text.trim();
          setState(() {
            _prDeparture = dep;
            _prArrival = arr;
          });
          _dispatchPackageRequestSearch();
          Navigator.of(ctx, rootNavigator: true).pop();
        },
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: depCtrl,
              decoration: const InputDecoration(
                labelText: 'Ville de départ',
                prefixIcon: DonyEmoji.planeTakeoff(size: 18),
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            TextField(
              controller: arrCtrl,
              decoration: const InputDecoration(
                labelText: "Ville d'arrivée",
                prefixIcon: DonyEmoji.planeLanding(size: 18),
              ),
            ),
            const SizedBox(height: DonySpacing.lg),
            if (_prDeparture != null ||
                _prDateFrom != null ||
                _prMaxWeight != null ||
                _prParcelSize != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _prDeparture = null;
                    _prArrival = null;
                    _prDateFrom = null;
                    _prDateTo = null;
                    _prMaxWeight = null;
                    _prParcelSize = null;
                  });
                  _dispatchPackageRequestSearch();
                  Navigator.of(ctx, rootNavigator: true).pop();
                },
                icon: DonyIcon(
                  'x',
                  size: 16,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                label: const Text('Effacer tous les filtres'),
              ),
          ],
        ),
      ),
    );
  }

  void _applySearchParams(SearchParams result) {
    if (!mounted) return;
    final dep = result.departureCity;
    final arr = result.arrivalCity;

    setState(() {
      if (dep != null && arr != null) {
        final matchedCorridor = _corridorOptions.firstWhere(
          (c) => c.departure == dep && c.arrival == arr,
          orElse: () => (
            label: '${dep.split(' ').first} → ${arr.split(' ').first}',
            departure: dep,
            arrival: arr,
          ),
        );
        _corridor = matchedCorridor;
        _allCorridors = false;
      }
      // If both cities are null (user cleared them), keep the current corridor.
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

  Future<void> _rebuildPackageRequestMarkers(
    List<PackageRequestSearchItem> items,
  ) async {
    if (identical(items, _lastBuiltRequests)) return;
    _lastBuiltRequests = items;

    final markers = <Marker>{};
    // On ne se voit jamais soi-même dans la recherche : les demandes dont
    // l'utilisateur est l'expéditeur sont exclues de la carte.
    final uid = context.read<AuthBloc>().state.currentUserId;
    for (final item in items) {
      if (uid != null && item.sender.id == uid) continue;
      if (item.departureLat == null || item.departureLng == null) continue;
      final price = item.targetPriceEur ?? 0;
      final icon = await MarkerBitmapFactory.pricePill(
        pricePerKg: price,
        dotColor: DonyColors.terra500,
        brightness: Theme.of(context).brightness,
        prefix: '📦',
      );
      markers.add(
        Marker(
          markerId: MarkerId('pkg-${item.id}'),
          position: LatLng(item.departureLat!, item.departureLng!),
          icon: icon,
          onTap: () {
            final authState = context.read<AuthBloc>().state;
            final uid = authState.currentUserId;
            if (uid != null && item.sender.id == uid) return;
            PackageRequestPreviewBottomSheet.show(context, item: item);
          },
        ),
      );
    }
    if (mounted) {
      setState(() => _packageRequestMarkers = markers);
    }
  }

  /// Exclut les demandes de l'utilisateur courant : on ne se voit jamais
  /// soi-même dans la recherche (les demandes restent accessibles via
  /// « Mes colis »).
  List<PackageRequestSearchItem> _visibleRequests(
    List<PackageRequestSearchItem> items,
  ) {
    final uid = context.read<AuthBloc>().state.currentUserId;
    if (uid == null) return items;
    return items.where((it) => it.sender.id != uid).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTraveler = _isTraveler;
    final vis = homeMapVisibility(isTraveler: isTraveler, focus: _mapFocus);
    final showParcelControls = isTraveler && _mapFocus == HomeMapFocus.parcels;
    final showBothTypes =
        !showParcelControls && isTraveler && _mapFocus == HomeMapFocus.all;
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState.currentUserId;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          final raw = state is AnnouncementSearchLoaded
              ? state.results
              : <AnnouncementModel>[];
          // On ne se voit jamais soi-même dans la recherche : les trajets dont
          // l'utilisateur est le voyageur sont exclus du feed ET de la carte
          // (ils restent accessibles via « Mes trajets » / Activités).
          final ownFiltered = currentUserId == null
              ? raw
              : raw.where((a) => a.travelerId != currentUserId).toList();
          final announcements = _urgencyFilter == null
              ? ownFiltered
              : ownFiltered
                    .where((a) => _urgencyFilter!.matches(a.departureDate))
                    .toList();

          return BlocConsumer<
            PackageRequestSearchBloc,
            PackageRequestSearchState
          >(
            listener: (ctx, prState) {
              if (prState.status == SearchStatus.loaded) {
                _rebuildPackageRequestMarkers(prState.results);
              }
            },
            builder: (ctx, prState) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: AnnouncementMapView(
                      announcements: vis.showTrips ? announcements : const [],
                      extraMarkers: vis.showParcels
                          ? _packageRequestMarkers
                          : const {},
                      isNearMeActive: _isNearMeActive,
                      activeRadiusKm: _nearMeRadiusKm,
                      userPosition: _userPosition,
                      isLocating: _isLocatingNearMe,
                      onNearMeToggle: () => _isNearMeActive
                          ? _deactivateNearMe()
                          : _activateNearMe(),
                      // Quand « Près de moi » est actif, le carousel (min 384px)
                      // recouvre le bas : on remonte le FAB juste au-dessus pour
                      // qu'il reste tappable (2e tap = désactiver le filtre).
                      fabBottomPadding: _isNearMeActive
                          ? (MediaQuery.of(context).size.height * 0.40).clamp(
                                  384.0,
                                  470.0,
                                ) +
                                MediaQuery.of(context).padding.bottom +
                                DonySpacing.base
                          : MediaQuery.of(context).size.height * 0.45,
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
                                const _FavoritesButton(),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: _CorridorBar(
                                    key: const Key('corridor-bar'),
                                    label: showParcelControls
                                        ? (_prDeparture != null
                                              ? '$_prDeparture → $_prArrival'
                                              : 'Tous les corridors')
                                        : (_allCorridors
                                              ? 'Tous les corridors'
                                              : _corridor.label),
                                    activeFilterCount: showParcelControls
                                        ? _prActiveFilterCount
                                        : _activeFilterCount,
                                    onTap: () => showParcelControls
                                        ? _showPrFilterSheet(context)
                                        : _showFilterSheet(context),
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                const _NotificationBell(),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.xs),
                            _filterChipsRow(
                              isTraveler: isTraveler,
                              showParcelControls: showParcelControls,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Pastille rayon (mode Près de moi actif) : change le rayon ──
                  //    sans couper le filtre.
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
                        child: _NearMeRadiusPill(
                          key: const Key('near-me-radius-pill'),
                          radiusKm: _nearMeRadiusKm ?? 25,
                          onTap: _changeNearMeRadius,
                        ),
                      ),
                    ),
                  ),

                  // ── Liste ou Carousel selon le mode Près de moi ───────────────
                  if (!_isNearMeActive || _nearMeShowList)
                    DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: 0.30,
                      minChildSize: 0.30,
                      snap: true,
                      snapSizes: const [0.30, 0.6, 1.0],
                      builder: (ctx, scrollCtrl) => _buildSheet(
                        ctx,
                        scrollCtrl,
                        announcements,
                        MediaQuery.of(context).padding.bottom,
                        showParcelControls,
                        currentUserId: currentUserId,
                      ),
                    )
                  else
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        child: SizedBox(
                          height: (MediaQuery.of(context).size.height * 0.40)
                              .clamp(384.0, 470.0),
                          child: showBothTypes
                              ? DefaultTabController(
                                      length: 2,
                                      child: Column(
                                        children: [
                                          TabBar(
                                            tabs: [
                                              Tab(
                                                text:
                                                    '📦 ${_visibleRequests(prState.results).length} colis',
                                              ),
                                              Tab(
                                                text:
                                                    '✈️ ${announcements.length} trajets',
                                              ),
                                            ],
                                          ),
                                          Expanded(
                                            child: TabBarView(
                                              children: [
                                                NearMePackageRequestCarousel(
                                                  items: _visibleRequests(prState.results),
                                                  userPosition:
                                                      _userPosition != null
                                                      ? (
                                                          lat: _userPosition!
                                                              .latitude,
                                                          lng: _userPosition!
                                                              .longitude,
                                                        )
                                                      : null,
                                                  currentUserId: currentUserId,
                                                  selectedRequestId:
                                                      _selectedAnnouncementId,
                                                  onCardChanged: (id) => setState(
                                                    () =>
                                                        _selectedAnnouncementId =
                                                            id,
                                                  ),
                                                  onSeeAll: _openNearMeList,
                                                  onTapCard: (it) =>
                                                      PackageRequestPreviewBottomSheet.show(
                                                        context,
                                                        item: it,
                                                        isOwnRequest:
                                                            currentUserId !=
                                                                null &&
                                                            it.sender.id ==
                                                                currentUserId,
                                                      ),
                                                  onMakeOffer: (it) =>
                                                      currentUserId == null ||
                                                          it.sender.id !=
                                                              currentUserId
                                                      ? PackageRequestPreviewBottomSheet.show(
                                                          context,
                                                          item: it,
                                                        )
                                                      : null,
                                                ),
                                                NearMeCarousel(
                                                  announcements: announcements,
                                                  userPosition:
                                                      _userPosition != null
                                                      ? (
                                                          lat: _userPosition!
                                                              .latitude,
                                                          lng: _userPosition!
                                                              .longitude,
                                                        )
                                                      : null,
                                                  selectedAnnouncementId:
                                                      _selectedAnnouncementId,
                                                  onCardChanged: (id) => setState(
                                                    () =>
                                                        _selectedAnnouncementId =
                                                            id,
                                                  ),
                                                  onSeeAll: _openNearMeList,
                                                  onTapCard: (a) =>
                                                      _onTravelerCardTap(
                                                        context,
                                                        a,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 250.ms)
                                    .slideY(
                                      begin: 0.1,
                                      curve: Curves.easeOutCubic,
                                    )
                              : showParcelControls
                              ? NearMePackageRequestCarousel(
                                      items: _visibleRequests(prState.results),
                                      userPosition: _userPosition != null
                                          ? (
                                              lat: _userPosition!.latitude,
                                              lng: _userPosition!.longitude,
                                            )
                                          : null,
                                      currentUserId: currentUserId,
                                      selectedRequestId:
                                          _selectedAnnouncementId,
                                      onCardChanged: (id) => setState(
                                        () => _selectedAnnouncementId = id,
                                      ),
                                      onSeeAll: _exitNearMeAndShowList,
                                      onTapCard: (it) =>
                                          PackageRequestPreviewBottomSheet.show(
                                            context,
                                            item: it,
                                            isOwnRequest:
                                                currentUserId != null &&
                                                it.sender.id == currentUserId,
                                          ),
                                      onMakeOffer: (it) =>
                                          currentUserId == null ||
                                              it.sender.id != currentUserId
                                          ? PackageRequestPreviewBottomSheet.show(
                                              context,
                                              item: it,
                                            )
                                          : null,
                                    )
                                    .animate()
                                    .fadeIn(duration: 250.ms)
                                    .slideY(
                                      begin: 0.1,
                                      curve: Curves.easeOutCubic,
                                    )
                              : NearMeCarousel(
                                      announcements: announcements,
                                      userPosition: _userPosition != null
                                          ? (
                                              lat: _userPosition!.latitude,
                                              lng: _userPosition!.longitude,
                                            )
                                          : null,
                                      selectedAnnouncementId:
                                          _selectedAnnouncementId,
                                      onCardChanged: (id) => setState(
                                        () => _selectedAnnouncementId = id,
                                      ),
                                      onSeeAll: _exitNearMeAndShowList,
                                      onTapCard: (a) =>
                                          _onTravelerCardTap(context, a),
                                    )
                                    .animate()
                                    .fadeIn(duration: 250.ms)
                                    .slideY(
                                      begin: 0.1,
                                      curve: Curves.easeOutCubic,
                                    ),
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
          );
        },
      ),
    );
  }

  Future<double?> _showMaxWeightSheet(BuildContext ctx) async {
    double? selected = _prMaxWeight;
    return await showModalBottomSheet<double>(
      context: ctx,
      useRootNavigator: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setSt) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DonySpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Poids max du colis',
                  style: Theme.of(ctx2).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DonySpacing.md),
                Wrap(
                  spacing: DonySpacing.sm,
                  runSpacing: DonySpacing.sm,
                  children: [5.0, 10.0, 15.0, 20.0, 30.0].map((v) {
                    final active = selected == v;
                    return ChoiceChip(
                      label: Text('≤ ${v.toInt()} kg'),
                      selected: active,
                      onSelected: (_) =>
                          setSt(() => selected = active ? null : v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: DonySpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx2, selected),
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<ParcelSize?> _showParcelSizeSheet(BuildContext ctx) async {
    return await showModalBottomSheet<ParcelSize>(
      context: ctx,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Taille du colis',
                style: Theme.of(
                  sheetCtx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: DonySpacing.md),
              ...ParcelSize.values.map(
                (s) => ListTile(
                  title: Text(s.wireName),
                  onTap: () => Navigator.pop(sheetCtx, s),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  void _onFocusChanged(HomeMapFocus focus) {
    if (focus == _mapFocus) return;
    setState(() => _mapFocus = focus);
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeMapFocusChanged,
        properties: {'focus': focus.name},
      ),
    );
    // Redéclencher la recherche de colis si on bascule en mode colis ou tout.
    if (focus == HomeMapFocus.parcels || focus == HomeMapFocus.all) {
      _dispatchPackageRequestSearch();
    }
  }

  void _resetPrFilters() {
    setState(() {
      _prDeparture = null;
      _prArrival = null;
      _prDateFrom = null;
      _prDateTo = null;
      _prMaxWeight = null;
      _prParcelSize = null;
    });
    _dispatchPackageRequestSearch();
  }

  void _resetSenderFilters() {
    setState(() {
      _kiloProOnly = false;
      _allCorridors = true;
      _minRating = null;
      _weightMin = null;
      _weightMax = null;
      _maxPricePerKg = null;
      _weekendOnly = false;
      _transportMode = null;
      _kycVerifiedOnly = false;
      _contentType = null;
      _urgencyFilter = null;
      _datePreset = _DatePreset.none;
    });
    _dispatchSearch();
  }

  Widget _filterChipsRow({
    required bool isTraveler,
    required bool showParcelControls,
  }) {
    return !showParcelControls
        ? _HomeFilterChipsRow(
            leadingChildren: [
              _SmallChip(
                label: '🔥 Urgent',
                isActive: _urgentOnly,
                onTap: _onUrgentToggle,
              ),
              const SizedBox(width: DonySpacing.xs),
              if (isTraveler) ...[
                _SmallChip(
                  label: '📦 Colis',
                  isActive: _mapFocus == HomeMapFocus.parcels,
                  onTap: () => _onFocusChanged(
                    _mapFocus == HomeMapFocus.parcels
                        ? HomeMapFocus.all
                        : HomeMapFocus.parcels,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                _SmallChip(
                  label: '✈️ Trajets',
                  isActive: _mapFocus == HomeMapFocus.trips,
                  onTap: () => _onFocusChanged(
                    _mapFocus == HomeMapFocus.trips
                        ? HomeMapFocus.all
                        : HomeMapFocus.trips,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
              ],
            ],
            datePreset: _datePreset,
            customDate: _customDate,
            kiloProOnly: _kiloProOnly,
            allCorridors: _allCorridors,
            minRating: _minRating,
            weightMin: _weightMin,
            weightMax: _weightMax,
            maxPricePerKg: _maxPricePerKg,
            onDateTap: _showDatePresetSheet,
            onRatingTap: _showRatingSheet,
            onWeightTap: _showWeightSheet,
            onPriceTap: _showPriceSheet,
            onDateClear: () {
              setState(() {
                _datePreset = _DatePreset.none;
                _customDate = null;
              });
              _dispatchSearch();
            },
            onRatingClear: () {
              setState(() => _minRating = null);
              _dispatchSearch();
            },
            onWeightClear: () {
              setState(() {
                _weightMin = null;
                _weightMax = null;
              });
              _dispatchSearch();
            },
            onPriceClear: () {
              setState(() => _maxPricePerKg = null);
              _dispatchSearch();
            },
            onKiloProToggle: () {
              setState(() => _kiloProOnly = !_kiloProOnly);
              _dispatchSearch();
            },
            onAllCorridorsToggle: () {
              setState(() => _allCorridors = !_allCorridors);
              _dispatchSearch();
            },
          )
        : _PackageRequestFilterChipsRow(
            leadingChildren: [
              _SmallChip(
                label: '🔥 Urgent',
                isActive: _urgentOnly,
                onTap: _onUrgentToggle,
              ),
              const SizedBox(width: DonySpacing.xs),
              if (isTraveler) ...[
                _SmallChip(
                  label: '📦 Colis',
                  isActive: _mapFocus == HomeMapFocus.parcels,
                  onTap: () => _onFocusChanged(
                    _mapFocus == HomeMapFocus.parcels
                        ? HomeMapFocus.all
                        : HomeMapFocus.parcels,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                _SmallChip(
                  label: '✈️ Trajets',
                  isActive: _mapFocus == HomeMapFocus.trips,
                  onTap: () => _onFocusChanged(
                    _mapFocus == HomeMapFocus.trips
                        ? HomeMapFocus.all
                        : HomeMapFocus.trips,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
              ],
            ],
            dateFrom: _prDateFrom,
            dateTo: _prDateTo,
            maxWeight: _prMaxWeight,
            parcelSize: _prParcelSize,
            onDateTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _prDateFrom != null && _prDateTo != null
                    ? DateTimeRange(start: _prDateFrom!, end: _prDateTo!)
                    : null,
                locale: const Locale('fr'),
                builder: (ctx, child) =>
                    Theme(data: Theme.of(ctx), child: child!),
              );
              if (picked != null) {
                setState(() {
                  _prDateFrom = picked.start;
                  _prDateTo = picked.end;
                });
                _dispatchPackageRequestSearch();
              }
            },
            onWeightTap: () async {
              final result = await _showMaxWeightSheet(context);
              if (result != null) {
                setState(() => _prMaxWeight = result);
                _dispatchPackageRequestSearch();
              }
            },
            onSizeTap: () async {
              final result = await _showParcelSizeSheet(context);
              if (result != null) {
                setState(
                  () => _prParcelSize = result == _prParcelSize ? null : result,
                );
                _dispatchPackageRequestSearch();
              }
            },
            onDateClear: () {
              setState(() {
                _prDateFrom = null;
                _prDateTo = null;
              });
              _dispatchPackageRequestSearch();
            },
            onWeightClear: () {
              setState(() => _prMaxWeight = null);
              _dispatchPackageRequestSearch();
            },
            onSizeClear: () {
              setState(() => _prParcelSize = null);
              _dispatchPackageRequestSearch();
            },
          );
  }

  Widget _buildSheet(
    BuildContext ctx,
    ScrollController scrollCtrl,
    List<AnnouncementModel> announcements,
    double bottomPad,
    bool showParcelControls, {
    String? currentUserId,
  }) {
    final tt = Theme.of(ctx).textTheme;
    final cs = Theme.of(ctx).colorScheme;
    final count = announcements.length;
    final showBothTypes =
        !showParcelControls && _isTraveler && _mapFocus == HomeMapFocus.all;

    final statusBarHeight = MediaQuery.of(ctx).padding.top;

    return Container(
      key: const Key('home-sheet'),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: _isMapHidden
            ? BorderRadius.zero
            : const BorderRadius.vertical(
                top: Radius.circular(DonyRadius.sheet),
              ),
      ),
      child: Column(
        children: [
          // Padding status bar quand le sheet est en plein écran
          if (_isMapHidden) SizedBox(height: statusBarHeight),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => _onHandleDrag(ctx, d),
            onVerticalDragEnd: (_) => _snapSheet(),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          if (_isMapHidden) ...[
            _pullHint(cs, down: true, count: count),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                0,
                DonySpacing.lg,
                DonySpacing.sm,
              ),
              child: _CorridorBar(
                key: const Key('corridor-bar-sheet'),
                label: showParcelControls
                    ? (_prDeparture != null
                          ? '$_prDeparture → $_prArrival'
                          : 'Tous les corridors')
                    : (_allCorridors ? 'Tous les corridors' : _corridor.label),
                activeFilterCount: showParcelControls
                    ? _prActiveFilterCount
                    : _activeFilterCount,
                onTap: () => showParcelControls
                    ? _showPrFilterSheet(ctx)
                    : _showFilterSheet(ctx),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: DonySpacing.lg,
                right: DonySpacing.lg,
                bottom: DonySpacing.sm,
              ),
              child: _filterChipsRow(
                isTraveler: _isTraveler,
                showParcelControls: showParcelControls,
              ),
            ),
          ],
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
                        showBothTypes
                            ? 'TRAJETS & COLIS'
                            : showParcelControls
                            ? 'DEMANDES D\'ENVOI'
                            : 'VOYAGEURS DISPONIBLES',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        showBothTypes
                            ? 'Voyageurs & demandes d\'envoi'
                            : showParcelControls
                            ? (_prDeparture != null
                                  ? '$_prDeparture → $_prArrival'
                                  : 'Toutes les demandes')
                            : _isNearMeActive
                            ? '$count voyageur${count > 1 ? 's' : ''} à proximité'
                            : _allCorridors
                            ? '$count résultat${count > 1 ? 's' : ''} · Tous les corridors'
                            : '$count résultat${count > 1 ? 's' : ''} · ${_corridor.label}',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!showParcelControls && !showBothTypes && count > 0)
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
          if (!_isMapHidden) _pullHint(cs, down: false, count: count),
          Divider(height: 1, color: cs.outline),
          Expanded(
            child: CustomScrollView(
              controller: scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: RoleGuidanceBanner(
                    // Le CTA suit l'onglet affiché (cohérence titre ↔ bouton) :
                    // onglet Trajets → « Publier mon trajet » ; onglet Colis
                    // (demandes d'envoi), vue « Tout » et expéditeur →
                    // « Publier ma demande ».
                    role: (_isTraveler && _mapFocus == HomeMapFocus.trips)
                        ? ActiveRole.traveler
                        : ActiveRole.sender,
                    hiveService: getIt<HiveService>(),
                  ),
                ),
                if (showBothTypes)
                  BlocBuilder<
                    PackageRequestSearchBloc,
                    PackageRequestSearchState
                  >(
                    builder: (ctx, prState) {
                      return BlocBuilder<BidBloc, BidState>(
                        buildWhen: (prev, curr) =>
                            curr is BidListLoaded || prev is BidListLoaded,
                        builder: (ctx, bidState) {
                          final myActiveBids = bidState
                              .activeBidsByAnnouncement();
                          final parcels = _visibleRequests(prState.results);
                          final totalCount = count + parcels.length;

                          if (totalCount == 0 &&
                              prState.status != SearchStatus.loading) {
                            return const SliverFillRemaining(
                              hasScrollBody: false,
                              child: DonyEmptyState(
                                title: 'Aucun résultat',
                                description:
                                    'Aucun voyageur ni demande disponible.',
                                mascotte: DonyMascotteType.assis,
                              ),
                            );
                          }

                          // Interleave 1:1 — paires trip/parcel puis reste
                          final minLen = count < parcels.length
                              ? count
                              : parcels.length;
                          final pairedCount = minLen * 2;
                          final tripsLonger = count >= parcels.length;

                          return SliverMainAxisGroup(
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  DonySpacing.base,
                                  DonySpacing.sm,
                                  DonySpacing.base,
                                  bottomPad +
                                      DonySpacing.huge +
                                      _kFloatingNavClearance,
                                ),
                                sliver: SliverList.separated(
                                  itemCount: totalCount,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: DonySpacing.md),
                                  itemBuilder: (ctx, i) {
                                    final bool isTrip;
                                    final int itemIndex;

                                    if (i < pairedCount) {
                                      isTrip = i.isEven;
                                      itemIndex = i ~/ 2;
                                    } else {
                                      isTrip = tripsLonger;
                                      itemIndex = minLen + (i - pairedCount);
                                    }

                                    if (isTrip) {
                                      final a = announcements[itemIndex];
                                      final authState = context
                                          .read<AuthBloc>()
                                          .state;
                                      final uid = authState.currentUserId;
                                      final isOwn =
                                          uid != null && a.travelerId == uid;
                                      final existingBid = myActiveBids[a.id];
                                      return TravelerCard(
                                        announcement: a,
                                        index: itemIndex,
                                        isOwnAnnouncement: isOwn,
                                        showFavorite: !isOwn,
                                        existingBidStatus: existingBid?.status,
                                        onTap: isOwn
                                            ? () async {
                                                final changed = await context
                                                    .push<bool>(
                                                      '/announcements/${a.id}/trip',
                                                      extra: a,
                                                    );
                                                if ((changed ?? false) &&
                                                    mounted) {
                                                  _dispatchSearch();
                                                }
                                              }
                                            : existingBid != null
                                            ? () async {
                                                await context.push(
                                                  '/bids/${existingBid.id}',
                                                  extra: existingBid,
                                                );
                                                if (!mounted) {
                                                  return;
                                                }
                                                context.read<BidBloc>().add(
                                                  const BidMyListAutoRefreshRequested(
                                                    force: true,
                                                  ),
                                                );
                                              }
                                            : () =>
                                                  showTravelerAnnouncementSheet(
                                                    context,
                                                    announcement: a,
                                                  ),
                                      );
                                    } else {
                                      final pr = parcels[itemIndex];
                                      final isOwn =
                                          currentUserId != null &&
                                          pr.sender.id == currentUserId;
                                      return PackageRequestListCard(
                                        item: pr,
                                        index: itemIndex,
                                        isOwnRequest: isOwn,
                                        showFavorite: _isTraveler && !isOwn,
                                        onTap: () async {
                                          await PackageRequestPreviewBottomSheet.show(
                                            ctx,
                                            item: pr,
                                          );
                                          if (ctx.mounted) {
                                            ctx
                                                .read<
                                                  PackageRequestSearchBloc
                                                >()
                                                .add(const SearchRefresh());
                                          }
                                        },
                                        onMakeOffer: isOwn
                                            ? null
                                            : () =>
                                                  PackageRequestPreviewBottomSheet.show(
                                                    ctx,
                                                    item: pr,
                                                  ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              if (prState.status == SearchStatus.loading)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: DonySpacing.lg,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  )
                else if (showParcelControls)
                  BlocBuilder<
                    PackageRequestSearchBloc,
                    PackageRequestSearchState
                  >(
                    builder: (ctx, prState) {
                      if (prState.status == SearchStatus.loading) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: CircularProgressIndicator(color: cs.primary),
                          ),
                        );
                      }
                      final visibleResults = _visibleRequests(prState.results);
                      if (visibleResults.isEmpty) {
                        final hasFilters = _prActiveFilterCount > 0;
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: DonyEmptyState(
                            title: hasFilters
                                ? 'Aucun colis avec ces filtres'
                                : 'Demandes bientôt disponibles',
                            description: hasFilters
                                ? 'Modifie ou supprime tes filtres pour voir plus de demandes.'
                                : 'Tu pourras bientôt consulter les demandes d\'envoi postées par les expéditeurs.',
                            mascotte: DonyMascotteType.assis,
                            actionLabel: hasFilters
                                ? 'Effacer les filtres'
                                : null,
                            onAction: hasFilters ? _resetPrFilters : null,
                          ),
                        );
                      }
                      return SliverMainAxisGroup(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              DonySpacing.base,
                              DonySpacing.sm,
                              DonySpacing.base,
                              bottomPad +
                                  DonySpacing.huge +
                                  _kFloatingNavClearance,
                            ),
                            sliver: SliverList.separated(
                              itemCount: visibleResults.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: DonySpacing.md),
                              itemBuilder: (_, i) {
                                final pr = visibleResults[i];
                                final isOwn =
                                    currentUserId != null &&
                                    pr.sender.id == currentUserId;
                                return PackageRequestListCard(
                                  item: pr,
                                  index: i,
                                  isOwnRequest: isOwn,
                                  showFavorite: _isTraveler && !isOwn,
                                  onTap: () async {
                                    await PackageRequestPreviewBottomSheet.show(
                                      ctx,
                                      item: pr,
                                    );
                                    if (ctx.mounted) {
                                      ctx.read<PackageRequestSearchBloc>().add(
                                        const SearchRefresh(),
                                      );
                                    }
                                  },
                                  onMakeOffer: isOwn
                                      ? null
                                      : () =>
                                            PackageRequestPreviewBottomSheet.show(
                                              ctx,
                                              item: pr,
                                            ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  )
                else if (count == 0)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: DonyEmptyState(
                      title: _isNearMeActive
                          ? 'Aucun voyageur à proximité'
                          : _activeFilterCount > 0
                          ? 'Aucun voyageur avec ces filtres'
                          : 'Aucun voyageur sur ce corridor',
                      description: _isNearMeActive
                          ? 'Élargis ta zone ou désactive "Près de moi"'
                          : _activeFilterCount > 0
                          ? 'Modifie tes filtres pour voir plus de voyageurs.'
                          : 'De nouveaux trajets sont publiés chaque jour. Reviens bientôt.',
                      mascotte: DonyMascotteType.assis,
                      actionLabel: !_isNearMeActive && _activeFilterCount > 0
                          ? 'Effacer les filtres'
                          : null,
                      onAction: !_isNearMeActive && _activeFilterCount > 0
                          ? _resetSenderFilters
                          : null,
                    ),
                  )
                else
                  SliverMainAxisGroup(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          DonySpacing.base,
                          DonySpacing.sm,
                          DonySpacing.base,
                          bottomPad + DonySpacing.huge + _kFloatingNavClearance,
                        ),
                        sliver: BlocBuilder<BidBloc, BidState>(
                          buildWhen: (prev, curr) =>
                              curr is BidListLoaded || prev is BidListLoaded,
                          builder: (context, bidState) {
                            final myActiveBidsByAnnouncement = bidState
                                .activeBidsByAnnouncement();
                            return SliverList.separated(
                              itemCount: count,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: DonySpacing.md),
                              itemBuilder: (context, i) {
                                final a = announcements[i];
                                final authState = context
                                    .read<AuthBloc>()
                                    .state;
                                final currentUserId = authState.currentUserId;
                                final isOwn =
                                    currentUserId != null &&
                                    a.travelerId == currentUserId;
                                final badge = _isNearMeActive
                                    ? buildDistanceBadge(
                                        a,
                                        _userPosition != null
                                            ? (
                                                lat: _userPosition!.latitude,
                                                lng: _userPosition!.longitude,
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
                                  showFavorite: !isOwn,
                                  distanceBadge: badge,
                                  existingBidStatus: existingBid?.status,
                                  onTap: isOwn
                                      ? () async {
                                          final changed = await context
                                              .push<bool>(
                                                '/announcements/${a.id}/trip',
                                                extra: a,
                                              );
                                          if ((changed ?? false) &&
                                              context.mounted) {
                                            _dispatchSearch();
                                          }
                                        }
                                      : existingBid != null
                                      ? () async {
                                          await context.push(
                                            '/bids/${existingBid.id}',
                                            extra: existingBid,
                                          );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          context.read<BidBloc>().add(
                                            const BidMyListAutoRefreshRequested(
                                              force: true,
                                            ),
                                          );
                                        }
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
              ],
            ),
          ),
        ],
      ),
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
            DonyIcon('search', size: 18, color: cs.onSurfaceVariant),
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
                    color: _hasActive
                        ? cs.primary
                        : Theme.of(context).scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: DonyIcon(
                    'sliders-horizontal',
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
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: cs.error,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(DonyRadius.sm),
                        ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.md,
        ),
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
            DonyIcon('map', size: 16, color: cs.surface),
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

// ── _NearMeRadiusPill ─────────────────────────────────────────────────────────

/// Affichée quand « Près de moi » est actif. Montre le rayon courant et rouvre
/// le slider au tap — pour ajuster le rayon sans désactiver le filtre.
class _NearMeRadiusPill extends StatelessWidget {
  const _NearMeRadiusPill({
    super.key,
    required this.radiusKm,
    required this.onTap,
  });

  final double radiusKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('circle-dot', size: 16, color: cs.primary),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Rayon · ${radiusKm.round()} km',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: DonySpacing.xs),
              DonyIcon(
                'sliders-horizontal',
                size: 15,
                color: cs.onSurfaceVariant,
              ),
            ],
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
    required this.allCorridors,
    required this.onDateTap,
    required this.onRatingTap,
    required this.onWeightTap,
    required this.onPriceTap,
    required this.onKiloProToggle,
    required this.onAllCorridorsToggle,
    required this.onDateClear,
    required this.onRatingClear,
    required this.onWeightClear,
    required this.onPriceClear,
    this.minRating,
    this.weightMin,
    this.weightMax,
    this.maxPricePerKg,
    this.leadingChildren = const [],
  });

  final _DatePreset datePreset;
  final DateTime? customDate;
  final bool kiloProOnly;
  final bool allCorridors;
  final double? minRating;
  final double? weightMin;
  final double? weightMax;
  final double? maxPricePerKg;
  final VoidCallback onDateTap;
  final VoidCallback onRatingTap;
  final VoidCallback onWeightTap;
  final VoidCallback onPriceTap;
  final VoidCallback onKiloProToggle;
  final VoidCallback onAllCorridorsToggle;
  final VoidCallback onDateClear;
  final VoidCallback onRatingClear;
  final VoidCallback onWeightClear;
  final VoidCallback onPriceClear;
  final List<Widget> leadingChildren;

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
          ...leadingChildren,
          _SmallChip(
            label: _dateLabel,
            isActive: datePreset != _DatePreset.none,
            iconAsset: 'calendar',
            onTap: datePreset != _DatePreset.none ? onDateClear : onDateTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: _ratingLabel,
            isActive: minRating != null,
            iconAsset: 'star',
            onTap: minRating != null ? onRatingClear : onRatingTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: _weightLabel,
            isActive: weightMin != null || weightMax != null,
            iconAsset: 'dumbbell',
            onTap: (weightMin != null || weightMax != null)
                ? onWeightClear
                : onWeightTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: _priceLabel,
            isActive: maxPricePerKg != null,
            iconAsset: 'euro',
            onTap: maxPricePerKg != null ? onPriceClear : onPriceTap,
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
        ],
      ),
    );
  }
}

// ── _SmallChip ────────────────────────────────────────────────────────────────

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.iconAsset,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? iconAsset;

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
          vertical: DonySpacing.sm,
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
            if (iconAsset != null) ...[
              DonyIcon(
                iconAsset!,
                size: 15,
                color: isActive ? Colors.white : cs.onSurfaceVariant,
              ),
              const SizedBox(width: DonySpacing.xxs),
            ],
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
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DonyRadius.sheet),
          ),
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
                            color: isSelected ? cs.primary : cs.outline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                opt.label,
                                style: tt.bodyMedium?.copyWith(
                                  color: isSelected ? cs.primary : cs.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isSelected)
                              DonyIcon(
                                'circle-check',
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
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
                  onTap: () => Navigator.of(context).pop((
                    preset: _DatePreset.none,
                    customDate: null as DateTime?,
                  )),
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
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((preset: _selected, customDate: _customDate)),
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected) DonyIcon('check', size: 18, color: cs.primary),
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
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
            'Note minimum',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
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
                  onPressed: () => Navigator.of(context).pop(_selected ?? -1.0),
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
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
            'Capacité kilo',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
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
              onChanged: (v) => setState(() {
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
                Text(
                  '1 kg',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  '50 kg',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.lg),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop((min: 0.0, max: 0.0)),
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
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
            'Prix maximum',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
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
                Text(
                  '3 €/kg',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  '25 €/kg',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
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

// ── _PackageRequestFilterChipsRow ─────────────────────────────────────────────

class _PackageRequestFilterChipsRow extends StatelessWidget {
  const _PackageRequestFilterChipsRow({
    required this.onDateTap,
    required this.onWeightTap,
    required this.onSizeTap,
    required this.onDateClear,
    required this.onWeightClear,
    required this.onSizeClear,
    this.dateFrom,
    this.dateTo,
    this.maxWeight,
    this.parcelSize,
    this.leadingChildren = const [],
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxWeight;
  final ParcelSize? parcelSize;
  final VoidCallback onDateTap;
  final VoidCallback onWeightTap;
  final VoidCallback onSizeTap;
  final VoidCallback onDateClear;
  final VoidCallback onWeightClear;
  final VoidCallback onSizeClear;
  final List<Widget> leadingChildren;

  String get _dateLabel {
    if (dateFrom == null) return 'Toutes dates';
    if (dateTo != null && dateTo!.difference(dateFrom!).inDays <= 1) {
      return DateFormat('d MMM', 'fr').format(dateFrom!);
    }
    return '${DateFormat('d MMM', 'fr').format(dateFrom!)} – ${DateFormat('d MMM', 'fr').format(dateTo!)}';
  }

  String get _weightLabel =>
      maxWeight != null ? '≤ ${maxWeight!.toInt()} kg' : 'Kilos';

  String get _sizeLabel => parcelSize != null ? parcelSize!.wireName : 'Taille';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...leadingChildren,
          _SmallChip(
            label: _dateLabel,
            isActive: dateFrom != null,
            iconAsset: 'calendar',
            onTap: dateFrom != null ? onDateClear : onDateTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: _weightLabel,
            isActive: maxWeight != null,
            iconAsset: 'dumbbell',
            onTap: maxWeight != null ? onWeightClear : onWeightTap,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: _sizeLabel,
            isActive: parcelSize != null,
            iconAsset: 'package',
            onTap: parcelSize != null ? onSizeClear : onSizeTap,
          ),
        ],
      ),
    );
  }
}

// ── _FavoritesButton ──────────────────────────────────────────────────────────

/// Bouton cœur en haut à gauche de l'overlay accueil (à gauche de la barre de
/// recherche). Même style que [_NotificationBell] : cercle 48×48, fond
/// [ColorScheme.surface], shadow `Colors.black @10% blur 12 offset(0,3)`.
/// Badge rouge [DonyColors.favorite] affiché si le nombre de favoris > 0.
/// Navigue vers `/favoris` au tap via GoRouter.
class _FavoritesButton extends StatelessWidget {
  const _FavoritesButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoriteIdsCubit, FavoriteIdsState>(
      buildWhen: (prev, next) => prev.count != next.count,
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        final count = state.count;
        return GestureDetector(
          key: const Key('favorites-button'),
          onTap: () => context.push('/favoris'),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  count > 0 ? Icons.favorite : Icons.favorite_border,
                  size: 22,
                  color: count > 0 ? DonyColors.favorite : cs.onSurfaceVariant,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    key: const Key('favorites-badge'),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: DonyColors.favorite,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
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
        );
      },
    );
  }
}

// ── _NotificationBell ─────────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (prev, next) {
        final prevCount = prev is NotificationLoaded ? prev.unreadCount : 0;
        final nextCount = next is NotificationLoaded ? next.unreadCount : 0;
        return prevCount != nextCount;
      },
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        final unreadCount = state is NotificationLoaded ? state.unreadCount : 0;
        return GestureDetector(
          onTap: () => showNotificationBottomSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DonyIcon(
                  'bell',
                  size: 22,
                  color: unreadCount > 0 ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    key: const Key('notification-badge'),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: DonyColors.error,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
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
        );
      },
    );
  }
}
