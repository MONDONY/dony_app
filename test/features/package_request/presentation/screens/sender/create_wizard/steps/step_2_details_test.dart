import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/money_keyword_warning.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../../helpers/l10n_test_helpers.dart';
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
      expect(find.text('Décrivez votre colis'), findsOneWidget);
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
      expect(find.text('Choisissez au moins une catégorie'), findsOneWidget);
    });

    testWidgets('validation poids échoue si vide', (tester) async {
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Valeur invalide'), findsOneWidget);
    });

    testWidgets('validation poids échoue si < 0,5 : la fourchette', (
      tester,
    ) async {
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      await tester.enterText(find.byType(TextFormField).first, '0,2');
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Entre 0,5 et 32 kg'), findsOneWidget);
    });

    testWidgets('validation poids échoue si > 32 : invite à choisir Route', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      addTearDown(resetTransportModesForTest);
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      await tester.enterText(find.byType(TextFormField).first, '35');
      key.currentState!.submit();
      await tester.pump();
      expect(
        find.text("Au-delà de 32 kg, choisissez Route à l'étape précédente."),
        findsOneWidget,
      );
    });

    // Recette 13/11 : à 360 dp, « … choisissez Route à l'étape … » finissait
    // en points de suspension.
    for (final english in [false, true]) {
      testWidgets('360 dp ${english ? 'EN' : 'FR'} : message des 32 kg entier, '
          'sur plusieurs lignes', (tester) async {
        if (english) useEnglish();
        setTransportModes(
          const TransportModesAvailability(road: true, boat: false),
        );
        addTearDown(resetTransportModesForTest);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey<Step2DetailsState>();
        await tester.pumpWidget(wrap(Step2Details(key: key)));
        await tester.enterText(find.byType(TextFormField).first, '35');
        key.currentState!.submit();
        await tester.pump();
        final message = find.text(
          english
              ? 'Above 32 kg, choose Road in the previous step.'
              : "Au-delà de 32 kg, choisissez Route à l'étape précédente.",
        );
        expect(message, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(message).didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('écran traduit en anglais : titre, poids et plage de poids', (
      tester,
    ) async {
      useEnglish();
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      addTearDown(resetTransportModesForTest);
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));

      expect(find.text('Describe your parcel'), findsOneWidget);
      expect(find.text('Approximate weight'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '0.2');
      key.currentState!.submit();
      await tester.pump();

      expect(find.text('Between 0.5 and 32 kg'), findsOneWidget);
      expect(find.text('Entre 0,5 et 32 kg'), findsNothing);

      await tester.enterText(find.byType(TextFormField).first, '35');
      await tester.pump();
      expect(
        find.text('Above 32 kg, choose Road in the previous step.'),
        findsOneWidget,
      );
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
        expect(find.text('Précisez le contenu (optionnel)'), findsOneWidget);
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

  group('Step2Details : description qui évoque de l\'argent', () {
    final description = find.byKey(const Key('description-input'));
    final banner = find.byKey(MoneyKeywordWarning.bannerKey);

    /// 360 dp de large, la plus petite largeur visée ; assez haut pour que
    /// l'overlay du combo catégories reste à l'écran.
    void narrowViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(360, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> typeDescription(WidgetTester tester, String text) async {
      await tester.ensureVisible(description);
      await tester.enterText(description, text);
      await tester.pumpAndSettle();
    }

    testWidgets(
      '« cash » affiche le bandeau, l\'effacer le retire (360 dp, sans erreur)',
      (tester) async {
        narrowViewport(tester);
        await tester.pumpWidget(wrap(const Step2Details()));
        await tester.pump();
        expect(banner, findsNothing);

        await typeDescription(tester, 'cash');
        expect(banner, findsOneWidget);
        expect(find.text("Envoi d'argent interdit"), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester.getTopLeft(banner).dy,
          greaterThan(tester.getBottomLeft(description).dy),
        );

        await typeDescription(tester, '');
        expect(banner, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('« vêtements » n\'affiche aucun bandeau', (tester) async {
      narrowViewport(tester);
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pump();

      await typeDescription(tester, 'vêtements');
      expect(banner, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en anglais : bandeau traduit, sans erreur à 360 dp', (
      tester,
    ) async {
      useEnglish();
      narrowViewport(tester);
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pump();

      await typeDescription(tester, 'some money');
      expect(find.text('Sending money is prohibited'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('non bloquant : la description part telle quelle au submit', (
      tester,
    ) async {
      narrowViewport(tester);
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key), bloc: mockBloc));
      await tester.enterText(find.byType(TextFormField).first, '2');
      await tester.tap(find.byKey(const Key('package-content-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('package-content-item-Vêtements & tissus')),
      );
      await tester.pumpAndSettle();
      await typeDescription(tester, 'Vêtements et un peu de cash');
      expect(banner, findsOneWidget);

      key.currentState!.submit();
      await tester.pump();
      verify(
        () => mockBloc.add(
          const FormStep2Submitted(
            weightKg: 2,
            parcelSize: ParcelSize.small,
            categories: ['Vêtements & tissus'],
            description: 'Vêtements et un peu de cash',
          ),
        ),
      ).called(1);
    });
  });

  group('Step2Details : avion seul (route éteinte, prod actuelle)', () {
    PackageRequestFormBloc editing({TransportMode? mode, double weight = 5}) {
      final bloc = PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: PackageRequest(
          id: 'r-1',
          senderId: 's-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          dateToleranceDays: 0,
          weightKg: weight,
          parcelSize: ParcelSize.large,
          transportMode: mode,
          categories: const ['Meubles'],
          status: PackageRequestStatus.open,
          createdAt: DateTime(2026, 11, 12),
        ),
      );
      addTearDown(bloc.close);
      return bloc;
    }

    void viewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    setUp(resetTransportModesForTest);

    testWidgets("33 kg : l'ancien message, jamais « choisissez Route »", (
      tester,
    ) async {
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      await tester.enterText(find.byType(TextFormField).first, '33');
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Entre 0,5 et 32 kg'), findsOneWidget);
      expect(find.textContaining('choisissez Route'), findsNothing);
    });

    testWidgets('anglais, 33 kg : « Between 0.5 and 32 kg »', (tester) async {
      useEnglish();
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key)));
      await tester.enterText(find.byType(TextFormField).first, '33');
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Between 0.5 and 32 kg'), findsOneWidget);
      expect(find.textContaining('choose Road'), findsNothing);
    });

    testWidgets('ancienne demande sans mode : pas de section taille, '
        "33 kg refusé avec l'ancien texte", (tester) async {
      viewport(tester);
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);
      await tester.pumpWidget(
        wrap(
          Step2Details(canContinueNotifier: canContinue),
          bloc: editing(weight: 20),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('request-item-size-section')), findsNothing);
      expect(canContinue.value, isTrue);

      await tester.enterText(find.byType(TextFormField).first, '33');
      await tester.pump();
      expect(canContinue.value, isFalse);
      expect(find.text('Entre 0,5 et 32 kg'), findsOneWidget);
      expect(find.textContaining('choisissez Route'), findsNothing);
    });
  });

  group('Step2Details : route, tonnes et taille facultative', () {
    const sep = ' ';

    // Route proposée (interrupteur allumé) : l'écran invite à choisir Route et
    // « peu importe » porte la taille. Avion seul : voir le groupe dédié.
    setUp(() {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      addTearDown(resetTransportModesForTest);
    });

    PackageRequest request({
      TransportMode? mode,
      double weight = 5,
      ItemSize? size,
      (int, int, int)? dimensions,
    }) => PackageRequest(
      id: 'r-1',
      senderId: 's-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      dateToleranceDays: 0,
      weightKg: weight,
      parcelSize: ParcelSize.large,
      transportMode: mode,
      itemSize: size,
      lengthCm: dimensions?.$1,
      widthCm: dimensions?.$2,
      heightCm: dimensions?.$3,
      categories: const ['Meubles'],
      status: PackageRequestStatus.open,
      createdAt: DateTime(2026, 11, 12),
    );

    /// Bloc en édition : mode, poids et taille sont connus dès le premier
    /// frame (la demande ouverte sert d'état initial). `mode: null` donne
    /// « peu importe ».
    PackageRequestFormBloc editing({
      TransportMode? mode,
      double weight = 5,
      ItemSize? size,
      (int, int, int)? dimensions,
    }) {
      final bloc = PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: request(
          mode: mode,
          weight: weight,
          size: size,
          dimensions: dimensions,
        ),
      );
      addTearDown(bloc.close);
      return bloc;
    }

    void viewport(WidgetTester tester, {double width = 1000}) {
      tester.view.physicalSize = Size(width, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    final sizeSection = find.byKey(const Key('request-item-size-section'));
    Finder tile(String code) => find.byKey(Key('item-size-$code'));

    Future<ValueNotifier<bool>> pump(
      WidgetTester tester,
      PackageRequestFormBloc bloc,
    ) async {
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);
      await tester.pumpWidget(
        wrap(Step2Details(canContinueNotifier: canContinue), bloc: bloc),
      );
      await tester.pump();
      return canContinue;
    }

    testWidgets('route : taille facultative, Continuer actif sans taille', (
      tester,
    ) async {
      viewport(tester);
      final bloc = editing(mode: TransportMode.car, weight: 1200);
      final canContinue = await pump(tester, bloc);

      expect(sizeSection, findsOneWidget);
      expect(find.text('Taille du colis (facultatif)'), findsOneWidget);
      expect(
        find.text(
          'Aide les voyageurs à voir si votre colis tient dans leur véhicule.',
        ),
        findsOneWidget,
      );
      expect(bloc.state.itemSize, isNull);
      expect(canContinue.value, isTrue);

      await tester.tap(tile('L'));
      await tester.pump();
      expect(bloc.state.itemSize, ItemSize.l);
      expect(canContinue.value, isTrue);

      // Second tap sur la tuile choisie : la taille est retirée.
      await tester.tap(tile('L'));
      await tester.pump();
      expect(bloc.state.itemSize, isNull);
      expect(canContinue.value, isTrue);
    });

    testWidgets('route : la taille déjà choisie est repérée', (tester) async {
      viewport(tester);
      await pump(
        tester,
        editing(mode: TransportMode.car, weight: 40, size: ItemSize.xl),
      );
      final selected = tester.widget<Semantics>(tile('XL'));
      expect(tester.widget<Semantics>(tile('S')).properties.selected, isFalse);
      expect(selected.properties.selected, isTrue);
    });

    testWidgets('avion : pas de bloc taille, aide « Entre 0,5 et 32 kg »', (
      tester,
    ) async {
      viewport(tester);
      final canContinue = await pump(
        tester,
        editing(mode: TransportMode.plane),
      );

      expect(sizeSection, findsNothing);
      expect(find.text('Taille du colis (facultatif)'), findsNothing);
      expect(find.text('Entre 0,5 et 32 kg.'), findsOneWidget);
      expect(canContinue.value, isTrue);
    });

    testWidgets('bateau : pas de bloc taille, poids sans plafond', (
      tester,
    ) async {
      viewport(tester);
      final canContinue = await pump(
        tester,
        editing(
          mode: TransportMode.boat,
          weight: 5000,
          dimensions: (50, 40, 30),
        ),
      );
      expect(sizeSection, findsNothing);
      expect(canContinue.value, isTrue);
    });

    testWidgets('peu importe : taille proposée en option, 32 kg max', (
      tester,
    ) async {
      viewport(tester);
      final bloc = editing(weight: 20);
      final canContinue = await pump(tester, bloc);
      expect(sizeSection, findsOneWidget);
      expect(find.text('Entre 0,5 et 32 kg.'), findsOneWidget);
      expect(canContinue.value, isTrue);

      await tester.enterText(find.byType(TextFormField).first, '33');
      await tester.pump();
      expect(canContinue.value, isFalse);
      expect(
        find.text("Au-delà de 32 kg, choisissez Route à l'étape précédente."),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField).first, '32');
      await tester.pump();
      expect(canContinue.value, isTrue);
    });

    testWidgets('route 1 200 kg puis avion : Continuer grisé, message Route', (
      tester,
    ) async {
      viewport(tester);
      // Poids repris d'une demande en route, mode repassé en avion : rien
      // n'est effacé, l'erreur est visible dès l'ouverture.
      final canContinue = await pump(
        tester,
        editing(mode: TransportMode.plane, weight: 1200),
      );

      expect(find.widgetWithText(TextFormField, '1${sep}200'), findsOneWidget);
      expect(canContinue.value, isFalse);
      expect(
        find.text("Au-delà de 32 kg, choisissez Route à l'étape précédente."),
        findsOneWidget,
      );
      expect(sizeSection, findsNothing);
    });

    testWidgets('route : poids jusqu\'à 999 999 kg, au-delà refusé', (
      tester,
    ) async {
      viewport(tester);
      final canContinue = await pump(
        tester,
        editing(mode: TransportMode.car, weight: 12),
      );
      const help = "À partir de 0,5 kg, sans plafond (jusqu'à 999 999 kg).";
      expect(find.text(help), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '999999');
      await tester.pump();
      expect(canContinue.value, isTrue);
      expect(find.text(help), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '1000000');
      await tester.pump();
      expect(canContinue.value, isFalse);
      // Aide et erreur disent la même fourchette ; jamais l'invite « Route ».
      expect(find.text(help), findsNWidgets(2));
      expect(find.textContaining('choisissez Route'), findsNothing);
    });

    testWidgets(
      'gros chiffre : 1200 saisi s\'affiche « 1 200 », part en 1200',
      (tester) async {
        viewport(tester);
        final bloc = editing(mode: TransportMode.car);
        final key = GlobalKey<Step2DetailsState>();
        await tester.pumpWidget(wrap(Step2Details(key: key), bloc: bloc));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, '1200');
        await tester.pump();
        expect(
          find.widgetWithText(TextFormField, '1${sep}200'),
          findsOneWidget,
        );

        key.currentState!.submit();
        await tester.pump();
        expect(bloc.state.weightKg, 1200);
        expect(bloc.state.currentStep, 2);
      },
    );

    Future<double?> submittedWeight(
      WidgetTester tester,
      String typed, {
      TransportMode mode = TransportMode.car,
    }) async {
      viewport(tester);
      final bloc = editing(mode: mode);
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key), bloc: bloc));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, typed);
      await tester.pump();
      key.currentState!.submit();
      await tester.pump();
      return bloc.state.currentStep == 2 ? bloc.state.weightKg : null;
    }

    testWidgets('route, anglais : « 1,200 » collé vaut 1 200 kg, pas 1,2', (
      tester,
    ) async {
      useEnglish();
      expect(await submittedWeight(tester, '1,200'), 1200);
      // Le champ montre ce qui est retenu.
      expect(find.widgetWithText(TextFormField, '1${sep}200'), findsOneWidget);
    });

    testWidgets('route, français : « 1 200 » vaut 1 200 kg', (tester) async {
      expect(await submittedWeight(tester, '1 200'), 1200);
    });

    testWidgets('route : « 1.5 » vaut 1,5 et « 1200.5 » vaut 1 200,5', (
      tester,
    ) async {
      expect(await submittedWeight(tester, '1.5'), 1.5);
    });

    testWidgets('route : « 1200.5 » vaut 1 200,5', (tester) async {
      expect(await submittedWeight(tester, '1200.5'), 1200.5);
    });

    testWidgets('avion : « 1,200 » reste décimal, 1,2 kg', (tester) async {
      expect(
        await submittedWeight(tester, '1,200', mode: TransportMode.plane),
        1.2,
      );
    });

    testWidgets('1 200,5 kg : décimale gardée', (tester) async {
      viewport(tester);
      final bloc = editing(mode: TransportMode.car);
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(wrap(Step2Details(key: key), bloc: bloc));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, '1200,5');
      await tester.pump();
      key.currentState!.submit();
      await tester.pump();
      expect(bloc.state.weightKg, 1200.5);
    });

    testWidgets('brouillon : la saisie groupée part en nombre', (tester) async {
      viewport(tester);
      final key = GlobalKey<Step2DetailsState>();
      await tester.pumpWidget(
        wrap(
          Step2Details(key: key),
          bloc: editing(mode: TransportMode.car),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, '2500');
      await tester.pump();
      expect(key.currentState!.draftInput['weightKg'], 2500);
      expect(key.currentState!.hasUnsubmittedInput, isTrue);
    });

    for (final locale in ['fr', 'en']) {
      testWidgets('360 dp $locale : tuiles de taille sans débordement', (
        tester,
      ) async {
        if (locale == 'en') useEnglish();
        viewport(tester, width: 360);
        await pump(tester, editing(mode: TransportMode.car, weight: 1200));

        final heights = <double>{};
        for (final code in ['S', 'M', 'L', 'XL']) {
          final rect = tester.getRect(tile(code));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
          heights.add(rect.height);
        }
        expect(heights, hasLength(1));
        expect(
          find.text(
            locale == 'en'
                ? 'Parcel size (optional)'
                : 'Taille du colis (facultatif)',
          ),
          findsOneWidget,
        );
        // Le gros chiffre à quatre chiffres tient dans le champ.
        expect(
          find.widgetWithText(TextFormField, '1${sep}200'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('anglais : aide route traduite', (tester) async {
      useEnglish();
      viewport(tester);
      await pump(tester, editing(mode: TransportMode.car, weight: 12));
      expect(
        find.text('From 0.5 kg, no cap (up to 999,999 kg).'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Helps travelers see whether your parcel fits in their vehicle.',
        ),
        findsOneWidget,
      );
    });
  });
}
