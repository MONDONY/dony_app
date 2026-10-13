import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/flights/bloc/flight_places_cubit.dart';
import 'package:dony/features/flights/bloc/flight_route_picker_cubit.dart';
import 'package:dony/features/flights/data/datasources/flight_locator.dart';
import 'package:dony/features/flights/data/datasources/flight_recent_store.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:dony/features/flights/presentation/flight_city_picker_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../bloc/flights_test_doubles.dart';

class _Locator implements FlightLocator {
  _Locator({this.place});

  final FlightPlace? place;

  @override
  Future<bool> canLocate() async => true;

  @override
  Future<FlightPlace?> nearestCity() async => place;
}

const _paris = FlightPlace(code: 'PAR', name: 'Paris', countryCode: 'FR');

void main() {
  late MockFlightsRepository repository;
  late FlightLocator locator;
  late MemoryFlightRecentStore recents;
  FlightRoutePick? popped;
  var poppedOnce = false;

  setUp(() {
    repository = MockFlightsRepository();
    locator = _Locator();
    popped = null;
    poppedOnce = false;
    recents = MemoryFlightRecentStore([
      FlightRecentSearch(
        origin: _paris,
        destination: const FlightPlace(
          code: 'ABJ',
          name: 'Abidjan',
          countryCode: 'CI',
        ),
        searchedAt: DateTime(2026, 10, 10),
      ),
    ]);
    if (getIt.isRegistered<FlightPlacesCubit>()) {
      getIt.unregister<FlightPlacesCubit>();
    }
    getIt.registerFactory<FlightPlacesCubit>(
      () => FlightPlacesCubit(
        repository,
        debounce: Duration.zero,
        recents: recents,
        locator: locator,
      ),
    );
    if (getIt.isRegistered<FlightRoutePickerCubit>()) {
      getIt.unregister<FlightRoutePickerCubit>();
    }
    getIt.registerFactoryParam<
      FlightRoutePickerCubit,
      FlightRoutePickerArgs,
      void
    >((args, _) => FlightRoutePickerCubit(args));
  });

  tearDown(() {
    getIt
      ..unregister<FlightPlacesCubit>()
      ..unregister<FlightRoutePickerCubit>();
  });

  Future<void> open(
    WidgetTester tester,
    FlightRoutePickerArgs args, {
    Locale locale = AppL10n.fr,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await pickFlightRoute(context, args);
                poppedOnce = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
        GoRoute(
          path: '/flights/city',
          builder: (_, state) => FlightCityPickerScreen(
            args: state.extra! as FlightRoutePickerArgs,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'destination : récentes, diaspora sans doublon, drapeau et code',
    (tester) async {
      await open(
        tester,
        const FlightRoutePickerArgs(origin: _paris, departure: false),
      );

      expect(find.text('Où allez-vous ?'), findsOneWidget);
      expect(find.text('PAR · Paris, France'), findsOneWidget);
      expect(find.text('DESTINATIONS RÉCENTES'), findsOneWidget);
      expect(find.byKey(const Key('flight-city-recent-ABJ')), findsOneWidget);
      // Abidjan, déjà en récentes, et Paris, déjà au départ, ne sont pas
      // reproposées.
      expect(find.byKey(const Key('flight-city-ABJ')), findsNothing);
      expect(find.byKey(const Key('flight-city-PAR')), findsNothing);
      expect(find.text('Côte d\'Ivoire'), findsOneWidget);
      // Pas de position pour une destination.
      expect(find.byKey(const Key('flight-city-locate')), findsNothing);

      await tester.tap(find.byKey(const Key('flight-city-recent-ABJ')));
      await tester.pumpAndSettle();

      expect(poppedOnce, isTrue);
      expect(popped?.destination?.code, 'ABJ');
      expect(popped?.origin, _paris);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('frappe : résultats du back, puis aucun, puis erreur', (
    tester,
  ) async {
    when(() => repository.places('bam')).thenAnswer(
      (_) async => const [
        FlightPlace(
          code: 'BKO',
          name: 'Bamako',
          countryCode: 'ML',
          countryName: 'Mali',
        ),
      ],
    );
    when(() => repository.places('zzz')).thenAnswer((_) async => const []);
    when(() => repository.places('err')).thenThrow(Exception('offline'));
    await open(
      tester,
      const FlightRoutePickerArgs(origin: _paris, departure: false),
    );

    await tester.enterText(find.byKey(const Key('flight-city-field')), 'bam');
    await tester.pumpAndSettle();
    expect(find.text('RÉSULTATS'), findsOneWidget);
    expect(find.byKey(const Key('flight-city-BKO')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('flight-city-field')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucune ville trouvée'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('flight-city-field')), 'err');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-city-BKO')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('départ vide : la ville choisie passe au champ destination', (
    tester,
  ) async {
    await open(tester, const FlightRoutePickerArgs(departure: true));

    expect(find.byKey(const Key('flight-city-locate')), findsOneWidget);
    expect(find.text('DÉPARTS RÉCENTS'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-city-recent-PAR')));
    await tester.pumpAndSettle();

    // Toujours ouvert, maintenant sur la destination.
    expect(find.text('Où allez-vous ?'), findsOneWidget);
    // En-tête Yadony standard, titre centré, scarabée.
    expect(find.byType(DonyAppBar), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
    expect(find.text('DESTINATIONS DE LA DIASPORA'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-city-DKR')));
    await tester.pumpAndSettle();
    expect(popped?.origin?.code, 'PAR');
    expect(popped?.destination?.code, 'DKR');
  });

  testWidgets('changer de champ, puis retour sans rien choisir : rien', (
    tester,
  ) async {
    await open(
      tester,
      const FlightRoutePickerArgs(origin: _paris, departure: false),
    );

    await tester.tap(find.byKey(const Key('flight-city-origin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-city-locate')), findsOneWidget);

    await tester.tap(find.byType(DonyAppBarBackButton));
    await tester.pumpAndSettle();
    expect(poppedOnce, isTrue);
    expect(popped, isNull);
  });

  testWidgets('ma position : ville proche choisie, sinon message', (
    tester,
  ) async {
    await open(tester, const FlightRoutePickerArgs(departure: true));
    await tester.tap(find.byKey(const Key('flight-city-locate')));
    await tester.pumpAndSettle();
    expect(find.text('Aucun aéroport trouvé près de vous.'), findsOneWidget);

    locator = _Locator(
      place: const FlightPlace(code: 'LYS', name: 'Lyon'),
    );
    await tester.pumpWidget(const SizedBox());
    await open(
      tester,
      const FlightRoutePickerArgs(
        destination: FlightPlace(code: 'ABJ', name: 'Abidjan'),
        departure: true,
      ),
    );
    await tester.tap(find.byKey(const Key('flight-city-locate')));
    await tester.pumpAndSettle();
    expect(popped?.origin?.code, 'LYS');
    expect(popped?.destination?.code, 'ABJ');
  });

  testWidgets('en anglais', (tester) async {
    enableEnglish();
    await open(
      tester,
      const FlightRoutePickerArgs(origin: _paris, departure: false),
      locale: const Locale('en'),
    );
    expect(find.text('Where are you going?'), findsOneWidget);
    expect(find.text('DIASPORA DESTINATIONS'), findsOneWidget);
  });
}
