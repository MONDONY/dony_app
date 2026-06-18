import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/colis_match_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockPackageRequestSearchBloc
    extends MockBloc<PackageRequestSearchEvent, PackageRequestSearchState>
    implements PackageRequestSearchBloc {}

AnnouncementModel _ann({
  String id = 'ann-1',
  String departure = 'Paris',
  String arrival = 'Dakar',
  String status = 'ACTIVE',
  double availableKg = 15,
  double totalKg = 23,
}) => AnnouncementModel(
  id: id,
  travelerId: 'u-1',
  departureCity: departure,
  arrivalCity: arrival,
  departureDate: DateTime(2026, 6, 12),
  availableKg: availableKg,
  totalKg: totalKg,
  pricePerKg: 5,
  status: status,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

PackageRequestSearchItem _searchItem({String id = 'pr-1'}) =>
    PackageRequestSearchItem(
      id: id,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 10),
      dateToleranceDays: 2,
      weightKg: 3,
      parcelSize: ParcelSize.small,
      categories: const ['Vêtements'],
      sender: const SenderPublicProfile(
        id: 's-1',
        displayName: 'Fatou Ba',
        averageRating: 4.8,
        totalRatings: 12,
        kycVerified: true,
      ),
    );

void main() {
  late _MockAnnouncementBloc announcementBloc;
  late _MockPackageRequestSearchBloc searchBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    registerFallbackValue(AnnouncementListRequested());
    registerFallbackValue(const SearchFiltersChanged());
  });

  setUp(() {
    announcementBloc = _MockAnnouncementBloc();
    searchBloc = _MockPackageRequestSearchBloc();

    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(
      () => announcementBloc.stream,
    ).thenAnswer((_) => const Stream<AnnouncementState>.empty());
    when(() => searchBloc.state).thenReturn(const PackageRequestSearchState());
    when(
      () => searchBloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestSearchState>.empty());

    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<PackageRequestSearchBloc>()) {
      getIt.unregister<PackageRequestSearchBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    getIt.registerFactory<PackageRequestSearchBloc>(() => searchBloc);
  });

  tearDown(() async {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<PackageRequestSearchBloc>()) {
      getIt.unregister<PackageRequestSearchBloc>();
    }
  });

  Widget wrap() => MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ColisMatchScreen()),
        GoRoute(
          path: '/announcements/create',
          builder: (_, __) => const Scaffold(body: Text('Créer trajet')),
        ),
        GoRoute(
          path: '/package-requests/:id/public',
          builder: (_, __) => const Scaffold(body: Text('Détail colis')),
        ),
      ],
    ),
    theme: AppTheme.light,
  );

  group('ColisMatchScreen', () {
    testWidgets('chips générés depuis annonces ACTIVE et FULL seulement', (
      tester,
    ) async {
      when(() => announcementBloc.state).thenReturn(
        AnnouncementListLoaded([
          _ann(
            id: 'a1',
            departure: 'Paris',
            arrival: 'Dakar',
            status: 'ACTIVE',
          ),
          _ann(id: 'a2', departure: 'Lyon', arrival: 'Abidjan', status: 'FULL'),
          _ann(
            id: 'a3',
            departure: 'Nice',
            arrival: 'Bamako',
            status: 'CLOSED',
          ),
        ]),
      );

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Paris→Dakar'), findsOneWidget);
      expect(find.textContaining('Lyon→Abidjan'), findsOneWidget);
      expect(find.textContaining('Nice→Bamako'), findsNothing);
    });

    testWidgets(
      'sélection chip → SearchFiltersChanged avec bons departure/arrival',
      (tester) async {
        when(() => announcementBloc.state).thenReturn(
          AnnouncementListLoaded([
            _ann(
              id: 'a1',
              departure: 'Paris',
              arrival: 'Dakar',
              status: 'ACTIVE',
            ),
            _ann(
              id: 'a2',
              departure: 'Lyon',
              arrival: 'Abidjan',
              status: 'ACTIVE',
            ),
          ]),
        );

        await tester.pumpWidget(wrap());
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.textContaining('Lyon→Abidjan'));
        await tester.pump();

        verify(
          () => searchBloc.add(
            any(
              that: isA<SearchFiltersChanged>()
                  .having((e) => e.departure, 'departure', 'Lyon')
                  .having((e) => e.arrival, 'arrival', 'Abidjan'),
            ),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'état vide "Aucun trajet actif" quand AnnouncementListLoaded([])',
      (tester) async {
        when(
          () => announcementBloc.state,
        ).thenReturn(AnnouncementListLoaded([]));

        await tester.pumpWidget(wrap());
        await tester.pump(const Duration(milliseconds: 500));

        verifyNever(() => searchBloc.add(any()));

        expect(find.text('Aucun trajet actif'), findsOneWidget);
        expect(find.text('Publier un trajet'), findsOneWidget);
      },
    );

    testWidgets(
      'état vide "Aucun colis ne correspond" quand search loaded vide',
      (tester) async {
        when(
          () => announcementBloc.state,
        ).thenReturn(AnnouncementListLoaded([_ann()]));
        when(() => searchBloc.state).thenReturn(
          const PackageRequestSearchState(
            status: SearchStatus.loaded,
            results: [],
          ),
        );

        await tester.pumpWidget(wrap());
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.textContaining('Aucun colis ne correspond'),
          findsOneWidget,
        );
      },
    );

    testWidgets('tap carte → navigation vers /package-requests/:id/public', (
      tester,
    ) async {
      when(
        () => announcementBloc.state,
      ).thenReturn(AnnouncementListLoaded([_ann()]));
      when(() => searchBloc.state).thenReturn(
        PackageRequestSearchState(
          status: SearchStatus.loaded,
          results: [_searchItem()],
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byType(PackageRequestListCard));
      await tester.pumpAndSettle();

      expect(find.text('Détail colis'), findsOneWidget);
    });

    testWidgets('CapacityBanner affiche availableKg et totalKg de l\'annonce', (
      tester,
    ) async {
      when(() => announcementBloc.state).thenReturn(
        AnnouncementListLoaded([_ann(availableKg: 15.0, totalKg: 23.0)]),
      );

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('15.0 kg restants'), findsOneWidget);
      expect(find.textContaining('23.0 kg total'), findsOneWidget);
    });

    testWidgets('spinner footer affiché en état loadingMore', (tester) async {
      when(
        () => announcementBloc.state,
      ).thenReturn(AnnouncementListLoaded([_ann()]));
      when(() => searchBloc.state).thenReturn(
        PackageRequestSearchState(
          status: SearchStatus.loadingMore,
          results: [_searchItem()],
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
