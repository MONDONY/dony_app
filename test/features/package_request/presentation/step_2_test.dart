// Step 2 widget test — catégories multiples (chips multi + input libre + ajout).
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

void main() {
  late _MockPackageRepo packageRepo;

  setUp(() {
    packageRepo = _MockPackageRepo();

    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    getIt.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
  });

  Widget wrap(Widget child) => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => PackageRequestFormBloc(
            packageRepo,
            analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
          ),
        ),
        BlocProvider(
          create: (_) => PackageRequestPhotosCubit(
            packageRepo,
            makeDisabledAnalytics(MockAnalyticsBackend()),
          ),
        ),
      ],
      child: Scaffold(body: child),
    ),
  );

  group('Step2Details — catégories multiples', () {
    // La liste dépliée de onze chips a été remplacée par l'autocomplétion
    // (`ContentCategoryComboBox`, déjà utilisée par la création de trajet).
    // Les intentions couvertes ici restent les mêmes : multi-sélection, ajout
    // d'une catégorie libre, retrait.
    const kField = Key('package-content-field');

    /// L'overlay de suggestions se place sous le champ : dans un viewport de
    /// 600 px il tombe hors écran et les taps n'atteignent rien.
    void tallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('le champ de saisie est toujours visible', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();
      expect(find.byKey(kField), findsOneWidget);
      // L'ancien couple input libre + bouton « + » n'existe plus.
      expect(find.byKey(const Key('add-category-btn')), findsNothing);
    });

    testWidgets('multi-sélection via le combo', (tester) async {
      // Les raccourcis « Fréquents » ont été retirés : la multi-sélection
      // passe uniquement par le combo, catalogue complet dont « Autre ».
      tallViewport(tester);
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(kField));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('package-content-item-Vêtements & tissus')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('package-content-item-Documents & administratif')),
      );
      await tester.pumpAndSettle();

      // Les deux sélections coexistent : pas d'exclusivité.
      expect(
        find.byKey(const Key('package-content-tag-Vêtements & tissus')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('package-content-tag-Documents & administratif')),
        findsOneWidget,
      );
    });

    testWidgets('une catégorie libre s\'ajoute par la frappe', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(kField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(kField), 'Textile brodé');
      await tester.pumpAndSettle();

      // L'entrée « ajouter » apparaît dans les suggestions, sans bouton dédié.
      final addItem = find.byKey(const Key('package-content-item-add'));
      expect(addItem, findsOneWidget);
      await tester.tap(addItem);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('package-content-tag-Textile brodé')),
        findsOneWidget,
      );
    });

    testWidgets('une catégorie libre est bien transmise à la soumission', (
      tester,
    ) async {
      // Le retrait d'une pastille appartient désormais au composant partagé
      // et est couvert avec lui. Ce qui reste propre à l'étape 2, c'est la
      // répartition entre libellés du catalogue et saisie libre.
      tallViewport(tester);
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '4');
      await tester.tap(find.byKey(kField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(kField), 'Textile brodé');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('package-content-item-add')));
      await tester.pumpAndSettle();

      key.currentState!.submit();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('package-content-tag-Textile brodé')),
        findsOneWidget,
      );
    });
  });
}
