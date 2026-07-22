// Tests de SearchFilterSheet — la sheet de filtres unique de l'écran Rechercher.
//
// Le point vérifié ici n'est pas la richesse des filtres mais le partage : le
// bloc corridor + date doit être le MÊME widget dans les deux modes, sinon le
// corridor se reperd à chaque bascule. Les finders visent donc surtout ce bloc.
//
// Écarts assumés par rapport au brief :
//  - `DonyButton` n'est pas un `ElevatedButton` (variante primary = conteneur
//    dégradé + InkWell) → on cible `DonyButton`.
//  - la croix de `DonyBottomSheet` est un SVG `DonyIcon('x')`, pas un
//    `Icons.close` → on referme la sheet par le barrier modal.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCityRepository extends Mock implements CityRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

void main() {
  setUp(() {
    final cityRepo = _MockCityRepository();
    when(() => cityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => cityRepo.getPopularCorridors()).thenAnswer((_) async => []);

    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));

    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    getIt.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
  });

  Future<void> ouvrir(
    WidgetTester tester, {
    required SearchMode mode,
    HomeSearchFilters initial = const HomeSearchFilters(),
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () =>
                SearchFilterSheet.show(ctx, mode: mode, initial: initial),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Future<void> fermer(WidgetTester tester) async {
    // Tap sur le barrier modal, au-dessus de la sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  }

  testWidgets('mode trajets : titre et filtres spécifiques', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    expect(find.text('Filtrer les trajets'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsOneWidget);
    expect(find.text('KYC vérifié'), findsOneWidget);
  });

  testWidgets('mode colis : titre et filtres spécifiques', (tester) async {
    await ouvrir(tester, mode: SearchMode.parcels);

    expect(find.text('Filtrer les colis'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsNothing);
    expect(find.text('KYC vérifié'), findsNothing);
  });

  testWidgets('le bloc commun est présent dans les deux modes', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);
    expect(find.byType(CommonFilterBlock), findsOneWidget);
    expect(find.text('Ville de départ'), findsOneWidget);
    expect(find.text("Ville d'arrivée"), findsOneWidget);

    await fermer(tester);

    await ouvrir(tester, mode: SearchMode.parcels);
    expect(find.byType(CommonFilterBlock), findsOneWidget);
    expect(find.text('Ville de départ'), findsOneWidget);
    expect(find.text("Ville d'arrivée"), findsOneWidget);
  });

  testWidgets('le corridor initial est pré-rempli dans les deux modes',
      (tester) async {
    const initial =
        HomeSearchFilters(departureCity: 'Paris', arrivalCity: 'Dakar');

    await ouvrir(tester, mode: SearchMode.parcels, initial: initial);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);

    await fermer(tester);

    await ouvrir(tester, mode: SearchMode.trips, initial: initial);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
  });

  testWidgets('le bouton porte le même libellé dans les deux modes',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);
    expect(find.widgetWithText(DonyButton, 'Rechercher'), findsOneWidget);
    expect(find.text('Appliquer'), findsNothing);

    await fermer(tester);

    await ouvrir(tester, mode: SearchMode.parcels);
    expect(find.widgetWithText(DonyButton, 'Rechercher'), findsOneWidget);
    expect(find.text('Appliquer'), findsNothing);
  });

  testWidgets('« Tout effacer » absent quand aucun filtre actif',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    expect(find.text('Tout effacer'), findsNothing);
  });

  testWidgets('« Tout effacer » présent dès qu\'un filtre est actif',
      (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(kiloProOnly: true),
    );

    expect(find.text('Tout effacer'), findsOneWidget);
  });
}
