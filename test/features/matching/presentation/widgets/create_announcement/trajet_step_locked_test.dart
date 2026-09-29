import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_recent_city_store.dart';

class _MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

/// Un champ verrouillé (édition, trajet dédié à une demande) n'avait qu'un
/// `onTap` vide : effet d'appui sans suite. Il explique désormais pourquoi.
void main() {
  late _MockCitySearchBloc departureBloc;
  late _MockCitySearchBloc arrivalBloc;

  setUpAll(() {
    initializeDateFormatting('fr');
    registerCityFallbackValues();
  });

  setUp(() {
    departureBloc = _MockCitySearchBloc();
    arrivalBloc = _MockCitySearchBloc();
    when(() => departureBloc.state).thenReturn(const CitySearchInitial());
    when(() => arrivalBloc.state).thenReturn(const CitySearchInitial());
    registerFakeRecentCityStore();
    DonySnackbar.clearDedup();
  });

  tearDown(() {
    departureBloc.close();
    arrivalBloc.close();
    unregisterFakeRecentCityStore();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrajetStep(
            departureCityNotifier: ValueNotifier<String?>('Paris'),
            arrivalCityNotifier: ValueNotifier<String?>('Dakar'),
            departureDateNotifier: ValueNotifier<DateTime?>(
              DateTime(2026, 10, 12),
            ),
            departureTimeNotifier: ValueNotifier<TimeOfDay?>(null),
            arrivalTimeNotifier: ValueNotifier<TimeOfDay?>(null),
            departureCityBloc: departureBloc,
            arrivalCityBloc: arrivalBloc,
            onSelectDepartureTime: () async {},
            onSelectArrivalTime: () async {},
            onSelectDate: () async => fail(
              'la date verrouillée ne doit pas '
              's\'ouvrir',
            ),
            lockCorridor: true,
            lockDate: true,
          ),
        ),
      ),
    ),
  );

  testWidgets('tap sur une ville verrouillée : message explicatif', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('departureCityField')));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Les villes de ce trajet ne peuvent plus être modifiées.'),
      findsOneWidget,
    );
    // Laisse expirer le minuteur d'affichage du snackbar.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('tap sur la date verrouillée : message, sans ouvrir le '
      'calendrier', (tester) async {
    await pump(tester);

    final dateField = find.textContaining('12 oct. 2026').first;
    await tester.ensureVisible(dateField);
    await tester.tap(dateField);
    await tester.pump();

    expect(
      find.text('La date de départ de ce trajet ne peut plus être modifiée.'),
      findsOneWidget,
    );
    // Laisse expirer le minuteur d'affichage du snackbar.
    await tester.pump(const Duration(seconds: 10));
  });
}
