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

  group('M4 — Uniformité visuelle champs heure/date', () {
    testWidgets(
      'les champs heure et date sont rendus via DonyTextField.tappable (InputDecorator)',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
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

    testWidgets(
      'les labels des champs heure s\'affichent correctement (optionnel)',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // Les labels optionnels sont présents
        expect(find.text('Heure de départ (optionnel)'), findsOneWidget);
        expect(find.text('Heure d\'arrivée (optionnel)'), findsOneWidget);
      },
    );

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

        await tester.pumpWidget(MaterialApp(
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
        ));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(const Key('departureTimeField')));
        await tester.pump();

        expect(called, isTrue);
      },
    );

    testWidgets(
      'tap sur le champ date de départ déclenche onSelectDate',
      (tester) async {
        var called = false;
        final departureCityNotifier = ValueNotifier<String?>(null);
        final arrivalCityNotifier = ValueNotifier<String?>(null);
        final departureDateNotifier = ValueNotifier<DateTime?>(null);
        final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
        final arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
        final transportModeNotifier = ValueNotifier<TransportMode?>(null);

        await tester.pumpWidget(MaterialApp(
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
        ));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(const Key('departureDateField')));
        await tester.pump();

        expect(called, isTrue);
      },
    );
  });

  group('M5 — Marquage champs requis (astérisque)', () {
    testWidgets(
      'les champs requis affichent un astérisque dans leur label',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // Exactement 3 champs requis : ville de départ, ville d'arrivée,
        // date de départ. Chacun affiche un TextSpan " *" via Text.rich.
        // find.textContaining(' *') matche chaque TextSpan séparément,
        // donc on attend exactement 3 occurrences.
        expect(find.textContaining(' *'), findsNWidgets(3));
      },
    );

    testWidgets(
      'le champ date de départ a requiredLabel true',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
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
      },
    );

    testWidgets(
      'les champs heure (optionnel) n\'ont pas d\'astérisque dans le label',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // Les labels optionnels ne contiennent pas " *"
        expect(find.text('Heure de départ (optionnel)'), findsOneWidget);
        expect(find.text('Heure d\'arrivée (optionnel)'), findsOneWidget);
        // Vérifier qu'aucun texte " * " n'est associé aux champs optionnels
        // (les champs heure n'ont pas requiredLabel: true)
        final donyTextFields = tester.widgetList<DonyTextField>(
          find.byType(DonyTextField),
        ).toList();
        // 3 DonyTextField.tappable : 2 heures + 1 date
        expect(donyTextFields.length, 3);
        // Les 2 champs heure n'ont pas requiredLabel
        final timeFields = donyTextFields
            .where((f) => f.label?.contains('optionnel') == true)
            .toList();
        expect(timeFields.length, 2);
        for (final f in timeFields) {
          expect(f.requiredLabel, isFalse);
        }
        // Le champ date a requiredLabel: true
        final dateFields = donyTextFields
            .where((f) => f.label == 'Date de départ')
            .toList();
        expect(dateFields.length, 1);
        expect(dateFields.first.requiredLabel, isTrue);
      },
    );
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

  // ---------------------------------------------------------------------------
  // P3 — Couleurs sémantiques arrivée (secondary) vs départ (primary)
  // P4 — Icône date utilise colorScheme.primary
  // ---------------------------------------------------------------------------
  group('P3/P4 — Couleurs sémantiques icônes départ/arrivée', () {
    testWidgets(
      'icône ville d\'arrivée reçoit colorScheme.secondary (terracotta)',
      (tester) async {
        // L'icône de la ville d'arrivée est un Icon widget passé en prefixIcon
        // à CityAutocompleteField. On trouve l'Icon dont la couleur est secondary.
        // Le thème MaterialApp par défaut expose un ColorScheme — secondary est
        // la couleur terracotta #D96A3A de l'app.
        // On vérifie que le prefixIconColor passé à DonyIcons.arrivalCity est
        // secondary et non primary (qui serait pour le départ).
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // L'Icon arrivée est rendu avec DonyIcons.arrivalCity et color secondary
        // On utilise find.byWidgetPredicate pour cibler l'Icon dont l'iconData
        // est DonyIcons.arrivalCity et vérifier sa couleur.
        final arrivalIconFinder = find.byWidgetPredicate((widget) {
          if (widget is! Icon) return false;
          if (widget.icon != DonyIcons.arrivalCity) return false;
          // La couleur passée doit être secondary (non primary)
          final cs = Theme.of(tester.element(find.byType(MaterialApp))).colorScheme;
          return widget.color == cs.secondary;
        });
        expect(arrivalIconFinder, findsOneWidget);
      },
    );

    testWidgets(
      'icône ville de départ reçoit colorScheme.primary (bleu)',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
        await tester.pump(const Duration(milliseconds: 300));

        final departureCityIconFinder = find.byWidgetPredicate((widget) {
          if (widget is! Icon) return false;
          if (widget.icon != DonyIcons.departureCity) return false;
          final cs = Theme.of(tester.element(find.byType(MaterialApp))).colorScheme;
          return widget.color == cs.primary;
        });
        expect(departureCityIconFinder, findsOneWidget);
      },
    );

    testWidgets(
      'P4 — champ date de départ a prefixIconColor = colorScheme.primary',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
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
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
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
        await tester.pumpWidget(_buildSubject(
          departureCityBloc: departureCityBloc,
          arrivalCityBloc: arrivalCityBloc,
        ));
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
}
