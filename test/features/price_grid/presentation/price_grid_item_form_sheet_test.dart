import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/presentation/price_grid_item_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPriceGridBloc extends MockBloc<PriceGridEvent, PriceGridState>
    implements PriceGridBloc {}

/// La feuille charge le catalogue serveur via GetIt, avec repli embarqué.
class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

const _existing = PriceGridItemModel(
  id: 'a1',
  label: 'Chaussures',
  unitPriceNet: 15.0,
  unitPriceDisplay: 15.75,
  position: 1,
);

/// Monte un écran minimal doté d'un bouton qui ouvre la feuille.
Future<PriceGridBloc> _open(
  WidgetTester tester, {
  PriceGridItemModel? item,
  List<String> takenLabels = const [],
}) async {
  // La fenêtre de test par défaut (800×600) tronque le pavé numérique : les
  // touches basses tombent hors du viewport et les taps n'y portent pas.
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final bloc = _MockPriceGridBloc();
  whenListen(
    bloc,
    const Stream<PriceGridState>.empty(),
    initialState: const PriceGridLoaded([]),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<PriceGridBloc>.value(
        value: bloc,
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PriceGridItemFormSheet.show(
                context,
                item: item,
                takenLabels: takenLabels,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  return bloc;
}

/// Tape une suite de chiffres sur le pavé.
Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.widgetWithText(InkWell, d).last);
    await tester.pump();
  }
}

