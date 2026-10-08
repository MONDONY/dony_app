import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

void main() {
  late MockCitySearchBloc mockBloc;

  setUpAll(() {
    registerFallbackValue(const CitySearchQueryChanged(''));
    registerFallbackValue(const CitySearchCleared());
  });

  setUp(() {
    mockBloc = MockCitySearchBloc();
    when(() => mockBloc.state).thenReturn(const CitySearchInitial());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget buildWidget({
    void Function(CityModel)? onSelected,
    String? initialValue,
    Widget? prefixIcon,
    CityFieldVariant variant = CityFieldVariant.outlined,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<CitySearchBloc>.value(
          value: mockBloc,
          child: CityAutocompleteField(
            label: 'Ville de départ',
            onSelected: onSelected ?? (_) {},
            initialValue: initialValue,
            prefixIcon: prefixIcon,
            variant: variant,
          ),
        ),
      ),
    );
  }

  // ── Rendu de base ──────────────────────────────────────────────────────────

  testWidgets('affiche le label correctement', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Ville de départ'), findsOneWidget);
  });

  testWidgets('initialValue pré-remplit le champ de texte', (tester) async {
    await tester.pumpWidget(buildWidget(initialValue: 'Paris'));
    await tester.pump();
    expect(find.text('Paris'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
      findsOneWidget,
    );
  });

  testWidgets(
    'changement externe d\'initialValue resynchronise le champ (application d\'un modèle)',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      expect(find.text('Paris'), findsNothing);

      // Simule l'application d'un modèle : le parent reconstruit le champ
      // avec un nouvel initialValue (même position → didUpdateWidget).
      await tester.pumpWidget(buildWidget(initialValue: 'Paris'));
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, 'Paris');
      expect(find.text('Paris'), findsOneWidget);
    },
  );

  testWidgets('saisie en cours non écrasée si initialValue inchangé', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Lyon');
    await tester.pump();
    // Rebuild avec le même initialValue (null) — ne doit pas effacer "Lyon".
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller?.text, 'Lyon');
  });

  testWidgets('prefixIcon affiché si fourni', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        prefixIcon: const Icon(Icons.flight, key: Key('prefix-icon')),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('prefix-icon')), findsOneWidget);
  });

  // ── Résultats ──────────────────────────────────────────────────────────────

  testWidgets('affiche les résultats quand état est Loaded', (tester) async {
    when(() => mockBloc.state).thenReturn(
      const CitySearchLoaded([
        CityModel(
          name: 'Dakar',
          countryCode: 'SN',
          countryName: 'Sénégal',
          lat: 14.71,
          lng: -17.47,
        ),
      ]),
    );

    await tester.pumpWidget(buildWidget());
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('Sénégal'), findsOneWidget);
  });

  testWidgets('Loaded avec liste vide n\'affiche pas de résultats', (
    tester,
  ) async {
    when(() => mockBloc.state).thenReturn(const CitySearchLoaded([]));
    await tester.pumpWidget(buildWidget());
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('état Error n\'affiche pas de liste ni de progressbar', (
    tester,
  ) async {
    when(
      () => mockBloc.state,
    ).thenReturn(const CitySearchError(NetworkException('network error')));
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  // ── Loading ────────────────────────────────────────────────────────────────

  testWidgets('affiche LinearProgressIndicator quand état est Loading', (
    tester,
  ) async {
    when(() => mockBloc.state).thenReturn(const CitySearchLoading());

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  // ── Sélection d'une ville ──────────────────────────────────────────────────

  testWidgets('appelle onSelected quand on tape sur un résultat', (
    tester,
  ) async {
    CityModel? selected;
    const city = CityModel(
      name: 'Dakar',
      countryCode: 'SN',
      countryName: 'Sénégal',
      lat: 14.71,
      lng: -17.47,
    );
    when(() => mockBloc.state).thenReturn(const CitySearchLoaded([city]));

    await tester.pumpWidget(buildWidget(onSelected: (c) => selected = c));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Dakar'));
    await tester.pump();
    expect(selected?.name, 'Dakar');
  });

  testWidgets('sélection d\'une ville pré-remplit le champ avec son nom', (
    tester,
  ) async {
    const city = CityModel(
      name: 'Abidjan',
      countryCode: 'CI',
      countryName: 'Côte d\'Ivoire',
      lat: 5.35,
      lng: -4.01,
    );
    when(() => mockBloc.state).thenReturn(const CitySearchLoaded([city]));

    await tester.pumpWidget(buildWidget());
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Abidjan'));
    await tester.pump();
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller?.text, 'Abidjan');
  });

  testWidgets(
    'la liste se referme après sélection même si le BLoC reste sur Loaded '
    '(réponse debouncée arrivée après le tap)',
    (tester) async {
      const city = CityModel(
        name: 'Abidjan',
        countryCode: 'CI',
        countryName: 'Côte d\'Ivoire',
        lat: 5.35,
        lng: -4.01,
      );
      // L'état reste Loaded tout du long : c'est le cas réel où la requête
      // debouncée (300 ms) répond après le tap, juste après CitySearchCleared.
      when(() => mockBloc.state).thenReturn(const CitySearchLoaded([city]));

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Côte d\'Ivoire'), findsOneWidget);

      await tester.tap(find.text('Abidjan'));
      await tester.pump(const Duration(milliseconds: 400));

      // Le sous-titre pays n'existe que dans la liste : le nom, lui, est
      // désormais dans le champ.
      expect(find.text('Côte d\'Ivoire'), findsNothing);
    },
  );

  testWidgets('retaper après une sélection rouvre la liste', (tester) async {
    const city = CityModel(
      name: 'Abidjan',
      countryCode: 'CI',
      countryName: 'Côte d\'Ivoire',
      lat: 5.35,
      lng: -4.01,
    );
    when(() => mockBloc.state).thenReturn(const CitySearchLoaded([city]));

    await tester.pumpWidget(buildWidget());
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Abidjan'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Côte d\'Ivoire'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Aby');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Côte d\'Ivoire'), findsOneWidget);
  });

  // ── Frappe / onChanged ────────────────────────────────────────────────────

  testWidgets('frappe dans le champ dispatche CitySearchQueryChanged', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Pa');
    await tester.pump();

    final captured = verify(() => mockBloc.add(captureAny())).captured;
    expect(
      captured.any((e) => e is CitySearchQueryChanged && e.query == 'Pa'),
      isTrue,
    );
  });

  testWidgets('bouton clear apparaît après saisie', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Lyon');
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
      findsOneWidget,
    );
  });

  testWidgets('bouton clear efface le texte et dispatche CitySearchCleared', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Lyon');
    await tester.pump();

    // Effacer les appels précédents (onChanged a déjà dispatché QueryChanged)
    clearInteractions(mockBloc);

    await tester.tap(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
    );
    await tester.pump();

    final captured = verify(() => mockBloc.add(captureAny())).captured;
    expect(captured.any((e) => e is CitySearchCleared), isTrue);
    // Le champ doit être vide (pas d'icône close)
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
      findsNothing,
    );
  });

  // ── Focus ─────────────────────────────────────────────────────────────────

  testWidgets('focus et unfocus du champ ne provoquent pas d\'erreur', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.byType(TextField));
    await tester.pump();
    // Clic en dehors pour perdre le focus
    await tester.tapAt(const Offset(1, 1));
    await tester.pump();
    // Pas d'exception = succès
  });

  testWidgets(
    'focus dans un Scrollable ancêtre déclenche ensureVisible sans exception',
    (tester) async {
      // Construit le widget DANS un SingleChildScrollView pour que
      // Scrollable.maybeOf() puisse résoudre un ancêtre scrollable,
      // ce qui valide le chemin focus → delayed callback → ensureVisible.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<CitySearchBloc>.value(
              value: mockBloc,
              child: SingleChildScrollView(
                child: CityAutocompleteField(
                  label: 'Ville de départ',
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Acquiert le focus sur le champ
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Laisse s'écouler le délai du postFrameCallback (300 ms) + marge
      await tester.pump(const Duration(milliseconds: 350));

      // Aucune exception ne doit avoir été levée
      expect(tester.takeException(), isNull);
    },
  );

  // ── Traductions ───────────────────────────────────────────────────────────

  testWidgets('bouton clear traduit en anglais (Clear city)', (tester) async {
    useEnglish();
    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Lyon');
    await tester.pump();
    expect(find.byTooltip('Clear city'), findsOneWidget);
  });

  testWidgets('placeholder traduit en anglais (Choose a city)', (tester) async {
    useEnglish();
    await tester.pumpWidget(buildWidget(variant: CityFieldVariant.connected));
    await tester.pump();
    expect(find.text('Choose a city'), findsOneWidget);
  });

  // ── Dispose ───────────────────────────────────────────────────────────────

  testWidgets('dispose s\'exécute sans erreur', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    // Remplace le widget par SizedBox vide pour déclencher dispose()
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    // Pas d'exception = dispose appelé avec succès
  });

  // ── FLUTTER-F0 : texte tapé sans toucher la suggestion ─────────────────────

  group('FLUTTER-F0 : correspondance exacte du texte tapé', () {
    const abidjan = CityModel(
      name: 'Abidjan',
      countryCode: 'CI',
      countryName: 'Côte d\'Ivoire',
      lat: 5.35,
      lng: -4.01,
    );
    const sedhiou = CityModel(
      name: 'Sédhiou',
      countryCode: 'SN',
      countryName: 'Sénégal',
      lat: 12.7,
      lng: -15.55,
    );
    late StreamController<CitySearchState> states;

    setUp(() {
      states = StreamController<CitySearchState>();
      whenListen(
        mockBloc,
        states.stream,
        initialState: const CitySearchInitial(),
      );
    });

    tearDown(() => states.close());

    Widget field({
      ValueChanged<CityModel>? onSelected,
      VoidCallback? onCleared,
      ValueChanged<String?>? onSelectionErrorChanged,
      bool requireSelection = true,
    }) => MaterialApp(
      home: Scaffold(
        body: BlocProvider<CitySearchBloc>.value(
          value: mockBloc,
          child: CityAutocompleteField(
            label: 'Ville de départ',
            onSelected: onSelected ?? (_) {},
            onCleared: onCleared,
            requireSelection: requireSelection,
            onSelectionErrorChanged: onSelectionErrorChanged,
          ),
        ),
      ),
    );

    Future<void> blur(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
    }

    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets(
      'perte de focus avant les résultats : la ville est choisie à leur arrivée',
      (tester) async {
        CityModel? selected;
        await tester.pumpWidget(field(onSelected: (c) => selected = c));
        await tester.enterText(find.byType(TextField), 'Abidjan');
        await blur(tester);
        expect(selected, isNull);

        states.add(const CitySearchLoading());
        await tester.pump();
        states.add(const CitySearchLoaded([abidjan]));
        await tester.pump();

        expect(selected?.name, 'Abidjan');
        expect(fieldText(tester), 'Abidjan');
        expect(find.text('Choisissez une ville dans la liste'), findsNothing);
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'casse et accents ignorés, et le nom officiel remplace la saisie',
      (tester) async {
        CityModel? selected;
        await tester.pumpWidget(field(onSelected: (c) => selected = c));
        await tester.enterText(find.byType(TextField), 'SEDHIOU');
        states.add(const CitySearchLoaded([sedhiou]));
        await tester.pump();
        // Correspondance pendant la saisie : remontée sans fermer le champ.
        expect(selected?.name, 'Sédhiou');

        await blur(tester);
        expect(fieldText(tester), 'SEDHIOU');
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('résultats déjà là : la perte de focus sélectionne la ville', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(const CitySearchLoaded([abidjan]));
      CityModel? selected;
      await tester.pumpWidget(field(onSelected: (c) => selected = c));
      await tester.enterText(find.byType(TextField), 'abidjan');
      // Résultats déjà reçus, aucune nouvelle requête en attente.
      states.add(const CitySearchLoaded([abidjan]));
      await tester.pump();
      selected = null;
      await blur(tester);
      // Déjà confirmée pendant la saisie : pas de double appel.
      expect(selected, isNull);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('validation clavier : la ville correspondante est choisie', (
      tester,
    ) async {
      CityModel? selected;
      await tester.pumpWidget(field(onSelected: (c) => selected = c));
      await tester.enterText(find.byType(TextField), 'Abidjan');
      when(() => mockBloc.state).thenReturn(const CitySearchLoaded([abidjan]));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(selected?.name, 'Abidjan');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'aucune correspondance : champ vidé, message, onCleared appelé',
      (tester) async {
        var cleared = 0;
        String? notified;
        await tester.pumpWidget(
          field(
            onCleared: () => cleared++,
            onSelectionErrorChanged: (m) => notified = m,
          ),
        );
        await tester.enterText(find.byType(TextField), 'Abidj');
        states.add(const CitySearchLoaded([abidjan]));
        await tester.pump();
        await blur(tester);

        expect(fieldText(tester), isEmpty);
        expect(find.text('Choisissez une ville dans la liste'), findsOneWidget);
        expect(notified, 'Choisissez une ville dans la liste');
        expect(cleared, 1);
        verify(() => mockBloc.add(any(that: isA<CitySearchCleared>())));

        // Retaper efface le message.
        await tester.enterText(find.byType(TextField), 'A');
        await tester.pump();
        expect(find.text('Choisissez une ville dans la liste'), findsNothing);
        expect(notified, isNull);
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('en anglais : message traduit', (tester) async {
      useEnglish();
      await tester.pumpWidget(field());
      await tester.enterText(find.byType(TextField), 'Zz');
      states.add(const CitySearchLoaded([abidjan]));
      await tester.pump();
      await blur(tester);
      expect(find.text('Choose a city from the list'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'sans requireSelection : le texte reste (comportement historique)',
      (tester) async {
        await tester.pumpWidget(field(requireSelection: false));
        await tester.enterText(find.byType(TextField), 'Abidj');
        states.add(const CitySearchLoaded([abidjan]));
        await tester.pump();
        await blur(tester);
        expect(fieldText(tester), 'Abidj');
        expect(find.text('Choisissez une ville dans la liste'), findsNothing);
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('erreur réseau : le texte est conservé', (tester) async {
      await tester.pumpWidget(field());
      await tester.enterText(find.byType(TextField), 'Abidjan');
      await blur(tester);
      states.add(const CitySearchError(NetworkException('network error')));
      await tester.pump();
      expect(fieldText(tester), 'Abidjan');
      expect(find.text('Choisissez une ville dans la liste'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'texte qui s\'écarte de la ville retenue : le parent l\'oublie',
      (tester) async {
        var cleared = 0;
        await tester.pumpWidget(field(onCleared: () => cleared++));
        await tester.enterText(find.byType(TextField), 'Abidjan');
        states.add(const CitySearchLoaded([abidjan]));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Abidjan-S');
        await tester.pump();
        expect(cleared, 1);
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
