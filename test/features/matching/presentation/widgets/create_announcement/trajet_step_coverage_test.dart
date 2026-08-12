// Tests complémentaires de couverture pour TrajetStep :
// - Corridor preview (affiché quand départ + arrivée sont renseignés)
// - _formatCorridorDateTime avec et sans heures
// - Transport chip snackbar pour modes non-avion
// - Transport chip sélection avion
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_recent_city_store.dart';

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

/// Construit l'arbre host avec des ValueNotifier configurables.
Widget _buildWithValues({
  String? departureCity,
  String? arrivalCity,
  DateTime? departureDate,
  TimeOfDay? departureTime,
  TimeOfDay? arrivalTime,
  TransportMode? transportMode,
  required MockCitySearchBloc departureCityBloc,
  required MockCitySearchBloc arrivalCityBloc,
}) {
  final departureCityNotifier = ValueNotifier<String?>(departureCity);
  final arrivalCityNotifier = ValueNotifier<String?>(arrivalCity);
  final departureDateNotifier = ValueNotifier<DateTime?>(departureDate);
  final departureTimeNotifier = ValueNotifier<TimeOfDay?>(departureTime);
  final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(arrivalTime);
  final transportModeNotifier = ValueNotifier<TransportMode?>(transportMode);

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
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerCityFallbackValues();
  });

  late MockCitySearchBloc departureCityBloc;
  late MockCitySearchBloc arrivalCityBloc;

  setUp(() {
    departureCityBloc = MockCitySearchBloc();
    arrivalCityBloc = MockCitySearchBloc();
    when(() => departureCityBloc.state).thenReturn(const CitySearchInitial());
    when(() => arrivalCityBloc.state).thenReturn(const CitySearchInitial());
    registerFakeRecentCityStore();
  });

  tearDown(() {
    departureCityBloc.close();
    arrivalCityBloc.close();
    unregisterFakeRecentCityStore();
  });

  group('Corridor preview', () {
    testWidgets(
      'le corridor preview est masqué quand départ et arrivée sont vides',
      (tester) async {
        await tester.pumpWidget(
          _buildWithValues(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        // Pas de "Confirmé" car les deux villes sont null
        expect(find.text('Confirmé'), findsNothing);
      },
    );

    testWidgets(
      'le corridor preview est masqué quand seul le départ est renseigné',
      (tester) async {
        await tester.pumpWidget(
          _buildWithValues(
            departureCity: 'Paris',
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Confirmé'), findsNothing);
      },
    );

    testWidgets(
      'le corridor preview affiche "Confirmé" quand départ ET arrivée sont renseignés',
      (tester) async {
        await tester.pumpWidget(
          _buildWithValues(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.text('Confirmé'), findsOneWidget);
      },
    );

    testWidgets(
      'le corridor preview affiche les codes aéroport départ → arrivée',
      (tester) async {
        await tester.pumpWidget(
          _buildWithValues(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        // Les codes sont affichés sous la forme "CDG → DKR" ou similaire
        final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
        final corridorText = textWidgets.map((t) => t.data ?? '').join(' ');
        expect(corridorText.contains('→'), isTrue);
      },
    );

    testWidgets(
      '_formatCorridorDateTime — retourne "" quand date est null (pas de ligne de date)',
      (tester) async {
        // Avec date null, la ligne dateStr est vide → if (dateStr.isNotEmpty) ne passe pas
        // Le corridor preview affiche uniquement les codes aéroport + "Confirmé".
        await tester.pumpWidget(
          _buildWithValues(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            // pas de date → dateStr == '' → pas de Text(dateStr)
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        // "Confirmé" visible (corridor preview affiché car dep+arr renseignés)
        expect(find.text('Confirmé'), findsOneWidget);
      },
    );

    testWidgets(
      '_formatCorridorDateTime — affiche la date formatée quand date seule est fournie',
      (tester) async {
        await tester.pumpWidget(
          _buildWithValues(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureDate: DateTime(2026, 8, 15),
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        // "Confirmé" est visible et la ligne de date est présente.
        // La date en fr serait "sam. 15 août" → check the Text widgets for date content.
        expect(find.text('Confirmé'), findsOneWidget);
        // Le corridor preview inclut un Text avec la date formatée (non vide)
        final dateTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
          final d = t.data ?? '';
          return d.contains('15') ||
              d.contains('août') ||
              d.contains('2026') ||
              d.contains('sam');
        }).toList();
        expect(
          dateTexts,
          isNotEmpty,
          reason: 'La date doit être affichée dans le corridor preview',
        );
      },
    );

    testWidgets(
      '_formatCorridorDateTime — affiche date et heure départ quand heure est fournie',
      (tester) async {
        await tester.pumpWidget(
          _buildWithValues(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureDate: DateTime(2026, 8, 15),
            departureTime: const TimeOfDay(hour: 10, minute: 0),
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        // La chaîne formatée inclut "10h"
        final textContents = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ');
        expect(
          textContents.contains('10h'),
          isTrue,
          reason: 'L\'heure 10h doit apparaître dans le corridor preview',
        );
      },
    );

    testWidgets(
      '_formatCorridorDateTime — affiche intervalle heure départ–arrivée quand les deux heures sont fournies',
      (tester) async {
        await tester.pumpWidget(
          _buildWithValues(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureDate: DateTime(2026, 8, 15),
            departureTime: const TimeOfDay(hour: 10, minute: 0),
            arrivalTime: const TimeOfDay(hour: 14, minute: 0),
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        final textContents = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ');
        // Les deux heures doivent apparaître
        expect(
          textContents.contains('10h'),
          isTrue,
          reason: 'Heure de départ 10h doit être dans le corridor',
        );
        expect(
          textContents.contains('14h'),
          isTrue,
          reason: 'Heure d\'arrivée 14h doit être dans le corridor',
        );
      },
    );
  });

  group('Transport chips', () {
    testWidgets('chip avion sélectionnable — tap met à jour le notifier', (
      tester,
    ) async {
      final transportNotifier = ValueNotifier<TransportMode?>(null);
      final departureCityNotifier = ValueNotifier<String?>(null);
      final arrivalCityNotifier = ValueNotifier<String?>(null);
      final departureDateNotifier = ValueNotifier<DateTime?>(null);
      final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
      final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrajetStep(
                departureCityNotifier: departureCityNotifier,
                arrivalCityNotifier: arrivalCityNotifier,
                departureDateNotifier: departureDateNotifier,
                departureTimeNotifier: departureTimeNotifier,
                arrivalTimeNotifier: arrivalTimeNotifier,
                transportModeNotifier: transportNotifier,
                departureCityBloc: departureCityBloc,
                arrivalCityBloc: arrivalCityBloc,
                onSelectDepartureTime: () async {},
                onSelectArrivalTime: () async {},
                onSelectDate: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Tapper sur le chip avion
      await tester.tap(find.byKey(const Key('transport-chip-plane')));
      await tester.pump();

      expect(transportNotifier.value, TransportMode.plane);
    });

    testWidgets(
      'chip non-avion désactivé — tap affiche un snackbar "Bientôt disponible"',
      (tester) async {
        final transportNotifier = ValueNotifier<TransportMode?>(null);
        final departureCityNotifier = ValueNotifier<String?>(null);
        final arrivalCityNotifier = ValueNotifier<String?>(null);
        final departureDateNotifier = ValueNotifier<DateTime?>(null);
        final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
        final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TrajetStep(
                  departureCityNotifier: departureCityNotifier,
                  arrivalCityNotifier: arrivalCityNotifier,
                  departureDateNotifier: departureDateNotifier,
                  departureTimeNotifier: departureTimeNotifier,
                  arrivalTimeNotifier: arrivalTimeNotifier,
                  transportModeNotifier: transportNotifier,
                  departureCityBloc: departureCityBloc,
                  arrivalCityBloc: arrivalCityBloc,
                  onSelectDepartureTime: () async {},
                  onSelectArrivalTime: () async {},
                  onSelectDate: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        // Tapper sur le chip voiture (non-avion)
        await tester.tap(find.byKey(const Key('transport-chip-car')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Le notifier n'a pas changé (avion seulement sélectionnable)
        expect(transportNotifier.value, isNull);
        // Le snackbar "Bientôt disponible" est visible
        expect(find.text('Bientôt disponible'), findsOneWidget);
      },
    );

    testWidgets(
      'tous les chips de transport sont présents (un par TransportMode)',
      (tester) async {
        await tester.pumpWidget(
          _buildWithValues(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        for (final mode in TransportMode.values) {
          expect(
            find.byKey(Key('transport-chip-${mode.name}')),
            findsOneWidget,
            reason: 'Le chip ${mode.name} doit être rendu',
          );
        }
      },
    );
  });

  group('Labels de section', () {
    testWidgets('le label "Trajet" est affiché', (tester) async {
      await tester.pumpWidget(
        _buildWithValues(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Trajet'), findsOneWidget);
    });

    testWidgets('le label "Mode de transport" est affiché', (tester) async {
      await tester.pumpWidget(
        _buildWithValues(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mode de transport'), findsOneWidget);
    });
  });
}
