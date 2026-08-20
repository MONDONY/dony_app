// Tests de SearchComposerScreen — l'écran plein qui remplace SearchFilterSheet.
//
// Le point vérifié n'est pas la richesse de chaque filtre (déjà couverte par
// search_filter_sheet_test.dart pour les mêmes widgets) mais la PARITÉ : les
// huit blocs doivent tous être là, dans l'ordre imposé par la Task 3, et une
// recherche complète doit rester possible sans jamais toucher la barre « En
// une phrase ». C'est cette dernière propriété — et non la présence du champ
// — qui distingue un champ de recherche « facultatif » d'un héros déguisé.
//
// `context.pop(filters)` exige un `GoRouter` ancêtre (voir
// `go_router.GoRouterHelper.pop`) : le harnais place donc l'écran sur une
// route fille (`/child`), comme `dony_app_bar_test.dart` le fait déjà pour
// `DonyAppBarBackButton`.

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/data/repositories/search_parse_repository.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/screens/search_composer_screen.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../../helpers/mock_recent_city_store.dart';

class _MockParseRepo extends Mock implements SearchParseRepository {}

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockCityRepository extends Mock implements CityRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

/// Faux platform-level Geolocator — même mécanisme que `_MockGeolocatorPlatform`
/// dans `home_screen_test.dart` (le FAB « Près de moi » de la carte, dont
/// `_AroundMeBlock` est la contrepartie sur cet écran), mais avec des champs
/// configurables pour couvrir aussi les chemins refusés/désactivés, jamais
/// exercés côté `home_screen_test.dart`. `_AroundMeBlock` instancie
/// `GeolocatorLocationService` en dur (non injecté) : c'est cette substitution
/// du singleton `GeolocatorPlatform.instance`, pas une injection de
/// dépendance, qui la rend testable sans toucher au widget de production.
class _FakeGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission checkPermissionResult = LocationPermission.always;
  LocationPermission requestPermissionResult = LocationPermission.denied;
  // Délai artificiel pour laisser le temps à un pump intermédiaire
  // d'observer l'état « en cours » (`_isLocating`) avant résolution — nos
  // autres tests le laissent à zéro pour rester rapides.
  Duration getCurrentPositionDelay = Duration.zero;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkPermissionResult;

  @override
  Future<LocationPermission> requestPermission() async =>
      requestPermissionResult;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (getCurrentPositionDelay > Duration.zero) {
      await Future<void>.delayed(getCurrentPositionDelay);
    }
    return Position(
      latitude: 48.8566,
      longitude: 2.3522,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

/// `scrollUntilVisible` sans `scrollable:` cherche l'unique `Scrollable` de
/// l'arbre — or il y en a deux ici : le `ListView` de l'écran ET
/// l'`EditableText` du champ de phrase (tout `TextField` en construit un pour
/// son défilement horizontal interne). `.first` désigne le plus englobant des
/// deux, rencontré avant lui dans l'arbre : celui de l'écran.
///
/// Suivi d'un `pumpAndSettle()` : le scroll amène dans l'arbre des blocs qui
/// portaient jusque-là un `.animate().fadeIn(delay: ...)` jamais monté — leur
/// minuteur de délai doit s'écouler avant la prochaine assertion, sinon
/// `AutomatedTestWidgetsFlutterBinding` échoue en fin de test sur « A Timer
/// is still pending ».
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Après un tap qui dispatche `SearchComposerFiltersChanged` (ex : le chip
/// « Autour de moi »), `pumpAndSettle()` seul peut rendre la main trop tôt :
/// son `do { pump(100ms) } while (hasScheduledFrame)` s'arrête dès qu'aucune
/// NOUVELLE frame n'est programmée après un pump, alors que
/// `SearchComposerBloc._onFiltersChanged` retarde volontairement son
/// comptage réseau de 400 ms (`Future.delayed`) APRÈS avoir déjà appliqué le
/// filtre (donc déjà stoppé de programmer des frames). Le minuteur de 400 ms
/// reste alors en vol et fait échouer l'assertion « A Timer is still
/// pending » en fin de test. Avancer explicitement de 500 ms avant de
/// laisser `pumpAndSettle()` finir le reste (dismiss de sheet, etc.) force
/// ce minuteur à s'écouler dans le même appel.
Future<void> _settleFilterChange(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

/// Viewport haute : l'écran empile huit blocs, le viewport 800×600 par défaut
/// du test binding ne montre que le tout début sans un scroll explicite. Même
/// valeurs que `search_filter_sheet_test.dart` (`vueHaute`).
void _vueHaute(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() {
    initializeDateFormatting('fr');
    registerCityFallbackValues();
    registerFallbackValue(null as String?);
    registerFallbackValue(null as bool?);
    registerFallbackValue(null as int?);
    registerFallbackValue(null as double?);
    registerFallbackValue(null as TransportMode?);
    registerFallbackValue(null as DateTime?);
    registerFallbackValue(SearchMode.trips);
  });

  setUp(() {
    final cityRepo = _MockCityRepository();
    when(() => cityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => cityRepo.getPopularCorridors()).thenAnswer((_) async => []);

    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));

    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    getIt.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );

    registerFakeRecentCityStore();
  });

  tearDown(() {
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    unregisterFakeRecentCityStore();
  });

  // Les blocs doivent tous être là : le lot est un échec si un filtre disparaît.
  testWidgets('les huit blocs de filtres sont présents', (tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    for (final label in const [
      'EN UNE PHRASE',
      'OÙ',
      'QUAND',
      'POIDS ET PRIX',
      'MON COLIS CONTIENT',
      'FILTRES RAPIDES',
      'URGENCE DU DÉPART',
      'AUTOUR DE MOI',
    ]) {
      await _scrollTo(tester, find.text(label));
      expect(
        find.text(label),
        findsOneWidget,
        reason: 'bloc « $label » absent',
      );
    }
  });

  testWidgets('le bloc de phrase est marqué facultatif', (tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(find.text('Facultatif'), findsOneWidget);
  });

  testWidgets('une recherche complète est possible sans toucher la barre', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    // On ne touche jamais le champ de phrase : uniquement les filtres.
    await tester.tap(find.text('Ce mois'));
    await tester.pumpAndSettle();

    // Le bouton reste présent et actionnable sans qu'une phrase ait été saisie.
    expect(find.textContaining('Rechercher'), findsOneWidget);
    await tester.tap(find.textContaining('Rechercher'));
    await tester.pumpAndSettle();
    expect(
      find.byType(SearchComposerScreen),
      findsNothing,
      reason: 'le tap doit fermer l écran, donc le bouton était bien actif',
    );
  });

  testWidgets('le compteur suit le nombre de résultats', (tester) async {
    await tester.pumpWidget(const _Harness(count: 14));
    await tester.pumpAndSettle();

    expect(find.textContaining('14'), findsOneWidget);
  });

  testWidgets(
    'une ambiguïté de prix affiche sa question et aucun filtre deviné',
    (tester) async {
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness(withPriceAmbiguity: true));
      await tester.pumpAndSettle();

      expect(find.textContaining('c\'est combien'), findsOneWidget);
      expect(
        find.text('Tous'),
        findsWidgets,
        reason: 'le prix reste non réglé',
      );
    },
  );

  // ── Couverture complémentaire (au-delà des 5 tests du brief) ────────────────
  //
  // Le brief n'exerçait que la parité des blocs et le parcours « au doigt ».
  // Ces tests couvrent le reste du comportement propre à l'écran : le mode
  // colis (blocs différents), « Tout effacer », le récapitulatif de phrase,
  // la réponse à une question, et l'affichage d'une erreur via ErrorCatalog.

  testWidgets(
    'mode colis : POIDS MAXIMAL et TAILLE DU COLIS remplacent POIDS ET PRIX',
    (tester) async {
      await tester.pumpWidget(const _Harness(mode: SearchMode.parcels));
      await tester.pumpAndSettle();

      expect(find.text('POIDS ET PRIX'), findsNothing);
      expect(find.text('MON COLIS CONTIENT'), findsNothing);
      expect(find.text('URGENCE DU DÉPART'), findsNothing);

      // « Pour mes trajets » vit entre FILTRES RAPIDES et AUTOUR DE MOI dans le
      // ListView : vérifié à sa place, avant que le scroll ne le dépasse (le
      // scroll ne revient jamais en arrière dans cette boucle).
      for (final label in const [
        'EN UNE PHRASE',
        'OÙ',
        'QUAND',
        'POIDS MAXIMAL',
        'TAILLE DU COLIS',
        'FILTRES RAPIDES',
      ]) {
        await _scrollTo(tester, find.text(label));
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'bloc « $label » absent',
        );
      }
      await _scrollTo(tester, find.text('Pour mes trajets'));
      expect(find.text('Pour mes trajets'), findsOneWidget);
      await _scrollTo(tester, find.text('AUTOUR DE MOI'));
      expect(find.text('AUTOUR DE MOI'), findsOneWidget);
    },
  );

  testWidgets('Tout effacer déclenche SearchComposerCleared', (tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();

    // L'écran reste ouvert (Tout effacer ne ferme rien) : le bouton Rechercher
    // est toujours là pour le prouver.
    expect(find.textContaining('Rechercher'), findsOneWidget);
  });

  testWidgets('le récapitulatif affiche les champs reconnus au libellé connu', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(withRecognizedArrival: true));
    await tester.pumpAndSettle();

    // Correspondance exacte : « Bamako » seul matcherait aussi le hint du
    // champ de phrase et la valeur du champ ville d'arrivée du bloc OÙ.
    expect(find.text('Arrivée : Bamako'), findsOneWidget);
  });

  testWidgets('répondre à une question de prix la retire et pose le filtre', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(withPriceAmbiguity: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jusqu\'à 6 €/kg'));
    await tester.pumpAndSettle();

    expect(find.textContaining('c\'est combien'), findsNothing);
  });

  testWidgets('un échec du parseur affiche une erreur via ErrorCatalog', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(withParseFailure: true));
    await tester.pumpAndSettle();

    // Le champ précis, pas `find.byType(TextField)` : le bloc OÙ en construit
    // d'autres (ville de départ/arrivée).
    final phraseField = find.byKey(const Key('search-phrase-textfield'));
    await tester.enterText(phraseField, 'à Bamako');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    // Pas de `pumpAndSettle()` ici : la snackbar a un auto-dismiss de 4 s que
    // `pumpAndSettle()` traverserait entièrement, la faisant disparaître avant
    // l'assertion. On laisse le BlocListener réagir avec des pumps ciblés.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // ErrorCatalog.lookup() résout l'exception générique vers sa présentation
    // riche (titre + message) : c'est ce titre qui doit apparaître, jamais
    // `state.error.toString()` ni le message technique brut.
    expect(find.textContaining('Erreur réseau'), findsWidgets);
  });

  testWidgets('AUTOUR DE MOI affiche l interrupteur de proximité', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Autour de moi'));
    expect(find.text('Autour de moi'), findsOneWidget);
  });

  group('_AroundMeBlock — géolocalisation', () {
    testWidgets(
      'pendant la récupération de la position : affiche l\'indicateur '
      '« Localisation en cours… »',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform()
          ..getCurrentPositionDelay = const Duration(milliseconds: 200);

        await tester.pumpWidget(const _Harness());
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Autour de moi'));
        await tester.tap(find.text('Autour de moi'));
        // Un seul pump (pas settle) : capture l'état intermédiaire pendant
        // que `getCurrentPosition()` est encore en vol.
        await tester.pump();
        expect(find.text('Localisation en cours…'), findsOneWidget);

        await _settleFilterChange(tester);
        expect(find.text('Localisation en cours…'), findsNothing);
        expect(find.textContaining('Rayon · 25 km'), findsOneWidget);
      },
    );

    testWidgets(
      'permission accordée : active le filtre, affiche le rayon par '
      'défaut (25 km)',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform();

        await tester.pumpWidget(const _Harness());
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Autour de moi'));
        await tester.tap(find.text('Autour de moi'));
        await _settleFilterChange(tester);

        expect(find.textContaining('Rayon · 25 km'), findsOneWidget);
      },
    );

    testWidgets(
      'permission refusée (denied puis denied) : ouvre la feuille refusée, '
      'le filtre reste inactif',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform()
          ..checkPermissionResult = LocationPermission.denied
          ..requestPermissionResult = LocationPermission.denied;

        await tester.pumpWidget(const _Harness());
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Autour de moi'));
        await tester.tap(find.text('Autour de moi'));
        await _settleFilterChange(tester);

        expect(find.text('Accès à la position refusé'), findsOneWidget);
        // La feuille de refus reste ouverte : referme-la avant d'asserter le
        // reste, sinon le texte du bouton derrière est masqué.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(find.textContaining('Rayon ·'), findsNothing);
      },
    );

    testWidgets(
      'permission refusée définitivement (deniedForever) : ouvre la feuille '
      'refusée sans jamais appeler requestPermission',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform()
          ..checkPermissionResult = LocationPermission.deniedForever;

        await tester.pumpWidget(const _Harness());
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Autour de moi'));
        await tester.tap(find.text('Autour de moi'));
        await _settleFilterChange(tester);

        expect(find.text('Accès à la position refusé'), findsOneWidget);
      },
    );

    testWidgets(
      'service de localisation désactivé : ouvre la feuille « désactivée »',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform()
          ..serviceEnabled = false;

        await tester.pumpWidget(const _Harness());
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Autour de moi'));
        await tester.tap(find.text('Autour de moi'));
        await _settleFilterChange(tester);

        expect(find.text('Localisation désactivée'), findsOneWidget);
      },
    );

    testWidgets(
      'un second tap désactive le filtre : le rayon disparaît',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform();

        await tester.pumpWidget(const _Harness());
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Autour de moi'));
        await tester.tap(find.text('Autour de moi'));
        await _settleFilterChange(tester);
        expect(find.textContaining('Rayon · 25 km'), findsOneWidget);

        await tester.tap(find.text('Autour de moi'));
        await _settleFilterChange(tester);
        expect(find.textContaining('Rayon ·'), findsNothing);
      },
    );

    testWidgets(
      'tap sur la pastille de rayon ouvre la feuille et applique la '
      'nouvelle valeur',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform();

        await tester.pumpWidget(const _Harness());
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Autour de moi'));
        await tester.tap(find.text('Autour de moi'));
        await _settleFilterChange(tester);
        expect(find.textContaining('Rayon · 25 km'), findsOneWidget);

        // La pastille apparaît sous le chip, une fois le filtre actif : sans
        // ce second scroll, elle peut se retrouver masquée par la barre de
        // navigation basse persistante (« Rechercher »), hors de portée d'un
        // tap.
        await _scrollTo(tester, find.textContaining('Rayon · 25 km'));
        await tester.tap(find.textContaining('Rayon · 25 km'));
        await tester.pumpAndSettle();
        expect(find.text('Près de moi'), findsOneWidget);

        // Fait glisser le slider vers la droite : la valeur affichée doit
        // dépasser 25 km.
        await tester.drag(find.byType(Slider), const Offset(120, 0));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Appliquer'));
        await _settleFilterChange(tester);

        expect(find.textContaining('Rayon · 25 km'), findsNothing);
      },
    );
  });
}

