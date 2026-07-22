// Tests de SearchFormBottomSheet — section "MON COLIS CONTIENT".
//
// Vérifie que le catalogue de types de contenu vient du repository (pas
// d'une liste figée) et que la saisie libre est possible. Le filtre reste
// à sélection UNIQUE (SearchParams.contentType est un String?, pas une
// liste) — décision documentée dans le rapport de tâche.

import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/presentation/widgets/search_form_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCityRepository extends Mock implements CityRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

Widget _harness(ValueNotifier<SearchParams?> resultNotifier) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            resultNotifier.value =
                await SearchFormBottomSheet.show(context);
          },
          child: const Text('Ouvrir filtres'),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(
  WidgetTester tester,
  ValueNotifier<SearchParams?> resultNotifier,
) async {
  await tester.pumpWidget(_harness(resultNotifier));
  await tester.tap(find.text('Ouvrir filtres'));
  await tester.pumpAndSettle();
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

  testWidgets(
    'affiche le catalogue fourni par le repository (pas une liste figée)',
    (tester) async {
      final result = ValueNotifier<SearchParams?>(null);
      await _openSheet(tester, result);

      for (final category in fallbackCatalog) {
        expect(find.text(category.label), findsOneWidget);
      }
    },
  );

  testWidgets(
    'saisie libre + Rechercher renvoie le libellé libre comme contentType',
    (tester) async {
      final result = ValueNotifier<SearchParams?>(null);
      await _openSheet(tester, result);

      final freeTextField = find.byKey(const Key('content-type-free-text'));
      await tester.dragUntilVisible(
        freeTextField,
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();
      await tester.enterText(freeTextField, 'Poissons');
      await tester.tap(
        find.byKey(const Key('content-type-free-text-add-btn')),
      );
      await tester.pump();

      await tester.tap(find.text('Rechercher · 1 filtre'));
      await tester.pumpAndSettle();

      expect(result.value?.contentType, 'Poissons');
    },
  );

  // ── Défaut 2 : effacer une ville vide bien le filtre correspondant ────────

  testWidgets(
    'vider la ville de départ efface son filtre sans perdre l\'arrivée',
    (tester) async {
      final result = ValueNotifier<SearchParams?>(null);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result.value = await SearchFormBottomSheet.show(
                  context,
                  initialParams: const SearchParams(
                    departureCity: 'Paris',
                    arrivalCity: 'Dakar',
                  ),
                );
              },
              child: const Text('Ouvrir filtres'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Ouvrir filtres'));
      await tester.pumpAndSettle();

      final croixDepart = find.descendant(
        of: find.byKey(const Key('search-form-departure-city')),
        matching: find.byType(IconButton),
      );
      await tester.ensureVisible(croixDepart);
      await tester.pumpAndSettle();
      await tester.tap(croixDepart);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();

      expect(result.value?.departureCity, isNull);
      expect(result.value?.arrivalCity, 'Dakar');
    },
  );
}
