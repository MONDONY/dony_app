import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_segmented_control.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:dony/features/profile/bloc/open_listings_cubit.dart';
import 'package:dony/features/profile/data/models/open_listing.dart';
import 'package:dony/features/profile/presentation/widgets/open_listings_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../data/models/open_listing_test.dart' show requestJson, tripJson;

class _MockOpenListingsCubit extends MockCubit<OpenListingsState>
    implements OpenListingsCubit {}

String _ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();

OpenListing _trip({Duration age = const Duration(days: 2)}) =>
    OpenListing.fromJson({
      'kind': 'TRIP',
      'publishedAt': _ago(age),
      'trip': tripJson(),
    })!;

OpenListing _request({Duration age = const Duration(days: 1)}) =>
    OpenListing.fromJson({
      'kind': 'REQUEST',
      'publishedAt': _ago(age),
      'request': requestJson(),
    })!;

void main() {
  late _MockOpenListingsCubit cubit;

  setUpAll(() => initializeDateFormatting('fr'));

  setUp(() {
    cubit = _MockOpenListingsCubit();
    registerFallbackValue(OpenListingsFilter.all);
  });

  Future<void> pump(
    WidgetTester tester, {
    required OpenListingsState state,
    bool withCubit = true,
  }) async {
    when(() => cubit.state).thenReturn(state);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: withCubit
                  ? BlocProvider<OpenListingsCubit>.value(
                      value: cubit,
                      child: const OpenListingsSection(),
                    )
                  : const OpenListingsSection(),
            ),
          ),
        ),
        GoRoute(
          path: '/package-requests/:id/public',
          builder: (_, s) => Text('detail ${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('sans cubit fourni, la section ne montre rien', (tester) async {
    await pump(tester, state: const OpenListingsInitial(), withCubit: false);

    expect(find.text('EN COURS'), findsNothing);
  });

  testWidgets('avant le chargement et après un échec, rien n\'est affiché', (
    tester,
  ) async {
    await pump(tester, state: const OpenListingsInitial());
    expect(find.text('EN COURS'), findsNothing);

    await pump(tester, state: const OpenListingsFailed());
    expect(find.text('EN COURS'), findsNothing);
  });

  testWidgets('pendant le chargement : titre et indicateur', (tester) async {
    await pump(tester, state: const OpenListingsLoading());

    expect(find.text('EN COURS'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('aucune annonce : message d\'état vide, pas de filtre', (
    tester,
  ) async {
    await pump(tester, state: const OpenListingsLoaded(items: []));

    expect(find.text('EN COURS'), findsOneWidget);
    expect(find.text('Rien en cours pour le moment.'), findsOneWidget);
    expect(find.byType(DonySegmentedControl<OpenListingsFilter>), findsNothing);
  });

  testWidgets(
    'trajets et demandes mélangés : filtre, compteur et date de publication',
    (tester) async {
      await pump(
        tester,
        state: OpenListingsLoaded(items: [_request(), _trip()]),
      );

      expect(find.text('2'), findsOneWidget);
      expect(
        find.byType(DonySegmentedControl<OpenListingsFilter>),
        findsOneWidget,
      );
      expect(find.byType(PackageRequestListCard), findsOneWidget);
      expect(find.byType(TravelerCard), findsOneWidget);
      expect(find.text('En ligne hier'), findsOneWidget);
      expect(find.text('En ligne il y a 2 j'), findsOneWidget);

      // La demande (publiée hier) est au-dessus du trajet (il y a 2 jours).
      expect(
        tester.getTopLeft(find.byType(PackageRequestListCard)).dy,
        lessThan(tester.getTopLeft(find.byType(TravelerCard)).dy),
      );
    },
  );

  testWidgets(
    'section repliée : l\'en-tête et le compteur restent, les cartes disparaissent',
    (tester) async {
      await pump(
        tester,
        state: OpenListingsLoaded(
          items: [_request(), _trip()],
          expanded: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EN COURS'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byKey(const Key('open-listings-chevron')), findsOneWidget);
      expect(find.byType(PackageRequestListCard), findsNothing);
      expect(find.byType(TravelerCard), findsNothing);
      expect(
        find.byType(DonySegmentedControl<OpenListingsFilter>),
        findsNothing,
      );
    },
  );

  testWidgets('toucher l\'en-tête demande la bascule au cubit', (tester) async {
    await pump(tester, state: OpenListingsLoaded(items: [_request(), _trip()]));

    await tester.tap(find.byKey(const Key('open-listings-header')));

    verify(() => cubit.toggleExpanded()).called(1);
  });

  testWidgets('l\'en-tête fait au moins 44 pt de haut (zone tactile)', (
    tester,
  ) async {
    await pump(tester, state: OpenListingsLoaded(items: [_trip()]));

    expect(
      tester.getSize(find.byKey(const Key('open-listings-header'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('accessibilité : l\'indication suit l\'état replié ou déplié', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, state: OpenListingsLoaded(items: [_trip()]));
    expect(
      tester.getSemantics(find.bySemanticsLabel('En cours')).hint,
      'Replier la section',
    );

    await pump(
      tester,
      state: OpenListingsLoaded(items: [_trip()], expanded: false),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('En cours')).hint,
      'Déplier la section',
    );
    handle.dispose();
  });

  testWidgets('pendant le chargement, l\'en-tête est inerte', (tester) async {
    await pump(tester, state: const OpenListingsLoading());

    expect(find.byKey(const Key('open-listings-header')), findsNothing);
    expect(find.byKey(const Key('open-listings-chevron')), findsNothing);
  });

  testWidgets('toucher « Trajets » demande le filtre au cubit', (tester) async {
    await pump(tester, state: OpenListingsLoaded(items: [_request(), _trip()]));

    await tester.tap(find.textContaining('Trajets'));

    verify(() => cubit.selectFilter(OpenListingsFilter.trips)).called(1);
  });

  testWidgets('le filtre « Demandes » ne laisse que les demandes', (
    tester,
  ) async {
    await pump(
      tester,
      state: OpenListingsLoaded(
        items: [_request(), _trip()],
        filter: OpenListingsFilter.requests,
      ),
    );

    expect(find.byType(PackageRequestListCard), findsOneWidget);
    expect(find.byType(TravelerCard), findsNothing);
  });

  testWidgets('un seul type d\'annonce : pas de filtre à afficher', (
    tester,
  ) async {
    await pump(tester, state: OpenListingsLoaded(items: [_trip()]));

    expect(find.byType(DonySegmentedControl<OpenListingsFilter>), findsNothing);
    expect(find.byType(TravelerCard), findsOneWidget);
  });

  testWidgets('toucher une demande la mesure et ouvre sa fiche publique', (
    tester,
  ) async {
    await pump(tester, state: OpenListingsLoaded(items: [_request()]));

    await tester.tap(find.byType(PackageRequestListCard));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    verify(() => cubit.trackOpened('request')).called(1);
    expect(find.text('detail pr-1'), findsOneWidget);
  });
}
