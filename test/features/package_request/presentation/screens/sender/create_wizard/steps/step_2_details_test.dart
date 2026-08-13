import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

class _MockFormBloc
    extends MockBloc<PackageRequestFormEvent, PackageRequestFormState>
    implements PackageRequestFormBloc {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

void main() {
  late _MockRepo repo;
  late _MockFormBloc mockBloc;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(
      FormStep1Submitted(
        departureCity: 'a',
        arrivalCity: 'b',
        desiredDate: DateTime(2026),
        dateToleranceDays: 0,
        transportMode: TransportMode.plane,
      ),
    );
  });

  setUp(() {
    repo = _MockRepo();
    mockBloc = _MockFormBloc();
    when(() => mockBloc.state).thenReturn(const PackageRequestFormState());
    when(
      () => mockBloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestFormState>.empty());

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

  Widget wrap(Widget child, {PackageRequestFormBloc? bloc}) => MaterialApp(
    theme: AppTheme.light(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<PackageRequestFormBloc>.value(
          value:
              bloc ??
              PackageRequestFormBloc(
                repo,
                analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
              ),
        ),
        BlocProvider<PackageRequestPhotosCubit>(
          create: (_) => PackageRequestPhotosCubit(
            repo,
            makeDisabledAnalytics(MockAnalyticsBackend()),
          ),
        ),
      ],
      child: Scaffold(body: child),
    ),
  );

  group('Step2Details', () {
    /// L'overlay du combo catégories se place sous le champ : dans un
    /// viewport de 600 px il tombe hors écran et les taps n'atteignent rien.
    void tallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('rend titre + sous-titre + labels de section', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      expect(find.text('Décris ton colis'), findsOneWidget);
      expect(
        find.textContaining('Ces infos aident les voyageurs'),
        findsOneWidget,
      );
      expect(find.text('Poids approximatif'), findsOneWidget);
      // La taille n'est plus saisie manuellement (dérivée du poids) : la
      // photo suffit à la montrer, cf. Step2DetailsState._sizeFromWeight.
      expect(find.text('Taille'), findsNothing);
      // « Catégories » (liste dépliée) est devenu « Contenu » (autocomplétion).
      expect(find.text('Contenu'), findsOneWidget);
      expect(find.text('Catégories'), findsNothing);
    });

    testWidgets(
      'les catégories passent par l\'autocomplétion, pas par la liste dépliée',
      (tester) async {
        // Les onze chips occupaient ~900 px et repoussaient la description
        // hors écran. Le combo est le même que celui de la création de trajet.
        await tester.pumpWidget(wrap(const Step2Details()));
        await tester.pump();

        expect(find.byType(ContentCategoryComboBox), findsOneWidget);
        // « Autre » fait partie du catalogue proposé par le combo.
        await tester.tap(find.byKey(const Key('package-content-field')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('package-content-item-Autre')),
          findsOneWidget,
        );
      },
    );

    testWidgets('submit sans catégorie → message d'
        "'"
        'erreur', (tester) async {
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      await tester.enterText(find.byType(TextFormField).first, '5');
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Choisis au moins une catégorie'), findsOneWidget);
    });

    testWidgets('validation poids échoue si vide', (tester) async {
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Valeur invalide'), findsOneWidget);
    });

    testWidgets('validation poids échoue si > 30', (tester) async {
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      await tester.enterText(find.byType(TextFormField).first, '35');
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Entre 0.5 et 30 kg'), findsOneWidget);
    });

    testWidgets('rend le champ Description (optionnel)', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      expect(find.text('Description (optionnel)'), findsOneWidget);
      expect(find.byKey(const Key('description-input')), findsOneWidget);
    });

    testWidgets('saisir une description → state.description après submit', (
      tester,
    ) async {
      tallViewport(tester);
      final bloc = PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key), bloc: bloc));
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.enterText(
        find.byKey(const Key('description-input')),
        'Colis fragile, vases en verre',
      );
      await tester.tap(find.byKey(const Key('package-content-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('package-content-item-Vêtements & tissus')),
      );
      await tester.pump();
      key.currentState!.submit();
      await tester.pump();
      expect(bloc.state.description, 'Colis fragile, vases en verre');
    });

    testWidgets('description vide → null (non envoyée)', (tester) async {
      tallViewport(tester);
      final bloc = PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key), bloc: bloc));
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.tap(find.byKey(const Key('package-content-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('package-content-item-Vêtements & tissus')),
      );
      await tester.pump();
      key.currentState!.submit();
      await tester.pump();
      expect(bloc.state.description, isNull);
    });

    testWidgets('prefill : state.description affichée dans le champ', (
      tester,
    ) async {
      when(
        () => mockBloc.state,
      ).thenReturn(const PackageRequestFormState(description: 'Déjà écrit'));
      await tester.pumpWidget(wrap(const Step2Details(), bloc: mockBloc));
      expect(find.text('Déjà écrit'), findsOneWidget);
    });

    testWidgets('taille dérivée du poids (≤ 3 kg → small) au submit', (
      tester,
    ) async {
      tallViewport(tester);
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key), bloc: mockBloc));
      await tester.enterText(find.byType(TextFormField).first, '2');
      await tester.tap(find.byKey(const Key('package-content-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('package-content-item-Vêtements & tissus')),
      );
      await tester.pump();
      key.currentState!.submit();
      await tester.pump();
      verify(
        () => mockBloc.add(
          const FormStep2Submitted(
            weightKg: 2,
            parcelSize: ParcelSize.small,
            categories: ['Vêtements & tissus'],
          ),
        ),
      ).called(1);
    });

    testWidgets(
      'sélectionner « Autre » propose une précision libre qui remplace la catégorie',
      (tester) async {
        tallViewport(tester);
        final bloc = PackageRequestFormBloc(
          repo,
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
        final key = GlobalKey<Step2DetailsState>();
        await tester.pumpWidget(wrap(Step2Details(key: key), bloc: bloc));
        await tester.enterText(find.byType(TextFormField).first, '5');
        await tester.tap(find.byKey(const Key('package-content-field')));
        await tester.pumpAndSettle();
        // « Autre » est le dernier item du catalogue : scroller la liste
        // interne du combo (tallViewport ne suffit pas, elle est clippée).
        await tester.ensureVisible(
          find.byKey(const Key('package-content-item-Autre')),
        );
        await tester.tap(find.byKey(const Key('package-content-item-Autre')));
        await tester.pumpAndSettle();

        // Le bottom sheet de précision s'ouvre automatiquement.
        expect(find.text('Précise le contenu (optionnel)'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('autre-detail-input')),
          'Instruments de musique',
        );
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();

        key.currentState!.submit();
        await tester.pump();
        expect(bloc.state.categories, ['Instruments de musique']);
      },
    );

    testWidgets(
      '« Autre » sans précision saisie reste tel quel dans la sélection',
      (tester) async {
        tallViewport(tester);
        final bloc = PackageRequestFormBloc(
          repo,
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
        final key = GlobalKey<Step2DetailsState>();
        await tester.pumpWidget(wrap(Step2Details(key: key), bloc: bloc));
        await tester.enterText(find.byType(TextFormField).first, '5');
        await tester.tap(find.byKey(const Key('package-content-field')));
        await tester.pumpAndSettle();
        // « Autre » est le dernier item du catalogue : scroller la liste
        // interne du combo (tallViewport ne suffit pas, elle est clippée).
        await tester.ensureVisible(
          find.byKey(const Key('package-content-item-Autre')),
        );
        await tester.tap(find.byKey(const Key('package-content-item-Autre')));
        await tester.pumpAndSettle();

        // Fermeture sans rien saisir (drag-to-dismiss simulé par un pop direct).
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        key.currentState!.submit();
        await tester.pump();
        expect(bloc.state.categories, ['Autre']);
      },
    );
  });
}
