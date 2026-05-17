// Tests B1 — Autocomplétion ville en liste inline (non masquée par sticky button).
// Vérifie que les suggestions s'affichent dans le flux scrollable (pas en Overlay)
// et qu'un tap sur une suggestion remplit le champ + ferme la liste.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

// Villes de test
const _dakar = CityModel(
  name: 'Dakar',
  countryCode: 'SN',
  countryName: 'Sénégal',
  lat: 14.72,
  lng: -17.47,
);

const _abidjan = CityModel(
  name: 'Abidjan',
  countryCode: 'CI',
  countryName: 'Côte d\'Ivoire',
  lat: 5.34,
  lng: -4.01,
);

Widget _buildSubject({
  required MockCitySearchBloc departureCityBloc,
  required MockCitySearchBloc arrivalCityBloc,
}) {
  final departureCityNotifier = ValueNotifier<String?>(null);
  final arrivalCityNotifier = ValueNotifier<String?>(null);
  final departureDateNotifier = ValueNotifier<DateTime?>(null);
  final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final transportModeNotifier = ValueNotifier<TransportMode?>(null);

  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TrajetStep(
          departureCityNotifier: departureCityNotifier,
          arrivalCityNotifier: arrivalCityNotifier,
          departureDateNotifier: departureDateNotifier,
          departureTimeNotifier: departureTimeNotifier,
          arrivalTimeNotifier: arrivalTimeNotifier,
          transportModeNotifier: transportModeNotifier,
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
          onSelectDepartureTime: () async {},
          onSelectArrivalTime: () async {},
          onSelectDate: () async {},
        ),
      ),
    ),
  );
}

void main() {
  late MockCitySearchBloc departureCityBloc;
  late MockCitySearchBloc arrivalCityBloc;

  setUp(() {
    departureCityBloc = MockCitySearchBloc();
    arrivalCityBloc = MockCitySearchBloc();

    // État initial par défaut
    when(() => departureCityBloc.state).thenReturn(const CitySearchInitial());
    when(() => arrivalCityBloc.state).thenReturn(const CitySearchInitial());
  });

  tearDown(() {
    departureCityBloc.close();
    arrivalCityBloc.close();
  });

  group('B1 — Suggestions ville inline', () {
    testWidgets(
      'les suggestions de ville s\'affichent sous le champ arrivée',
      (tester) async {
        // Émettre CitySearchLoaded pour le bloc arrivée
        whenListen(
          arrivalCityBloc,
          Stream.fromIterable([
            const CitySearchInitial(),
            CitySearchLoaded(const [_dakar, _abidjan]),
          ]),
          initialState: const CitySearchInitial(),
        );

        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));

        // Taper dans le champ ville d'arrivée
        await tester.enterText(
          find.byKey(const Key('arrivalCityField')),
          'Dak',
        );
        // Laisser passer le debounce + les émissions du stream
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        // La suggestion doit être visible dans le flux (pas en Overlay)
        expect(find.text('Dakar'), findsOneWidget);
        expect(find.text('Abidjan'), findsOneWidget);

        // B1 structural check — la suggestion n'est pas enfant d'un ClipRRect
        expect(
          find.ancestor(
            of: find.text('Dakar'),
            matching: find.byType(ClipRRect),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'toucher une suggestion remplit le champ et ferme la liste',
      (tester) async {
        // StreamController manuel pour contrôler précisément le timing des états
        final controller = StreamController<CitySearchState>();

        // État initial : Initial
        when(() => arrivalCityBloc.state).thenReturn(const CitySearchInitial());
        whenListen(
          arrivalCityBloc,
          controller.stream,
          initialState: const CitySearchInitial(),
        );

        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));

        // Émettre les suggestions
        controller.add(CitySearchLoaded(const [_dakar]));
        await tester.pump();
        await tester.pump();

        // La suggestion Dakar est visible
        expect(find.text('Dakar'), findsOneWidget);

        // Simuler la sélection : le widget appelle CitySearchCleared → Initial
        controller.add(const CitySearchInitial());

        // Taper sur la suggestion
        await tester.tap(find.text('Dakar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Le champ est rempli avec "Dakar"
        final field = tester.widget<TextField>(
          find.byKey(const Key('arrivalCityField')),
        );
        expect(field.controller?.text, 'Dakar');

        // La liste est fermée : le BLoC est en CitySearchInitial → pas de suggestions
        // "Dakar" n'apparaît qu'une fois (dans le champ, plus dans la liste)
        expect(find.text('Dakar'), findsOneWidget);

        await controller.close();
      },
    );

    testWidgets(
      'les Keys departureCityField et arrivalCityField sont présentes',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
        // Laisser les animations initiales se terminer
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('departureCityField')), findsOneWidget);
        expect(find.byKey(const Key('arrivalCityField')), findsOneWidget);
      },
    );
  });
}
