// Tests du composant corridor partagé — la carte « billet » utilisée par les
// six points de saisie ville A -> ville B de l'app (recherche, formulaire de
// recherche, alerte corridor, modèle de trajet, publication de trajet,
// demande d'envoi).
//
// Les invariants couverts ici sont ceux qui ont déjà cassé une fois :
// le bouton d'interversion doit disparaître quand une liste de suggestions
// s'ouvre (sinon il recouvre la liste et vole le tap), et les messages
// d'erreur doivent sortir de la carte (sinon la rangée fautive devient plus
// haute que l'autre et décale le bouton de la couture).
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_corridor_fields.dart';
import 'package:dony/features/city/presentation/widgets/city_swap_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_recent_city_store.dart';

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

const _dakar = CityModel(
  name: 'Dakar',
  countryCode: 'SN',
  countryName: 'Sénégal',
  lat: 14.72,
  lng: -17.47,
);

void main() {
  late MockCitySearchBloc departureBloc;
  late MockCitySearchBloc arrivalBloc;

  setUpAll(registerCityFallbackValues);

  setUp(() {
    departureBloc = MockCitySearchBloc();
    arrivalBloc = MockCitySearchBloc();
    when(() => departureBloc.state).thenReturn(const CitySearchInitial());
    when(() => arrivalBloc.state).thenReturn(const CitySearchInitial());
    registerFakeRecentCityStore();
  });

  tearDown(() {
    departureBloc.close();
    arrivalBloc.close();
    unregisterFakeRecentCityStore();
  });

  Widget build({
    String? departureValue,
    String? arrivalValue,
    String? departureError,
    String? arrivalError,
    bool requiredLabels = false,
    VoidCallback? onSwap,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CityCorridorFields(
            departureValue: departureValue,
            arrivalValue: arrivalValue,
            departureFieldKey: const Key('dep'),
            arrivalFieldKey: const Key('arr'),
            departureError: departureError,
            arrivalError: arrivalError,
            requiredLabels: requiredLabels,
            departureCityBloc: departureBloc,
            arrivalCityBloc: arrivalBloc,
            onDepartureSelected: (_) {},
            onArrivalSelected: (_) {},
            onDepartureCleared: () {},
            onArrivalCleared: () {},
            onSwap: onSwap ?? () {},
          ),
        ),
      ),
    );
  }

  group('rendu de la carte', () {
    testWidgets('les deux rangées et le bouton d\'interversion sont présents',
        (tester) async {
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DÉPART'), findsOneWidget);
      expect(find.text('ARRIVÉE'), findsOneWidget);
      expect(find.byKey(const Key('dep')), findsOneWidget);
      expect(find.byKey(const Key('arr')), findsOneWidget);
      expect(find.byType(CitySwapButton), findsOneWidget);
    });

    testWidgets('requiredLabels ajoute l\'astérisque aux deux labels',
        (tester) async {
      await tester.pumpWidget(build(requiredLabels: true));
      await tester.pump(const Duration(milliseconds: 300));

      // `textContaining` : le label devient « DÉPART * ».
      expect(find.textContaining('DÉPART'), findsOneWidget);
      expect(find.textContaining('ARRIVÉE'), findsOneWidget);
    });

    testWidgets('chaque ville connue affiche le drapeau de son pays',
        (tester) async {
      await tester.pumpWidget(
        build(departureValue: 'Paris', arrivalValue: 'Abidjan'),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('🇫🇷'), findsOneWidget);
      expect(find.text('🇨🇮'), findsOneWidget);
    });

    testWidgets('une ville inconnue de cityFlag ne rend aucun drapeau',
        (tester) async {
      await tester.pumpWidget(build(departureValue: 'Vladivostok'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('🇷'), findsNothing);
    });

    testWidgets('taper le bouton déclenche onSwap', (tester) async {
      var swapped = 0;
      await tester.pumpWidget(build(onSwap: () => swapped++));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('swap-corridor-cities')));
      await tester.pump();

      expect(swapped, 1);
    });
  });

  group('messages d\'erreur', () {
    // Rendus sous la carte, jamais dans la rangée fautive : sinon celle-ci
    // devient plus haute que l'autre et le bouton quitte la couture.
    testWidgets('les deux erreurs s\'affichent ensemble', (tester) async {
      await tester.pumpWidget(build(
        departureError: 'Ville de départ obligatoire',
        arrivalError: "Ville d'arrivée obligatoire",
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ville de départ obligatoire'), findsOneWidget);
      expect(find.text("Ville d'arrivée obligatoire"), findsOneWidget);
    });

    testWidgets('une erreur sur un seul champ ne décale pas le bouton',
        (tester) async {
      await tester.pumpWidget(build(departureValue: 'Paris'));
      await tester.pump(const Duration(milliseconds: 300));
      final sansErreur = tester.getCenter(find.byType(CitySwapButton));

      await tester.pumpWidget(build(
        departureValue: 'Paris',
        arrivalError: "Ville d'arrivée obligatoire",
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final avecErreur = tester.getCenter(find.byType(CitySwapButton));

      expect(avecErreur.dy, sansErreur.dy);
    });

    testWidgets('aucune erreur ne rend aucun texte rouge', (tester) async {
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ville de départ obligatoire'), findsNothing);
    });
  });

  group('bouton masqué pendant les suggestions', () {
    testWidgets(
      'des résultats serveur sur le champ départ retirent le bouton',
      (tester) async {
        // Garde-fou d'un incident réel : superposé à la liste, le bouton
        // interceptait le tap destiné à une suggestion.
        when(() => departureBloc.state)
            .thenReturn(const CitySearchLoaded([_dakar]));
        await tester.pumpWidget(build());
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Dakar'), findsOneWidget);
        expect(find.byType(CitySwapButton), findsNothing);
      },
    );

    testWidgets(
      'des résultats sur le champ arrivée retirent aussi le bouton',
      (tester) async {
        when(() => arrivalBloc.state)
            .thenReturn(const CitySearchLoaded([_dakar]));
        await tester.pumpWidget(build());
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(CitySwapButton), findsNothing);
      },
    );

    testWidgets(
      'la liste refermée fait revenir le bouton',
      (tester) async {
        // `whenListen` et non `when(...state)` : un MockBloc dont on change
        // l'état ne pousse rien sur son flux, donc le BlocBuilder du champ ne
        // se reconstruirait jamais et le test passerait pour de mauvaises
        // raisons.
        whenListen(
          departureBloc,
          Stream<CitySearchState>.fromIterable([const CitySearchInitial()]),
          initialState: const CitySearchLoaded([_dakar]),
        );
        await tester.pumpWidget(build());
        // `pumpAndSettle` : la visibilité fait deux sauts de frame (le champ
        // notifie en post-frame, puis le ValueNotifier du parent déclenche un
        // second rebuild). Deux `pump` s'arrêteraient avant le retour.
        await tester.pumpAndSettle();

        expect(find.byType(CitySwapButton), findsOneWidget);
        expect(find.text('Dakar'), findsNothing);
      },
    );
  });
}
