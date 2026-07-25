import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart'
    show OptionButton;
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
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
    testWidgets('rend titre + sous-titre + labels de section', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      expect(find.text('Décris ton colis'), findsOneWidget);
      expect(
        find.textContaining('Ces infos aident les voyageurs'),
        findsOneWidget,
      );
      expect(find.text('Poids approximatif'), findsOneWidget);
      expect(find.text('Taille'), findsOneWidget);
      // « Catégories » (liste dépliée) est devenu « Contenu » (autocomplétion).
      expect(find.text('Contenu'), findsOneWidget);
      expect(find.text('Catégories'), findsNothing);
    });

    testWidgets('rend 3 cards de taille (S/M/L)', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      expect(find.text('S'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('Sac'), findsOneWidget);
      expect(find.text('Carton'), findsOneWidget);
      expect(find.text('Valise'), findsOneWidget);
    });

    testWidgets(
      'les catégories passent par l\'autocomplétion, pas par la liste dépliée',
      (tester) async {
        // Les onze chips occupaient ~900 px et repoussaient la description
        // hors écran. Le combo est le même que celui de la création de trajet.
        await tester.pumpWidget(wrap(const Step2Details()));
        await tester.pump();

        expect(find.byType(ContentCategoryComboBox), findsOneWidget);
        // Seuls les raccourcis « Fréquents » restent en chips.
        expect(find.text('Fréquents'), findsOneWidget);
        expect(find.byType(OptionButton), findsNWidgets(4));
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
      await tester.ensureVisible(find.text('Vêtements & tissus'));
      await tester.tap(find.text('Vêtements & tissus'));
      await tester.pump();
      key.currentState!.submit();
      await tester.pump();
      expect(bloc.state.description, 'Colis fragile, vases en verre');
    });

    testWidgets('description vide → null (non envoyée)', (tester) async {
      final bloc = PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key), bloc: bloc));
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.ensureVisible(find.text('Vêtements & tissus'));
      await tester.tap(find.text('Vêtements & tissus'));
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
  });
}
