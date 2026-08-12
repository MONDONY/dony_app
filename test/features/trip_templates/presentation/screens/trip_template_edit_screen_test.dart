// Tests de TripTemplateEditScreen — section "CE QUE J'ACCEPTE".
//
// Vérifie que les chips de catégorie viennent du catalogue fourni par le
// repository (pas d'une liste figée) et que la saisie libre est possible.

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_template_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_recent_city_store.dart';

class _MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

class _MockCityRepository extends Mock implements CityRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

Widget _wrap(Widget child, TripTemplateBloc bloc) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<TripTemplateBloc>.value(
          value: bloc,
          child: child,
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

void main() {
  late _MockTripTemplateBloc bloc;

  setUpAll(registerCityFallbackValues);

  setUp(() {
    bloc = _MockTripTemplateBloc();
    when(() => bloc.state).thenReturn(const TripTemplateState());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

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

    registerFakeRecentCityStore();
  });

  tearDown(() {
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    unregisterFakeRecentCityStore();
  });

  testWidgets(
    'affiche le catalogue fourni par le repository (pas une liste figée)',
    (tester) async {
      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      for (final category in fallbackCatalog) {
        // findsAtLeastNWidgets : le libellé "Autre" existe aussi comme mode
        // de transport ailleurs sur l'écran — pas d'exclusivité de texte
        // attendue, seule la présence du libellé du catalogue est vérifiée.
        expect(
          find.text(category.label),
          findsAtLeastNWidgets(1),
          reason: 'Chip "${category.label}" doit être présente',
        );
      }
    },
  );

  testWidgets('saisie libre ajoute une catégorie custom', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('custom-category-input')),
      'Poissons',
    );
    await tester.tap(find.byKey(const Key('add-custom-category-btn')));
    await tester.pump();

    expect(find.text('Poissons'), findsOneWidget);
  });
}
