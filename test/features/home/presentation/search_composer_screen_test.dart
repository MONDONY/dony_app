// Tests de SearchComposerScreen — l'écran plein « Filtrer ».
//
// Ordre vérifié : OÙ, QUAND, POIDS ET PRIX, FILTRES RAPIDES, « Plus de
// filtres » replié (contenu, transport, note, week-end, escales, paiement,
// urgence), AUTOUR DE MOI. Le bloc « En une phrase » n'existe plus : une
// recherche complète se fait aux filtres seuls.
//
// `context.pop(filters)` exige un `GoRouter` ancêtre (voir
// `go_router.GoRouterHelper.pop`) : le harnais place donc l'écran sur une
// route fille (`/child`), comme `dony_app_bar_test.dart` le fait déjà pour
// `DonyAppBarBackButton`.

import 'dart:io';

import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/screens/search_composer_screen.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_recent_city_store.dart';
import '../../../helpers/plane_icon_expectations.dart';

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
/// l'arbre — or il y en a plusieurs ici : le `ListView` de l'écran ET les
/// `EditableText` des champs de ville (tout `TextField` en construit un pour
/// son défilement horizontal interne). `.first` désigne le plus englobant,
/// rencontré avant les autres dans l'arbre : celui de l'écran.
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
/// Charge les vraies polices de l'app : avec la police de repli des tests,
/// chaque glyphe fait un cadratin et la mesure d'un titre serait fausse.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

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
    registerFallbackValue(null as List<String>?);
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
    resetTransportModesForTest();
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    unregisterFakeRecentCityStore();
  });

  // Les blocs doivent tous être là : le lot est un échec si un filtre disparaît.
  testWidgets('les blocs, dans l\'ordre, « Plus de filtres » replié', (
    tester,
  ) async {
    _vueHaute(tester);
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    final tops = <String, double>{};
    // Plus de titre « OÙ » : la carte des villes ouvre l'écran.
    expect(find.text('OÙ'), findsNothing);
    for (final label in const [
      'QUAND',
      'POIDS ET PRIX',
      'FILTRES RAPIDES',
      'AUTOUR DE MOI',
    ]) {
      await _scrollTo(tester, find.text(label));
      expect(
        find.text(label),
        findsOneWidget,
        reason: 'bloc « $label » absent',
      );
      tops[label] = tester.getTopLeft(find.text(label)).dy;
    }
    expect(find.text('EN UNE PHRASE'), findsNothing);

    // « Plus de filtres » vient entre les filtres rapides et « Autour de moi ».
    await _scrollTo(tester, find.text('Plus de filtres'));
    final more = tester.getTopLeft(find.text('Plus de filtres')).dy;
    await _scrollTo(tester, find.text('AUTOUR DE MOI'));
    final around = tester.getTopLeft(find.text('AUTOUR DE MOI')).dy;
    expect(more, lessThan(around));

    // Replié : les filtres rares ne sont pas dans l'arbre.
    for (final label in const [
      'MON COLIS CONTIENT',
      'ESCALES',
      'MOYENS DE PAIEMENT',
      'URGENCE DU DÉPART',
    ]) {
      expect(
        find.text(label),
        findsNothing,
        reason: '« $label » devrait être replié',
      );
    }
  });

  testWidgets('ville tapée sans choisir de suggestion : le filtre la retient '
      'et le comptage la reçoit', (tester) async {
    _vueHaute(tester);
    final repo = _MockAnnouncementRepo();
    await tester.pumpWidget(_Harness(announcementRepo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('composer-departure-city')),
      'Lyon',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settleFilterChange(tester);

    verify(
      () => repo.countAnnouncements(
        departureCity: 'Lyon',
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
        maxAvailableKg: any(named: 'maxAvailableKg'),
        maxPricePerKg: any(named: 'maxPricePerKg'),
        gpProOnly: any(named: 'gpProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        maxStops: any(named: 'maxStops'),
        paymentMethods: any(named: 'paymentMethods'),
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('« Plus de filtres » s\'ouvre au toucher et montre les filtres '
      'rares', (tester) async {
    _vueHaute(tester);
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
    await tester.tap(find.byKey(const Key('composer-more-filters')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composer-more-filters-body')), findsOneWidget);
    for (final label in const [
      'MON COLIS CONTIENT',
      'ESCALES',
      'MOYENS DE PAIEMENT',
      'URGENCE DU DÉPART',
    ]) {
      await _scrollTo(tester, find.text(label));
      expect(find.text(label), findsOneWidget, reason: '« $label » absent');
    }

    // Un second toucher le referme.
    await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
    await tester.tap(find.byKey(const Key('composer-more-filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer-more-filters-body')), findsNothing);
  });

  testWidgets('un filtre rare déjà actif ouvre « Plus de filtres » d\'office, '
      'avec son compte', (tester) async {
    _vueHaute(tester);
    await tester.pumpWidget(
      const _Harness(
        initialFilters: HomeSearchFilters(weekendOnly: true, minRating: 4.5),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
    expect(find.byKey(const Key('composer-more-filters-body')), findsOneWidget);
    final count = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('composer-more-filters-count')),
        matching: find.byType(Text),
      ),
    );
    expect(count.data, '2');
  });

  testWidgets('filtres rapides : Urgent, Valise 23 kg, GP Pro, Identité '
      'vérifiée', (tester) async {
    _vueHaute(tester);
    final repo = _MockAnnouncementRepo();
    await tester.pumpWidget(_Harness(announcementRepo: repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('composer-urgent')));
    await tester.tap(find.byKey(const Key('composer-urgent')));
    await _settleFilterChange(tester);

    expect(find.byKey(const Key('composer-suitcase-23')), findsOneWidget);
    expect(find.text('GP Pro'), findsWidgets);
    expect(find.text('Identité vérifiée'), findsOneWidget);
    // La note et le week-end ne sont plus des filtres rapides.
    expect(find.text('Note ≥ 4.5'), findsNothing);
    expect(find.text('Week-end'), findsNothing);

    final calls = verify(
      () => repo.countAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
        maxAvailableKg: any(named: 'maxAvailableKg'),
        maxPricePerKg: any(named: 'maxPricePerKg'),
        gpProOnly: any(named: 'gpProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: captureAny(named: 'urgent'),
        maxStops: any(named: 'maxStops'),
        paymentMethods: any(named: 'paymentMethods'),
      ),
    ).captured;
    expect(calls.last, isTrue);
  });

  // Le curseur « Poids min » laissé au minimum ne pose aucun minimum.
  testWidgets('Poids min confirmé sans toucher : aucune borne de kilos', (
    tester,
  ) async {
    _vueHaute(tester);
    final repo = _MockAnnouncementRepo();
    await tester.pumpWidget(_Harness(announcementRepo: repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('POIDS MIN'));
    await tester.tap(find.text('POIDS MIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await _settleFilterChange(tester);

    final captured = verify(
      () => repo.countAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: captureAny(named: 'minAvailableKg'),
        maxAvailableKg: captureAny(named: 'maxAvailableKg'),
        maxPricePerKg: any(named: 'maxPricePerKg'),
        gpProOnly: any(named: 'gpProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        maxStops: any(named: 'maxStops'),
        paymentMethods: any(named: 'paymentMethods'),
      ),
    ).captured;
    expect(captured.every((v) => v == null), isTrue);
    expect(find.text('Tous'), findsWidgets);
  });

  // Les escales sont une notion d'avion : leur puce ne dessine un avion que
  // si le filtre de mode vaut avion. Le bateau n'a pas d'escales du tout (voir
  // le groupe « bateau »).
  for (final (mode, planeShown) in <(TransportMode?, bool)>[
    (null, false),
    (TransportMode.plane, true),
  ]) {
    testWidgets('puces Escales, filtre mode $mode : avion $planeShown', (
      tester,
    ) async {
      // Plusieurs modes proposés : sans choix de mode, le filtre est écarté.
      // La route a ses propres filtres (PASSE PAR) : pas d'escales pour elle.
      setTransportModes(
        const TransportModesAvailability(road: true, boat: true),
      );
      addTearDown(resetTransportModesForTest);
      _vueHaute(tester);
      await tester.pumpWidget(
        _Harness(initialFilters: HomeSearchFilters(transportMode: mode)),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
      await tester.tap(find.byKey(const Key('composer-more-filters')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('ESCALES'));

      final chip = find.byKey(const Key('chip-stops-directOnly'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: findDonyIcon('plane')),
        planeShown ? findsOneWidget : findsNothing,
      );
      if (!planeShown) {
        expect(
          find.descendant(of: chip, matching: findDonyIcon('route')),
          findsOneWidget,
        );
      }
    });
  }

  testWidgets('puces Escales, avion seul proposé : l\'avion reste dessiné', (
    tester,
  ) async {
    _vueHaute(tester);
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
    await tester.tap(find.byKey(const Key('composer-more-filters')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('ESCALES'));

    final chip = find.byKey(const Key('chip-stops-directOnly'));
    expect(
      find.descendant(of: chip, matching: findDonyIcon('plane')),
      findsOneWidget,
    );
  });

  // FLUTTER-GD / FLUTTER-G0 : les deux filtres partent au serveur.
  testWidgets('Escales et moyens de paiement alimentent la recherche', (
    tester,
  ) async {
    _vueHaute(tester);
    final repo = _MockAnnouncementRepo();
    await tester.pumpWidget(_Harness(announcementRepo: repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
    await tester.tap(find.byKey(const Key('composer-more-filters')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('ESCALES'));
    await tester.tap(find.byKey(const Key('chip-stops-directOnly')));
    await _settleFilterChange(tester);

    await _scrollTo(tester, find.byKey(const Key('chip-payment-cash')));
    await tester.tap(find.byKey(const Key('chip-payment-cash')));
    await _settleFilterChange(tester);
    await tester.tap(find.byKey(const Key('chip-payment-stripe')));
    await _settleFilterChange(tester);

    final calls = verify(
      () => repo.countAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
        maxAvailableKg: any(named: 'maxAvailableKg'),
        maxPricePerKg: any(named: 'maxPricePerKg'),
        gpProOnly: any(named: 'gpProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        maxStops: captureAny(named: 'maxStops'),
        paymentMethods: captureAny(named: 'paymentMethods'),
      ),
    ).captured;
    // Derniers arguments capturés : maxStops puis paymentMethods.
    expect(calls[calls.length - 2], 0);
    expect(calls.last, ['CASH', 'STRIPE']);

    // « Peu importe » retire le filtre d'escales.
    await _scrollTo(tester, find.byKey(const Key('chip-stops-any')));
    await tester.tap(find.byKey(const Key('chip-stops-any')));
    await _settleFilterChange(tester);
    final after = verify(
      () => repo.countAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
        maxAvailableKg: any(named: 'maxAvailableKg'),
        maxPricePerKg: any(named: 'maxPricePerKg'),
        gpProOnly: any(named: 'gpProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        maxStops: captureAny(named: 'maxStops'),
        paymentMethods: any(named: 'paymentMethods'),
      ),
    ).captured;
    expect(after.last, isNull);
  });

  // YADONY-FLUTTER-PROD-Z : la puce rapide compte les trajets à 23 kg et plus.
  testWidgets('Filtres rapides : « 🧳 Valise 23 kg » demande 23 kg minimum', (
    tester,
  ) async {
    _vueHaute(tester);
    final repo = _MockAnnouncementRepo();
    await tester.pumpWidget(_Harness(announcementRepo: repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('composer-suitcase-23')));
    await tester.tap(find.byKey(const Key('composer-suitcase-23')));
    await _settleFilterChange(tester);

    final captured = verify(
      () => repo.countAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: captureAny(named: 'minAvailableKg'),
        maxAvailableKg: any(named: 'maxAvailableKg'),
        maxPricePerKg: any(named: 'maxPricePerKg'),
        gpProOnly: any(named: 'gpProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        maxStops: any(named: 'maxStops'),
        paymentMethods: any(named: 'paymentMethods'),
      ),
    ).captured;
    expect(captured.last, 23);
  });

  testWidgets('mode Colis : pas de puce Valise 23 kg', (tester) async {
    _vueHaute(tester);
    await tester.pumpWidget(const _Harness(mode: SearchMode.parcels));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composer-suitcase-23')), findsNothing);
  });

  group('route : taille du colis, passe par, curseur 1 000 kg', () {
    const road = HomeSearchFilters(transportMode: TransportMode.car);

    void roadOn() {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      addTearDown(resetTransportModesForTest);
    }

    /// Derniers arguments du comptage : kilos min, mode, taille, ville.
    ({double? kg, TransportMode? mode, ItemSize? size, String? via}) lastCount(
      _MockAnnouncementRepo repo,
    ) {
      final captured = verify(
        () => repo.countAnnouncements(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          departureDateFrom: any(named: 'departureDateFrom'),
          departureDateTo: any(named: 'departureDateTo'),
          minAvailableKg: captureAny(named: 'minAvailableKg'),
          maxAvailableKg: any(named: 'maxAvailableKg'),
          maxPricePerKg: any(named: 'maxPricePerKg'),
          gpProOnly: any(named: 'gpProOnly'),
          minRating: any(named: 'minRating'),
          weekendOnly: any(named: 'weekendOnly'),
          transportMode: captureAny(named: 'transportMode'),
          kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
          contentType: any(named: 'contentType'),
          userLat: any(named: 'userLat'),
          userLng: any(named: 'userLng'),
          radiusKm: any(named: 'radiusKm'),
          urgent: any(named: 'urgent'),
          maxStops: any(named: 'maxStops'),
          paymentMethods: any(named: 'paymentMethods'),
          minItemSize: captureAny(named: 'minItemSize'),
          viaCity: captureAny(named: 'viaCity'),
        ),
      ).captured;
      final n = captured.length - 4;
      return (
        kg: captured[n] as double?,
        mode: captured[n + 1] as TransportMode?,
        size: captured[n + 2] as ItemSize?,
        via: captured[n + 3] as String?,
      );
    }

    Future<void> openMore(WidgetTester tester) async {
      await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
      if (find
          .byKey(const Key('composer-more-filters-body'))
          .evaluate()
          .isEmpty) {
        await tester.tap(find.byKey(const Key('composer-more-filters')));
        await tester.pumpAndSettle();
      }
    }

    bool tileSelected(WidgetTester tester, String code) => tester
        .widget<Semantics>(find.byKey(Key('item-size-$code')))
        .properties
        .selected!;

    testWidgets('composeur route : TAILLE DU COLIS sous POIDS ET PRIX, PASSE '
        'PAR, ni ESCALES ni Valise 23 kg', (tester) async {
      roadOn();
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness(initialFilters: road));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('POIDS ET PRIX'));
      final weightTop = tester.getTopLeft(find.text('POIDS ET PRIX')).dy;
      await _scrollTo(tester, find.text('TAILLE DU COLIS'));
      final sizeTop = tester.getTopLeft(find.text('TAILLE DU COLIS')).dy;
      await _scrollTo(tester, find.text('FILTRES RAPIDES'));
      final quickTop = tester.getTopLeft(find.text('FILTRES RAPIDES')).dy;
      expect(weightTop, lessThan(sizeTop));
      expect(sizeTop, lessThan(quickTop));
      for (final code in ['S', 'M', 'L', 'XL']) {
        expect(find.byKey(Key('item-size-$code')), findsOneWidget);
      }
      expect(
        find.text('Trajets qui acceptent au moins cette taille.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('composer-suitcase-23')), findsNothing);
      expect(find.text('🧳 Valise 23 kg'), findsNothing);

      // Replié, l'en-tête annonce la ville de passage.
      expect(
        find.text('Type de contenu, note, ville de passage, paiement'),
        findsOneWidget,
      );
      await openMore(tester);
      await _scrollTo(tester, find.text('PASSE PAR'));
      expect(find.text('PASSE PAR'), findsOneWidget);
      expect(find.byKey(const Key('composer-via-city')), findsOneWidget);
      expect(
        find.text(
          'Pour confier un colis à un voyageur dont le voyage s\'arrête dans '
          'votre ville.',
        ),
        findsOneWidget,
      );
      expect(find.text('ESCALES'), findsNothing);
      expect(find.byKey(const Key('chip-stops-directOnly')), findsNothing);
    });

    testWidgets('composeur avion (et « tous ») : inchangé, Valise 23 kg et '
        'ESCALES, ni TAILLE ni PASSE PAR', (tester) async {
      roadOn();
      _vueHaute(tester);
      for (final mode in [TransportMode.plane, null]) {
        await tester.pumpWidget(
          _Harness(
            key: ValueKey(mode),
            initialFilters: HomeSearchFilters(transportMode: mode),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('TAILLE DU COLIS'), findsNothing, reason: '$mode');
        expect(find.byKey(const Key('item-size-L')), findsNothing);
        await _scrollTo(tester, find.byKey(const Key('composer-suitcase-23')));
        expect(find.byKey(const Key('composer-suitcase-23')), findsOneWidget);
        expect(
          find.text('Type de contenu, note, escales, paiement'),
          findsOneWidget,
        );
        await openMore(tester);
        await _scrollTo(tester, find.text('ESCALES'));
        expect(find.text('ESCALES'), findsOneWidget);
        expect(find.text('PASSE PAR'), findsNothing);
        expect(find.byKey(const Key('composer-via-city')), findsNothing);
      }
    });

    testWidgets('passer d\'avion à route efface la Valise 23 kg (23 kg '
        'n\'est plus demandé)', (tester) async {
      roadOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(
          announcementRepo: repo,
          initialFilters: const HomeSearchFilters(
            transportMode: TransportMode.plane,
            suitcase23Only: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('composer-transport-car')));
      await _settleFilterChange(tester);

      expect(find.byKey(const Key('composer-suitcase-23')), findsNothing);
      final count = lastCount(repo);
      expect(count.mode, TransportMode.car);
      expect(count.kg, isNull);
    });

    testWidgets('taille : un tap pose, un second tap retire ; le comptage '
        'suit', (tester) async {
      roadOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(announcementRepo: repo, initialFilters: road),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const Key('item-size-L')));
      await tester.tap(find.byKey(const Key('item-size-L')));
      await _settleFilterChange(tester);
      expect(tileSelected(tester, 'L'), isTrue);
      expect(tileSelected(tester, 'M'), isFalse);
      expect(lastCount(repo).size, ItemSize.l);

      await tester.tap(find.byKey(const Key('item-size-L')));
      await _settleFilterChange(tester);
      expect(tileSelected(tester, 'L'), isFalse);
      expect(lastCount(repo).size, isNull);
    });

    testWidgets('passe par : la ville tapée est retenue, trimée, et vider '
        'le champ la retire', (tester) async {
      roadOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(announcementRepo: repo, initialFilters: road),
      );
      await tester.pumpAndSettle();

      await openMore(tester);
      await _scrollTo(tester, find.byKey(const Key('composer-via-city')));
      await tester.enterText(
        find.byKey(const Key('composer-via-city')),
        ' Tanger ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settleFilterChange(tester);
      expect(lastCount(repo).via, 'Tanger');
      // La ville compte dans « Plus de filtres ».
      final badge = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('composer-more-filters-count')),
          matching: find.byType(Text),
        ),
      );
      expect(badge.data, '1');

      await tester.enterText(find.byKey(const Key('composer-via-city')), '');
      await _settleFilterChange(tester);
      expect(lastCount(repo).via, isNull);
      expect(
        find.byKey(const Key('composer-more-filters-count')),
        findsNothing,
      );
    });

    Future<HomeSearchFilters?> typeViaThenSearch(
      WidgetTester tester,
      String typed,
    ) async {
      HomeSearchFilters? popped;
      var closed = false;
      await tester.pumpWidget(
        _Harness(
          initialFilters: road,
          onPopped: (f) {
            popped = f;
            closed = true;
          },
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      await openMore(tester);
      await _scrollTo(tester, find.byKey(const Key('composer-via-city')));
      // Ni validation clavier ni perte de focus voulue : on saisit puis on
      // touche directement le bouton « Rechercher ».
      await tester.enterText(find.byKey(const Key('composer-via-city')), typed);
      await tester.pump();
      await tester.tap(find.byType(DonyButton));
      await tester.pumpAndSettle();
      expect(closed, isTrue, reason: 'le composeur doit se refermer');
      return popped;
    }

    testWidgets('« Passe par » tapé puis « Rechercher » touché sans valider : '
        'la ville n\'est pas perdue', (tester) async {
      roadOn();
      _vueHaute(tester);
      final popped = await typeViaThenSearch(tester, '  Tanger ');

      expect(popped?.viaCity, 'Tanger');
      expect(popped?.toAnnouncementQuery().viaCity, 'Tanger');
    });

    testWidgets('« Passe par » laissé blanc puis « Rechercher » : aucune '
        'ville', (tester) async {
      roadOn();
      _vueHaute(tester);
      final popped = await typeViaThenSearch(tester, '   ');

      expect(popped, isNotNull);
      expect(popped!.toAnnouncementQuery().viaCity, isNull);
      expect(popped.activeKeys, isNot(contains('via_city')));
    });

    testWidgets('une ville de passage déjà posée ouvre « Plus de filtres » '
        'd\'office ; une ville blanche ne compte pas', (tester) async {
      roadOn();
      _vueHaute(tester);
      await tester.pumpWidget(
        _Harness(initialFilters: road.copyWith(viaCity: 'Tanger')),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
      expect(
        find.byKey(const Key('composer-more-filters-body')),
        findsOneWidget,
      );
      expect(find.text('Tanger'), findsWidgets);

      await tester.pumpWidget(
        _Harness(
          key: const ValueKey('blank'),
          initialFilters: road.copyWith(viaCity: '   '),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
      expect(find.byKey(const Key('composer-more-filters-body')), findsNothing);
      expect(
        find.byKey(const Key('composer-more-filters-count')),
        findsNothing,
      );
    });

    testWidgets('Tout effacer : taille et ville de passage disparaissent', (
      tester,
    ) async {
      roadOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(
          announcementRepo: repo,
          initialFilters: road.copyWith(
            minItemSize: ItemSize.xl,
            viaCity: 'Tanger',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('item-size-XL')));
      expect(tileSelected(tester, 'XL'), isTrue);
      expect(find.text('Tanger'), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout effacer'));
      await _settleFilterChange(tester);

      // Plus de filtre Transport : la section Taille n'existe plus ; le
      // comptage ne porte ni taille ni ville.
      expect(find.text('TAILLE DU COLIS'), findsNothing);
      expect(find.text('Tanger'), findsNothing);
      final count = lastCount(repo);
      expect(count.size, isNull);
      expect(count.via, isNull);
      expect(count.mode, isNull);
    });

    testWidgets('Tout effacer puis retour à la route : le champ « Passe par » '
        'est vide et aucune ville n\'est comptée', (tester) async {
      roadOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(
          announcementRepo: repo,
          initialFilters: road.copyWith(viaCity: 'Tanger'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tanger'), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout effacer'));
      await _settleFilterChange(tester);
      expect(find.text('Tanger'), findsNothing);

      await tester.tap(find.byKey(const Key('composer-transport-car')));
      await _settleFilterChange(tester);
      await openMore(tester);
      await _scrollTo(tester, find.byKey(const Key('composer-via-city')));
      expect(find.text('Tanger'), findsNothing);
      expect(
        find.byKey(const Key('composer-more-filters-count')),
        findsNothing,
      );
      expect(lastCount(repo).via, isNull);
    });

    // Curseur « Poids min » du composeur.
    Slider slider(WidgetTester tester) =>
        tester.widget<Slider>(find.byType(Slider));

    Future<void> openWeight(WidgetTester tester) async {
      await _scrollTo(tester, find.text('POIDS MIN'));
      await tester.tap(find.text('POIDS MIN'));
      await tester.pumpAndSettle();
    }

    testWidgets('route : le curseur monte à 1 000 kg et garde 600 kg', (
      tester,
    ) async {
      roadOn();
      _vueHaute(tester);
      await tester.pumpWidget(
        _Harness(initialFilters: road.copyWith(weightMin: 600)),
      );
      await tester.pumpAndSettle();
      await openWeight(tester);

      expect(slider(tester).min, 1);
      expect(slider(tester).max, 1000);
      expect(slider(tester).value, 600);
    });

    testWidgets('avion : curseur 1..50 inchangé', (tester) async {
      roadOn();
      _vueHaute(tester);
      await tester.pumpWidget(
        const _Harness(
          initialFilters: HomeSearchFilters(transportMode: TransportMode.plane),
        ),
      );
      await tester.pumpAndSettle();
      await openWeight(tester);

      expect(slider(tester).min, 1);
      expect(slider(tester).max, 50);
    });

    testWidgets('600 kg posés depuis l\'accueil, mode avion : ramenés dans '
        'les bornes sans planter', (tester) async {
      roadOn();
      _vueHaute(tester);
      // État incohérent que seul un chemin hors `withTransportModeChanged`
      // peut produire (SearchParams, ancienne persistance) : le curseur ne
      // doit jamais recevoir une valeur hors de ses bornes.
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(
          announcementRepo: repo,
          initialFilters: const HomeSearchFilters(
            transportMode: TransportMode.plane,
            weightMin: 600,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openWeight(tester);

      expect(tester.takeException(), isNull);
      expect(slider(tester).max, 50);
      expect(slider(tester).value, 50);
      await tester.tap(find.text('Confirmer'));
      await _settleFilterChange(tester);
      expect(lastCount(repo).kg, 50);
    });

    testWidgets('route 600 kg puis retour à l\'avion : la capacité hors '
        'plage est retirée, le champ dit Tous', (tester) async {
      roadOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(
          announcementRepo: repo,
          initialFilters: road.copyWith(weightMin: 600),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('POIDS MIN'));
      expect(find.text('600 kg'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('composer-transport-plane')));
      await _settleFilterChange(tester);

      await _scrollTo(tester, find.text('POIDS MIN'));
      expect(find.text('600 kg'), findsNothing);
      final count = lastCount(repo);
      expect(count.kg, isNull);
      expect(count.mode, TransportMode.plane);
      await openWeight(tester);
      expect(slider(tester).max, 50);
      expect(tester.takeException(), isNull);
    });

    for (final english in [false, true]) {
      testWidgets('360 dp ${english ? 'EN' : 'FR'} : composeur route sans '
          'débordement, bouton Rechercher sur une ligne', (tester) async {
        if (english) useEnglish();
        roadOn();
        await _loadAppFonts();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _Harness(
            theme: AppTheme.light(),
            initialFilters: road.copyWith(minItemSize: ItemSize.xl),
          ),
        );
        await tester.pumpAndSettle();

        await _scrollTo(
          tester,
          find.text(english ? 'PARCEL SIZE' : 'TAILLE DU COLIS'),
        );
        await openMore(tester);
        await _scrollTo(
          tester,
          find.text(english ? 'PASSES THROUGH' : 'PASSE PAR'),
        );
        expect(tester.takeException(), isNull);

        final button = find.byType(DonyButton);
        final label = find.descendant(of: button, matching: find.byType(Text));
        // Une seule ligne : le libellé tient dans la hauteur d'une ligne de
        // 15 px (pas deux) et dans la largeur du bouton, sans être rétréci ;
        // le bouton garde sa hauteur de 48 à 56.
        expect(label, findsOneWidget);
        expect(tester.getSize(label).height, lessThan(15 * 1.6));
        expect(
          tester.getSize(label).width,
          lessThanOrEqualTo(tester.getSize(button).width),
        );
        expect(tester.getSize(button).height, inInclusiveRange(48, 56));
      });
    }
  });

  group('bateau : volume et prix, arrivée', () {
    const boat = HomeSearchFilters(transportMode: TransportMode.boat);

    void boatOn() {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: true),
      );
      addTearDown(resetTransportModesForTest);
    }

    /// Derniers arguments du comptage : volume, prix au m³, arrivée, mode.
    ({
      double? volume,
      double? price,
      DateTime? arrival,
      TransportMode? mode,
      double? kg,
    })
    lastCount(_MockAnnouncementRepo repo) {
      final captured = verify(
        () => repo.countAnnouncements(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          departureDateFrom: any(named: 'departureDateFrom'),
          departureDateTo: any(named: 'departureDateTo'),
          minAvailableKg: captureAny(named: 'minAvailableKg'),
          maxAvailableKg: any(named: 'maxAvailableKg'),
          maxPricePerKg: any(named: 'maxPricePerKg'),
          gpProOnly: any(named: 'gpProOnly'),
          minRating: any(named: 'minRating'),
          weekendOnly: any(named: 'weekendOnly'),
          transportMode: captureAny(named: 'transportMode'),
          kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
          contentType: any(named: 'contentType'),
          userLat: any(named: 'userLat'),
          userLng: any(named: 'userLng'),
          radiusKm: any(named: 'radiusKm'),
          urgent: any(named: 'urgent'),
          maxStops: any(named: 'maxStops'),
          paymentMethods: any(named: 'paymentMethods'),
          minVolumeM3: captureAny(named: 'minVolumeM3'),
          maxPricePerM3: captureAny(named: 'maxPricePerM3'),
          arrivalBefore: captureAny(named: 'arrivalBefore'),
        ),
      ).captured;
      final n = captured.length - 5;
      return (
        kg: captured[n] as double?,
        mode: captured[n + 1] as TransportMode?,
        volume: captured[n + 2] as double?,
        price: captured[n + 3] as double?,
        arrival: captured[n + 4] as DateTime?,
      );
    }

    DateTime inWeeks(int weeks) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day + weeks * 7);
    }

    Future<void> openMore(WidgetTester tester) async {
      await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
      if (find
          .byKey(const Key('composer-more-filters-body'))
          .evaluate()
          .isEmpty) {
        await tester.tap(find.byKey(const Key('composer-more-filters')));
        await tester.pumpAndSettle();
      }
    }

    DonyButton applyButton(WidgetTester tester) =>
        tester.widget<DonyButton>(find.byKey(const Key('boat-filter-apply')));

    Future<void> typeIn(WidgetTester tester, String key, String text) async {
      await tester.enterText(find.byKey(Key(key)), text);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('boatHidesEscalesAndUrgent : VOLUME ET PRIX et ARRIVÉE, ni '
        'Urgent, ni Valise 23 kg, ni ESCALES, ni PASSE PAR', (tester) async {
      boatOn();
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness(initialFilters: boat));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('POIDS ET PRIX'));
      final weightTop = tester.getTopLeft(find.text('POIDS ET PRIX')).dy;
      await _scrollTo(tester, find.text('VOLUME ET PRIX'));
      final volumeTop = tester.getTopLeft(find.text('VOLUME ET PRIX')).dy;
      await _scrollTo(tester, find.text('ARRIVÉE ESTIMÉE'));
      final arrivalTop = tester.getTopLeft(find.text('ARRIVÉE ESTIMÉE')).dy;
      await _scrollTo(tester, find.text('FILTRES RAPIDES'));
      final quickTop = tester.getTopLeft(find.text('FILTRES RAPIDES')).dy;
      expect(weightTop, lessThan(volumeTop));
      expect(volumeTop, lessThan(arrivalTop));
      expect(arrivalTop, lessThan(quickTop));

      expect(find.text('VOLUME MIN'), findsOneWidget);
      expect(find.text('PRIX MAX AU M³'), findsOneWidget);
      expect(
        find.text('Ces filtres ne montrent que les trajets facturés au m³.'),
        findsOneWidget,
      );
      for (final weeks in [4, 6, 8]) {
        expect(find.byKey(Key('boat-arrival-$weeks')), findsOneWidget);
        expect(find.text('Sous $weeks semaines'), findsOneWidget);
      }
      expect(
        find.text('Selon l\'arrivée estimée annoncée par le transporteur.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('composer-urgent')), findsNothing);
      expect(find.text('🔥 Urgent'), findsNothing);
      expect(find.byKey(const Key('composer-suitcase-23')), findsNothing);
      expect(find.text('TAILLE DU COLIS'), findsNothing);

      expect(find.text('Type de contenu, note, paiement'), findsOneWidget);
      await openMore(tester);
      expect(find.text('ESCALES'), findsNothing);
      expect(find.byKey(const Key('chip-stops-directOnly')), findsNothing);
      expect(find.text('PASSE PAR'), findsNothing);
      expect(find.text('MOYENS DE PAIEMENT'), findsOneWidget);

      // Aucun avion hors du choix du mode (la puce « Avion » du TRANSPORT).
      expect(
        findPlaneDonyIcons().evaluate().length,
        find
            .descendant(
              of: find.byKey(const Key('composer-transport-plane')),
              matching: findPlaneDonyIcons(),
            )
            .evaluate()
            .length,
      );
      expect(findMaterialFlightIcons(), findsNothing);
    });

    testWidgets('planeFiltersUnchanged : avion, route et « tous » sans section '
        'bateau, avec Urgent', (tester) async {
      boatOn();
      _vueHaute(tester);
      for (final mode in [null, TransportMode.plane, TransportMode.car]) {
        await tester.pumpWidget(
          _Harness(
            key: ValueKey(mode),
            initialFilters: HomeSearchFilters(transportMode: mode),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('VOLUME ET PRIX'), findsNothing, reason: '$mode');
        expect(find.text('ARRIVÉE ESTIMÉE'), findsNothing, reason: '$mode');
        expect(find.byKey(const Key('composer-boat-volume')), findsNothing);
        expect(find.byKey(const Key('boat-arrival-4')), findsNothing);
        await _scrollTo(tester, find.byKey(const Key('composer-urgent')));
        expect(find.byKey(const Key('composer-urgent')), findsOneWidget);
      }
    });

    testWidgets('volume : saisie 2,5 → comptage, champ « ≥ 2,5 m³ », bornes '
        'du back', (tester) async {
      boatOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(announcementRepo: repo, initialFilters: boat),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const Key('composer-boat-volume')));
      await tester.tap(find.byKey(const Key('composer-boat-volume')));
      await tester.pumpAndSettle();
      expect(find.text('Volume minimum'), findsOneWidget);
      expect(
        find.text('De 0,1 à 9 999 m³. Laissez vide pour tous les trajets.'),
        findsOneWidget,
      );

      // Hors bornes : erreur, « Appliquer » grisé.
      for (final bad in ['0,05', '10000', '0']) {
        await typeIn(tester, 'boat-filter-volume-field', bad);
        expect(
          find.text('Indiquez un volume entre 0,1 et 9 999 m³'),
          findsOneWidget,
          reason: bad,
        );
        expect(applyButton(tester).onPressed, isNull, reason: bad);
      }
      // Seules les décimales utiles sont saisissables.
      await typeIn(tester, 'boat-filter-volume-field', '2,5');
      expect(
        find.text('Indiquez un volume entre 0,1 et 9 999 m³'),
        findsNothing,
      );
      expect(applyButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('boat-filter-apply')));
      await _settleFilterChange(tester);

      expect(find.text('≥ 2,5 m³'), findsOneWidget);
      final count = lastCount(repo);
      expect(count.volume, 2.5);
      expect(count.mode, TransportMode.boat);
      expect(count.price, isNull);
      expect(count.arrival, isNull);

      // Champ vidé puis « Appliquer » : le filtre est retiré.
      await tester.tap(find.byKey(const Key('composer-boat-volume')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('boat-filter-volume-field')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        '2,5',
      );
      await typeIn(tester, 'boat-filter-volume-field', '');
      expect(applyButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('boat-filter-apply')));
      await _settleFilterChange(tester);
      expect(lastCount(repo).volume, isNull);
      expect(find.text('≥ 2,5 m³'), findsNothing);
    });

    testWidgets('prix max au m³ : saisie dans la devise du lecteur, plafond '
        'du back', (tester) async {
      boatOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(announcementRepo: repo, initialFilters: boat),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const Key('composer-boat-price')));
      await tester.tap(find.byKey(const Key('composer-boat-price')));
      await tester.pumpAndSettle();
      expect(find.text('Prix maximum au m³'), findsOneWidget);

      for (final bad in ['0', '10000001']) {
        await typeIn(tester, 'boat-filter-price-field', bad);
        expect(applyButton(tester).onPressed, isNull, reason: bad);
        expect(
          find.textContaining('Indiquez un prix supérieur à zéro'),
          findsOneWidget,
        );
      }
      await typeIn(tester, 'boat-filter-price-field', '600');
      expect(applyButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('boat-filter-apply')));
      await _settleFilterChange(tester);

      expect(find.textContaining('/m³'), findsOneWidget);
      expect(find.textContaining('600'), findsWidgets);
      final count = lastCount(repo);
      expect(count.price, 600);
      expect(count.volume, isNull);
    });

    testWidgets('arrivée : 6 semaines → aujourd\'hui + 42 jours, retoucher '
        'la pastille retire le filtre', (tester) async {
      boatOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(announcementRepo: repo, initialFilters: boat),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const Key('boat-arrival-6')));
      await tester.tap(find.byKey(const Key('boat-arrival-6')));
      await _settleFilterChange(tester);
      expect(
        tester
            .widget<QuickChip>(find.byKey(const Key('boat-arrival-6')))
            .active,
        isTrue,
      );
      expect(lastCount(repo).arrival, inWeeks(6));

      await tester.tap(find.byKey(const Key('boat-arrival-8')));
      await _settleFilterChange(tester);
      expect(lastCount(repo).arrival, inWeeks(8));

      await tester.tap(find.byKey(const Key('boat-arrival-8')));
      await _settleFilterChange(tester);
      expect(lastCount(repo).arrival, isNull);
    });

    testWidgets('bateau puis avion : volume, prix au m³ et arrivée effacés, '
        'Urgent revient', (tester) async {
      boatOn();
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(
        _Harness(
          announcementRepo: repo,
          initialFilters: boat.copyWith(
            minVolumeM3: 3,
            maxPricePerM3: 500,
            arrivalWithinWeeks: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('composer-transport-plane')));
      await _settleFilterChange(tester);

      final count = lastCount(repo);
      expect(count.mode, TransportMode.plane);
      expect(count.volume, isNull);
      expect(count.price, isNull);
      expect(count.arrival, isNull);
      expect(find.text('VOLUME ET PRIX'), findsNothing);
      await _scrollTo(tester, find.byKey(const Key('composer-urgent')));
      expect(find.byKey(const Key('composer-urgent')), findsOneWidget);
    });

    testWidgets('le curseur du poids minimum monte à 1 000 kg en bateau', (
      tester,
    ) async {
      boatOn();
      _vueHaute(tester);
      await tester.pumpWidget(
        _Harness(initialFilters: boat.copyWith(weightMin: 600)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('POIDS MIN'));
      expect(find.text('600 kg'), findsOneWidget);
      await tester.tap(find.text('POIDS MIN'));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.max, 1000);
      expect(slider.value, 600);
    });

    for (final english in [false, true]) {
      testWidgets('360 dp ${english ? 'EN' : 'FR'} : composeur bateau sans '
          'débordement, boutons sur une ligne', (tester) async {
        if (english) useEnglish();
        boatOn();
        await _loadAppFonts();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _Harness(
            theme: AppTheme.light(),
            initialFilters: boat.copyWith(
              minVolumeM3: 1234.5,
              maxPricePerM3: 9999999,
              arrivalWithinWeeks: 8,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _scrollTo(
          tester,
          find.text(english ? 'VOLUME AND PRICE' : 'VOLUME ET PRIX'),
        );
        await _scrollTo(
          tester,
          find.text(english ? 'ESTIMATED ARRIVAL' : 'ARRIVÉE ESTIMÉE'),
        );
        expect(tester.takeException(), isNull);

        // Les champs gardent une seule ligne de valeur, même hauteur.
        final heights = {
          tester.getSize(find.byKey(const Key('composer-boat-volume'))).height,
          tester.getSize(find.byKey(const Key('composer-boat-price'))).height,
        };
        expect(heights.length, 1);

        final button = find.byType(DonyButton);
        final label = find.descendant(of: button, matching: find.byType(Text));
        expect(label, findsOneWidget);
        expect(tester.getSize(label).height, lessThan(15 * 1.6));
        expect(
          tester.getSize(label).width,
          lessThanOrEqualTo(tester.getSize(button).width),
        );
        expect(tester.getSize(button).height, inInclusiveRange(48, 56));

        // Feuille du volume : bouton « Appliquer » sur une ligne.
        await tester.tap(find.byKey(const Key('composer-boat-volume')));
        await tester.pumpAndSettle();
        final apply = find.byKey(const Key('boat-filter-apply'));
        final applyLabel = find.descendant(
          of: apply,
          matching: find.byType(Text),
        );
        expect(applyLabel, findsOneWidget);
        expect(tester.getSize(applyLabel).height, lessThan(15 * 1.6));
        expect(
          tester.getSize(applyLabel).width,
          lessThanOrEqualTo(tester.getSize(apply).width),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('une recherche complète est possible sans toucher la barre', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    // Uniquement les filtres : aucun autre parcours n'existe.
    await tester.tap(find.text('Ce mois'));
    await tester.pumpAndSettle();

    // Le bouton reste présent et actionnable.
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

  // ── Couverture complémentaire (au-delà des 5 tests du brief) ────────────────
  //
  // Le brief n'exerçait que la parité des blocs et le parcours « au doigt ».
  // Ces tests couvrent le reste du comportement propre à l'écran : le mode
  // colis (blocs différents) et « Tout effacer ».

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
      expect(find.text('OÙ'), findsNothing);
      for (final label in const [
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

  testWidgets('Tout effacer : dans le corps, hors de la barre, et efface les '
      'filtres', (tester) async {
    await tester.pumpWidget(
      const _Harness(initialFilters: HomeSearchFilters(departureCity: 'Paris')),
    );
    await tester.pumpAndSettle();

    final clear = find.text('Tout effacer');
    expect(clear, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: clear),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(ListView), matching: clear),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(TextButton).first).height,
      greaterThanOrEqualTo(44),
    );
    expect(find.text('Paris'), findsWidgets);

    await tester.tap(clear);
    await tester.pumpAndSettle();

    expect(find.text('Paris'), findsNothing);
    // L'écran reste ouvert : le bouton Rechercher est toujours là.
    expect(find.textContaining('Rechercher'), findsOneWidget);
  });

  for (final mode in SearchMode.values) {
    testWidgets('titre de la barre complet à 360 dp (${mode.name})', (
      tester,
    ) async {
      await _loadAppFonts();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_Harness(mode: mode, theme: AppTheme.light()));
      await tester.pumpAndSettle();

      final title = mode.isTrips ? 'Filtrer les trajets' : 'Filtrer les colis';
      final finder = find.descendant(
        of: find.byType(AppBar),
        matching: find.text(title),
      );
      expect(finder, findsOneWidget);
      // Le paragraphe réellement posé : coupé par « … » s'il dépasse la place.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: finder, matching: find.byType(RichText)).first,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        tester.getSize(finder).width,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
        ),
      );
    });
  }

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

    testWidgets('permission accordée : activez le filtre, affiche le rayon par '
        'défaut (25 km)', (tester) async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform();

      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Autour de moi'));
      await tester.tap(find.text('Autour de moi'));
      await _settleFilterChange(tester);

      expect(find.textContaining('Rayon · 25 km'), findsOneWidget);
    });

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

    testWidgets('un second tap désactive le filtre : le rayon disparaît', (
      tester,
    ) async {
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
    });

    testWidgets('tap sur la pastille de rayon ouvre la feuille et applique la '
        'nouvelle valeur', (tester) async {
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
    });
  });

  group('en anglais', () {
    testWidgets('titre, action et sections traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(const _Harness(count: 3));
      await tester.pumpAndSettle();

      expect(find.text('Filter trips'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
      expect(find.text('WHERE'), findsNothing);
      expect(find.text('Search (3)'), findsOneWidget);
    });

    testWidgets('mode colis : titre et tailles traduits', (tester) async {
      useEnglish();
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness(mode: SearchMode.parcels));
      await tester.pumpAndSettle();

      expect(find.text('Filter parcels'), findsOneWidget);
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      expect(find.text('Around me'), findsOneWidget);
    });

    testWidgets('« Plus de filtres » traduit', (tester) async {
      useEnglish();
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('More filters'));
      expect(find.text('More filters'), findsOneWidget);
      expect(find.text('IN ONE SENTENCE'), findsNothing);
    });
  });

  group('section TRANSPORT', () {
    const roadOn = TransportModesAvailability(road: true, boat: false);
    const allOn = TransportModesAvailability(road: true, boat: true);

    Finder transportChip(String mode) =>
        find.byKey(Key('composer-transport-$mode'));

    bool isActive(WidgetTester tester, String mode) =>
        tester.widget<QuickChip>(transportChip(mode)).active;

    Future<void> openMoreFilters(WidgetTester tester) async {
      await _scrollTo(tester, find.byKey(const Key('composer-more-filters')));
      await tester.tap(find.byKey(const Key('composer-more-filters')));
      await tester.pumpAndSettle();
    }

    testWidgets('avion seul : ni section ni champ Transport', (tester) async {
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      expect(find.text('TRANSPORT'), findsNothing);
      expect(transportChip('all'), findsNothing);

      await openMoreFilters(tester);
      expect(find.text('TRANSPORT'), findsNothing);
    });

    testWidgets('route allumée : section TRANSPORT visible hors de « Plus de '
        'filtres », Tous / Avion / Route', (tester) async {
      setTransportModes(roadOn);
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      // Visible sans déplier « Plus de filtres », avant QUAND.
      expect(find.text('TRANSPORT'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('TRANSPORT')).dy,
        lessThan(tester.getTopLeft(find.text('QUAND')).dy),
      );
      for (final (key, label) in const [
        ('all', 'Tous'),
        ('plane', 'Avion'),
        ('car', 'Route'),
      ]) {
        expect(
          find.descendant(of: transportChip(key), matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(transportChip('boat'), findsNothing);
      expect(isActive(tester, 'all'), isTrue);

      // Et le champ a quitté « Plus de filtres » : un seul « TRANSPORT ».
      await openMoreFilters(tester);
      expect(find.text('TRANSPORT'), findsOneWidget);
    });

    testWidgets('bateau et route allumés : Tous / Avion / Bateau / Route', (
      tester,
    ) async {
      setTransportModes(allOn);
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      for (final key in const ['all', 'plane', 'boat', 'car']) {
        expect(transportChip(key), findsOneWidget);
      }
    });

    testWidgets('Route applique le mode car, Tous le retire', (tester) async {
      setTransportModes(roadOn);
      _vueHaute(tester);
      final repo = _MockAnnouncementRepo();
      await tester.pumpWidget(_Harness(announcementRepo: repo));
      await tester.pumpAndSettle();

      Future<void> verifyCount(TransportMode? mode) async {
        await _settleFilterChange(tester);
        verify(
          () => repo.countAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            maxAvailableKg: any(named: 'maxAvailableKg'),
            maxPricePerKg: any(named: 'maxPricePerKg'),
            gpProOnly: any(named: 'gpProOnly'),
            minRating: any(named: 'minRating'),
            weekendOnly: any(named: 'weekendOnly'),
            transportMode: mode,
            kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
            contentType: any(named: 'contentType'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            urgent: any(named: 'urgent'),
            maxStops: any(named: 'maxStops'),
            paymentMethods: any(named: 'paymentMethods'),
          ),
        ).called(greaterThanOrEqualTo(1));
      }

      await tester.tap(transportChip('car'));
      await tester.pump();
      expect(isActive(tester, 'car'), isTrue);
      expect(isActive(tester, 'all'), isFalse);
      await verifyCount(TransportMode.car);

      await tester.tap(transportChip('all'));
      await tester.pump();
      expect(isActive(tester, 'car'), isFalse);
      expect(isActive(tester, 'all'), isTrue);
      await verifyCount(null);
    });

    testWidgets('filtre BUS persistant : « Route » est actif', (tester) async {
      setTransportModes(roadOn);
      _vueHaute(tester);
      await tester.pumpWidget(
        const _Harness(
          initialFilters: HomeSearchFilters(transportMode: TransportMode.bus),
        ),
      );
      await tester.pumpAndSettle();

      expect(isActive(tester, 'car'), isTrue);
      expect(isActive(tester, 'all'), isFalse);
    });

    testWidgets("filtre d'un mode non proposé (train, bateau éteint) retiré "
        'au chargement', (tester) async {
      setTransportModes(roadOn);
      _vueHaute(tester);
      for (final mode in [TransportMode.train, TransportMode.boat]) {
        await tester.pumpWidget(
          _Harness(
            key: ValueKey(mode),
            initialFilters: HomeSearchFilters(transportMode: mode),
          ),
        );
        await tester.pumpAndSettle();

        expect(isActive(tester, 'all'), isTrue, reason: '$mode retiré');
        expect(isActive(tester, 'car'), isFalse);
        expect(isActive(tester, 'plane'), isFalse);
      }
    });

    testWidgets('mode Colis (Je voyage) : pas de section Transport', (
      tester,
    ) async {
      setTransportModes(roadOn);
      _vueHaute(tester);
      await tester.pumpWidget(const _Harness(mode: SearchMode.parcels));
      await tester.pumpAndSettle();

      expect(find.text('TRANSPORT'), findsNothing);
    });

    for (final locale in ['fr', 'en']) {
      testWidgets('360 dp $locale : section sans débordement', (tester) async {
        if (locale == 'en') useEnglish();
        setTransportModes(allOn);
        tester.view.physicalSize = const Size(360, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const _Harness());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(transportChip('boat'), findsOneWidget);
        final heights = {
          for (final k in const ['all', 'plane', 'boat', 'car'])
            tester.getSize(transportChip(k)).height,
        };
        expect(heights.length, 1, reason: 'puces de même hauteur');
        expect(
          tester.getRect(transportChip('car')).right,
          lessThanOrEqualTo(360),
        );
      });
    }
  });
}

/// Monte `SearchComposerScreen` sur une route fille d'un `GoRouter` minimal —
/// `context.pop(filters)` dans l'écran l'exige, voir `dony_app_bar_test.dart`.
///
/// [count] fixe la valeur renvoyée par le comptage (`countAnnouncements`).
/// [initialFilters] part de filtres déjà posés (ex. un filtre rare actif).
class _Harness extends StatelessWidget {
  const _Harness({
    super.key,
    this.mode = SearchMode.trips,
    this.count,
    this.announcementRepo,
    this.initialFilters = const HomeSearchFilters(),
    this.theme,
    this.onPopped,
  });

  /// Quand il est fourni, l'écran s'ouvre depuis une page « Root » (bouton
  /// « ouvrir ») et reçoit les filtres que le composeur renvoie en se
  /// refermant : c'est ce que l'accueil applique, pas l'état du bloc après coup.
  final ValueChanged<HomeSearchFilters?>? onPopped;

  final _MockAnnouncementRepo? announcementRepo;
  final SearchMode mode;
  final int? count;
  final HomeSearchFilters initialFilters;

  /// Thème de l'app quand le test mesure du texte (sinon thème par défaut).
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final announcementRepo = this.announcementRepo ?? _MockAnnouncementRepo();
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
        gpProOnly: any(named: 'gpProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
        maxStops: any(named: 'maxStops'),
        paymentMethods: any(named: 'paymentMethods'),
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

    final bloc = SearchComposerBloc(
      announcementRepo,
      packageRepo,
      analytics,
      mode: mode,
      initialFilters: initialFilters,
    );

    // Route fille NESTED (pas une route sœur) : c'est ce qui met deux pages
    // dans la pile de GoRouter (« / » puis « /child ») et rend `context.pop()`
    // possible — sinon « nothing to pop ». Même montage que
    // `dony_app_bar_test.dart` pour `DonyAppBarBackButton`.
    final router = GoRouter(
      initialLocation: onPopped == null ? '/child' : '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => onPopped == null
              ? const Scaffold(body: Text('Root'))
              : Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async => onPopped!(
                        await context.push<HomeSearchFilters>('/child'),
                      ),
                      child: const Text('ouvrir'),
                    ),
                  ),
                ),
          routes: [
            GoRoute(
              path: 'child',
              builder: (_, _) => BlocProvider<SearchComposerBloc>.value(
                value: bloc,
                child: SearchComposerScreen(
                  mode: mode,
                  initialFilters: initialFilters,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router, theme: theme);
  }
}
