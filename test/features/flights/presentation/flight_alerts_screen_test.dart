import 'package:dony/core/di/injection.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/presentation/flight_alerts_screen.dart';
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
    expect(tester.takeException(), isNull);
  });
}
