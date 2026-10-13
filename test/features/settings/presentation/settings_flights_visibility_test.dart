import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/config/flights_flag.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/flights/bloc/flight_alert_updates.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/bloc/flight_alerts_pause_cubit.dart';
import 'package:dony/features/settings/bloc/flights_visibility_cubit.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppPreferencesBloc
    extends MockBloc<AppPreferencesEvent, AppPreferencesState>
    implements AppPreferencesBloc {}

class _MockBox extends Mock implements Box<dynamic> {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockFlightsRepository extends Mock implements FlightsRepository {}

FlightAlert _alert(String id, {bool active = true}) => FlightAlert(
  id: id,
  originCode: 'PAR',
  destinationCode: 'ABJ',
  directOnly: false,
  maxPrice: 450,
  currency: 'EUR',
  active: active,
);

Widget _wrap() {
  final prefsBloc = _MockAppPreferencesBloc();
  when(
    () => prefsBloc.state,
  ).thenReturn(const AppPreferencesState(preferences: UserPreferencesModel()));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<AppPreferencesBloc>.value(
          value: prefsBloc,
          child: const SettingsScreen(),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockBox box;
  late _MockAnalyticsService analytics;
  late FlightsVisibilityCubit cubit;

  setUp(() {
    box = _MockBox();
    when(
      () => box.get(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = FlightsVisibilityCubit(box, analytics);
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerSingleton<FlightsVisibilityCubit>(cubit);
  });

  tearDown(() async {
    resetFlightsFlagForTest();
    await cubit.close();
    await getIt.reset();
  });

  const tile = Key('settings-flights-visible');
  const toggle = Key('settings-flights-visible-switch');

  testWidgets('flag éteint : pas d\'interrupteur des billets', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(tile), findsNothing);
    expect(find.text('Afficher les billets d\'avion'), findsNothing);
  });

  testWidgets('flag allumé : interrupteur activé dans Apparence', (
    tester,
  ) async {
    setFlightsEnabled(true);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(tile), findsOneWidget);
    expect(find.text('Afficher les billets d\'avion'), findsOneWidget);
    expect(
      find.text('Bons plans et alertes prix dans Activités'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byKey(toggle)).value, isTrue);
    // Sous le thème, avant la section Langue.
    expect(
      tester.getTopLeft(find.byKey(tile)).dy,
      greaterThan(tester.getTopLeft(find.text('Thème')).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(tile)).dy,
      lessThan(tester.getTopLeft(find.text('LANGUE & COMMUNICATION')).dy),
    );
  });

  testWidgets('l\'interrupteur masque puis réaffiche, et persiste', (
    tester,
  ) async {
    setFlightsEnabled(true);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(toggle));
    await tester.pumpAndSettle();
    expect(cubit.state, isFalse);
    expect(tester.widget<Switch>(find.byKey(toggle)).value, isFalse);
    verify(() => box.put(HiveService.kFlightsVisible, false)).called(1);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.settingsFlightsVisibilityChanged,
        properties: {'visible': false},
      ),
    ).called(1);

