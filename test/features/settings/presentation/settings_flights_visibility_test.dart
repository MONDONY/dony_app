import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/flights_flag.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
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
}
