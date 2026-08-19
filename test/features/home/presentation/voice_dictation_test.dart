// Tests du câblage de la dictée vocale dans SearchComposerScreen.
//
// `VoiceDictationSheet` elle-même dépend de la plateforme réelle de
// reconnaissance vocale (`speech_to_text`, canal de méthode natif) :
// impossible à exercer dans un widget test sans plateforme. Ce fichier
// couvre donc le seul point testable sans device : le paramètre
// `speechAvailable`, injecté sur `SearchComposerScreen` pour rendre la
// disponibilité du micro testable, qui conditionne l'affichage du bouton
// micro existant (`SearchPhraseField.onMicPressed`, câblé Task 3, label
// d'accessibilité posé dès cette task-là).
//
// `context.pop(filters)` exige un `GoRouter` ancêtre : le harnais place donc
// l'écran sur une route fille, comme `search_composer_screen_test.dart`.

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/data/repositories/search_parse_repository.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/screens/search_composer_screen.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

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

void main() {
  setUpAll(() {
    initializeDateFormatting('fr');
    registerCityFallbackValues();
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

  testWidgets('sans reconnaissance disponible, le micro disparaît et le champ reste',
      (tester) async {
    // Le test monte l'écran avec un service de dictée déclaré indisponible.
    await tester.pumpWidget(const _HarnessWithoutSpeech());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    // `find.byType(TextField)` matcherait aussi les champs ville du bloc OÙ
    // (le squelette imposé de la Task 3) : la clé du champ de phrase cible
    // précisément la saisie au clavier que ce test protège.
    expect(find.byKey(const Key('search-phrase-textfield')), findsOneWidget,
        reason: 'la saisie au clavier doit rester possible');
  });

  testWidgets('le bouton de dictée porte un libellé d accessibilité',
      (tester) async {
    await tester.pumpWidget(const _HarnessWithSpeech());
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Dicter votre recherche'),
      findsOneWidget,
    );
  });
}

/// Monte `SearchComposerScreen` sur une route fille d'un `GoRouter` minimal,
/// avec [speechAvailable] transmis tel quel.
class _Harness extends StatelessWidget {
  const _Harness({required this.speechAvailable});

  final bool speechAvailable;

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
    ).thenAnswer((_) async => 0);

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
      (_) async => const PackageRequestSearchPage(
        content: [],
        totalElements: 0,
        page: 0,
        size: 1,
      ),
    );

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    final bloc = SearchComposerBloc(
      parseRepo,
      announcementRepo,
      packageRepo,
      analytics,
      mode: SearchMode.trips,
      initialFilters: const HomeSearchFilters(),
    );

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
                  mode: SearchMode.trips,
                  initialFilters: const HomeSearchFilters(),
                  speechAvailable: speechAvailable,
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

class _HarnessWithoutSpeech extends StatelessWidget {
  const _HarnessWithoutSpeech();

  @override
  Widget build(BuildContext context) => const _Harness(speechAvailable: false);
}

class _HarnessWithSpeech extends StatelessWidget {
  const _HarnessWithSpeech();

  @override
  Widget build(BuildContext context) => const _Harness(speechAvailable: true);
}
