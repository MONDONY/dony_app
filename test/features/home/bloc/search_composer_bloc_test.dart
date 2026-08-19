import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/bloc/search_composer_state.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/data/repositories/search_parse_repository.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockParseRepo extends Mock implements SearchParseRepository {}
class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}
class _MockPackageRepo extends Mock implements PackageRequestRepository {}
class _MockAnalytics extends Mock implements AnalyticsService {}

SearchParseResult _result({
  Map<String, dynamic> filters = const {},
  List<Map<String, dynamic>> unresolved = const [],
}) =>
    SearchParseResult.fromJson({
      'filters': filters,
      'recognized': const [],
      'unresolved': unresolved,
      'ignored': const [],
    });

void main() {
  late _MockParseRepo parseRepo;
  late _MockAnnouncementRepo announcementRepo;
  late _MockPackageRepo packageRepo;
  late _MockAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(null as String?);
    registerFallbackValue(null as bool?);
    registerFallbackValue(null as int?);
    registerFallbackValue(null as double?);
    registerFallbackValue(null as TransportMode?);
    registerFallbackValue(null as DateTime?);
    registerFallbackValue(SearchMode.trips);
  });

  setUp(() {
    parseRepo = _MockParseRepo();
    announcementRepo = _MockAnnouncementRepo();
    packageRepo = _MockPackageRepo();
    analytics = _MockAnalytics();

    // Setup mock pour countAnnouncements - accepte n'importe quels paramètres
    when(() => announcementRepo.countAnnouncements(
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
        )).thenAnswer((_) async => 14);
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
  });

  SearchComposerBloc build() => SearchComposerBloc(
        parseRepo,
        announcementRepo,
        packageRepo,
        analytics,
        mode: SearchMode.trips,
        initialFilters: const HomeSearchFilters(),
      );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'une phrase comprise pose les filtres et met à jour le compteur',
    build: () {
      when(() => parseRepo.parse(any(), any()))
          .thenAnswer((_) async => _result(filters: const {'arrivalCity': 'Bamako'}));
      return build();
    },
    act: (bloc) => bloc.add(const SearchComposerPhraseSubmitted('à Bamako')),
    wait: const Duration(milliseconds: 600),
    expect: () => [
      isA<SearchComposerState>().having((s) => s.isParsing, 'isParsing', true),
      isA<SearchComposerState>()
          .having((s) => s.filters.arrivalCity, 'arrivalCity', 'Bamako')
          .having((s) => s.isParsing, 'isParsing', false),
      isA<SearchComposerState>().having((s) => s.isCounting, 'isCounting', true),
      isA<SearchComposerState>().having((s) => s.resultCount, 'resultCount', 14),
    ],
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'une ambiguïté de prix ne pose aucun filtre de prix',
    build: () {
      when(() => parseRepo.parse(any(), any())).thenAnswer((_) async => _result(
            filters: const {'arrivalCity': 'Kolda'},
            unresolved: const [
              {'kind': 'PRICE_VAGUE', 'phrase': 'pas trop cher', 'options': ['6', '9']},
            ],
          ));
      return build();
    },
    act: (bloc) => bloc.add(const SearchComposerPhraseSubmitted('à Kolda pas trop cher')),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.filters.maxPricePerKg, isNull);
      expect(bloc.state.unresolved.first.kind, UnresolvedKind.priceVague);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'répondre à une ambiguïté pose le filtre et retire la question',
    build: () {
      when(() => parseRepo.parse(any(), any())).thenAnswer((_) async => _result(
            unresolved: const [
              {'kind': 'PRICE_VAGUE', 'phrase': 'pas cher', 'options': ['6', '9']},
            ],
          ));
      return build();
    },
    act: (bloc) async {
      bloc.add(const SearchComposerPhraseSubmitted('pas cher'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      bloc.add(const SearchComposerUnresolvedAnswered(
        kind: UnresolvedKind.priceVague,
        value: '6',
      ));
    },
    wait: const Duration(milliseconds: 900),
    verify: (bloc) {
      expect(bloc.state.filters.maxPricePerKg, 6);
      expect(bloc.state.unresolved, isEmpty);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'un échec réseau laisse les filtres intacts et n efface pas la saisie',
    build: () {
      when(() => parseRepo.parse(any(), any())).thenThrow(Exception('réseau'));
      return build();
    },
    act: (bloc) => bloc.add(const SearchComposerPhraseSubmitted('à Bamako')),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.error, isNotNull);
      expect(bloc.state.filters.arrivalCity, isNull);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'régler un filtre à la main met le compteur à jour sans appeler le parseur',
    build: build,
    act: (bloc) => bloc.add(const SearchComposerFiltersChanged(
      HomeSearchFilters(arrivalCity: 'Dakar'),
    )),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.resultCount, 14);
      verifyNever(() => parseRepo.parse(any(), any()));
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'un échec du comptage masque le nombre sans casser l écran',
    build: () {
      when(() => announcementRepo.countAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
          )).thenThrow(Exception('réseau'));
      return build();
    },
    act: (bloc) => bloc.add(const SearchComposerFiltersChanged(
      HomeSearchFilters(arrivalCity: 'Dakar'),
    )),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.resultCount, isNull);
      expect(bloc.state.error, isNull);
    },
  );
}
