// Tests B1 — Autocomplétion ville en liste inline (non masquée par sticky button).
// Vérifie que les suggestions s'affichent dans le flux scrollable (pas en Overlay)
// et qu'un tap sur une suggestion remplit le champ + ferme la liste.
//
// Tests M4 — Uniformité visuelle : les champs heure et date sont des
// DonyTextField.tappable (InputDecorator + InkWell, pas de clavier) et
// les champs ville sont des CityAutocompleteField avec le même InputDecoration.
//
// Tests M5 — Marquage requis : les champs Ville de départ, Ville d'arrivée
// et Date de départ affichent un astérisque rouge dans leur label.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_corridor_fields.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_recent_city_store.dart';

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
  String? departureCity,
  String? arrivalCity,
}) {
  final departureCityNotifier = ValueNotifier<String?>(departureCity);
  final arrivalCityNotifier = ValueNotifier<String?>(arrivalCity);
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

  setUpAll(() {
    initializeDateFormatting('fr');
    registerCityFallbackValues();
  });

  setUp(() {
    departureCityBloc = MockCitySearchBloc();
    arrivalCityBloc = MockCitySearchBloc();

    // État initial par défaut
    when(() => departureCityBloc.state).thenReturn(const CitySearchInitial());
    when(() => arrivalCityBloc.state).thenReturn(const CitySearchInitial());

    registerFakeRecentCityStore();
  });

  tearDown(() {
    departureCityBloc.close();
    arrivalCityBloc.close();
    unregisterFakeRecentCityStore();
  });

  group('M4 — Uniformité visuelle champs heure/date', () {
    testWidgets(
      'les champs heure et date sont rendus via DonyTextField.tappable (InputDecorator)',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Les trois DonyTextField.tappable ont leurs Keys stables
        expect(find.byKey(const Key('departureTimeField')), findsOneWidget);
        expect(find.byKey(const Key('arrivalTimeField')), findsOneWidget);
        expect(find.byKey(const Key('departureDateField')), findsOneWidget);

        // Les champs heure/date utilisent InputDecorator (pas TextField)
        // → au moins 3 InputDecorator présents (les 3 tappable)
        expect(find.byType(InputDecorator), findsAtLeastNWidgets(3));
      },
    );

    testWidgets('heure de départ requise (D1), heure d\'arrivée optionnelle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final depTime = tester.widget<DonyTextField>(
        find.byKey(const Key('departureTimeField')),
      );
      expect(depTime.label, 'Heure de départ');
      expect(depTime.requiredLabel, isTrue);

      // L'heure d'arrivée reste optionnelle.
      expect(find.text('Heure d\'arrivée (optionnel)'), findsOneWidget);
    });

    testWidgets(
      'tap sur le champ heure de départ déclenche onSelectDepartureTime',
      (tester) async {
        var called = false;
        final departureCityNotifier = ValueNotifier<String?>(null);
        final arrivalCityNotifier = ValueNotifier<String?>(null);
        final departureDateNotifier = ValueNotifier<DateTime?>(null);
        final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
        final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
        final transportModeNotifier = ValueNotifier<TransportMode?>(null);

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
                  transportModeNotifier: transportModeNotifier,
                  departureCityBloc: departureCityBloc,
                  arrivalCityBloc: arrivalCityBloc,
                  onSelectDepartureTime: () async {
                    called = true;
                  },
                  onSelectArrivalTime: () async {},
                  onSelectDate: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(const Key('departureTimeField')));
        await tester.pump();

        expect(called, isTrue);
      },
    );

    testWidgets('tap sur le champ date de départ déclenche onSelectDate', (
      tester,
    ) async {
      var called = false;
      final departureCityNotifier = ValueNotifier<String?>(null);
      final arrivalCityNotifier = ValueNotifier<String?>(null);
      final departureDateNotifier = ValueNotifier<DateTime?>(null);
      final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
      final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
      final transportModeNotifier = ValueNotifier<TransportMode?>(null);

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
                transportModeNotifier: transportModeNotifier,
                departureCityBloc: departureCityBloc,
                arrivalCityBloc: arrivalCityBloc,
                onSelectDepartureTime: () async {},
                onSelectArrivalTime: () async {},
                onSelectDate: () async {
                  called = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('departureDateField')));
      await tester.pump();

      expect(called, isTrue);
    });
  });

  group('M5 — Marquage champs requis (astérisque)', () {
    testWidgets('les champs requis affichent un astérisque dans leur label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Exactement 4 champs requis : ville de départ, ville d'arrivée,
      // date de départ, heure de départ (D1). Chacun affiche un TextSpan " *"
      // via Text.rich. find.textContaining(' *') matche chaque TextSpan
      // séparément, donc on attend exactement 4 occurrences.
      expect(find.textContaining(' *'), findsNWidgets(4));
    });

    testWidgets('le champ date de départ a requiredLabel true', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Le champ date de départ est un DonyTextField.tappable (required)
      // → son Key est présente et le widget est rendu
      final dateFinder = find.byKey(const Key('departureDateField'));
      expect(dateFinder, findsOneWidget);

      // Le widget DonyTextField.tappable avec requiredLabel
      // → on vérifie la propriété directement
      final dateField = tester.widget<DonyTextField>(dateFinder);
      expect(dateField.requiredLabel, isTrue);
      expect(dateField.label, 'Date de départ');
    });

    testWidgets(
      'seule l\'heure d\'arrivée est optionnelle (départ requis, D1)',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // L'heure d'arrivée reste le seul champ optionnel.
        expect(find.text('Heure d\'arrivée (optionnel)'), findsOneWidget);

        final donyTextFields = tester
            .widgetList<DonyTextField>(find.byType(DonyTextField))
            .toList();
        // 3 DonyTextField.tappable : 2 heures + 1 date
        expect(donyTextFields.length, 3);

        // Un seul champ optionnel (heure d'arrivée), sans requiredLabel.
        final optionalFields = donyTextFields
            .where((f) => f.label?.contains('optionnel') == true)
            .toList();
        expect(optionalFields.length, 1);
        expect(optionalFields.first.requiredLabel, isFalse);

        // Date de départ ET heure de départ sont requis (requiredLabel: true).
        final requiredTappables = donyTextFields
            .where(
              (f) =>
                  f.label == 'Date de départ' || f.label == 'Heure de départ',
            )
            .toList();
        expect(requiredTappables.length, 2);
        for (final f in requiredTappables) {
          expect(f.requiredLabel, isTrue);
        }
      },
    );
  });

  group('B1 — Suggestions ville inline', () {
    testWidgets('les suggestions de ville s\'affichent sous le champ arrivée', (
      tester,
    ) async {
      // Émettre CitySearchLoaded pour le bloc arrivée
      whenListen(
        arrivalCityBloc,
        Stream.fromIterable([
          const CitySearchInitial(),
          const CitySearchLoaded([_dakar, _abidjan]),
        ]),
        initialState: const CitySearchInitial(),
      );

      await tester.pumpWidget(
        _buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ),
      );

      // Taper dans le champ ville d'arrivée
      await tester.enterText(find.byKey(const Key('arrivalCityField')), 'Dak');
      // Laisser passer le debounce + les émissions du stream
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // La suggestion doit être visible dans le flux (pas en Overlay)
      expect(find.text('Dakar'), findsOneWidget);
      expect(find.text('Abidjan'), findsOneWidget);

      // B1 structural check — la suggestion n'est pas enfant d'un ClipRRect
      expect(
        find.ancestor(of: find.text('Dakar'), matching: find.byType(ClipRRect)),
        findsNothing,
      );
    });

    testWidgets('toucher une suggestion remplit le champ et ferme la liste', (
      tester,
    ) async {
      // StreamController manuel pour contrôler précisément le timing des états
      final controller = StreamController<CitySearchState>();

      // État initial : Initial
      when(() => arrivalCityBloc.state).thenReturn(const CitySearchInitial());
      whenListen(
        arrivalCityBloc,
        controller.stream,
        initialState: const CitySearchInitial(),
      );

      await tester.pumpWidget(
        _buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ),
      );

      // Émettre les suggestions
      controller.add(const CitySearchLoaded([_dakar]));
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
    });

    testWidgets(
      'les Keys departureCityField et arrivalCityField sont présentes',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        // Laisser les animations initiales se terminer
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('departureCityField')), findsOneWidget);
        expect(find.byKey(const Key('arrivalCityField')), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // P3 — Couleurs sémantiques arrivée (secondary) vs départ (primary)
  // P4 — Icône date utilise colorScheme.primary
  // ---------------------------------------------------------------------------
  group('P3/P4 — Couleurs sémantiques icônes départ/arrivée', () {
    testWidgets(
      'le corridor est rendu par la carte billet partagée CityCorridorFields',
      (tester) async {
        // Les deux villes ne sont plus deux champs isolés à emoji
        // décollage/atterrissage : elles partagent la carte « billet »
        // commune à la recherche et aux alertes, labels courts en capitales.
        await tester.pumpWidget(
          _buildSubject(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(CityCorridorFields), findsOneWidget);
        // `textContaining` et non `text` : le corridor est obligatoire ici,
        // donc le label porte l'astérisque (« DÉPART * »).
        expect(find.textContaining('DÉPART'), findsOneWidget);
        expect(find.textContaining('ARRIVÉE'), findsOneWidget);
      },
    );

    testWidgets('chaque ville sélectionnée affiche le drapeau de son pays', (
      tester,
    ) async {
      // Le drapeau remplace l'ancien emoji avion : il porte une information
      // (le pays), là où 🛫/🛬 ne faisait que redire le rôle du champ.
      await tester.pumpWidget(
        _buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
          departureCity: 'Paris',
          arrivalCity: 'Abidjan',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('🇫🇷'), findsOneWidget);
      expect(find.text('🇨🇮'), findsOneWidget);
    });

    testWidgets(
      'P4 — champ date de départ a prefixIconColor = colorScheme.primary',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final dateField = tester.widget<DonyTextField>(
          find.byKey(const Key('departureDateField')),
        );
        // Le paramètre prefixIconColor doit être non-null (couleur départ)
        expect(dateField.prefixIconColor, isNotNull);

        // Vérifier que la couleur correspond à colorScheme.primary
        final cs = Theme.of(
          tester.element(find.byKey(const Key('departureDateField'))),
        ).colorScheme;
        expect(dateField.prefixIconColor, equals(cs.primary));
      },
    );

    testWidgets(
      'champ heure d\'arrivée a prefixIconColor = colorScheme.secondary',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final arrivalTimeField = tester.widget<DonyTextField>(
          find.byKey(const Key('arrivalTimeField')),
        );
        expect(arrivalTimeField.prefixIconColor, isNotNull);

        final cs = Theme.of(
          tester.element(find.byKey(const Key('arrivalTimeField'))),
        ).colorScheme;
        expect(arrivalTimeField.prefixIconColor, equals(cs.secondary));
      },
    );

    testWidgets(
      'champ heure de départ a prefixIconColor = colorScheme.primary',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            departureCityBloc: departureCityBloc,
            arrivalCityBloc: arrivalCityBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final departureTimeField = tester.widget<DonyTextField>(
          find.byKey(const Key('departureTimeField')),
        );
        expect(departureTimeField.prefixIconColor, isNotNull);

        final cs = Theme.of(
          tester.element(find.byKey(const Key('departureTimeField'))),
        ).colorScheme;
        expect(departureTimeField.prefixIconColor, equals(cs.primary));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Task 5 — Feedback informatif « sera signalé urgent » sous le date picker.
  // ---------------------------------------------------------------------------
  group('Feedback urgent sous le date picker trajet', () {
    testWidgets('date proche (demain) → le hint urgent est affiché', (
      tester,
    ) async {
      final departureCityNotifier = ValueNotifier<String?>(null);
      final arrivalCityNotifier = ValueNotifier<String?>(null);
      final departureDateNotifier = ValueNotifier<DateTime?>(null);
      final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
      final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
      final transportModeNotifier = ValueNotifier<TransportMode?>(null);

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
                transportModeNotifier: transportModeNotifier,
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

      // Absent tant qu'aucune date n'est sélectionnée.
      expect(
        find.text('🔥 Départ proche — ce trajet sera signalé urgent'),
        findsNothing,
      );

      departureDateNotifier.value = DateTime.now().add(const Duration(days: 1));
      await tester.pump();

      expect(
        find.text('🔥 Départ proche — ce trajet sera signalé urgent'),
        findsOneWidget,
      );
    });

    testWidgets(
      'date lointaine → le hint urgent reste absent (SizedBox.shrink)',
      (tester) async {
        final departureCityNotifier = ValueNotifier<String?>(null);
        final arrivalCityNotifier = ValueNotifier<String?>(null);
        final departureDateNotifier = ValueNotifier<DateTime?>(null);
        final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
        final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
        final transportModeNotifier = ValueNotifier<TransportMode?>(null);

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
                  transportModeNotifier: transportModeNotifier,
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

        departureDateNotifier.value = DateTime.now().add(
          const Duration(days: 60),
        );
        await tester.pump();

        expect(
          find.text('🔥 Départ proche — ce trajet sera signalé urgent'),
          findsNothing,
        );
      },
    );
  });
}
