import 'dart:async';
import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/map_camera_math.dart';
import 'package:dony/features/matching/presentation/widgets/map_styles.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:dony/features/matching/presentation/widgets/marker_clustering.dart';
import 'package:dony/features/matching/presentation/widgets/marker_urgency.dart';
import 'package:dony/features/matching/presentation/widgets/same_address_announcements_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

export 'package:dony/features/matching/presentation/widgets/location_permission.dart'
    show LocationService, GeolocatorLocationService, LocationAccess;

// ── Internal types ────────────────────────────────────────────────────────────

enum _MarkerSide { pickup }

class _AnnouncementPoint {
  const _AnnouncementPoint(this.announcement, this.side);

  final AnnouncementModel announcement;
  final _MarkerSide side;

  LatLng get location {
    final addr = side == _MarkerSide.pickup
        ? announcement.pickupAddress
        : announcement.deliveryAddress;
    return LatLng(addr!.lat, addr.lng); // ! safe: callers filter null
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class AnnouncementMapView extends StatefulWidget {
  const AnnouncementMapView({
    super.key,
    required this.announcements,
    this.extraMarkers = const {},
    this.searchDepartureCity,
    this.searchArrivalCity,
    this.locationService = const GeolocatorLocationService(),
    this.isNearMeActive = false,
    this.activeRadiusKm,
    this.userPosition,
    this.fabBottomPadding = 0,
    this.mapStyle,
    this.selectedAnnouncementId,
    this.onAnnouncementSelected,
    this.onNearMeToggle,
    this.isLocating = false,
  });

  final List<AnnouncementModel> announcements;

  /// Additional markers to render alongside announcement markers (e.g. package requests).
  /// They bypass the cluster logic and are drawn as-is.
  final Set<Marker> extraMarkers;
  final String? searchDepartureCity;
  final String? searchArrivalCity;
  final LocationService locationService;
  final bool isNearMeActive;
  final double? activeRadiusKm;
  final LatLng? userPosition;
  final double fabBottomPadding;

  /// Style JSON Google Maps. Null = style par défaut Google Maps.
  final String? mapStyle;

  /// ID of the currently selected announcement (highlighted marker).
  final String? selectedAnnouncementId;

  /// Called when user taps a single marker.
  final void Function(String id)? onAnnouncementSelected;

  /// Called when the user taps the single "Près de moi" FAB. When null, the
  /// FAB is hidden. The parent owns the near-me filter lifecycle (permission,
  /// radius, search) — this widget only renders the toggle and frames the map.
  final VoidCallback? onNearMeToggle;

  /// True while the parent acquires the position after a FAB tap (FAB spinner).
  final bool isLocating;

  @override
  State<AnnouncementMapView> createState() => _AnnouncementMapViewState();
}

/// Durée de pause au-delà de laquelle la carte native est recréée.
const Duration kMapRecreateAfterPause = Duration(seconds: 3);

/// L'app est-elle restée assez longtemps en arrière-plan pour que la vue
/// native de la carte ait pu être détruite (FLUTTER-BK) ?
@visibleForTesting
bool shouldRecreateNativeMap(Duration pausedFor) =>
    pausedFor >= kMapRecreateAfterPause;

/// Intervalle minimal entre deux recréations dues à la pression mémoire : iOS
/// peut répéter l'alerte, recréer la carte à chaque fois l'aggraverait.
const Duration kMapMemoryRecreateCooldown = Duration(seconds: 30);

/// Faut-il recréer tout de suite la carte native sur une alerte mémoire
/// (FLUTTER-FF) ? Sous pression mémoire ou thermique, iOS libère la surface de
/// rendu de la carte, qui reste noire alors que les tuiles se chargent. Seule
/// une carte déjà créée et visible (app au premier plan) est concernée ; en
/// arrière-plan, la recréation attend le retour ([shouldRecreateOnResume]).
@visibleForTesting
bool shouldRecreateOnMemoryPressure({
  required bool mapCreated,
  required bool inForeground,
  required DateTime now,
  DateTime? lastRecreatedAt,
}) {
  if (!mapCreated || !inForeground) return false;
  if (lastRecreatedAt == null) return true;
  return now.difference(lastRecreatedAt) >= kMapMemoryRecreateCooldown;
}

/// Faut-il recréer la carte native au retour au premier plan ? Après une vraie
/// pause (FLUTTER-BK), ou dès qu'une alerte mémoire est arrivée pendant
/// l'arrière-plan sur une carte déjà créée (FLUTTER-FF), même pour une pause
/// brève : c'est justement là que la surface a pu être libérée.
@visibleForTesting
bool shouldRecreateOnResume({
  required Duration pausedFor,
  required bool mapCreated,
  required bool memoryPressureWhilePaused,
}) =>
    shouldRecreateNativeMap(pausedFor) ||
    (mapCreated && memoryPressureWhilePaused);

/// Délai au-delà duquel une carte native toujours pas créée est annoncée
/// comme indisponible (FLUTTER-CD) : sans message, une carte vide laisse
/// croire que la recherche ne charge pas.
const Duration kMapLoadTimeout = Duration(seconds: 10);

/// Message discret à afficher sur la carte, ou null quand tout va bien
/// (FLUTTER-CD). La panne de la carte prime sur la localisation refusée.
@visibleForTesting
String? mapNoticeMessage(
  AppLocalizations l, {
  required bool mapUnavailable,
  required LocationAccess? locationAccess,
}) {
  if (mapUnavailable) return l.listingMapUnavailable;
  if (locationAccess != null && locationAccess != LocationAccess.granted) {
    return l.listingMapLocationOff;
  }
  return null;
}

class _AnnouncementMapViewState extends State<AnnouncementMapView>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;

  /// Génération de la carte native : elle change quand l'app revient au
  /// premier plan après une vraie pause, ce qui recrée la vue native (FLUTTER-BK).
  int _mapGeneration = 0;
  DateTime? _pausedAt;

  /// Alerte mémoire reçue pendant que l'app était en arrière-plan (FLUTTER-FF).
  bool _memoryPressureWhilePaused = false;
  DateTime? _lastRecreatedAt;

  /// Dernière position de la caméra, pour recréer la carte au même endroit.
  CameraPosition? _lastCamera;

  Set<Marker> _markers = {};
  final Map<int, BitmapDescriptor> _clusterIcons = {};
  double _currentZoom = 3.5;
  bool _locationGranted = false;
  LatLng? _myLocation;
  bool _awaitingFirstLocation = false;
  // Cached brightness — updated in didChangeDependencies (safe to read in initState-triggered async work).
  Brightness _brightness = Brightness.light;
  // Cached langue — le libellé de grille tarifaire dessiné sur les marqueurs
  // (gridLabel) dépend de la langue ; sans ce suivi, un changement de langue
  // en session laisserait les marqueurs déjà construits dans l'ancienne
  // langue jusqu'au prochain critère de rebuild (zoom, sélection...).
  String _localeName = 'fr';
  // Improvement A: signature guard to skip redundant re-clustering.
  String? _lastMarkerSignature;

  /// Surveille la création de la carte native (FLUTTER-CD).
  Timer? _mapLoadWatchdog;
  bool _mapUnavailable = false;

  /// Résultat de la demande de localisation à l'ouverture (null : en cours).
  LocationAccess? _locationAccess;

  /// Le message de la carte a été fermé par l'utilisateur.
  bool _noticeDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMapWatchdog();
    // `_prewarmCommonIcons` construit des marqueurs via `_buildMarker`, qui
    // lit `context.l10n` (le libellé de grille tarifaire) : un `Localizations`
    // ne peut pas être consulté avant la fin de `initState`, d'où le report
    // en post-frame, comme `_initLocationOnOpen` juste en dessous.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prewarmCommonIcons());
      _initLocationOnOpen();
    });
  }

  @override
  void dispose() {
    _mapLoadWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startMapWatchdog() {
    _mapLoadWatchdog?.cancel();
    _mapLoadWatchdog = Timer(kMapLoadTimeout, () {
      if (mounted && _mapController == null) {
        setState(() => _mapUnavailable = true);
      }
    });
  }

  /// Le moteur Flutter survit à l'Activity Android (moteur en cache,
  /// MainActivity) : au retour, l'arbre Dart est intact mais la vue native de
  /// la carte peut avoir disparu, et rien ne la recrée. Elle restait vide
  /// jusqu'à la fermeture complète de l'app (FLUTTER-BK).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final pausedAt = _pausedAt;
    final memoryPressure = _memoryPressureWhilePaused;
    _pausedAt = null;
    _memoryPressureWhilePaused = false;
    if (pausedAt == null || !mounted) return;
    if (shouldRecreateOnResume(
      pausedFor: DateTime.now().difference(pausedAt),
      mapCreated: _mapController != null,
      memoryPressureWhilePaused: memoryPressure,
    )) {
      _recreateNativeMap();
    }
  }

  /// Carte noire sur iPhone sous pression mémoire ou thermique (FLUTTER-FF,
  /// breadcrumb LOW_MEMORY, tuiles pourtant chargées) : la surface native a
  /// été libérée. Au premier plan on la recrée tout de suite, en arrière-plan
  /// au retour.
  @override
  void didHaveMemoryPressure() {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final inForeground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (!inForeground) {
      if (_mapController != null) _memoryPressureWhilePaused = true;
      return;
    }
    if (shouldRecreateOnMemoryPressure(
      mapCreated: _mapController != null,
      inForeground: inForeground,
      now: DateTime.now(),
      lastRecreatedAt: _lastRecreatedAt,
    )) {
      _recreateNativeMap();
    }
  }

  /// Recrée la vue native au même endroit (la caméra est gardée dans
  /// [_lastCamera]) ; les marqueurs sont reconstruits dans `onMapCreated`.
  void _recreateNativeMap() {
    _lastRecreatedAt = DateTime.now();
    setState(() {
      _mapGeneration++;
      _mapController = null;
      _lastMarkerSignature = null;
    });
    _startMapWatchdog();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newBrightness = Theme.of(context).brightness;
    final newLocaleName = context.l10n.localeName;
    final brightnessChanged = newBrightness != _brightness;
    final localeChanged = newLocaleName != _localeName;
    if (brightnessChanged || localeChanged) {
      _brightness = newBrightness;
      _localeName = newLocaleName;
      _rebuildMarkers();
    }
  }

  @override
  void didUpdateWidget(covariant AnnouncementMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announcements != widget.announcements ||
        oldWidget.selectedAnnouncementId != widget.selectedAnnouncementId) {
      _rebuildMarkers();
    }
    // Auto-fit when "Près de moi" turns on or its radius/position changes
    // (e.g. user toggled it from the filter sheet).
    final nearMeChanged =
        oldWidget.isNearMeActive != widget.isNearMeActive ||
        oldWidget.activeRadiusKm != widget.activeRadiusKm ||
        oldWidget.userPosition != widget.userPosition;
    if (nearMeChanged &&
        widget.isNearMeActive &&
        widget.userPosition != null &&
        widget.activeRadiusKm != null) {
      // The parent only activates near-me once it holds a granted position, so
      // turn on the native blue dot here even if the open-flow was denied.
      if (!_locationGranted) {
        setState(() => _locationGranted = true);
      }
      _fitNearMeBounds(widget.userPosition!, widget.activeRadiusKm!);
    }
  }

  Future<void> _prewarmCommonIcons() async {
    // Price pills don't need prewarm — built lazily and cached per price
    await _rebuildMarkers();
  }

  Future<void> _initLocationOnOpen() async {
    _awaitingFirstLocation = true;
    final access = await requestLocationAccess(widget.locationService);
    if (mounted) setState(() => _locationAccess = access);
    if (access != LocationAccess.granted) {
      _awaitingFirstLocation = false;
      if (mounted) {
        _applyInitialCamera(); // fallback annonces, silencieux (pas de point bleu)
      }
      return;
    }
    if (!mounted) {
      _awaitingFirstLocation = false;
      return;
    }
    setState(() => _locationGranted = true);
    try {
      final pos = await widget.locationService.getCurrentPosition();
      if (!mounted) {
        return;
      }
      _awaitingFirstLocation = false;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _applyInitialCamera();
    } catch (_) {
      _awaitingFirstLocation = false;
      if (mounted) {
        _applyInitialCamera();
      }
    }
  }

  void _applyInitialCamera() {
    final controller = _mapController;
    if (controller == null) {
      return; // onMapCreated rappellera
    }
    final me = _myLocation;
    if (me != null) {
      // Cadre ~300 km autour de la position, soit l'échelle du pays (zoom ~5,5).
      // 1000 km auparavant : le cadre couvrait 2000 km de diamètre, ce qui donne
      // un zoom ~3,8 contre 3,5 pour la vue par défaut sans position. Accepter la
      // localisation ne changeait donc quasiment rien à l'écran, et l'utilisateur
      // ne se reconnaissait pas sur la carte.
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(boundsAround(me, 300), 60.0),
      );
    } else if (!_awaitingFirstLocation) {
      _fitInitialBounds();
    }
  }

  List<_AnnouncementPoint> _pickupPoints() => widget.announcements
      .where((a) => a.pickupAddress != null)
      .map((a) => _AnnouncementPoint(a, _MarkerSide.pickup))
      .toList();

  /// Everything that affects the rendered marker set. Panning within the same
  /// zoom bucket leaves this unchanged, so `_rebuildMarkers` can skip the work.
  String _markerSignature() {
    final buf = StringBuffer();
    for (final a in widget.announcements) {
      if (a.pickupAddress == null) {
        continue;
      }
      // Le marqueur rend senderPricePerKg (prix expéditeur), pas pricePerKg
      // (net voyageur, masqué pour un invité) : la clé de cache doit suivre
      // la valeur réellement affichée, sinon un changement de ce qui compte
      // pour le rendu ne casserait jamais le cache pour un invité.
      final renderedPrice = a.senderPricePerKg;
      buf
        ..write(a.id)
        ..write(':')
        // cents → clé entière stable ; absent → jeton dédié, jamais confondu
        // avec un vrai montant à 0.
        ..write(renderedPrice == null ? 'null' : (renderedPrice * 100).round())
        ..write(':')
        ..write(a.departureDate.millisecondsSinceEpoch)
        ..write(';');
    }
    buf
      ..write('|sel=')
      ..write(widget.selectedAnnouncementId)
      ..write('|b=')
      ..write(_brightness.index)
      ..write('|l=')
      ..write(_localeName)
      ..write('|c=')
      ..write(cellDegForZoom(_currentZoom));
    return buf.toString();
  }

  Future<void> _rebuildMarkers({bool force = false}) async {
    final signature = _markerSignature();
    if (!force && signature == _lastMarkerSignature) {
      return;
    }
    _lastMarkerSignature = signature;
    final allPoints = [..._pickupPoints()];
    final rawClusters = gridCluster<_AnnouncementPoint>(
      allPoints,
      _currentZoom,
      (p) => p.location,
    );
    // Merge singleton clusters that straddle a grid-cell boundary but share
    // the same physical address (within the kSameSpot threshold).
    final clusters = mergeSameSpotSingletons<_AnnouncementPoint>(
      rawClusters,
      (p) => p.location,
    );
    final futures = clusters.map((c) => _buildMarker(c));
    final built = await Future.wait(futures);
    if (!mounted) {
      _lastMarkerSignature =
          null; // unmounted mid-build → don't suppress a later rebuild
      return;
    }
    setState(() => _markers = built.toSet());
  }

  Future<Marker> _buildMarker(MarkerCluster<_AnnouncementPoint> cluster) async {
    if (cluster.isMultiple) {
      if (cluster.isSameSpot) {
        // Same address: stacked pill with count badge.
        // Show cheapest price and most urgent (earliest) departure.
        // Prix affiché à l'expéditeur (net + commission) — cohérent avec les cartes/sheets.
        // On ne compare que les prix réellement présents : un `?? 0` par
        // élément ferait gagner « le moins cher » à une annonce sans prix
        // face à une annonce qui en a un, et ferait basculer tout le cluster
        // en affichage « Grille » à tort. Seule l'absence de TOUT prix dans
        // le cluster retombe sur la sentinelle `<= 0` (`_renderStackedPricePill`
        // affiche alors « Grille » plutôt qu'un faux montant).
        final itemsWithPrice = cluster.items.where(
          (it) => it.announcement.senderPricePerKg != null,
        );
        final cheapestItem = itemsWithPrice.isEmpty
            ? cluster.items.first
            : itemsWithPrice.reduce(
                (a, b) =>
                    a.announcement.senderPricePerKg! <
                        b.announcement.senderPricePerKg!
                    ? a
                    : b,
              );
        final cheapest = cheapestItem.announcement.senderPricePerKg ?? 0.0;
        final earliest = cluster.items
            .map((it) => it.announcement.departureDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final urgencyColor = MarkerUrgencyColor.fromDeparture(
          earliest,
          brightness: _brightness,
        );
        final isSelected = cluster.items.any(
          (it) => it.announcement.id == widget.selectedAnnouncementId,
        );
        final icon = await MarkerBitmapFactory.stackedPricePill(
          pricePerKg: cheapest,
          count: cluster.count,
          dotColor: urgencyColor,
          isSelected: isSelected,
          brightness: _brightness,
          prefix: '✈️',
          currencyCode: cheapestItem.announcement.currency,
          gridLabel: context.l10n.listingPriceGridShort,
        );
        return Marker(
          markerId: MarkerId(
            'same_spot_${cluster.centroid.latitude}_${cluster.centroid.longitude}',
          ),
          position: cluster.centroid,
          icon: icon,
          onTap: () => _onClusterTapped(cluster),
        );
      }

      // Proximity cluster: classic blue badge.
      final icon = await _getClusterIcon(cluster.count);
      return Marker(
        markerId: MarkerId(
          'cluster_${cluster.centroid.latitude}_${cluster.centroid.longitude}_${cluster.count}',
        ),
        position: cluster.centroid,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        onTap: () => _onClusterTapped(cluster),
      );
    }

    // Single marker.
    final item = cluster.items.first;
    final urgencyColor = MarkerUrgencyColor.fromDeparture(
      item.announcement.departureDate,
      brightness: _brightness,
    );
    final isSelected = item.announcement.id == widget.selectedAnnouncementId;
    final icon = await MarkerBitmapFactory.pricePill(
      // Idem : absent → sentinelle `<= 0`, déjà rendue comme « Grille ».
      pricePerKg: item.announcement.senderPricePerKg ?? 0,
      dotColor: urgencyColor,
      isSelected: isSelected,
      brightness: _brightness,
      prefix: '✈️',
      currencyCode: item.announcement.currency,
      gridLabel: context.l10n.listingPriceGridShort,
    );
    return Marker(
      markerId: MarkerId('${item.side.name}_${item.announcement.id}'),
      position: item.location,
      icon: icon,
      onTap: () => _onMarkerTapped(item.announcement),
    );
  }

  Future<BitmapDescriptor> _getClusterIcon(int count) async {
    if (_clusterIcons.containsKey(count)) {
      return _clusterIcons[count]!;
    }
    final icon = await MarkerBitmapFactory.clusterBadge(count);
    _clusterIcons[count] = icon;
    return icon;
  }

  void _onMarkerTapped(AnnouncementModel a) {
    widget.onAnnouncementSelected?.call(a.id);
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState.currentUserId;
    final isOwn = currentUserId != null && a.travelerId == currentUserId;
    if (isOwn) return;
    showTravelerAnnouncementSheet(context, announcement: a);
  }

  void _onClusterTapped(MarkerCluster<_AnnouncementPoint> cluster) {
    if (cluster.isSameSpot) {
      // Same address → list sheet (type known at build time, no recheck needed).
      final firstItem = cluster.items.first;
      final addr = firstItem.side == _MarkerSide.pickup
          ? firstItem.announcement.pickupAddress
          : firstItem.announcement.deliveryAddress;
      final authState = context.read<AuthBloc>().state;
      final currentUserId = authState.currentUserId;
      // La feuille se ferme elle-même (navigateur racine) avant d'ouvrir la
      // fiche : jamais de pop avec le context de la carte (FLUTTER-FE/FD).
      unawaited(
        showSameAddressAnnouncementsSheet(
          context,
          addressLabel: addr?.label ?? context.l10n.listingAddressFallback,
          announcements: cluster.items.map((it) => it.announcement).toList(),
          currentUserId: currentUserId,
          onSelected: (a) {
            if (!mounted) return;
            showTravelerAnnouncementSheet(context, announcement: a);
          },
        ),
      );
    } else {
      // Proximity cluster → zoom in to separate the pins.
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          cluster.centroid,
          math.min(_currentZoom + 2, 18),
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fabBottom = widget.fabBottomPadding + DonySpacing.lg;

    return Stack(
      children: [
        GoogleMap(
          key: ValueKey<int>(_mapGeneration),
          initialCameraPosition:
              _lastCamera ??
              const CameraPosition(target: LatLng(30.0, -5.0), zoom: 3.5),
          style: widget.mapStyle ?? resolveMapStyle(_brightness),
          onMapCreated: (controller) {
            _mapController = controller;
            _mapLoadWatchdog?.cancel();
            if (_mapUnavailable) setState(() => _mapUnavailable = false);
            // Carte recréée après une pause : on garde la caméra de
            // l'utilisateur au lieu de recadrer sur sa position.
            if (_lastCamera == null) _applyInitialCamera();
            if (_mapGeneration > 0) unawaited(_rebuildMarkers());
          },
          onCameraMove: (position) {
            _currentZoom = position.zoom;
            _lastCamera = position;
          },
          onCameraIdle: () => _rebuildMarkers(),
          markers: {..._markers, ...widget.extraMarkers},
          circles: _radiusCircle(),
          myLocationEnabled: _locationGranted,
          // Notre FAB est l'unique contrôle de localisation — on masque le
          // bouton natif Google pour ne pas avoir deux boutons qui se doublent.
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        _buildNotice(context, fabBottom),
        if (widget.onNearMeToggle != null)
          // Animé : le bouton suit la feuille de résultats quand elle s'ouvre
          // à mi-hauteur (FLUTTER-CD).
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            bottom: fabBottom,
            right: DonySpacing.lg,
            child: _NearMeFab(
              key: const Key('near-me-fab'),
              isActive: widget.isNearMeActive,
              isLoading: widget.isLocating,
              onTap: widget.onNearMeToggle!,
            ),
          ),
      ],
    );
  }

  /// Message discret, à gauche du bouton « Près de moi » : carte qui ne se
  /// charge pas, ou position non partagée (FLUTTER-CD). Fermable.
  Widget _buildNotice(BuildContext context, double fabBottom) {
    final message = _noticeDismissed || widget.isNearMeActive
        ? null
        : mapNoticeMessage(
            context.l10n,
            mapUnavailable: _mapUnavailable,
            locationAccess: _locationGranted ? null : _locationAccess,
          );
    final cs = Theme.of(context).colorScheme;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: DonySpacing.lg,
      right: DonySpacing.lg + 48 + DonySpacing.sm,
      bottom: fabBottom,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: message == null
            ? const SizedBox.shrink()
            : Align(
                key: ValueKey(message),
                alignment: Alignment.bottomLeft,
                child: Container(
                  key: const Key('map-notice'),
                  padding: const EdgeInsets.only(left: DonySpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _mapUnavailable
                            ? Icons.map_outlined
                            : Icons.location_off_outlined,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Flexible(
                        child: Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                      IconButton(
                        key: const Key('map-notice-close'),
                        tooltip: context.l10n.commonClose,
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        color: cs.onSurfaceVariant,
                        onPressed: () =>
                            setState(() => _noticeDismissed = true),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Set<Circle> _radiusCircle() {
    if (!widget.isNearMeActive ||
        widget.userPosition == null ||
        widget.activeRadiusKm == null) {
      return {};
    }
    final primary = Theme.of(context).colorScheme.primary;
    return {
      Circle(
        circleId: const CircleId('near-me-radius'),
        center: widget.userPosition!,
        radius: widget.activeRadiusKm! * 1000,
        strokeColor: primary,
        strokeWidth: 2,
        fillColor: primary.withValues(alpha: 0.08),
      ),
    };
  }

  Future<void> _fitNearMeBounds(LatLng center, double radiusKm) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    // 1° latitude ≈ 111 km ; longitude shrinks by cos(lat) towards the poles.
    final latDelta = radiusKm / 111.0;
    final lngDelta =
        radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180).abs());
    final bounds = LatLngBounds(
      southwest: LatLng(
        center.latitude - latDelta,
        center.longitude - lngDelta,
      ),
      northeast: LatLng(
        center.latitude + latDelta,
        center.longitude + lngDelta,
      ),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
  }

  Future<void> _fitInitialBounds() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    final allPoints = <LatLng>[..._pickupPoints().map((it) => it.location)];
    if (allPoints.isEmpty) {
      return;
    }
    final bounds = _boundsFromPoints(allPoints);
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

// ── _NearMeFab ────────────────────────────────────────────────────────────────

class _NearMeFab extends StatelessWidget {
  const _NearMeFab({
    super.key,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Tooltip(
      message: isActive
          ? l.listingNearMeDeactivateTooltip
          : l.listingNearMeActivateTooltip,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? cs.primary : cs.surface,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? cs.primary : cs.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isActive ? Colors.white : cs.primary,
                    ),
                  )
                : DonyIcon(
                    'navigation',
                    size: 22,
                    color: isActive ? Colors.white : cs.primary,
                  ),
          ),
        ),
      ),
    );
  }
}
