// Tests de TripTemplateEditScreen — section "CE QUE J'ACCEPTE".
//
// La section utilise le combobox partagé ContentCategorySelector (même
// composant que la création de trajet et le wizard colis) : catalogue
// déroulant issu du repository, tags supprimables, saisie libre par la ligne
// « Ajouter ».

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
        builder: (_, _) =>
            BlocProvider<TripTemplateBloc>.value(value: bloc, child: child),
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

  const field = Key('template-content-field');

  testWidgets(
    'le combo affiche le catalogue fourni par le repository (pas une liste '
    'figée)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.ensureVisible(find.byKey(field));
      await tester.tap(find.byKey(field));
      await tester.pumpAndSettle();

      for (final category in fallbackCatalog) {
        expect(
          find.byKey(Key('template-content-item-${category.label}')),
          findsOneWidget,
          reason: 'Item "${category.label}" doit être proposé',
        );
      }
    },
  );

  testWidgets('choisir un item ajoute un tag et referme la liste', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.ensureVisible(find.byKey(field));
    await tester.tap(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('template-content-item-Livres')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template-content-item-Livres')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('template-content-tag-Livres')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('template-content-dropdown')), findsNothing);
  });

  testWidgets('saisie libre ajoute une catégorie custom', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const TripTemplateEditScreen(), bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.ensureVisible(find.byKey(field));
    await tester.tap(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(field), 'Poissons');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template-content-item-add')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('template-content-tag-Poissons')),
      findsOneWidget,
    );
  });
}
