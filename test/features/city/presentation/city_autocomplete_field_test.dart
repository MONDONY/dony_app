import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCitySearchBloc
    extends MockBloc<CitySearchEvent, CitySearchState>
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
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('prefixIcon affiché si fourni', (tester) async {
    await tester.pumpWidget(buildWidget(
      prefixIcon: const Icon(Icons.flight, key: Key('prefix-icon')),
    ));
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

  testWidgets('Loaded avec liste vide n\'affiche pas de résultats',
      (tester) async {
    when(() => mockBloc.state).thenReturn(const CitySearchLoaded([]));
    await tester.pumpWidget(buildWidget());
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('état Error n\'affiche pas de liste ni de progressbar',
      (tester) async {
    when(() => mockBloc.state)
        .thenReturn(CitySearchError(NetworkException('network error')));
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  // ── Loading ────────────────────────────────────────────────────────────────

  testWidgets('affiche LinearProgressIndicator quand état est Loading',
      (tester) async {
    when(() => mockBloc.state).thenReturn(const CitySearchLoading());

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  // ── Sélection d'une ville ──────────────────────────────────────────────────

  testWidgets('appelle onSelected quand on tape sur un résultat',
      (tester) async {
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

  testWidgets('sélection d\'une ville pré-remplit le champ avec son nom',
      (tester) async {
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

  // ── Frappe / onChanged ────────────────────────────────────────────────────

  testWidgets('frappe dans le champ dispatche CitySearchQueryChanged',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Pa');
    await tester.pump();

    final captured =
        verify(() => mockBloc.add(captureAny())).captured;
    expect(
      captured.any((e) => e is CitySearchQueryChanged && e.query == 'Pa'),
      isTrue,
    );
  });

  testWidgets('bouton clear apparaît après saisie', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Lyon');
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets(
      'bouton clear efface le texte et dispatche CitySearchCleared',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Lyon');
    await tester.pump();

    // Effacer les appels précédents (onChanged a déjà dispatché QueryChanged)
    clearInteractions(mockBloc);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    final captured =
        verify(() => mockBloc.add(captureAny())).captured;
    expect(captured.any((e) => e is CitySearchCleared), isTrue);
    // Le champ doit être vide (pas d'icône close)
    expect(find.byIcon(Icons.close), findsNothing);
  });

  // ── Focus ─────────────────────────────────────────────────────────────────

  testWidgets('focus et unfocus du champ ne provoquent pas d\'erreur',
      (tester) async {
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
}