    // Toucher la ligne bascule aussi.
    await tester.tap(find.text('Afficher les billets d\'avion'));
    await tester.pumpAndSettle();
    expect(cubit.state, isTrue);
    verify(() => box.put(HiveService.kFlightsVisible, true)).called(1);
  });

  group('mise en pause des alertes au masquage', () {
    late _MockFlightsRepository repository;
    late FlightAlertUpdates updates;

    const confirm = Key('flight-alerts-pause-confirm');
    const keep = Key('flight-alerts-pause-keep');

    setUp(() {
      repository = _MockFlightsRepository();
      updates = FlightAlertUpdates();
      when(() => repository.alerts()).thenAnswer(
        (_) async => [_alert('a'), _alert('b', active: false), _alert('c')],
      );
      when(() => repository.setAlertActive(any(), any())).thenAnswer(
        (inv) async =>
            _alert(inv.positionalArguments[0] as String, active: false),
      );
      getIt.registerFactory<FlightAlertsPauseCubit>(
        () => FlightAlertsPauseCubit(repository, analytics, updates: updates),
      );
      setFlightsEnabled(true);
    });

    tearDown(() => updates.dispose());

    Future<void> hide(WidgetTester tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
    }

    testWidgets('feuille avec le nombre d\'alertes, boutons fixés en bas', (
      tester,
    ) async {
      await hide(tester);

      // Le masquage n'attend pas la réponse.
      expect(cubit.state, isFalse);
      expect(find.text('Mettre aussi vos alertes prix en pause ?'), findsOne);
      expect(
        find.text(
          'Vous avez 2 alertes actives. Masquer les billets ne coupe pas '
          'leurs notifications. Vous pourrez les relancer depuis Mes alertes '
          'prix.',
        ),
        findsOneWidget,
      );
      final scroll = find.byType(SingleChildScrollView).last;
      expect(
        find.descendant(
          of: scroll,
          matching: find.byKey(const Key('flight-alerts-pause-body')),
        ),
        findsOneWidget,
      );
      for (final key in [confirm, keep]) {
        expect(find.byKey(key), findsOneWidget);
        expect(
          find.descendant(of: scroll, matching: find.byKey(key)),
          findsNothing,
        );
      }
    });

    testWidgets('« Mettre en pause » : PATCH, fermeture, confirmation', (
      tester,
    ) async {
      await hide(tester);
      await tester.tap(find.byKey(confirm));
      await tester.pumpAndSettle();

      verify(() => repository.setAlertActive('a', false)).called(1);
      verify(() => repository.setAlertActive('c', false)).called(1);
      verifyNever(() => repository.setAlertActive('b', any()));
      expect(find.byKey(confirm), findsNothing);
      expect(find.text('2 alertes mises en pause'), findsOneWidget);
      expect(cubit.state, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('bouton en chargement pendant la pause', (tester) async {
      final pending = Completer<FlightAlert>();
      when(
        () => repository.setAlertActive('a', false),
      ).thenAnswer((_) => pending.future);
      await hide(tester);

      await tester.tap(find.byKey(confirm));
      await tester.pump();
      expect(tester.widget<DonyButton>(find.byKey(confirm)).isLoading, isTrue);
      expect(tester.widget<DonyButton>(find.byKey(keep)).onPressed, isNull);

      pending.complete(_alert('a', active: false));
      await tester.pumpAndSettle();
      expect(find.byKey(confirm), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('échec partiel : snackbar d\'erreur', (tester) async {
      when(() => repository.setAlertActive('c', false)).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );
      await hide(tester);
      await tester.tap(find.byKey(confirm));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Certaines alertes n\'ont pas pu être mises en pause. Réessayez '
          'depuis Mes alertes prix.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('« Garder les alertes » : aucun PATCH, billets masqués', (
      tester,
    ) async {
      await hide(tester);
      await tester.tap(find.byKey(keep));
      await tester.pumpAndSettle();

      expect(find.byKey(keep), findsNothing);
      verifyNever(() => repository.setAlertActive(any(), any()));
      expect(cubit.state, isFalse);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.settingsFlightsAlertsPausePrompt,
          properties: {'active_count': 2, 'choice': 'keep'},
        ),
      ).called(1);
    });

    testWidgets('fermée par geste : alertes gardées', (tester) async {
      await hide(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byKey(keep), findsNothing);
      verifyNever(() => repository.setAlertActive(any(), any()));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.settingsFlightsAlertsPausePrompt,
          properties: {'active_count': 2, 'choice': 'dismiss'},
        ),
      ).called(1);
    });

    testWidgets('aucune alerte active : masqué sans feuille', (tester) async {
      when(
        () => repository.alerts(),
      ).thenAnswer((_) async => [_alert('a', active: false)]);
      await hide(tester);

      expect(cubit.state, isFalse);
      expect(find.byKey(confirm), findsNothing);
    });

    testWidgets('hors ligne : masqué sans feuille', (tester) async {
      when(() => repository.alerts()).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );
      await hide(tester);

      expect(cubit.state, isFalse);
      expect(find.byKey(confirm), findsNothing);
    });

    testWidgets('réactiver : ni lecture ni relance des alertes', (
      tester,
    ) async {
      when(() => repository.alerts()).thenAnswer((_) async => []);
      await hide(tester);
      clearInteractions(repository);

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();

      expect(cubit.state, isTrue);
      verifyZeroInteractions(repository);
      expect(find.byKey(confirm), findsNothing);
    });

    testWidgets('réaffichés pendant la lecture : pas de feuille', (
      tester,
    ) async {
      final pending = Completer<List<FlightAlert>>();
      when(() => repository.alerts()).thenAnswer((_) => pending.future);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(toggle));
      await tester.pump();
      await tester.tap(find.byKey(toggle));
      await tester.pump();

      pending.complete([_alert('a')]);
      await tester.pumpAndSettle();

      expect(cubit.state, isTrue);
      expect(find.byKey(confirm), findsNothing);
    });
  });
}
