import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/role_guidance_banner.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/home_filter_chips_row.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
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

// ── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PackageRequestSearchBloc>(
          create: (_) => getIt<PackageRequestSearchBloc>(),
        ),
        // Résumé d'activité : seul son `activeTrips` sert ici, il pilote le
        // filtre « Pour mes trajets » (pastille et en-tête de liste).
        BlocProvider<TripsSummaryCubit>(
          create: (_) => getIt<TripsSummaryCubit>()..load(),
        ),
      ],
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

  bool _nearMeShowList = false;
  // True between the FAB tap and the position being acquired (FAB spinner).
  bool _isLocatingNearMe = false;

  String? _selectedAnnouncementId;

  /// Mode de recherche courant. Deux valeurs exclusives : il n'existe plus de
  /// vue mixte. Le mode pilote la liste, les marqueurs de carte, les chips
  /// spécifiques et la feuille de filtres.
  SearchMode _mode = SearchMode.trips;

  /// Filtres de recherche, communs et spécifiques réunis. Un seul porteur pour
  /// les deux modes : c'est ce qui fait survivre le corridor et la date à la
  /// bascule, là où deux jeux de champs parallèles les perdaient.
  HomeSearchFilters _filters = const HomeSearchFilters();

  /// Nombre de résultats de l'autre mode, pour le compteur du segment inactif.
  /// Null tant qu'aucun filtre commun n'est posé, le total serait alors un
  /// nombre plateforme sans valeur informative.
  int? _otherModeCount;

  // « Près de moi » vit dans [_filters] (il neutralise le corridor et fournit
  // lat/lng/rayon aux deux recherches). Ces accesseurs évitent de disperser
  // `_filters.` dans tout le rendu de la carte.
  bool get _isNearMeActive => _filters.nearMeActive;
  double? get _nearMeRadiusKm => _filters.nearMeRadiusKm;
  LatLng? get _userPosition =>
      (_filters.userLat != null && _filters.userLng != null)
      ? LatLng(_filters.userLat!, _filters.userLng!)
      : null;

  int get _activeFilterCount => _filters.activeCountFor(_mode);

  /// Libellé de la barre corridor : le corridor posé, ou son absence.
  String get _corridorLabel {
    final dep = _filters.departureCity;
    final arr = _filters.arrivalCity;
    if (dep != null && arr != null) {
      return '$dep → $arr';
    }
    if (dep != null) {
      return 'Départ de $dep';
    }
    if (arr != null) {
      return 'Vers $arr';
    }
    return 'Tous les corridors';
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
        _dispatchForMode();
      }
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
    // `toAnnouncementQuery` (et non `toSearchParams`) : c'est elle qui porte le
    // vrai payload serveur — corridor neutralisé par « près de moi », booléens
    // jamais envoyés à false.
    final q = _filters.toAnnouncementQuery();
    context.read<AnnouncementBloc>().add(
      AnnouncementSearchRequested(
        departureCity: q.departureCity,
        arrivalCity: q.arrivalCity,
        departureDateFrom: q.departureDateFrom,
        departureDateTo: q.departureDateTo,
        minAvailableKg: q.minAvailableKg,
        maxAvailableKg: q.maxAvailableKg,
        maxPricePerKg: q.maxPricePerKg,
        kiloProOnly: q.kiloProOnly,
        minRating: q.minRating,
        weekendOnly: q.weekendOnly,
        transportMode: q.transportMode,
        kycVerifiedOnly: q.kycVerifiedOnly,
        contentType: q.contentType,
        userLat: q.userLat,
        userLng: q.userLng,
        radiusKm: q.radiusKm,
        urgent: q.urgent,
      ),
    );
  }

  void _dispatchPackageRequestSearch() {
    if (!mounted) return;
    final q = _filters.toPackageRequestQuery();
    context.read<PackageRequestSearchBloc>().add(
      SearchFiltersChanged(
        departure: q.departure,
        arrival: q.arrival,
        dateFrom: q.dateFrom,
        dateTo: q.dateTo,
        maxWeight: q.maxWeight,
        parcelSize: q.parcelSize,
        userLat: q.userLat,
        userLng: q.userLng,
        radiusKm: q.radiusKm,
        urgent: q.urgent,
        matchingMyTrips: q.matchingMyTrips,
      ),
    );
  }

  /// Une recherche par mode : la liste affichée est celle du mode courant,
  /// dispatcher l'autre chargerait des résultats que personne ne regarde.
  void _dispatchForMode() {
    if (_mode.isTrips) {
      _dispatchSearch();
    } else {
      _dispatchPackageRequestSearch();
    }
  }

  /// Compteur de l'autre mode, sans charger les résultats : on ne lit que le
  /// total de la page. Une requête légère, pas une seconde recherche.
  ///
  /// Appel direct au repository plutôt qu'au BLoC de recherche : l'état de ce
  /// dernier porte les résultats affichés, et y injecter une page de taille 1
  /// écraserait la liste à l'écran.
  ///
  /// Les deux branches passent par les mêmes `toXxxQuery()` que les dispatchs
  /// réels : c'est la seule façon que le nombre annoncé soit celui que la
  /// bascule produira. Lire `_filters` directement laisserait tomber la
  /// neutralisation du corridor par « près de moi », la position et le rayon.
  Future<void> _dispatchOtherModeCount() async {
    // Sans rôle voyageur, la bascule vers Colis est refusée par le garde-fou :
    // compter les colis n'a plus aucune valeur, et la requête partirait pour
    // rien (403 avalé par le `catch` plus bas). On ne l'envoie pas du tout.
    if (_mode.isTrips && !_isTraveler) {
      if (mounted) {
        setState(() => _otherModeCount = null);
      }
      return;
    }
    if (!_filters.otherModeCountIsMeaningful) {
      if (mounted) {
        setState(() => _otherModeCount = null);
      }
      return;
    }
    try {
      final int total;
      if (_mode.isTrips) {
        // Mode courant trajets : on compte les colis.
        final q = _filters.toPackageRequestQuery();
        final page = await getIt<PackageRequestRepository>().search(
          departure: q.departure,
          arrival: q.arrival,
          dateFrom: q.dateFrom,
          dateTo: q.dateTo,
          maxWeight: q.maxWeight,
          parcelSize: q.parcelSize,
          lat: q.userLat,
          lng: q.userLng,
          radiusKm: q.radiusKm,
          urgent: q.urgent,
          matchingMyTrips: q.matchingMyTrips,
          page: 0,
          size: 1,
        );
        total = page.totalElements;
      } else {
        // Mode courant colis : on compte les trajets.
        final q = _filters.toAnnouncementQuery();
        total = await getIt<AnnouncementRepository>().countAnnouncements(
          departureCity: q.departureCity,
          arrivalCity: q.arrivalCity,
          departureDateFrom: q.departureDateFrom,
          departureDateTo: q.departureDateTo,
          minAvailableKg: q.minAvailableKg,
          maxAvailableKg: q.maxAvailableKg,
          maxPricePerKg: q.maxPricePerKg,
          kiloProOnly: q.kiloProOnly,
          minRating: q.minRating,
          weekendOnly: q.weekendOnly,
          transportMode: q.transportMode,
          kycVerifiedOnly: q.kycVerifiedOnly,
          contentType: q.contentType,
          userLat: q.userLat,
          userLng: q.userLng,
          radiusKm: q.radiusKm,
          urgent: q.urgent,
        );
      }
      if (mounted) {
        setState(() => _otherModeCount = total);
      }
    } catch (_) {
      // Le compteur est une aide à la découverte, jamais un bloquant :
      // en cas d'échec on le masque au lieu de remonter une erreur.
      if (mounted) {
        setState(() => _otherModeCount = null);
      }
    }
  }

  /// Applique un changement de filtres : relance la recherche du mode courant
  /// et rafraîchit le compteur de l'autre mode.
  void _onFiltersChanged(HomeSearchFilters next) {
    setState(() => _filters = next);
    _dispatchForMode();
    unawaited(_dispatchOtherModeCount());
  }

  /// Nombre de trajets actifs, source unique du filtre « Pour mes trajets ».
  ///
  /// `null` = inconnu (résumé pas encore chargé, ou échec réseau), et ce n'est
  /// PAS zéro : sur un échec, prétendre « Aucun trajet actif » à un voyageur
  /// qui en a cinq serait un mensonge durable (le résumé n'est rechargé qu'à la
  /// création de l'écran). Inconnu laisse donc la pastille utilisable et confie
  /// l'arbitrage au serveur, qui connaît la vérité.
  int? get _activeTrips =>
      context.read<TripsSummaryCubit>().state.knownActiveTrips;

  void _onModeChanged(SearchMode mode) {
    if (mode == _mode) {
      return;
    }
    // Rôle voyageur retiré : le serveur refuserait la recherche de colis. On
    // explique au lieu de laisser partir une requête qui répondra 403.
    if (mode.isParcels && !_isTraveler) {
      unawaited(_showTravelerRoleDisabledSheet());
      return;
    }
    setState(() {
      _mode = mode;
      // Le compteur affiché portait sur l'ancien « autre mode » : il devient
      // faux à l'instant de la bascule, on l'efface avant de le recalculer.
      _otherModeCount = null;
      _selectedAnnouncementId = null;
    });
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeSearchModeChanged,
        properties: {'mode': mode.name},
      ),
    );
    _dispatchForMode();
    unawaited(_dispatchOtherModeCount());
  }

  /// L'état vide propose la bascule plutôt qu'un effacement de filtres quand
  /// l'autre mode, lui, a des résultats sur les mêmes critères.
  bool get _showCrossDiscovery => (_otherModeCount ?? 0) > 0;

  /// Suffixe corridor du libellé de découverte croisée.
  ///
  /// Le compteur peut être significatif sans corridor (date seule, ou « près de
  /// moi ») : dans ce cas le libellé se passe simplement de suffixe. Décision
  /// assumée, plutôt que d'afficher une flèche orpheline ou un « Tous les
  /// corridors » qui ne veut rien dire dans cette phrase.
  String get _crossDiscoveryCorridorSuffix {
    final dep = _filters.departureCity;
    final arr = _filters.arrivalCity;
    if (dep != null && arr != null) {
      return ' sur $dep → $arr';
    }
    if (dep != null) {
      return ' au départ de $dep';
    }
    if (arr != null) {
      return ' vers $arr';
    }
    return '';
  }

  /// Nomme le corridor courant : « 5 colis cherchent un voyageur sur Lyon →
  /// Bamako » en mode trajets, son symétrique « 12 voyageurs passent sur Lyon →
  /// Bamako » en mode colis. Jamais de tiret cadratin ici, c'est un texte
  /// affiché.
  String get _crossDiscoveryLabel {
    final n = _otherModeCount ?? 0;
    final corridor = _crossDiscoveryCorridorSuffix;
    return _mode.isTrips
        ? '$n colis ${n > 1 ? 'cherchent' : 'cherche'} un voyageur$corridor'
        : '$n voyageur${n > 1 ? 's' : ''} ${n > 1 ? 'passent' : 'passe'}$corridor';
  }

  /// Empile l'état vide et, quand l'autre mode a des résultats sur les mêmes
  /// critères, la tuile de bascule. Zéro résultat sur un corridor est le moment
  /// où l'autre mode a le plus de valeur.
  Widget _emptyWithCrossDiscovery(Widget emptyState) {
    if (!_showCrossDiscovery) {
      return emptyState;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        emptyState,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            0,
            DonySpacing.lg,
            DonySpacing.lg,
          ),
          child: _CrossDiscoveryTile(
            key: const Key('cross-discovery'),
            label: _crossDiscoveryLabel,
            onTap: _onCrossDiscoveryTap,
          ),
        ),
      ],
    );
  }

  /// Bascule proposée depuis l'état vide : l'autre mode a des résultats là où
  /// le mode courant n'en a aucun.
  void _onCrossDiscoveryTap() {
    final count = _otherModeCount ?? 0;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeCrossDiscoveryTapped,
        properties: {'from_mode': _mode.name, 'count': count},
      ),
    );
    _onModeChanged(_mode.other);
  }

  /// Explique le refus du mode Colis à un utilisateur qui a désactivé son rôle
  /// voyageur, et l'emmène là où il peut le réactiver. Bouton en position
  /// collée en bas, jamais dans le contenu défilant.
  Future<void> _showTravelerRoleDisabledSheet() {
    // Capturé avant l'ouverture : après le pop, le contexte de la feuille est
    // mort. `maybeOf` couvre les montages hors routeur (tests de rendu isolé).
    final router = GoRouter.maybeOf(context);
    return DonyBottomSheet.show<void>(
      context,
      title: 'Rôle voyageur désactivé',
      subtitle: 'Les demandes de colis sont réservées aux voyageurs. '
          'Réactive ton rôle voyageur pour les consulter.',
      stickyBottom: DonyButton(
        label: 'Ouvrir les réglages',
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          router?.push('/settings');
        },
      ),
      child: const SizedBox.shrink(),
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

  // Chip « 🔥 Urgent » : filtre serveur commun aux deux modes, appliqué à la
  // recherche du mode courant.
  void _onUrgentToggle() {
    final next = !_filters.urgentOnly;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.urgentFilterToggled,
        properties: {'active': next},
      ),
    );
    _onFiltersChanged(_filters.copyWith(urgentOnly: next));
  }

  void _deactivateNearMe() {
    setState(() {
      _nearMeShowList = false;
      _selectedAnnouncementId = null;
    });
    _onFiltersChanged(_filters.copyWith(clearNearMe: true));
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
    _onFiltersChanged(_filters.copyWith(nearMeRadiusKm: radiusKm));
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

    setState(() => _isLocatingNearMe = false);
    _onFiltersChanged(
      _filters.copyWith(
        nearMeActive: true,
        nearMeRadiusKm: _filters.nearMeRadiusKm ?? 25,
        userLat: pos.latitude,
        userLng: pos.longitude,
      ),
    );
  }

  Future<void> _showDatePresetSheet() async {
    final result =
        await showModalBottomSheet<
          ({DonyDatePreset preset, DateTime? customDate})
        >(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _DatePresetSheet(
            currentPreset: _filters.datePreset,
            customDate: _filters.customDate,
          ),
        );
    if (result != null && mounted) {
      _onFiltersChanged(
        result.customDate == null
            ? _filters.copyWith(
                datePreset: result.preset,
                clearCustomDate: true,
              )
            : _filters.copyWith(
                datePreset: result.preset,
                customDate: result.customDate,
              ),
      );
    }
  }

  Future<void> _showRatingSheet() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingFilterSheet(currentRating: _filters.minRating),
    );
    if (result == null || !mounted) return;
    _onFiltersChanged(
      result < 0
          ? _filters.copyWith(clearMinRating: true)
          : _filters.copyWith(minRating: result),
    );
  }

  Future<void> _showWeightSheet() async {
    final result = await showModalBottomSheet<({double min, double max})>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WeightRangeSheet(
        currentMin: _filters.weightMin,
        currentMax: _filters.weightMax,
      ),
    );
    if (result == null || !mounted) return;
    final cleared = _filters.copyWith(clearWeight: true);
    _onFiltersChanged(
      cleared.copyWith(
        weightMin: result.min <= 0 ? null : result.min,
        weightMax: result.max <= 0 ? null : result.max,
      ),
    );
  }

  Future<void> _showPriceSheet() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PriceFilterSheet(currentMaxPrice: _filters.maxPricePerKg),
    );
    if (result == null || !mounted) return;
    _onFiltersChanged(
      result < 0
          ? _filters.copyWith(clearMaxPricePerKg: true)
          : _filters.copyWith(maxPricePerKg: result),
    );
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

  /// Une seule feuille dans les deux modes : c'est elle qui porte le bloc
  /// corridor + date partagé.
  Future<void> _showFilterSheet(BuildContext ctx) async {
    final activeTrips = _activeTrips;
    final result = await SearchFilterSheet.show(
      ctx,
      mode: _mode,
      initial: _filters,
      activeTrips: activeTrips,
      onPublishTrip: _onPublishTripRequested,
    );
    if (result == null || !mounted) return;
    // La pastille « Pour mes trajets » vit dans la feuille : sa bascule ne se
    // constate qu'au retour, en comparant l'avant et l'après.
    if (result.matchingMyTrips != _filters.matchingMyTrips) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: {
            'active': result.matchingMyTrips,
            // Nombre inconnu : la propriété est absente plutôt que remplie
            // d'un zéro qui fausserait l'analyse.
            'active_trips': ?activeTrips,
          },
        ),
      );
    }
    _onFiltersChanged(result);
  }

  /// « Publier un trajet » depuis le garde-fou de la pastille « Pour mes
  /// trajets ». La feuille de filtres est déjà fermée quand on arrive ici :
  /// c'est l'écran, qui lui survit, qui attend le retour de la création puis
  /// recharge le résumé. Sans ce rechargement, l'utilisateur publierait son
  /// trajet et retrouverait la pastille grisée avec « Aucun trajet actif »,
  /// c'est-à-dire le scénario nominal du garde-fou pris en défaut.
  Future<void> _onPublishTripRequested() async {
    // `maybeOf` : hors routeur (tests de rendu isolé) il n'y a rien à ouvrir.
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final summary = context.read<TripsSummaryCubit>();
    await router.push<void>('/announcements/create');
    if (!mounted) {
      return;
    }
    await summary.load();
  }

  /// Applique une recherche préparée ailleurs (onglet Envoyer via
  /// [PendingSearchNotifier]), qui parle encore en [SearchParams]. Seule
  /// passerelle restante entre ce porteur historique et [HomeSearchFilters] :
  /// une recherche venue d'ailleurs porte sur des trajets, on force le mode.
  void _applySearchParams(SearchParams result) {
    if (!mounted) return;
    var next = _filters;
    final dep = result.departureCity;
    final arr = result.arrivalCity;
    if (dep != null && arr != null) {
      next = next.copyWith(departureCity: dep, arrivalCity: arr);
    }
    // Les deux villes nulles = l'utilisateur les a vidées : on garde le corridor.
    if (result.date != null) {
      next = next.copyWith(
        datePreset: DonyDatePreset.custom,
        customDate: result.date,
      );
    }
    next = next.copyWith(
      kiloProOnly: result.kiloProOnly,
      weekendOnly: result.weekendFilter,
      kycVerifiedOnly: result.kycVerifiedOnly,
    );
    next = result.ratingFilter
        ? next.copyWith(minRating: 4.5)
        : next.copyWith(clearMinRating: true);
    next = result.priceFilter
        ? next.copyWith(maxPricePerKg: result.maxPricePerKg)
        : next.copyWith(clearMaxPricePerKg: true);
    next = result.transportMode != null
        ? next.copyWith(transportMode: result.transportMode)
        : next.copyWith(clearTransportMode: true);
    next = result.contentType != null
        ? next.copyWith(contentType: result.contentType)
        : next.copyWith(clearContentType: true);
    next = result.urgencyFilter != null
        ? next.copyWith(urgencyFilter: result.urgencyFilter)
        : next.copyWith(clearUrgencyFilter: true);
    if (result.weightKg > 0) {
      next = next.copyWith(clearWeight: true).copyWith(
        weightMin: result.weightKg,
      );
    }

    setState(() {
      _mode = SearchMode.trips;
      _filters = next;
      _otherModeCount = null;
    });
    _dispatchSearch();
    unawaited(_dispatchOtherModeCount());
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
          final urgencyFilter = _filters.urgencyFilter;
          final announcements = urgencyFilter == null
              ? ownFiltered
              : ownFiltered
                    .where((a) => urgencyFilter.matches(a.departureDate))
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
                      announcements: _mode.isTrips ? announcements : const [],
                      extraMarkers: _mode.isParcels
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
                                    label: _corridorLabel,
                                    activeFilterCount: _activeFilterCount,
                                    onTap: () => _showFilterSheet(context),
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                const _NotificationBell(),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.xs),
                            _filterChipsRow(),
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
                          // Un seul carousel : celui du mode courant. La vue
                          // mixte à deux onglets a disparu avec le mode « Tout ».
                          child: _mode.isParcels
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
    double? selected = _filters.maxWeight;
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

  /// Efface les filtres communs et ceux du mode courant. Ceux de l'autre mode
  /// sont préservés : ils ne sont pas comptés par `activeCountFor(_mode)`, les
  /// effacer serait une surprise invisible. Même règle que « Tout effacer »
  /// dans la feuille de filtres.
  void _resetFilters() {
    final common = _filters.copyWith(
      clearCorridor: true,
      datePreset: DonyDatePreset.none,
      clearCustomDate: true,
      urgentOnly: false,
      clearNearMe: true,
    );
    _onFiltersChanged(
      _mode.isTrips
          ? common.copyWith(
              clearMaxPricePerKg: true,
              clearWeight: true,
              kiloProOnly: false,
              clearMinRating: true,
              weekendOnly: false,
              clearTransportMode: true,
              kycVerifiedOnly: false,
              clearContentType: true,
              clearUrgencyFilter: true,
            )
          : common.copyWith(
              clearMaxWeight: true,
              clearParcelSize: true,
              matchingMyTrips: false,
            ),
    );
  }

  /// Une seule rangée de chips, pilotée par le mode. Le sélecteur de mode en
  /// est le premier enfant : il défile avec elle plutôt que d'occuper une
  /// bande propre au-dessus de la carte.
  Widget _filterChipsRow() {
    return HomeFilterChipsRow(
      mode: _mode,
      filters: _filters,
      otherModeCount: _otherModeCount,
      onModeChanged: _onModeChanged,
      onUrgentToggle: _onUrgentToggle,
      onDateTap: _showDatePresetSheet,
      onDateClear: () => _onFiltersChanged(
        _filters.copyWith(
          datePreset: DonyDatePreset.none,
          clearCustomDate: true,
        ),
      ),
      onRatingTap: _showRatingSheet,
      onRatingClear: () =>
          _onFiltersChanged(_filters.copyWith(clearMinRating: true)),
      onCapacityTap: _showWeightSheet,
      onCapacityClear: () =>
          _onFiltersChanged(_filters.copyWith(clearWeight: true)),
      onPriceTap: _showPriceSheet,
      onPriceClear: () =>
          _onFiltersChanged(_filters.copyWith(clearMaxPricePerKg: true)),
      onKiloProToggle: () => _onFiltersChanged(
        _filters.copyWith(kiloProOnly: !_filters.kiloProOnly),
      ),
      onMaxWeightTap: () async {
        final result = await _showMaxWeightSheet(context);
        if (result == null || !mounted) return;
        _onFiltersChanged(_filters.copyWith(maxWeight: result));
      },
      onMaxWeightClear: () =>
          _onFiltersChanged(_filters.copyWith(clearMaxWeight: true)),
      onParcelSizeTap: () async {
        final result = await _showParcelSizeSheet(context);
        if (result == null || !mounted) return;
        _onFiltersChanged(
          result == _filters.parcelSize
              ? _filters.copyWith(clearParcelSize: true)
              : _filters.copyWith(parcelSize: result),
        );
      },
      onParcelSizeClear: () =>
          _onFiltersChanged(_filters.copyWith(clearParcelSize: true)),
    );
  }

  /// Sous-titre de l'en-tête quand la recherche colis est filtrée « sur mes
  /// trajets » : ce qu'on a trouvé, et sur combien de trajets on a cherché.
  /// [trips] à `null` = nombre de trajets actifs inconnu : on annonce les
  /// résultats sans inventer un « 0 trajet actif » que rien ne prouve.
  String _matchingSubtitle(PackageRequestSearchState prState, int? trips) {
    final n = _visibleRequests(prState.results).length;
    final resultats = '$n résultat${n > 1 ? 's' : ''}';
    if (trips == null) {
      return resultats;
    }
    return '$resultats · '
        '$trips trajet${trips > 1 ? 's' : ''} actif${trips > 1 ? 's' : ''}';
  }

  Widget _buildSheet(
    BuildContext ctx,
    ScrollController scrollCtrl,
    List<AnnouncementModel> announcements,
    double bottomPad, {
    String? currentUserId,
  }) {
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
                label: _corridorLabel,
                activeFilterCount: _activeFilterCount,
                onTap: () => _showFilterSheet(ctx),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: DonySpacing.lg,
                right: DonySpacing.lg,
                bottom: DonySpacing.sm,
              ),
              child: _filterChipsRow(),
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
                  // L'en-tête colis suit ce qui a RÉELLEMENT été demandé au
                  // serveur (l'état du bloc), pas les filtres en cours
                  // d'édition : sinon il annoncerait « sur tes trajets » avant
                  // que la recherche filtrée soit partie.
                  child: BlocBuilder<TripsSummaryCubit, TripsSummaryState>(
                    builder: (summaryCtx, summaryState) => BlocBuilder<
                      PackageRequestSearchBloc,
                      PackageRequestSearchState
                    >(
                      builder: (headerCtx, prState) {
                        final matching = prState.matchingMyTrips == true;
                        // Inconnu reste inconnu : voir `knownActiveTrips`.
                        final trips = summaryState.knownActiveTrips;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              !_mode.isParcels
                                  ? 'VOYAGEURS DISPONIBLES'
                                  : matching
                                  ? 'COLIS SUR TES TRAJETS'
                                  : 'DEMANDES D\'ENVOI',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !_mode.isParcels
                                  ? (_isNearMeActive
                                        ? '$count voyageur${count > 1 ? 's' : ''} à proximité'
                                        : '$count résultat${count > 1 ? 's' : ''} · $_corridorLabel')
                                  : matching
                                  ? _matchingSubtitle(prState, trips)
                                  : 'Demandes · $_corridorLabel',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                if (_mode.isTrips && count > 0)
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
                    // Le CTA suit le mode affiché (cohérence titre ↔ bouton) :
                    // mode Trajets → « Publier mon trajet » ; mode Colis
                    // (demandes d'envoi) et expéditeur → « Publier ma demande ».
                    role: (_isTraveler && _mode.isTrips)
                        ? ActiveRole.traveler
                        : ActiveRole.sender,
                    hiveService: getIt<HiveService>(),
                  ),
                ),
                if (_mode.isParcels)
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
                        final hasFilters = _activeFilterCount > 0;
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          // L'autre mode a des résultats sur les mêmes filtres :
                          // la bascule est proposée sous le message.
                          child: _emptyWithCrossDiscovery(
                            DonyEmptyState(
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
                              onAction: hasFilters ? _resetFilters : null,
                            ),
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
                    child: _emptyWithCrossDiscovery(
                      DonyEmptyState(
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
                            ? _resetFilters
                            : null,
                      ),
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

// ── _CrossDiscoveryTile ───────────────────────────────────────────────────────

/// Tuile de découverte croisée affichée sous l'état vide : elle nomme ce que
/// l'autre mode contient sur le corridor courant, et un tap y bascule en
/// conservant corridor et date.
///
/// Reprend le style des cartes de l'écran : bordure `cs.primary`, fond
/// `cs.primaryContainer`, chevron à droite.
class _CrossDiscoveryTile extends StatelessWidget {
  const _CrossDiscoveryTile({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(DonyRadius.card);

    return Material(
      color: cs.primaryContainer,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: cs.primary),
          ),
          child: Container(
            // Cible tactile confortable : jamais sous 44 pt (HIG).
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.primary,
                ),
              ],
            ),
          ),
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


// ── _DatePresetSheet ──────────────────────────────────────────────────────────

class _DatePresetSheet extends StatefulWidget {
  const _DatePresetSheet({
    required this.currentPreset,
    required this.customDate,
  });

  final DonyDatePreset currentPreset;
  final DateTime? customDate;

  @override
  State<_DatePresetSheet> createState() => _DatePresetSheetState();
}

class _DatePresetSheetState extends State<_DatePresetSheet> {
  late DonyDatePreset _selected;
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
        _selected = DonyDatePreset.custom;
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
            isSelected: _selected == DonyDatePreset.today,
            onTap: () => setState(() => _selected = DonyDatePreset.today),
          ),
          _PresetOption(
            label: 'Cette semaine',
            isSelected: _selected == DonyDatePreset.thisWeek,
            onTap: () => setState(() => _selected = DonyDatePreset.thisWeek),
          ),
          _PresetOption(
            label: 'Ce mois-ci',
            isSelected: _selected == DonyDatePreset.thisMonth,
            onTap: () => setState(() => _selected = DonyDatePreset.thisMonth),
          ),
          _PresetOption(
            label: _selected == DonyDatePreset.custom && _customDate != null
                ? DateFormat('EEE d MMM', 'fr').format(_customDate!)
                : 'Choisir une date',
            isSelected: _selected == DonyDatePreset.custom,
            onTap: _pickCustomDate,
          ),
          const SizedBox(height: DonySpacing.lg),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop((
                    preset: DonyDatePreset.none,
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