void main() {
  setUpAll(() {
    // mocktail exige une valeur de repli pour capturer les events du BLoC.
    registerFallbackValue(const PriceGridLoadRequested());
  });

  setUp(() {
    if (!getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.registerFactory<IContentCategoryRepository>(
        () => _FakeContentCategoryRepository(),
      );
    }
  });

  tearDown(() {
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
  });

  group('PriceGridItemFormSheet — étape catalogue', () {
    testWidgets('s\'ouvre sur le catalogue, pas sur un formulaire', (
      tester,
    ) async {
      await _open(tester);

      expect(find.byKey(const Key('price-grid-search')), findsOneWidget);
      expect(find.text('Chaussures'), findsOneWidget);
      expect(find.text('Livres'), findsOneWidget);
    });

    testWidgets('aucun bouton de validation tant qu\'aucun article n\'est '
        'choisi', (tester) async {
      await _open(tester);

      expect(find.byKey(const Key('price-grid-submit')), findsNothing);
    });

    testWidgets('les articles déjà tarifés ne sont pas reproposés', (
      tester,
    ) async {
      await _open(tester, takenLabels: const ['Chaussures']);

      expect(find.text('Chaussures'), findsNothing);
      expect(find.text('Livres'), findsOneWidget);
    });

    testWidgets('la recherche filtre le catalogue', (tester) async {
      await _open(tester);

      await tester.enterText(
        find.byKey(const Key('price-grid-search')),
        'chauss',
      );
      await tester.pumpAndSettle();

      expect(find.text('Chaussures'), findsOneWidget);
      expect(find.text('Livres'), findsNothing);
    });

    testWidgets('un libellé inconnu propose de l\'ajouter tel quel', (
      tester,
    ) async {
      await _open(tester);

      await tester.enterText(
        find.byKey(const Key('price-grid-search')),
        'Pagne 6 yards',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('price-grid-create-custom')), findsOneWidget);
      expect(find.text('Ajouter « Pagne 6 yards »'), findsOneWidget);
    });

    testWidgets('un libellé qui existe déjà ne propose pas de doublon', (
      tester,
    ) async {
      await _open(tester);

      await tester.enterText(
        find.byKey(const Key('price-grid-search')),
        'Chaussures',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('price-grid-create-custom')), findsNothing);
    });
  });

  group('PriceGridItemFormSheet — étape prix', () {
    testWidgets('choisir un article fait passer à la saisie du prix', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('price-grid-search')), findsNothing);
      expect(find.text('Ce que vous encaissez'), findsOneWidget);
      expect(find.byKey(const Key('price-grid-submit')), findsOneWidget);
    });

    testWidgets('le pavé alimente le montant affiché', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();

      await _type(tester, '15');

      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('le montant se ferme à zéro décimale de trop', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();

      await _type(tester, '15');
      await tester.tap(find.widgetWithText(InkWell, ',').last);
      await tester.pump();
      await _type(tester, '567');

      // Deux décimales au maximum : le troisième chiffre est ignoré.
      expect(find.text('15,56'), findsOneWidget);
    });

    testWidgets('l\'écho annonce ce que paiera l\'expéditeur', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Saisissez le montant'),
        findsOneWidget,
      );

      await _type(tester, '15');

      expect(find.textContaining('L\'expéditeur paiera'), findsOneWidget);
    });

    testWidgets('un montant hors plafond bloque et l\'explique', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();

      // Au-delà du plafond par article.
      await _type(tester, '9999');

      expect(find.textContaining('Maximum'), findsOneWidget);
      final btn = tester.widget<DonyButton>(
        find.byKey(const Key('price-grid-submit')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('le bouton reste inerte sans montant', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();

      final btn = tester.widget<DonyButton>(
        find.byKey(const Key('price-grid-submit')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('« Changer » ramène au catalogue', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('price-grid-change-item')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('price-grid-search')), findsOneWidget);
    });
  });

  group('PriceGridItemFormSheet — soumission', () {
    testWidgets('créer envoie le libellé et le net saisi', (tester) async {
      final bloc = await _open(tester);

      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();
      await _type(tester, '15');
      await tester.tap(find.byKey(const Key('price-grid-submit')));
      await tester.pumpAndSettle();

      final captured = verify(() => bloc.add(captureAny())).captured
          .whereType<PriceGridItemAddRequested>()
          .toList();

      expect(captured, hasLength(1));
      expect(captured.single.label, 'Chaussures');
      expect(captured.single.unitPriceNet, 15.0);
    });

    testWidgets('un libellé libre part tel quel', (tester) async {
      final bloc = await _open(tester);

      await tester.enterText(
        find.byKey(const Key('price-grid-search')),
        'Pagne 6 yards',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('price-grid-create-custom')));
      await tester.pumpAndSettle();
      await _type(tester, '20');
      await tester.tap(find.byKey(const Key('price-grid-submit')));
      await tester.pumpAndSettle();

      final captured = verify(() => bloc.add(captureAny())).captured
          .whereType<PriceGridItemAddRequested>()
          .toList();

      expect(captured.single.label, 'Pagne 6 yards');
    });

    testWidgets('la virgule est acceptée comme séparateur décimal', (
      tester,
    ) async {
      final bloc = await _open(tester);

      await tester.tap(find.text('Chaussures'));
      await tester.pumpAndSettle();
      await _type(tester, '12');
      await tester.tap(find.widgetWithText(InkWell, ',').last);
      await tester.pump();
      await _type(tester, '50');
      await tester.tap(find.byKey(const Key('price-grid-submit')));
      await tester.pumpAndSettle();

      final captured = verify(() => bloc.add(captureAny())).captured
          .whereType<PriceGridItemAddRequested>()
          .toList();

      expect(captured.single.unitPriceNet, 12.5);
    });
  });

  group('PriceGridItemFormSheet — modification', () {
    testWidgets('s\'ouvre directement sur le prix, article déjà connu', (
      tester,
    ) async {
      await _open(tester, item: _existing);

      expect(find.byKey(const Key('price-grid-search')), findsNothing);
      expect(find.text('Chaussures'), findsOneWidget);
      // 15.00 se réécrit plus vite depuis « 15 ».
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('enregistrer envoie une mise à jour, pas un ajout', (
      tester,
    ) async {
      final bloc = await _open(tester, item: _existing);

      await tester.tap(find.widgetWithText(InkWell, '9').last);
      await tester.pump();
      await tester.tap(find.byKey(const Key('price-grid-submit')));
      await tester.pumpAndSettle();

      final updates = verify(() => bloc.add(captureAny())).captured
          .whereType<PriceGridItemUpdateRequested>()
          .toList();

      expect(updates, hasLength(1));
      expect(updates.single.itemId, 'a1');
      expect(updates.single.unitPriceNet, 159.0);
    });
  });

  group('PriceGridItemFormSheet — garde-fous', () {
    test('le plafond par article reste celui du domaine', () {
      // Si le plafond bouge, le message d'erreur de la feuille doit suivre.
      expect(maxUnitPriceActive, greaterThan(0));
    });
  });
}
