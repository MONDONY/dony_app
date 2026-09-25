import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/evergreen_guidance_carousel.dart';
import 'package:dony/features/home/presentation/widgets/home_filter_chips_row.dart';
import 'package:dony/features/home/presentation/widgets/no_active_trip_sheet.dart';
import 'package:dony/features/home/presentation/widgets/search_mode_selector.dart';
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
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/widgets/near_me_package_request_carousel.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
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
    final isGuest = context.read<AuthBloc>().state.currentUser == null;
    return MultiBlocProvider(
      providers: [
        BlocProvider<PackageRequestSearchBloc>(
          create: (_) => getIt<PackageRequestSearchBloc>(),
        ),
        // Résumé d'activité : seul son `activeTrips` sert ici, il pilote le
        // filtre « Pour mes trajets » (pastille et en-tête de liste).
        BlocProvider<TripsSummaryCubit>(
          create: (_) {
            final cubit = getIt<TripsSummaryCubit>();
            if (!isGuest) {
              cubit.load();
            }
            return cubit;
          },
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

// ── Libellés reconstruits ────────────────────────────────────────────────────
//
// Fonctions de premier niveau : un test les appelle sans monter l'écran
// (`home_screen_messages_test.dart`).

/// Libellé de la barre corridor : le corridor posé, ou son absence.
@visibleForTesting
String homeCorridorLabel(AppLocalizations l, HomeSearchFilters filters) {
  final dep = filters.departureCity;
  final arr = filters.arrivalCity;
  if (dep != null && arr != null) {
    return '$dep → $arr';
  }
  if (dep != null) {
    return l.homeCorridorFrom(dep);
  }
  if (arr != null) {
    return l.homeCorridorTo(arr);
  }
  return l.homeCorridorAll;
}

/// « Tirer pour voir les 4 voyageurs » : la poignée nomme ce qu'il y a
/// dessous, dans les mots du sélecteur de mode, jamais « résultats ».
@visibleForTesting
String homePullUpLabel(
  AppLocalizations l, {
  required SearchMode mode,
  required int count,
}) {
  if (count == 0) {
    return l.homePullToList;
  }
  return mode.isTrips
      ? l.homePullToTravelers(count)
      : l.homePullToParcels(count);
}

/// Indication de drag dans le header du sheet selon l'état : peek → « tirer
/// pour voir les N voyageurs/colis », plein écran → « tirer pour voir la
/// carte ».
@visibleForTesting
String homePullHintLabel(
  AppLocalizations l, {
  required SearchMode mode,
  required int count,
  required bool down,
}) {
  return down ? l.homePullToMap : homePullUpLabel(l, mode: mode, count: count);
}

/// Nomme le corridor courant : « 5 colis cherchent un voyageur sur Lyon →
/// Bamako » en mode trajets, son symétrique « 12 voyageurs passent sur Lyon →
/// Bamako » en mode colis. Jamais de tiret cadratin ici, c'est un texte
/// affiché.
///
/// Le compteur peut être significatif sans corridor (date seule, ou « près de
/// moi ») : dans ce cas le libellé se passe simplement de suffixe. Décision
/// assumée, plutôt que d'afficher une flèche orpheline ou un « Tous les
/// corridors » qui ne veut rien dire dans cette phrase.
@visibleForTesting
String homeCrossDiscoveryLabel(
  AppLocalizations l, {
  required SearchMode mode,
  required HomeSearchFilters filters,
  required int count,
}) {
  final dep = filters.departureCity;
  final arr = filters.arrivalCity;
  if (mode.isTrips) {
    if (dep != null && arr != null) {
      return l.homeCrossParcelsRoute(count, dep, arr);
    }
    if (dep != null) {
      return l.homeCrossParcelsFrom(count, dep);
    }
    if (arr != null) {
      return l.homeCrossParcelsTo(count, arr);
    }
    return l.homeCrossParcels(count);
  }
  if (dep != null && arr != null) {
    return l.homeCrossTravelersRoute(count, dep, arr);
  }
  if (dep != null) {
    return l.homeCrossTravelersFrom(count, dep);
  }
  if (arr != null) {
    return l.homeCrossTravelersTo(count, arr);
  }
  return l.homeCrossTravelers(count);
}

/// Libellé de la tuile d'alerte proposée sous un état vide, corridor complet.
@visibleForTesting
String homeAlertForSearchLabel(
  AppLocalizations l, {
  required SearchMode mode,
  required String departureCity,
  required String arrivalCity,
}) {
  return mode.isTrips
      ? l.homeAlertTrip(departureCity, arrivalCity)
      : l.homeAlertParcel(departureCity, arrivalCity);
}

/// Titre de la liste : le nombre, ce que la liste contient et le corridor.
/// Il répète l'intention du sélecteur de mode (« voyageurs » / « colis à
/// transporter ») pour que le contenu de la liste ne soit jamais à deviner.
///
/// Le corridor s'écrit « pour Abidjan → Paris » quand les deux villes sont
/// posées, sinon c'est le libellé de corridor tel quel (« Départ de Lyon »,
/// « Tous les corridors ») derrière un point médian.
///
/// Le mot « compatibles » est essentiel : le filtre « Pour mes trajets »
/// liste les demandes encore libres qu'on POURRAIT prendre, pas les colis
/// déjà embarqués sur ses trajets, qui se consultent depuis le détail du
/// trajet. Un titre du genre « colis sur tes trajets » se lit à l'envers.
@visibleForTesting
String homeListTitle(
  AppLocalizations l, {
  required SearchMode mode,
  required HomeSearchFilters filters,
  required int trips,
  required int parcels,
  required bool matching,
}) {
  final dep = filters.departureCity;
  final arr = filters.arrivalCity;
  final hasRoute = dep != null && arr != null;
  if (mode.isTrips) {
    if (filters.nearMeActive) {
      return l.homeListTravelersNearby(trips);
    }
    return hasRoute
        ? l.homeListTravelersRoute(trips, dep, arr)
        : l.homeListTravelersCorridor(trips, homeCorridorLabel(l, filters));
  }
  if (matching) {
    return l.homeListParcelsMatching(parcels);
  }
  return hasRoute
      ? l.homeListParcelsRoute(parcels, dep, arr)
      : l.homeListParcelsCorridor(parcels, homeCorridorLabel(l, filters));
}

/// Sous-titre de la liste : ce que l'utilisateur peut en faire, ou pourquoi
/// elle est vide. En mode « Pour mes trajets », l'accord porte sur le
/// nombre de trajets actifs, connu ou non (voir `knownActiveTrips`) :
/// [activeTrips] à `null` annonce les résultats sans inventer un « 0 trajet
/// actif » que rien ne prouve.
@visibleForTesting
String homeListSubtitle(
  AppLocalizations l, {
  required SearchMode mode,
  required int trips,
  required int parcels,
  required bool matching,
  required int? activeTrips,
}) {
  if (mode.isTrips) {
    return trips == 0
        ? l.homeListSubtitleNoTraveler
        : l.homeListSubtitleTravelersCanCarry;
  }
  if (matching) {
    if (activeTrips == null) {
      return l.homeListSubtitleActiveTripsUnknown;
    }
    return l.homeListSubtitleActiveTrips(activeTrips);
  }
  return parcels == 0
      ? l.homeListSubtitleNoRequest
      : l.homeListSubtitleYouCanCarry;
}

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

  StreamSubscription<BlockChange>? _blockSub;

  bool _nearMeShowList = false;
  // True between the FAB tap and the position being acquired (FAB spinner).
  bool _isLocatingNearMe = false;

  String? _selectedAnnouncementId;

  /// Mode de recherche courant. Deux valeurs exclusives : il n'existe plus de
  /// vue mixte. Le mode pilote la liste, les marqueurs de carte, les chips
  /// spécifiques et la feuille de filtres.
  late SearchMode _mode;

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

  String get _corridorLabel => homeCorridorLabel(context.l10n, _filters);

  @override
  void initState() {
    super.initState();
    // Mode par défaut identique pour tout le monde : la recherche de trajets
    // fonctionne désormais pour un visiteur (Task 7), il n'y a plus de raison
    // de le distinguer d'un inscrit à l'ouverture de l'écran.
    _mode = SearchMode.trips;
    if (getIt.isRegistered<PendingSearchNotifier>()) {
      _pendingSearchNotifier = getIt<PendingSearchNotifier>();
      _pendingSearchNotifier!.addListener(_consumePendingSearch);
    }
    _sheetController.addListener(_onSheetSizeChanged);
    // Blocage ou déblocage : le serveur ne renvoie plus (ou renvoie de nouveau)
    // les trajets et demandes de cette personne. On relance la recherche du mode
    // affiché plutôt que de laisser une liste que le serveur désavoue.
    //
    // Abonnement côté widget : les filtres courants vivent ici (`_filters`), le
    // BLoC de recherche ne les mémorise pas et ne saurait pas quoi rejouer.
    _blockSub = _blockEvents()?.changes.listen((_) {
      if (!mounted) return;
      _dispatchForMode();
    });
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
      final isGuest = context.read<AuthBloc>().state.currentUser == null;
      if (!isGuest) {
        context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
      }
      // Réaligne la carte d'onboarding « première publication » sur l'état réel
      // du serveur : si l'utilisateur a déjà un trajet ou une demande, la carte
      // ne doit plus s'afficher (le flag Hive local pouvait être absent —
      // trajet créé sur un autre appareil, avant ce mécanisme, ou après
      // réinstallation).
      if (!isGuest) {
        unawaited(_syncGuidanceFlags());
      }
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

  /// Variante de [_pullHint] qui compte les résultats du mode courant.
  ///
  /// Le compteur des trajets vient de la liste déjà construite, celui des colis
  /// de l'état du bloc de recherche des demandes : sans ce branchement, le mode
  /// Colis afficherait le nombre de trajets, ce qui a été constaté à l'écran.
  Widget _pullHintForMode(
    ColorScheme cs, {
    required bool down,
    required int tripCount,
  }) {
    if (!_mode.isParcels) {
      return _pullHint(cs, down: down, count: tripCount);
    }
    return BlocBuilder<PackageRequestSearchBloc, PackageRequestSearchState>(
      // `_visibleRequests` et non `results` : le feed masque les demandes de
      // l'utilisateur courant, donc compter la liste brute annonçait un
      // résultat de plus que ce que l'écran affiche. Le compteur du mode
      // Trajets ne souffrait pas du problème, sa liste étant déjà filtrée en
      // amont.
      builder: (ctx, prState) => _pullHint(
        cs,
        down: down,
        count: _visibleRequests(prState.results).length,
      ),
    );
  }

  /// Indication de drag dans le header du sheet selon l'état : peek → « tirer
  /// pour voir les N voyageurs/colis », plein écran → « tirer pour voir la
  /// carte ».
  Widget _pullHint(ColorScheme cs, {required bool down, required int count}) {
    final text = homePullHintLabel(
      context.l10n,
      mode: _mode,
      count: count,
      down: down,
    );
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
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
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

  BlockEventsService? _blockEvents() {
    try {
      return getIt.isRegistered<BlockEventsService>()
          ? getIt<BlockEventsService>()
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _blockSub?.cancel();
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
    if (context.read<AuthBloc>().state.currentUser == null) {
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
  ///
  /// Ne trace PAS `search_submitted` : ce n'est pas ici qu'une recherche est
  /// réellement « soumise », c'est le seul point de sortie de TOUT réglage de
  /// filtre (chips, sheets de date/prix/poids/note, bascule « Pour mes
  /// trajets », retour de l'écran de composition…). Le tracking vit dans
  /// [_openComposer], seul endroit où l'utilisateur valide vraiment une
  /// recherche via le bouton « Rechercher ».
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

  String get _crossDiscoveryLabel => homeCrossDiscoveryLabel(
    context.l10n,
    mode: _mode,
    filters: _filters,
    count: _otherModeCount ?? 0,
  );

  /// Empile l'état vide et, quand l'autre mode a des résultats sur les mêmes
  /// critères, la tuile de bascule. Zéro résultat sur un corridor est le moment
  /// où l'autre mode a le plus de valeur.
  Widget _emptyWithCrossDiscovery(Widget emptyState) {
    final showAlert = _showAlertForSearch;
    if (!_showCrossDiscovery && !showAlert) {
      return emptyState;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        emptyState,
        if (_showCrossDiscovery)
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
        // Zéro résultat sur un corridor précis : le meilleur moment pour
        // proposer d'être prévenu quand quelque chose y apparaîtra.
        if (showAlert)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              0,
              DonySpacing.lg,
              DonySpacing.lg,
            ),
            child: _CrossDiscoveryTile(
              key: const Key('alert-for-search'),
              label: homeAlertForSearchLabel(
                context.l10n,
                mode: _mode,
                departureCity: _filters.departureCity!,
                arrivalCity: _filters.arrivalCity!,
              ),
              onTap: _onAlertForSearchTap,
            ),
          ),
      ],
    );
  }

  /// Une alerte exige un corridor complet et un compte connecté : un invité
  /// n'a pas d'alertes, et le formulaire ne sait pas partir d'une seule ville.
  bool get _showAlertForSearch {
    if (_filters.departureCity == null || _filters.arrivalCity == null) {
      return false;
    }
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated || s is AuthProfileUpdated;
  }

  /// Ouvre le formulaire d'alerte prérempli avec le corridor et la fenêtre
  /// de dates de la recherche, dans la direction du mode courant.
  Future<void> _onAlertForSearchTap() async {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeAlertForSearchTapped,
        properties: {'mode': _mode.name},
      ),
    );
    final direction = _mode.isTrips
        ? AlertDirection.senderWantsTrips
        : AlertDirection.travelerWantsPackages;
    final s = context.read<AuthBloc>().state;
    final user = switch (s) {
      final AuthAuthenticated a => a.user,
      final AuthProfileUpdated a => a.user,
      _ => null,
    };
    await CorridorAlertFormSheet.show(
      context,
      prefill: CorridorAlertDraft(
        departureCity: _filters.departureCity!,
        arrivalCity: _filters.arrivalCity!,
        dateFrom: _filters.dateFrom,
        dateTo: _filters.dateTo,
        direction: direction,
      ),
      isTraveler: user?.isTraveler ?? false,
      isSender: user?.isSender ?? false,
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

  /// Capacité réelle de l'utilisateur (pas le rôle actif sélectionné). Tout
  /// compte porte les deux rôles dès l'inscription et ne peut jamais les
  /// perdre.
  ///
  /// Sert aussi, de facto, de garde anti-invité pour un usage précis :
  /// `showFavorite` sur `PackageRequestListCard` plus bas, qui ferme la mise
  /// en favori d'une demande de colis à qui n'a ni `AuthAuthenticated` ni
  /// `AuthProfileUpdated` — donc toujours `false` pour un visiteur. C'est
  /// assumé : contrairement à `canUseSearchMode` (tautologie supprimée en
  /// Task 7), ce gate a été posé à la revue produit et tranché « on garde
  /// fermé ». Ne pas le retirer au prétexte qu'il ressemble à un garde-fou
  /// invité oublié.
  bool get _isTraveler {
    final s = context.read<AuthBloc>().state;
    return switch (s) {
      final AuthAuthenticated a => a.user.isTraveler,
      final AuthProfileUpdated a => a.user.isTraveler,
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
      confirmLabel: context.l10n.commonApply,
    );
    if (radiusKm == null || !mounted) return;
    _onFiltersChanged(_filters.copyWith(nearMeRadiusKm: radiusKm));
  }

  Future<void> _activateNearMe() async {
    const locationService = GeolocatorLocationService();
    final access = await requestLocationAccess(locationService);
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      await LocationDeniedSheet.show(context, access: access);
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
        DonySnackbar.show(context, message: context.l10n.homeLocateError);
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

  /// Ouvre l'écran de composition et applique ce qui en revient.
  ///
  /// L'écran remplace la feuille de filtres : la hauteur d'une feuille ne
  /// permettait pas de faire tenir la barre de recherche, le micro et les
  /// dix-huit filtres. Conserve intégralement le bloc analytics de la
  /// pastille « Pour mes trajets », qui compare l'avant et l'après : sa
  /// bascule ne se constate qu'au retour.
  Future<void> _openComposer(BuildContext ctx) async {
    final activeTrips = _activeTrips;
    final result = await ctx
        .push<({HomeSearchFilters filters, bool cameFromPhrase})>(
          '/recherche/composer',
          extra: {
            'mode': _mode,
            'filters': _filters,
            'activeTrips': activeTrips,
            'onPublishTrip': _onPublishTripRequested,
          },
        );
    if (result == null || !mounted) return;

    if (result.filters.matchingMyTrips != _filters.matchingMyTrips) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.homeMatchingTripsFilterToggled,
          properties: {
            'active': result.filters.matchingMyTrips,
            // Nombre inconnu : la propriété est absente plutôt que remplie
            // d'un zéro qui fausserait l'analyse.
            'active_trips': ?activeTrips,
          },
        ),
      );
    }
    _onFiltersChanged(result.filters);
    // Seul point de sortie de `search_submitted` : c'est ici, et nulle part
    // ailleurs (voir `_onFiltersChanged`), qu'une recherche est réellement
    // « soumise ». `came_from_phrase` mesure la part des recherches qui
    // passent par la phrase plutôt que par les filtres au doigt — si elle
    // dépasse 90 % des cas après un mois, le bloc « En une phrase » se
    // retire sans rien casser.
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.searchSubmitted,
        properties: {
          'mode': _mode.name,
          'filter_count': result.filters.activeCount,
          'came_from_phrase': result.cameFromPhrase,
        },
      ),
    );
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
    await router.push<void>('/trips/create');
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
      next = next
          .copyWith(clearWeight: true)
          .copyWith(weightMin: result.weightKg);
    }

    setState(() {
      _mode = SearchMode.trips;
      _filters = next;
      _otherModeCount = null;
    });
    _dispatchForMode();
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
      // grossPriceEur (PR #219) est le brut réellement payé ; targetPriceEur
      // seul est un NET. Les marqueurs de trajets affichent déjà le brut
      // (senderPricePerKg) : sans ce repli, un invité voyait deux bases de
      // prix différentes selon qu'il regardait un trajet ou une demande.
      final price = item.grossPriceEur ?? item.targetPriceEur ?? 0;
      final icon = await MarkerBitmapFactory.pricePill(
        pricePerKg: price,
        gridLabel: context.l10n.listingPriceGridShort,
        dotColor: DonyColors.terra500,
        brightness: Theme.of(context).brightness,
        prefix: '📦',
        currencyCode: item.currency,
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
    final isKycVerified = authState.currentUser?.isKycVerified ?? false;
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
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                          ),
                          child: SingleChildScrollView(
                            primary: false,
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
                                        onTap: () => _openComposer(context),
                                      ),
                                    ),
                                    const SizedBox(width: DonySpacing.sm),
                                    const _NotificationBell(),
                                  ],
                                ),
                                const SizedBox(height: DonySpacing.sm),
                                _modeSelector(),
                                const SizedBox(height: DonySpacing.sm),
                                _filterChipsRow(),
                              ],
                            ),
                          ),
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
                    Builder(
                      builder: (sheetCtx) {
                        // La fraction de peek (0.30) est calibrée pour le
                        // contenu à 100 % : poignée + indication + en-tête. À
                        // 200 %, ce même contenu ne tient plus dans 30 % de la
                        // hauteur (RenderFlex overflow constaté). On agrandit
                        // le peek proportionnellement au facteur d'échelle du
                        // texte, sans rien changer à 100 % (facteur = 1).
                        final textScale =
                            MediaQuery.textScalerOf(sheetCtx).scale(14) / 14;
                        // À 200 %, la poignée, l'indication et l'en-tête
                        // dépassent encore 55 % sur les petits écrans. Une
                        // peek plus haute garde le contenu utilisable sans
                        // modifier la taille normale à 100 %.
                        final peekSize = (0.30 * textScale).clamp(0.30, 0.70);
                        final middleSnap = peekSize >= 0.6 ? 0.8 : 0.6;
                        return DraggableScrollableSheet(
                          controller: _sheetController,
                          initialChildSize: peekSize,
                          minChildSize: peekSize,
                          snap: true,
                          snapSizes: [peekSize, middleSnap, 1.0],
                          builder: (ctx, scrollCtrl) => _buildSheet(
                            ctx,
                            scrollCtrl,
                            announcements,
                            MediaQuery.of(context).padding.bottom,
                            currentUserId: currentUserId,
                            isKycVerified: isKycVerified,
                            tripsFailed: state is AnnouncementError,
                            tripsLoading: state is AnnouncementLoading,
                          ),
                        );
                      },
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
                  ctx2.l10n.homeMaxWeightTitle,
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
                    child: Text(ctx2.l10n.commonApply),
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
                sheetCtx.l10n.homeParcelSizeTitle,
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
  /// Sélecteur d'intention, sur sa propre ligne sous la barre de recherche,
  /// à l'écart des chips de filtre. Clé STABLE : elle ne doit pas encoder la
  /// présence du compteur, sinon l'arrivée du nombre démonte le sélecteur et
  /// emporte l'animation de 200 ms du segment actif. La clé du compteur vit
  /// dans `SearchModeSelector`, sur le compteur lui-même.
  Widget _modeSelector() {
    return SearchModeSelector(
      key: const Key('search-mode-selector'),
      mode: _mode,
      onChanged: _onModeChanged,
      otherModeCount: _otherModeCount,
    );
  }

  Widget _filterChipsRow() {
    return HomeFilterChipsRow(
      mode: _mode,
      filters: _filters,
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
      activeTrips: _activeTrips,
      onMatchingMyTripsToggle: () =>
          _onMatchingMyTripsChanged(!_filters.matchingMyTrips, _activeTrips),
      // Une seule feuille ouverte ici, contrairement au même garde-fou déclenché
      // depuis la feuille de filtres, qui en a deux empilées.
      onMatchingMyTripsBlocked: () => unawaited(
        showNoActiveTripSheet(
          context,
          sheetsToPop: 1,
          onPublishTrip: _onPublishTripRequested,
        ),
      ),
    );
  }

  /// Bascule du filtre « Pour mes trajets » depuis la rangée de chips.
  ///
  /// La feuille de filtres a son propre chemin : elle renvoie un état complet
  /// dont la bascule se constate au retour. Ici l'action est immédiate, donc
  /// l'événement analytique est tiré sur place, avec les mêmes propriétés.
  void _onMatchingMyTripsChanged(bool active, int? trips) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeMatchingTripsFilterToggled,
        properties: {
          'active': active,
          // Nombre inconnu : propriété absente plutôt que remplie d'un zéro
          // que rien ne prouve.
          'active_trips': ?trips,
        },
      ),
    );
    _onFiltersChanged(_filters.copyWith(matchingMyTrips: active));
  }

  /// Les états vides remplissent le reste de la feuille et se centrent. Comme
  /// les listes, ils s'arrêtent au-dessus de la pastille « Carte » (feuille
  /// plein écran) et de la barre flottante : sans cette marge, le bouton
  /// « Effacer les filtres » passait sous la pastille sur un téléphone.
  Widget _aboveFloatingControls(double bottomPad, Widget sliver) =>
      SliverPadding(
        padding: EdgeInsets.only(bottom: bottomPad + _kFloatingNavClearance),
        sliver: sliver,
      );

  Widget _buildSheet(
    BuildContext ctx,
    ScrollController scrollCtrl,
    List<AnnouncementModel> announcements,
    double bottomPad, {
    String? currentUserId,
    required bool isKycVerified,
    required bool tripsFailed,
    required bool tripsLoading,
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
            _pullHintForMode(cs, down: true, tripCount: count),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                0,
                DonySpacing.lg,
                DonySpacing.sm,
              ),
              // Le scarabée de signalement vit dans la feuille, jamais sur la
              // carte où il se perd dans le fond : à côté de la barre de
              // recherche quand la feuille est dépliée, à côté de « Trier »
              // quand elle est repliée (voir plus bas).
              child: Row(
                children: [
                  Expanded(
                    child: _CorridorBar(
                      key: const Key('corridor-bar-sheet'),
                      label: _corridorLabel,
                      activeFilterCount: _activeFilterCount,
                      onTap: () => _openComposer(ctx),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  const DonyFeedbackButton(key: Key('feedback-sheet-expanded')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: DonySpacing.lg,
                right: DonySpacing.lg,
                bottom: DonySpacing.sm,
              ),
              child: _modeSelector(),
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
                    builder: (summaryCtx, summaryState) =>
                        BlocBuilder<
                          PackageRequestSearchBloc,
                          PackageRequestSearchState
                        >(
                          builder: (headerCtx, prState) {
                            final matching = prState.matchingMyTrips == true;
                            // Inconnu reste inconnu : voir `knownActiveTrips`.
                            final trips = summaryState.knownActiveTrips;
                            final parcels = _visibleRequests(
                              prState.results,
                            ).length;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  key: const Key('results-header-title'),
                                  homeListTitle(
                                    context.l10n,
                                    mode: _mode,
                                    filters: _filters,
                                    trips: count,
                                    parcels: parcels,
                                    matching: matching,
                                  ),
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  key: const Key('results-header-subtitle'),
                                  homeListSubtitle(
                                    context.l10n,
                                    mode: _mode,
                                    trips: count,
                                    parcels: parcels,
                                    matching: matching,
                                    activeTrips: trips,
                                  ),
                                  // Une ligne : la feuille repliée a une
                                  // hauteur fixe, un sous-titre qui passerait
                                  // sur deux lignes à 200 % de taille de texte
                                  // ferait déborder sa colonne.
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
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
                    onTap: () => _openComposer(ctx),
                    child: Text(
                      ctx.l10n.homeSort,
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!_isMapHidden) ...[
                  const SizedBox(width: DonySpacing.xs),
                  const SizedBox.square(
                    dimension: kDonyMinTapTarget,
                    child: DonyFeedbackButton(
                      key: Key('feedback-sheet-collapsed'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!_isMapHidden)
            _pullHintForMode(cs, down: false, tripCount: count),
          Divider(height: 1, color: cs.outline),
          Expanded(
            child: CustomScrollView(
              controller: scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: EvergreenGuidanceCarousel(
                    hiveService: getIt<HiveService>(),
                    isKycVerified: isKycVerified,
                  ),
                ),
                if (_mode.isParcels)
                  BlocBuilder<
                    PackageRequestSearchBloc,
                    PackageRequestSearchState
                  >(
                    builder: (ctx, prState) {
                      if (prState.status == SearchStatus.loading) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            DonySpacing.base,
                            DonySpacing.sm,
                            DonySpacing.base,
                            DonySpacing.huge,
                          ),
                          sliver: SliverList.separated(
                            itemCount: 4,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: DonySpacing.md),
                            itemBuilder: (_, _) =>
                                const DonyTicketCardSkeleton(),
                          ),
                        );
                      }
                      // Backend injoignable : surtout ne pas afficher « aucun
                      // résultat », qui laisserait croire que le corridor est
                      // vide. On propose un réessai explicite.
                      if (prState.status == SearchStatus.error) {
                        return _aboveFloatingControls(
                          bottomPad,
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: DonyEmptyState(
                              type: DonyEmptyStateType.error,
                              title: ctx.l10n.homeConnectionErrorTitle,
                              description: ctx.l10n.homeRequestsLoadError,
                              mascotte: DonyMascotteType.erreurLegere,
                              actionLabel: ctx.l10n.commonRetry,
                              onAction: () => ctx
                                  .read<PackageRequestSearchBloc>()
                                  .add(const SearchRefresh()),
                            ),
                          ),
                        );
                      }
                      final visibleResults = _visibleRequests(prState.results);
                      if (visibleResults.isEmpty) {
                        final hasFilters = _activeFilterCount > 0;
                        return _aboveFloatingControls(
                          bottomPad,
                          SliverFillRemaining(
                            hasScrollBody: false,
                            // L'autre mode a des résultats sur les mêmes filtres :
                            // la bascule est proposée sous le message.
                            child: _emptyWithCrossDiscovery(
                              DonyEmptyState(
                                title: hasFilters
                                    ? ctx.l10n.homeEmptyParcelsFiltered
                                    : ctx.l10n.homeEmptyParcelsSoon,
                                description: hasFilters
                                    ? ctx.l10n.homeEmptyParcelsFilteredHint
                                    : ctx.l10n.homeEmptyParcelsSoonHint,
                                mascotte: DonyMascotteType.aucunResultat,
                                actionLabel: hasFilters
                                    ? ctx.l10n.commonClearFilters
                                    : null,
                                onAction: hasFilters ? _resetFilters : null,
                              ),
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
                              separatorBuilder: (_, _) =>
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
                else if (tripsLoading && count == 0)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.base,
                      DonySpacing.sm,
                      DonySpacing.base,
                      DonySpacing.huge,
                    ),
                    sliver: SliverList.separated(
                      itemCount: 4,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: DonySpacing.md),
                      itemBuilder: (_, _) => const DonyTripCardSkeleton(),
                    ),
                  )
                // Backend injoignable : « aucun voyageur » serait un mensonge.
                else if (tripsFailed && count == 0)
                  _aboveFloatingControls(
                    bottomPad,
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: DonyEmptyState(
                        type: DonyEmptyStateType.error,
                        title: ctx.l10n.homeConnectionErrorTitle,
                        description: ctx.l10n.homeTripsLoadError,
                        mascotte: DonyMascotteType.erreurLegere,
                        actionLabel: ctx.l10n.commonRetry,
                        onAction: _dispatchSearch,
                      ),
                    ),
                  )
                else if (count == 0)
                  _aboveFloatingControls(
                    bottomPad,
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyWithCrossDiscovery(
                        DonyEmptyState(
                          title: _isNearMeActive
                              ? ctx.l10n.homeEmptyTravelersNearby
                              : _activeFilterCount > 0
                              ? ctx.l10n.homeEmptyTravelersFiltered
                              : ctx.l10n.homeEmptyTravelersRoute,
                          description: _isNearMeActive
                              ? ctx.l10n.homeEmptyNearbyHint
                              : _activeFilterCount > 0
                              ? ctx.l10n.homeEmptyTravelersFilteredHint
                              : ctx.l10n.homeEmptyTravelersRouteHint,
                          mascotte: DonyMascotteType.aucunResultat,
                          actionLabel:
                              !_isNearMeActive && _activeFilterCount > 0
                              ? ctx.l10n.commonClearFilters
                              : null,
                          onAction: !_isNearMeActive && _activeFilterCount > 0
                              ? _resetFilters
                              : null,
                        ),
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
                maxLines: 1,
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
                Icon(Icons.chevron_right_rounded, size: 20, color: cs.primary),
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
              context.l10n.homeMapButton,
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
                context.l10n.homeRadiusKm(radiusKm.round()),
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
      locale: Localizations.localeOf(context),
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
            context.l10n.homeDepartureDateTitle,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.md),
          _PresetOption(
            label: context.l10n.commonDateToday,
            isSelected: _selected == DonyDatePreset.today,
            onTap: () => setState(() => _selected = DonyDatePreset.today),
          ),
          _PresetOption(
            label: context.l10n.commonDateThisWeek,
            isSelected: _selected == DonyDatePreset.thisWeek,
            onTap: () => setState(() => _selected = DonyDatePreset.thisWeek),
          ),
          _PresetOption(
            label: context.l10n.commonDateThisMonthLong,
            isSelected: _selected == DonyDatePreset.thisMonth,
            onTap: () => setState(() => _selected = DonyDatePreset.thisMonth),
          ),
          _PresetOption(
            label: _selected == DonyDatePreset.custom && _customDate != null
                ? DateFormat.MMMEd(context.l10n.localeName).format(_customDate!)
                : context.l10n.homeChooseDate,
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
                        context.l10n.commonClear,
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
                  label: context.l10n.commonApply,
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
            context.l10n.homeMinRatingTitle,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.md),
          for (final r in ratings)
            _PresetOption(
              label: r == 5.0
                  ? context.l10n.homeRatingOnlyFive
                  : context.l10n.homeRatingAndUp(r.toStringAsFixed(1)),
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
                        context.l10n.commonClear,
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
                  label: context.l10n.commonApply,
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
            context.l10n.homeWeightCapacityTitle,
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
                        context.l10n.commonClear,
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
                  label: context.l10n.commonApply,
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
            context.l10n.homeMaxPriceTitle,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.xl),
          Center(
            child: Text(
              isAtMax
                  ? context.l10n.homeAnyPrice
                  : '≤ ${formatPriceActive(_maxPrice)}/kg',
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
                  '${formatPriceActive(3)}/kg',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  '${formatPriceActive(25)}/kg',
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
                        context.l10n.commonClear,
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
                  label: context.l10n.commonApply,
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
/// Icône signet, remplie [DonyColors.primary] si des favoris existent.
/// Pastille de comptage rouge conservée (convention de badge).
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
          // Les favoris sont accessibles à un visiteur : c'est le seul
          // contenu qu'une session invitée peut conserver (backend et
          // routeur les autorisent déjà — `GuestAccessGuard.isPublicGuestPath`).
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
                  count > 0 ? Icons.bookmark : Icons.bookmark_border,
                  size: 22,
                  color: count > 0 ? DonyColors.primary : cs.onSurfaceVariant,
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
          onTap: () {
            if (context.read<AuthBloc>().state.currentUser == null) {
              AuthRequiredSheet.show(context);
              return;
            }
            showNotificationBottomSheet(context);
          },
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
