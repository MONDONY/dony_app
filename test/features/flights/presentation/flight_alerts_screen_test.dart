import 'package:dony/core/di/injection.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/presentation/flight_alerts_screen.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../bloc/flights_test_doubles.dart';

void main() {
  late MockFlightsRepository repository;

  setUp(() {
    repository = MockFlightsRepository();
    if (getIt.isRegistered<FlightAlertsCubit>()) {
      getIt.unregister<FlightAlertsCubit>();
    }
    getIt.registerFactory<FlightAlertsCubit>(
      () => FlightAlertsCubit(repository, silentAnalytics()),
    );
  });

  tearDown(() => getIt.unregister<FlightAlertsCubit>());

  testWidgets('liste : trajet, période, seuil et dernier prix', (tester) async {
    when(() => repository.alerts()).thenAnswer(
      (_) async => [
        FlightAlert(
          id: 'a1',
          originCode: 'PAR',
          destinationCode: 'ABJ',
          originLabel: 'Paris',
          destinationLabel: 'Abidjan',
          departureFrom: DateTime(2026, 12, 12),
          departureTo: DateTime(2026, 12, 31),
          returnFrom: DateTime(2027, 1, 2),
          returnTo: DateTime(2027, 1, 15),
          directOnly: false,
          maxPrice: 450,
          currency: 'EUR',
          active: true,
          lastSeenPrice: 431,
        ),
      ],
    );

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Mes alertes prix'), findsOneWidget);
    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(find.textContaining('Départ du'), findsOneWidget);
    expect(find.textContaining('Retour du'), findsOneWidget);
    expect(find.text('1 sur 10'), findsOneWidget);
    expect(find.byKey(const Key('flight-alerts-new')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aucune alerte : état vide avec bouton de création', (
    tester,
  ) async {
    when(() => repository.alerts()).thenAnswer((_) async => const []);

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Aucune alerte prix'), findsOneWidget);
    // L'état vide porte déjà son bouton : pas de second bouton flottant.
    expect(find.byKey(const Key('flight-alerts-new')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chargement : squelettes, puis interrupteur Yadony', (
    tester,
  ) async {
    const alert = FlightAlert(
      id: 'a1',
      originCode: 'PAR',
      destinationCode: 'ABJ',
      directOnly: true,
      maxPrice: 450,
      currency: 'EUR',
      active: true,
    );
    when(() => repository.alerts()).thenAnswer((_) async => [alert]);
    when(
      () => repository.setAlertActive('a1', false),
    ).thenAnswer((_) async => alert.copyWith(active: false));

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    expect(find.byKey(const Key('flight-alerts-loading')), findsOneWidget);
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('flight-alert-switch-a1'));
    expect(tester.widget<FlightToggle>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<FlightToggle>(toggle).value, isFalse);
    verify(() => repository.setAlertActive('a1', false)).called(1);
  });

  testWidgets('premier chargement en échec : erreur puis réessayer', (
    tester,
  ) async {
    var calls = 0;
    when(() => repository.alerts()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return const [];
    });

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune alerte prix'), findsOneWidget);
  });

  testWidgets('état vide : le bouton ouvre la feuille de création', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    when(() => repository.alerts()).thenAnswer((_) async => const []);

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle alerte').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-alert-submit')), findsOneWidget);
  });

  testWidgets('glisser supprime ; une bascule refusée affiche l\'erreur', (
    tester,
  ) async {
    final alerts = [
      for (final id in ['a1', 'a2'])
        FlightAlert(
          id: id,
          originCode: 'PAR',
          destinationCode: 'ABJ',
          directOnly: false,
          maxPrice: 450,
          currency: 'EUR',
          active: true,
        ),
    ];
    when(() => repository.alerts()).thenAnswer((_) async => alerts);
    when(() => repository.deleteAlert('a1')).thenAnswer((_) async {});
    when(
      () => repository.setAlertActive('a2', false),
    ).thenThrow(Exception('offline'));

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('2 sur 10'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('flight-alert-switch-a1')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    verify(() => repository.deleteAlert('a1')).called(1);
    expect(find.byKey(const Key('flight-alert-switch-a1')), findsNothing);

    await tester.tap(find.byKey(const Key('flight-alert-switch-a2')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