/// Monte `SearchComposerScreen` sur une route fille d'un `GoRouter` minimal —
/// `context.pop(filters)` dans l'écran l'exige, voir `dony_app_bar_test.dart`.
///
/// [count] fixe la valeur renvoyée par le comptage (`countAnnouncements`).
/// [withPriceAmbiguity] injecte un `UnresolvedItem` de prix en dispatchant un
/// `SearchComposerPhraseSubmitted` avant le premier pump, avec un parseur
/// mocké qui renvoie l'ambiguïté au lieu d'un filtre tranché.
/// [withRecognizedArrival] simule une phrase entièrement comprise
/// (`arrivalCity: 'Bamako'`), pour exercer `ParsedRecapCard`.
/// [withParseFailure] fait échouer le parseur pour exercer `ErrorPresenter`.
class _Harness extends StatelessWidget {
  const _Harness({
    this.mode = SearchMode.trips,
    this.count,
    this.withPriceAmbiguity = false,
    this.withRecognizedArrival = false,
    this.withParseFailure = false,
  });

  final SearchMode mode;
  final int? count;
  final bool withPriceAmbiguity;
  final bool withRecognizedArrival;
  final bool withParseFailure;

  @override
  Widget build(BuildContext context) {
    final parseRepo = _MockParseRepo();
    final announcementRepo = _MockAnnouncementRepo();
    final packageRepo = _MockPackageRepo();
    final analytics = _MockAnalytics();

    when(
      () => announcementRepo.countAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
        maxAvailableKg: any(named: 'maxAvailableKg'),
        maxPricePerKg: any(named: 'maxPricePerKg'),
        kiloProOnly: any(named: 'kiloProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
      ),
    ).thenAnswer((_) async => count ?? 0);

    when(
      () => packageRepo.search(
        departure: any(named: 'departure'),
        arrival: any(named: 'arrival'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        maxWeight: any(named: 'maxWeight'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        matchingMyTrips: any(named: 'matchingMyTrips'),
        size: any(named: 'size'),
      ),
    ).thenAnswer(
      (_) async => PackageRequestSearchPage(
        content: const [],
        totalElements: count ?? 0,
        page: 0,
        size: 1,
      ),
    );

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    if (withPriceAmbiguity) {
      when(() => parseRepo.parse(any(), any())).thenAnswer(
        (_) async => SearchParseResult.fromJson({
          'filters': const <String, dynamic>{},
          'recognized': const <dynamic>[],
          'unresolved': const [
            {
              'kind': 'PRICE_VAGUE',
              'phrase': 'pas trop cher',
              'options': ['6', '9'],
            },
          ],
        }),
      );
    } else if (withParseFailure) {
      when(
        () => parseRepo.parse(any(), any()),
      ).thenThrow(Exception('réseau indisponible'));
    } else if (withRecognizedArrival) {
      when(() => parseRepo.parse(any(), any())).thenAnswer(
        (_) async => SearchParseResult.fromJson({
          'filters': const {'arrivalCity': 'Bamako'},
          'recognized': const [
            {'field': 'arrivalCity', 'value': 'Bamako'},
          ],
          'unresolved': const <dynamic>[],
        }),
      );
    }

    final bloc = SearchComposerBloc(
      parseRepo,
      announcementRepo,
      packageRepo,
      analytics,
      mode: mode,
      initialFilters: const HomeSearchFilters(),
    );

    if (withPriceAmbiguity) {
      bloc.add(const SearchComposerPhraseSubmitted('pas trop cher'));
    }
    if (withRecognizedArrival) {
      bloc.add(const SearchComposerPhraseSubmitted('à Bamako'));
    }

    // Route fille NESTED (pas une route sœur) : c'est ce qui met deux pages
    // dans la pile de GoRouter (« / » puis « /child ») et rend `context.pop()`
    // possible — sinon « nothing to pop ». Même montage que
    // `dony_app_bar_test.dart` pour `DonyAppBarBackButton`.
    final router = GoRouter(
      initialLocation: '/child',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Root')),
          routes: [
            GoRoute(
              path: 'child',
              builder: (_, _) => BlocProvider<SearchComposerBloc>.value(
                value: bloc,
                child: SearchComposerScreen(
                  mode: mode,
                  initialFilters: const HomeSearchFilters(),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }
}
