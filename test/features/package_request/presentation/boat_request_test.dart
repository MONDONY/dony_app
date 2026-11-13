// Demande d'envoi en bateau : dimensions et volume à l'étape « Le colis »,
// prix au m³ et encadré du versement au dépôt à l'étape « Le prix », aperçu
// et récapitulatif. Avion, route et « peu importe » gardent leur écran.
import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';
import '../../../helpers/plane_icon_expectations.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

class _FakeCategories implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

PackageRequestFormState _seed({
  TransportMode? mode = TransportMode.boat,
  bool any = false,
  double weight = 40,
  int? l,
  int? w,
  int? h,
  SupportedCurrency currency = SupportedCurrency.eur,
}) => PackageRequestFormState(
  currentStep: 1,
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
  transportMode: mode,
  transportModeAny: any,
  weightKg: weight,
  parcelSize: ParcelSize.large,
  categories: const ['Meubles'],
  lengthCm: l,
  widthCm: w,
  heightCm: h,
  currency: currency,
);

void main() {
  late _MockRepo repo;
  late PackageRequestFormBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerFallbackValue(<PaymentMethod>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repo = _MockRepo();
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    getIt.registerFactory<IContentCategoryRepository>(_FakeCategories.new);
    setTransportModes(const TransportModesAvailability(road: true, boat: true));
  });

  tearDown(() {
    resetTransportModesForTest();
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
  });

  Future<void> pumpStep(
    WidgetTester tester,
    Widget Function() step,
    PackageRequestFormState seed, {
    double width = 360,
    double height = 900,
  }) async {
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bloc = PackageRequestFormBloc(
      repo,
      analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
    )..add(FormDraftRestored(seed));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<PackageRequestFormBloc>.value(value: bloc),
            BlocProvider(
              create: (_) => PackageRequestPhotosCubit(
                repo,
                makeDisabledAnalytics(MockAnalyticsBackend()),
              ),
            ),
          ],
          child: Scaffold(body: step()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('étape « Le colis » (Step2Details)', () {
    late ValueNotifier<bool> canContinue;
    late GlobalKey<Step2DetailsState> key;

    setUp(() {
      canContinue = ValueNotifier<bool>(false);
      key = GlobalKey<Step2DetailsState>();
    });
    tearDown(() => canContinue.dispose());

    Future<void> pump(
      WidgetTester tester,
      PackageRequestFormState seed, {
      double width = 360,
    }) => pumpStep(
      tester,
      () => Step2Details(key: key, canContinueNotifier: canContinue),
      seed,
      width: width,
    );

    final length = find.byKey(const Key('request-dimension-length'));
    final width = find.byKey(const Key('request-dimension-width'));
    final height = find.byKey(const Key('request-dimension-height'));

    Future<void> typeDims(
      WidgetTester tester,
      String l,
      String w,
      String h,
    ) async {
      await tester.enterText(length, l);
      await tester.enterText(width, w);
      await tester.enterText(height, h);
      await tester.pump();
    }

    testWidgets('boat_requiresDimensions : « Continuer » attend les trois', (
      tester,
    ) async {
      await pump(tester, _seed());
      expect(
        find.byKey(const Key('request-dimensions-section')),
        findsOneWidget,
      );
      expect(find.text('Dimensions du colis'), findsOneWidget);
      expect(find.text('Longueur'), findsOneWidget);
      expect(find.text('Largeur'), findsOneWidget);
      expect(find.text('Hauteur'), findsOneWidget);
      // Poids et catégorie valides, dimensions absentes : bloqué.
      expect(canContinue.value, isFalse);

      await tester.enterText(length, '50');
      await tester.enterText(width, '40');
      await tester.pump();
      expect(canContinue.value, isFalse);

      await tester.enterText(height, '30');
      await tester.pump();
      expect(canContinue.value, isTrue);
    });

    testWidgets('boat_requiresDimensions : bornes 1 à 400 cm', (tester) async {
      await pump(tester, _seed());
      await typeDims(tester, '401', '40', '30');
      expect(canContinue.value, isFalse);
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Entre 1 et 400 cm'), findsOneWidget);

      await typeDims(tester, '0', '40', '30');
      expect(canContinue.value, isFalse);
      await typeDims(tester, '400', '1', '1');
      expect(canContinue.value, isTrue);
    });

    testWidgets(
      'boat_requiresDimensions : une case vide signale « Obligatoire »',
      (tester) async {
        await pump(tester, _seed());
        key.currentState!.submit();
        await tester.pump();
        expect(find.text('Obligatoire'), findsNWidgets(3));
      },
    );

    testWidgets('boat_volumeDisplayed : « 0,10 m³ » pour 50 × 40 × 50 cm', (
      tester,
    ) async {
      await pump(tester, _seed());
      expect(find.byKey(const Key('request-volume-preview')), findsNothing);
      await typeDims(tester, '50', '40', '50');
      expect(find.text('Volume : 0,10 m³'), findsOneWidget);
      // Trois décimales quand il le faut.
      await typeDims(tester, '30', '30', '30');
      expect(find.text('Volume : 0,027 m³'), findsOneWidget);
    });

    testWidgets('boat_volumeDisplayed : en anglais, point décimal', (
      tester,
    ) async {
      useEnglish();
      await pump(tester, _seed());
      await typeDims(tester, '50', '40', '50');
      expect(find.text('Package dimensions'), findsOneWidget);
      expect(find.text('Volume: 0.10 m³'), findsOneWidget);
      expect(find.text('Length'), findsOneWidget);
    });

    testWidgets('submit : les dimensions remontent au bloc', (tester) async {
      await pump(tester, _seed());
      await typeDims(tester, '50', '40', '30');
      key.currentState!.submit();
      await tester.pump();
      expect(bloc.state.currentStep, 2);
      expect(
        [bloc.state.lengthCm, bloc.state.widthCm, bloc.state.heightCm],
        [50, 40, 30],
      );
      expect(bloc.state.volumeM3, 0.06);
    });

    testWidgets('reprise : dimensions du bloc préremplies', (tester) async {
      await pump(tester, _seed(l: 50, w: 40, h: 30));
      expect(find.widgetWithText(TextFormField, '50'), findsOneWidget);
      expect(find.text('Volume : 0,06 m³'), findsOneWidget);
      expect(canContinue.value, isTrue);
      expect(key.currentState!.draftInput, containsPair('lengthCm', 50));
      expect(key.currentState!.hasUnsubmittedInput, isFalse);
      await tester.enterText(length, '60');
      await tester.pump();
      expect(key.currentState!.hasUnsubmittedInput, isTrue);
      expect(key.currentState!.draftInput['lengthCm'], 60);
    });

    testWidgets('any_dimensionsOptional : bloc replié, étape non bloquée', (
      tester,
    ) async {
      await pump(tester, _seed(mode: null, any: true, weight: 20));
      expect(find.byKey(const Key('request-dimensions-add')), findsOneWidget);
      expect(find.text('Ajouter les dimensions'), findsOneWidget);
      expect(length, findsNothing);
      expect(canContinue.value, isTrue);

      await tester.tap(find.byKey(const Key('request-dimensions-add')));
      await tester.pump();
      expect(length, findsOneWidget);
      expect(find.text('Dimensions du colis (facultatif)'), findsOneWidget);
      // Dépliées et vides : toujours facultatives.
      expect(canContinue.value, isTrue);
      expect(key.currentState!.draftInput['lengthCm'], isNull);
    });

    testWidgets('any_dimensionsOptional : tout ou rien une fois saisies', (
      tester,
    ) async {
      await pump(tester, _seed(mode: null, any: true, weight: 20));
      await tester.tap(find.byKey(const Key('request-dimensions-add')));
      await tester.pump();

      await tester.enterText(length, '50');
      await tester.pump();
      expect(canContinue.value, isFalse);
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Obligatoire'), findsNWidgets(2));

      await typeDims(tester, '50', '40', '30');
      expect(canContinue.value, isTrue);
      key.currentState!.submit();
      await tester.pump();
      expect(bloc.state.volumeM3, 0.06);
    });

    testWidgets('any_dimensionsOptional : bateau éteint, aucun bloc', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      await pump(tester, _seed(mode: null, any: true, weight: 20));
      expect(find.byKey(const Key('request-dimensions-section')), findsNothing);
    });

    testWidgets('« peu importe » avec dimensions reprises : bloc déplié', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      await pump(
        tester,
        _seed(mode: null, any: true, weight: 20, l: 50, w: 40, h: 30),
      );
      expect(length, findsOneWidget);
      expect(find.text('Volume : 0,06 m³'), findsOneWidget);
    });

    for (final mode in [TransportMode.plane, TransportMode.car]) {
      testWidgets('plane_unchanged : ${mode.name}, pas de dimensions et pas '
          'd\'icône avion', (tester) async {
        await pump(tester, _seed(mode: mode, weight: 20));
        expect(
          find.byKey(const Key('request-dimensions-section')),
          findsNothing,
        );
        expect(length, findsNothing);
        expect(canContinue.value, isTrue);
        key.currentState!.submit();
        await tester.pump();
        expect(bloc.state.hasDimensions, isFalse);
        if (mode != TransportMode.plane) expectNoPlaneIcon(tester);
      });
    }

    testWidgets('boat_noPlaneIcon : étape bateau sans icône avion', (
      tester,
    ) async {
      await pump(tester, _seed());
      expectNoPlaneIcon(tester);
      await tester.tap(find.byType(Scrollable).first);
    });

    for (final english in [false, true]) {
      testWidgets('${english ? 'en' : 'fr'} : 360 dp, libellés sur une ligne, '
          'rien ne déborde', (tester) async {
        if (english) useEnglish();
        await pump(tester, _seed(l: 400, w: 400, h: 400));
        expect(tester.takeException(), isNull);
        for (final f in [length, width, height]) {
          expect(tester.getSize(f).width, greaterThan(60));
        }
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '');
        for (final s in texts) {
          expect(s.contains('—'), isFalse, reason: s);
        }
        // Volume maximal : « 64,00 m³ », sur une seule ligne.
        final volume = tester.getSize(
          find.byKey(const Key('request-volume-preview')),
        );
        expect(volume.height, lessThan(30));
      });
    }

    testWidgets('« peu importe » replié, 360 dp en français et anglais', (
      tester,
    ) async {
      for (final english in [false, true]) {
        if (english) useEnglish();
        await pump(tester, _seed(mode: null, any: true, weight: 20));
        expect(tester.takeException(), isNull);
        final box = tester.getSize(
          find.byKey(const Key('request-dimensions-add')),
        );
        expect(box.height, lessThan(100));
      }
    });
  });

  group('étape « Le prix » (Step3RecapBudget)', () {
    late ValueNotifier<bool> canContinue;
    late GlobalKey<Step3RecapBudgetState> key;

    setUp(() {
      canContinue = ValueNotifier<bool>(false);
      key = GlobalKey<Step3RecapBudgetState>();
    });
    tearDown(() => canContinue.dispose());

    Future<void> pump(
      WidgetTester tester,
      PackageRequestFormState seed, {
      double width = 360,
    }) => pumpStep(
      tester,
      () => Step3RecapBudget(
        key: key,
        canContinueNotifier: canContinue,
        currency: seed.currency,
      ),
      seed,
      width: width,
      height: 1400,
    );

    final perM3 = find.byKey(const Key('price-basis-per-m3'));
    final input = find.byKey(const Key('total-budget-input'));

    Future<void> total(WidgetTester tester, String text) async {
      await tester.enterText(input, text);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('boat_pricePerM3_sendsTotalOnly : 0,10 m³ × 600 € = 60 €', (
      tester,
    ) async {
      await pump(tester, _seed(l: 50, w: 40, h: 50));
      expect(perM3, findsOneWidget);
      await tester.tap(perM3);
      await tester.pump();
      expect(find.text('€ / m³'), findsOneWidget);

      await total(tester, '600');
      // Seul le total est dans le bloc : volume × prix au m³.
      expect(bloc.state.totalBudgetEur, 60);
      final price = CurrencyFormatter.format(
        600,
        SupportedCurrency.eur,
        compact: true,
      );
      final sum = CurrencyFormatter.format(60, SupportedCurrency.eur);
      expect(
        find.text('0,10 m³ × $price / m³ = $sum au total'),
        findsOneWidget,
      );
      expect(
        find.textContaining("Prix de l'envoi (0,10 m³ × "),
        findsOneWidget,
      );
    });

    testWidgets('le total part au back, sans prix au m³ ni volume', (
      tester,
    ) async {
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          photoKeys: any(named: 'photoKeys'),
          saveAsDraft: any(named: 'saveAsDraft'),
          promoCode: any(named: 'promoCode'),
          currency: any(named: 'currency'),
          itemSize: any(named: 'itemSize'),
          lengthCm: any(named: 'lengthCm'),
          widthCm: any(named: 'widthCm'),
          heightCm: any(named: 'heightCm'),
        ),
      ).thenAnswer(
        (_) async => PackageRequest(
          id: 'r-1',
          senderId: 's',
          departureCity: 'Paris',
          arrivalCity: 'Abidjan',
          dateToleranceDays: 0,
          weightKg: 40,
          parcelSize: ParcelSize.large,
          transportMode: TransportMode.boat,
          status: PackageRequestStatus.open,
          createdAt: DateTime(2026, 11, 13),
        ),
      );
      await pump(tester, _seed(l: 50, w: 40, h: 50));
      await tester.tap(perM3);
      await tester.pump();
      await total(tester, '600');
      key.currentState!.submit();
      await tester.pump();
      await tester.pump();

      final call = verify(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: TransportMode.boat,
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: captureAny(named: 'totalBudgetEur'),
          saveAsDraft: any(named: 'saveAsDraft'),
          currency: any(named: 'currency'),
          lengthCm: captureAny(named: 'lengthCm'),
          widthCm: captureAny(named: 'widthCm'),
          heightCm: captureAny(named: 'heightCm'),
        ),
      );
      expect(call.captured, [60, 50, 40, 50]);
    });

    testWidgets('revenir au prix total reprend le total calculé', (
      tester,
    ) async {
      await pump(tester, _seed(l: 50, w: 40, h: 50));
      await tester.tap(perM3);
      await tester.pump();
      await total(tester, '600');
      await tester.tap(find.byKey(const Key('price-basis-total')));
      await tester.pump();
      expect(tester.widget<TextFormField>(input).controller!.text, '60');
      // Total → m³ : 60 € pour 0,10 m³ redonne 600 € le m³.
      await tester.tap(perM3);
      await tester.pump();
      expect(tester.widget<TextFormField>(input).controller!.text, '600');
    });

    testWidgets('boat_noBudgetCap : 5 000 € accepté, au-delà de 560 €', (
      tester,
    ) async {
      await pump(tester, _seed(l: 50, w: 40, h: 50));
      await total(tester, '5000');
      expect(bloc.state.totalBudgetEur, 5000);
      expect(canContinue.value, isTrue);
      expect(find.textContaining('560'), findsNothing);
    });

    testWidgets('boat_noBudgetCap : seul le garde-fou technique refuse', (
      tester,
    ) async {
      await pump(tester, _seed(l: 50, w: 40, h: 50));
      await total(tester, '1000001');
      expect(canContinue.value, isFalse);
      key.currentState!.submit();
      await tester.pump();
      expect(find.textContaining('Montant trop élevé'), findsOneWidget);
    });

    testWidgets('boat_noBudgetCap : prix au m³ à 5 000 € le m³ sans plafond', (
      tester,
    ) async {
      await pump(tester, _seed(l: 100, w: 100, h: 100));
      await tester.tap(perM3);
      await tester.pump();
      await total(tester, '5000');
      expect(bloc.state.totalBudgetEur, 5000);
      expect(canContinue.value, isTrue);
    });

    for (final (label, seed) in [
      ('avion', _seed(mode: TransportMode.plane, weight: 5)),
      ('peu importe', _seed(mode: null, any: true, weight: 5)),
    ]) {
      testWidgets('plane_budgetCapUnchanged : $label, 600 € refusé', (
        tester,
      ) async {
        await pump(tester, seed);
        await total(tester, '600');
        expect(canContinue.value, isFalse);
        await total(tester, '500');
        expect(canContinue.value, isTrue);
        // Pas de segment « Prix au m³ » hors bateau.
        expect(perM3, findsNothing);
        expect(
          find.byKey(const Key('request-boat-deposit-notice')),
          findsNothing,
        );
      });
    }

    testWidgets('route : segment au m³ absent, plafond levé, sans avion', (
      tester,
    ) async {
      await pump(tester, _seed(mode: TransportMode.car, weight: 5));
      expect(perM3, findsNothing);
      await total(tester, '5000');
      expect(canContinue.value, isTrue);
      expectNoPlaneIcon(tester);
    });

    testWidgets('boat_depositNoticeShown : délai et versement au dépôt', (
      tester,
    ) async {
      await pump(tester, _seed(l: 50, w: 40, h: 50));
      final notice = find.byKey(const Key('request-boat-deposit-notice'));
      expect(notice, findsOneWidget);
      expect(
        find.descendant(
          of: notice,
          matching: find.text(
            'Par bateau, comptez plusieurs semaines. Le transporteur est payé '
            "dès le dépôt de votre colis à l'entrepôt : le paiement n'attend "
            'pas la livraison.',
          ),
        ),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('boat_depositNoticeShown : en anglais', (tester) async {
      useEnglish();
      await pump(tester, _seed(l: 50, w: 40, h: 50));
      expect(find.textContaining('By boat, expect several weeks.'), findsOne);
      expect(find.text('Price per m³'), findsOneWidget);
    });

    testWidgets('sans dimensions : « Prix au m³ » grisé et expliqué', (
      tester,
    ) async {
      await pump(tester, _seed());
      expect(perM3, findsOneWidget);
      await tester.tap(perM3);
      await tester.pump();
      // Le tap est sans effet : le champ reste en prix total.
      expect(find.text('€ au total'), findsOneWidget);
      expect(find.byKey(const Key('price-basis-per-m3-hint')), findsOneWidget);
    });

    testWidgets('récap : poids et volume sur une ligne', (tester) async {
      await pump(tester, _seed(l: 50, w: 40, h: 50));
      expect(find.byType(WizardSummaryCard), findsOneWidget);
      expect(find.text('40 kg · 0,10 m³'), findsOneWidget);
    });

    for (final english in [false, true]) {
      testWidgets('${english ? 'en' : 'fr'} : 360 dp, trois segments sur une '
          'ligne, aucun tiret cadratin', (tester) async {
        if (english) useEnglish();
        await pump(tester, _seed(l: 50, w: 40, h: 50));
        expect(tester.takeException(), isNull);
        for (final k in [
          'price-basis-total',
          'price-basis-per-kilo',
          'price-basis-per-m3',
        ]) {
          final box = tester.getSize(find.byKey(Key(k)));
          expect(box.height, lessThan(60), reason: k);
          expect(box.width, greaterThan(90), reason: k);
        }
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
        for (final s in texts) {
          expect(s.contains('—'), isFalse, reason: s);
        }
        // Libellé sans rétrécissement : taille 12,5 des autres segments.
        for (final t in tester.widgetList<Text>(
          find.descendant(of: perM3, matching: find.byType(Text)),
        )) {
          expect(t.style?.fontSize, 12.5);
          expect(t.maxLines, 1);
        }
      });
    }
  });

  group('aperçu de publication', () {
    testWidgets('boat : volume et dimensions affichés', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PackageRequestPreviewSheet.show(
                  context,
                  formState: _seed(l: 50, w: 40, h: 50),
                  onConfirm: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('0,10 m³ (50 × 40 × 50 cm)'), findsOneWidget);
    });

    testWidgets('avion : pas de ligne volume', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PackageRequestPreviewSheet.show(
                  context,
                  formState: _seed(mode: TransportMode.plane, weight: 5),
                  onConfirm: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Volume'), findsNothing);
    });
  });
}
