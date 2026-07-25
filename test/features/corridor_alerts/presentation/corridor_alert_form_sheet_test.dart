import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockFormCubit extends MockCubit<CorridorAlertFormState>
    implements CorridorAlertFormCubit {}

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

CorridorAlertModel _alert({
  AlertDirection direction = AlertDirection.travelerWantsPackages,
}) =>
    CorridorAlertModel(
      id: 'a1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      active: true,
      createdAt: DateTime(2026, 6, 20),
      direction: direction,
    );

Future<void> _pumpSheet(
  WidgetTester tester, {
  bool isTraveler = false,
  bool isSender = false,
  CorridorAlertModel? alert,
}) async {
  final cubit = MockFormCubit();
  final cityBloc = MockCitySearchBloc();
  when(() => cityBloc.state).thenReturn(const CitySearchInitial());
  when(() => cubit.isEditing).thenReturn(alert != null);

  // Direction based on roles / editing
  final direction = alert?.direction ??
      (isSender && !isTraveler
          ? AlertDirection.senderWantsTrips
          : AlertDirection.travelerWantsPackages);

  when(() => cubit.state).thenReturn(CorridorAlertFormState(
    departureCity: alert?.departureCity,
    arrivalCity: alert?.arrivalCity,
    direction: direction,
  ));

  GetIt.I.registerFactoryParam<CorridorAlertFormCubit,
      ({CorridorAlertModel? editing, AlertDirection direction}), void>(
    (params, _) => cubit,
  );
  GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => CorridorAlertFormSheet.show(
              ctx,
              alert: alert,
              isTraveler: isTraveler,
              isSender: isSender,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  setUp(() {
    // Le formulaire charge le catalogue de types de contenu via getIt —
    // requis dans tous les tests, y compris ceux hors direction "colis"
    // (le champ n'est rendu que si showColisFilters, mais _loadCatalog()
    // s'exécute inconditionnellement dans initState).
    GetIt.I.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );
  });

  tearDown(() => GetIt.I.reset());

  // ---------------------------------------------------------------------------
  // Existing tests (updated for new show() signature + new DI param type)
  // ---------------------------------------------------------------------------

  testWidgets('submit button is disabled while corridor is invalid',
      (t) async {
    final cubit = MockFormCubit();
    final cityBloc = MockCitySearchBloc();
    when(() => cityBloc.state).thenReturn(const CitySearchInitial());
    when(() => cubit.isEditing).thenReturn(false);
    when(() => cubit.state)
        .thenReturn(const CorridorAlertFormState()); // invalid

    GetIt.I.registerFactoryParam<CorridorAlertFormCubit,
        ({CorridorAlertModel? editing, AlertDirection direction}), void>(
      (params, _) => cubit,
    );
    GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  CorridorAlertFormSheet.show(ctx, isTraveler: true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    // The sticky submit button exists but is disabled (DonyButton with null onPressed).
    final submit = find.byKey(const Key('corridor-alert-submit'));
    expect(submit, findsOneWidget);
    // Tapping should NOT call submit() because onPressed is null.
    await t.tap(submit, warnIfMissed: false);
    await t.pump();
    verifyNever(() => cubit.submit());
  });

  testWidgets('submit button enabled when valid → calls submit()',
      (t) async {
    final cubit = MockFormCubit();
    final cityBloc = MockCitySearchBloc();
    when(() => cityBloc.state).thenReturn(const CitySearchInitial());
    when(() => cubit.isEditing).thenReturn(false);
    when(() => cubit.state).thenReturn(const CorridorAlertFormState(
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
    ));
    when(() => cubit.submit()).thenAnswer((_) async {});

    GetIt.I.registerFactoryParam<CorridorAlertFormCubit,
        ({CorridorAlertModel? editing, AlertDirection direction}), void>(
      (params, _) => cubit,
    );
    GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  CorridorAlertFormSheet.show(ctx, isTraveler: true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('corridor-alert-submit')));
    await t.pump();
    verify(() => cubit.submit()).called(1);
  });

  // ---------------------------------------------------------------------------
  // Fix 1 — date-window field
  // ---------------------------------------------------------------------------

  testWidgets('date-window field renders in form with placeholder',
      (t) async {
    final cubit = MockFormCubit();
    final cityBloc = MockCitySearchBloc();
    when(() => cityBloc.state).thenReturn(const CitySearchInitial());
    when(() => cubit.isEditing).thenReturn(false);
    when(() => cubit.state).thenReturn(const CorridorAlertFormState());

    GetIt.I.registerFactoryParam<CorridorAlertFormCubit,
        ({CorridorAlertModel? editing, AlertDirection direction}), void>(
      (params, _) => cubit,
    );
    GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  CorridorAlertFormSheet.show(ctx, isTraveler: true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    // The date-window container is present.
    expect(find.byKey(const Key('corridor-alert-date-window')), findsOneWidget);
    // Placeholder text shown when no dates set.
    expect(find.text('Toute date'), findsOneWidget);
    // No clear button when no dates are set.
    expect(
        find.byKey(const Key('corridor-alert-date-window-clear')), findsNothing);
  });

  testWidgets('edit mode prefills date window from cubit state', (t) async {
    final cubit = MockFormCubit();
    final cityBloc = MockCitySearchBloc();
    when(() => cityBloc.state).thenReturn(const CitySearchInitial());
    when(() => cubit.isEditing).thenReturn(true);
    when(() => cubit.state).thenReturn(CorridorAlertFormState(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      dateFrom: DateTime(2026, 7, 20),
      dateTo: DateTime(2026, 7, 28),
    ));

    GetIt.I.registerFactoryParam<CorridorAlertFormCubit,
        ({CorridorAlertModel? editing, AlertDirection direction}), void>(
      (params, _) => cubit,
    );
    GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  CorridorAlertFormSheet.show(ctx, isTraveler: true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    // Formatted date range should appear (e.g. "20 juil → 30 juil").
    expect(find.textContaining('juil'), findsWidgets);
    // Clear button should be visible.
    expect(find.byKey(const Key('corridor-alert-date-window-clear')),
        findsOneWidget);
    // Placeholder must NOT be present.
    expect(find.text('Toute date'), findsNothing);
  });

  testWidgets('tapping clear button calls cubit.clearDateWindow()', (t) async {
    final cubit = MockFormCubit();
    final cityBloc = MockCitySearchBloc();
    when(() => cityBloc.state).thenReturn(const CitySearchInitial());
    when(() => cubit.isEditing).thenReturn(true);
    when(() => cubit.state).thenReturn(CorridorAlertFormState(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      dateFrom: DateTime(2026, 7, 20),
      dateTo: DateTime(2026, 7, 28),
    ));
    when(() => cubit.clearDateWindow()).thenReturn(null);

    GetIt.I.registerFactoryParam<CorridorAlertFormCubit,
        ({CorridorAlertModel? editing, AlertDirection direction}), void>(
      (params, _) => cubit,
    );
    GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  CorridorAlertFormSheet.show(ctx, isTraveler: true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('corridor-alert-date-window-clear')));
    await t.pump();
    verify(() => cubit.clearDateWindow()).called(1);
  });

  // ---------------------------------------------------------------------------
  // Task 2 — direction segment + role-gating
  // ---------------------------------------------------------------------------

  testWidgets('both roles → direction segment visible', (tester) async {
    await _pumpSheet(tester, isTraveler: true, isSender: true);
    expect(find.byKey(const Key('alert-direction-segment')), findsOneWidget);
  });

  testWidgets('sender only → no segment, direction forced senderWantsTrips',
      (tester) async {
    await _pumpSheet(tester, isTraveler: false, isSender: true);
    expect(find.byKey(const Key('alert-direction-segment')), findsNothing);
    // trajet direction hides weight + categories
    expect(find.byKey(const Key('corridor-alert-min-weight')), findsNothing);
    expect(find.text('Types de contenu (optionnel)'), findsNothing);
  });

  testWidgets('traveler only → no segment, colis fields shown', (tester) async {
    await _pumpSheet(tester, isTraveler: true, isSender: false);
    expect(find.byKey(const Key('alert-direction-segment')), findsNothing);
    expect(find.byKey(const Key('corridor-alert-min-weight')), findsOneWidget);
    expect(find.text('Types de contenu (optionnel)'), findsOneWidget);
  });

  testWidgets('edit mode → segment read-only (absent), shows existing direction',
      (tester) async {
    await _pumpSheet(tester,
        isTraveler: true,
        isSender: true,
        alert: _alert(direction: AlertDirection.senderWantsTrips));
    expect(find.byKey(const Key('alert-direction-segment')), findsNothing);
    expect(find.byKey(const Key('corridor-alert-min-weight')), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Catalogue de types de contenu (Task 7) — catalogue fourni par le
  // repository, pas la liste figée _kAlertContentTypes ("Électronique" et
  // "Nourriture" ont disparu, remplacés par le catalogue unifié).
  // ---------------------------------------------------------------------------

  testWidgets(
    'affiche le catalogue fourni par le repository (pas une liste figée)',
    (tester) async {
      await _pumpSheet(tester, isTraveler: true);

      // Le catalogue n'est plus déplié : il alimente les suggestions du
      // sélecteur, qu'on ouvre en tapant dans le champ.
      final champ = find.byKey(const Key('alert-content-field'));
      await tester.ensureVisible(champ);
      await tester.tap(champ);
      await tester.pumpAndSettle();

      for (final category in fallbackCatalog) {
        expect(
          find.byKey(Key('alert-content-item-${category.label}')),
          findsOneWidget,
          reason: 'suggestion manquante : ${category.label}',
        );
      }
      // Anciennes valeurs figées disparues (migrées par V171).
      expect(find.byKey(const Key('alert-content-item-Électronique')),
          findsNothing);
      expect(find.byKey(const Key('alert-content-item-Nourriture')),
          findsNothing);
    },
  );

  testWidgets(
    'saisie libre transmet la sélection complète au cubit',
    (tester) async {
      final cubit = MockFormCubit();
      final cityBloc = MockCitySearchBloc();
      when(() => cityBloc.state).thenReturn(const CitySearchInitial());
      when(() => cubit.isEditing).thenReturn(false);
      when(() => cubit.state).thenReturn(const CorridorAlertFormState(
        direction: AlertDirection.travelerWantsPackages,
      ));
      when(() => cubit.toggleCategory(any())).thenReturn(null);

      GetIt.I.registerFactoryParam<CorridorAlertFormCubit,
          ({CorridorAlertModel? editing, AlertDirection direction}), void>(
        (params, _) => cubit,
      );
      GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    CorridorAlertFormSheet.show(ctx, isTraveler: true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Un type absent du catalogue s'ajoute par la frappe, sans bouton « + ».
      final champ = find.byKey(const Key('alert-content-field'));
      await tester.ensureVisible(champ);
      await tester.tap(champ);
      await tester.pumpAndSettle();
      await tester.enterText(champ, 'Poissons');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('alert-content-item-add')));
      await tester.pumpAndSettle();

      verify(() => cubit.setCategories(['Poissons'])).called(1);
    },
  );
}
