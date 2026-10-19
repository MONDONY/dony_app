import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/negotiation_quote.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../../helpers/commission_grid_test_doubles.dart';
import '../../../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

class _MockConfigRepo extends Mock implements IConfigRepository {}

void _unregisterRepos() {
  if (getIt.isRegistered<PackageRequestRepository>()) {
    getIt.unregister<PackageRequestRepository>();
  }
  if (getIt.isRegistered<IConfigRepository>()) {
    getIt.unregister<IConfigRepository>();
  }
}

class _MockFormBloc
    extends MockBloc<PackageRequestFormEvent, PackageRequestFormState>
    implements PackageRequestFormBloc {}

void main() {
  late _MockRepo repo;
  late _MockFormBloc mockBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  setUp(() {
    repo = _MockRepo();
    mockBloc = _MockFormBloc();
    when(() => mockBloc.state).thenReturn(const PackageRequestFormState());
    when(
      () => mockBloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestFormState>.empty());
  });

  Widget wrap(
    Widget child, {
    PackageRequestFormState? seed,
    bool useMock = false,
  }) {
    if (useMock && seed != null) {
      when(() => mockBloc.state).thenReturn(seed);
    }
    final bloc = useMock
        ? mockBloc
        : PackageRequestFormBloc(
            repo,
            analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
          );
    return MaterialApp(
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
        child: Scaffold(body: child),
      ),
    );
  }

  group('Step3RecapBudget', () {
    testWidgets('rend titre + récap + budget', (tester) async {
      await tester.pumpWidget(wrap(const Step3RecapBudget()));
      expect(find.text('Budget'), findsOneWidget);
      expect(find.byType(WizardSummaryCard), findsOneWidget);
      // Budget input (1 TextFormField visible dans cette étape)
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('le récap reflète les choix précédents stockés dans le state', (
      tester,
    ) async {
      final seed = PackageRequestFormState(
        currentStep: 2,
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 6, 15),
        dateToleranceDays: 2,
        transportMode: TransportMode.plane,
        weightKg: 5,
        parcelSize: ParcelSize.medium,
        categories: const ['Vêtements'],
      );
      await tester.pumpWidget(
        wrap(const Step3RecapBudget(), seed: seed, useMock: true),
      );
      expect(find.text('Paris → Dakar'), findsOneWidget);
      // La ligne "Colis" contient la catégorie en suffixe (ex: "MEDIUM · 5 kg · Vêtements.")
      expect(find.textContaining('Vêtements'), findsOneWidget);
    });

    testWidgets(
      'le récap traduit une catégorie du catalogue (Vêtements & tissus)',
      (tester) async {
        final seed = PackageRequestFormState(
          currentStep: 2,
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          transportMode: TransportMode.plane,
          weightKg: 5,
          parcelSize: ParcelSize.medium,
          categories: const ['Vêtements & tissus'],
        );
        await tester.pumpWidget(
          wrap(const Step3RecapBudget(), seed: seed, useMock: true),
        );

        expect(find.text('Vêtements & tissus'), findsOneWidget);
      },
    );

    testWidgets(
      'le récap traduit une catégorie du catalogue en anglais (Clothing & '
      'fabrics)',
      (tester) async {
        useEnglish();
        final seed = PackageRequestFormState(
          currentStep: 2,
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          transportMode: TransportMode.plane,
          weightKg: 5,
          parcelSize: ParcelSize.medium,
          categories: const ['Vêtements & tissus'],
        );
        await tester.pumpWidget(
          wrap(const Step3RecapBudget(), seed: seed, useMock: true),
        );

        expect(find.text('Clothing & fabrics'), findsOneWidget);
        expect(find.text('Vêtements & tissus'), findsNothing);
      },
    );

    testWidgets('validation budget — accepte vide', (tester) async {
      final key = GlobalKey<Step3RecapBudgetState>();
      await tester.pumpWidget(wrap(Step3RecapBudget(key: key)));
      // Pas de saisie → submit ne doit pas lever d'erreur de validation
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Entre 0 et 500€'), findsNothing);
    });

    // Plafond aligné sur le backend (@DecimalMax("560.0")), qui acceptait
    // 60 € de plus que ce que le formulaire laissait saisir.
    testWidgets('validation budget — refuse au-delà de 560', (tester) async {
      final key = GlobalKey<Step3RecapBudgetState>();
      await tester.pumpWidget(wrap(Step3RecapBudget(key: key)));
      await tester.enterText(find.byType(TextFormField).first, '600');
      key.currentState!.submit();
      await tester.pump();
      expect(find.textContaining('560'), findsWidgets);
    });

    testWidgets('validation budget — accepte 560', (tester) async {
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);
      await tester.pumpWidget(
        wrap(Step3RecapBudget(canContinueNotifier: canContinue)),
      );
      await tester.enterText(find.byType(TextFormField).first, '560');
      await tester.pump();
      expect(canContinue.value, isTrue);
    });

    // Fix post-revue Tâche 13 : les bornes de budget reproduisaient
    // exactement le bug corrigé côté trajet (maxUnitPriceFor) — une
    // constante figée en euros, comparée telle quelle à un montant saisi
    // dans N'IMPORTE QUELLE devise. Pendant, côté demande de colis, des
    // tests `dony_pricing_currency_test.dart` / `maxUnitPriceFor`.
    testWidgets(
      '700 refusé en EUR devient valide en XOF (bornes mises à l\'échelle)',
      (tester) async {
        const seedEur = PackageRequestFormState(
          currency: SupportedCurrency.eur,
          totalBudgetEur: 700,
        );
        final canContinueEur = ValueNotifier<bool>(true);
        addTearDown(canContinueEur.dispose);
        await tester.pumpWidget(
          wrap(
            Step3RecapBudget(canContinueNotifier: canContinueEur),
            seed: seedEur,
            useMock: true,
          ),
        );
        await tester.pump();
        expect(
          canContinueEur.value,
          isFalse,
          reason: '700 dépasse le plafond EUR de 560',
        );

        const seedXof = PackageRequestFormState(
          currency: SupportedCurrency.xof,
          totalBudgetEur: 700,
        );
        final canContinueXof = ValueNotifier<bool>(false);
        addTearDown(canContinueXof.dispose);
        await tester.pumpWidget(
          wrap(
            Step3RecapBudget(canContinueNotifier: canContinueXof),
            seed: seedXof,
            useMock: true,
          ),
        );
        await tester.pump();
        expect(
          canContinueXof.value,
          isTrue,
          reason:
              '700 XOF est au-dessus du plancher XOF mis à l\'échelle (655) '
              'et très en-deçà du plafond (367335) : la même saisie, '
              'refusée en EUR, devient valide en XOF',
        );
      },
    );

    // La devise borne les moyens : pas de puce « Carte » sur une demande en
    // franc CFA, la carte n'y existe pas ; le mobile money y apparaît.
    testWidgets('en XOF, les puces Mobile money et Espèces sont proposées, '
        'sans Carte', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Step3RecapBudget(currency: SupportedCurrency.xof),
          seed: const PackageRequestFormState(
            currency: SupportedCurrency.xof,
            acceptedPaymentMethods: {
              PaymentMethod.mobileMoney,
              PaymentMethod.cash,
            },
          ),
          useMock: true,
        ),
      );
      await tester.pump();

      expect(find.text('Mobile money'), findsOneWidget);
      expect(find.text('Espèces'), findsOneWidget);
      expect(find.text('Carte'), findsNothing);
    });

    testWidgets('en XOF, décocher Mobile money envoie le toggle au bloc', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Step3RecapBudget(currency: SupportedCurrency.xof),
          seed: const PackageRequestFormState(
            currency: SupportedCurrency.xof,
            acceptedPaymentMethods: {
              PaymentMethod.mobileMoney,
              PaymentMethod.cash,
            },
          ),
          useMock: true,
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Mobile money'));
      await tester.tap(find.text('Mobile money'));
      await tester.pump();

      // Le bloc est mocké : on vérifie l'événement émis, pas l'état.
      verify(
        () => mockBloc.add(
          const PackageRequestPaymentMethodToggled(PaymentMethod.mobileMoney),
        ),
      ).called(1);
    });

    testWidgets('en EUR, les puces Carte et Espèces sont proposées', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Step3RecapBudget(currency: SupportedCurrency.eur),
          seed: const PackageRequestFormState(currency: SupportedCurrency.eur),
          useMock: true,
        ),
      );
      await tester.pump();

      expect(find.text('Carte'), findsOneWidget);
      expect(find.text('Espèces'), findsOneWidget);
      expect(find.text('Mobile money'), findsNothing);
    });

    testWidgets(
      'en EUR, les puces de paiement et le titre sont traduits en anglais',
      (tester) async {
        useEnglish();
        await tester.pumpWidget(
          wrap(
            const Step3RecapBudget(currency: SupportedCurrency.eur),
            seed: const PackageRequestFormState(
              currency: SupportedCurrency.eur,
            ),
            useMock: true,
          ),
        );
        await tester.pump();

        expect(find.text('Card'), findsOneWidget);
        expect(find.text('Cash'), findsOneWidget);
        expect(find.text('Carte'), findsNothing);
        expect(find.text('Espèces'), findsNothing);
      },
    );

    testWidgets('affiche le suffixe et le détail du budget en CAD', (
      tester,
    ) async {
      const seed = PackageRequestFormState(totalBudgetEur: 40);
      await tester.pumpWidget(
        wrap(
          const Step3RecapBudget(currency: SupportedCurrency.cad),
          seed: seed,
          useMock: true,
        ),
      );

      final budget = CurrencyFormatter.formatOrPlain(40, SupportedCurrency.cad);
      expect(find.text(r'CA$'), findsOneWidget);
      expect(find.text(budget), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
    });

    testWidgets(
      'le choix du prix remplace l\'interrupteur, avec sa conséquence écrite',
      (tester) async {
        await tester.pumpWidget(wrap(const Step3RecapBudget()));
        await tester.pump();

        // « Prix négociable » nommait un réglage ; les deux cartes nomment
        // chacune ce qui va se passer.
        expect(find.text('Prix négociable'), findsNothing);
        expect(find.byKey(const Key('price-mode-open')), findsOneWidget);
        expect(find.byKey(const Key('price-mode-fixed')), findsOneWidget);
        expect(
          find.textContaining('Les voyageurs proposent leur prix'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'budget indicatif sans montant : publication bloquée, et annoncée comme telle',
      (tester) async {
        final canContinue = ValueNotifier<bool>(true);
        addTearDown(canContinue.dispose);

        final key = GlobalKey<Step3RecapBudgetState>();
        await tester.pumpWidget(
          wrap(Step3RecapBudget(key: key, canContinueNotifier: canContinue)),
        );
        await tester.pump();

        expect(canContinue.value, isFalse);
        expect(find.text('Budget indicatif'), findsOneWidget);
        expect(find.text('Budget indicatif (optionnel)'), findsNothing);
        // Le message ne s'affiche plus à l'ouverture — un formulaire vierge
        // n'accueille pas par un reproche —, mais dès que la publication est
        // tentée. Sans lui, le tap sur « Publier » ne produisait rien. Il est
        // porté par le validateur du champ, seul afficheur de cette erreur.
        expect(find.text('Indiquez un budget'), findsNothing);

        key.currentState!.submit();
        await tester.pump();
        expect(find.text('Indiquez un budget'), findsOneWidget);
      },
    );

    testWidgets('code promo : aide « pas un code de parrainage »', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step3RecapBudget()));
      await tester.enterText(find.byType(TextFormField).first, '32');
      await tester.pumpAndSettle();

      expect(
        find.text('Code promo Yadony (pas un code de parrainage).'),
        findsOneWidget,
      );
    });

    testWidgets('budget indicatif saisi : le bouton se dégrise', (
      tester,
    ) async {
      // Régression : le bouton restait grisé après saisie du budget car
      // canContinueNotifier n'était resynchronisé qu'au toggle de mode,
      // jamais à la frappe dans le champ.
      final canContinue = ValueNotifier<bool>(true);
      addTearDown(canContinue.dispose);

      await tester.pumpWidget(
        wrap(Step3RecapBudget(canContinueNotifier: canContinue)),
      );
      await tester.pump();

      expect(canContinue.value, isFalse);

      await tester.enterText(find.byType(TextFormField).first, '32');
      await tester.pumpAndSettle();

      expect(canContinue.value, isTrue);
    });

    testWidgets(
      'budget tapé puis effacé : le bouton se regrise et l\'erreur revient',
      (tester) async {
        // Régression : effacer le budget ne remettait pas totalBudgetEur à
        // null côté bloc (copyWith `??`), donc le bouton restait actif et
        // l'erreur restait masquée malgré un champ visuellement vide.
        final canContinue = ValueNotifier<bool>(true);
        addTearDown(canContinue.dispose);

        await tester.pumpWidget(
          wrap(Step3RecapBudget(canContinueNotifier: canContinue)),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, '40');
        await tester.pumpAndSettle();
        expect(canContinue.value, isTrue);

        await tester.enterText(find.byType(TextFormField).first, '');
        await tester.pumpAndSettle();

        expect(canContinue.value, isFalse);
        // Champ vidé après saisie : l'autovalidation à l'interaction rend le
        // message sans qu'il faille tenter la publication.
        expect(find.text('Indiquez un budget'), findsOneWidget);
      },
    );

    testWidgets(
      'tap sur la ligne devise ouvre le sélecteur avec l\'avertissement sur '
      'les moyens de paiement, et le choix se répercute',
      (tester) async {
        await tester.pumpWidget(
          wrap(const Step3RecapBudget(currency: SupportedCurrency.eur)),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('package-request-currency-selector-row')),
          findsOneWidget,
        );
        expect(find.text('Euro (EUR)'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('package-request-currency-selector-row')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Choisir une devise'), findsOneWidget);
        expect(
          find.byKey(const Key('currency-payment-methods-notice')),
          findsOneWidget,
        );

        await tester.tap(find.text('Dollar canadien (CAD)'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('currency-selector-confirm')));
        await tester.pumpAndSettle();

        expect(find.text('Dollar canadien (CAD)'), findsOneWidget);
        expect(find.text('Euro (EUR)'), findsNothing);
      },
    );

    testWidgets('le sélecteur de devise annonce mobile money et espèces pour '
        'le XOF', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Step3RecapBudget(currency: SupportedCurrency.xof),
          seed: const PackageRequestFormState(
            currency: SupportedCurrency.xof,
            acceptedPaymentMethods: {
              PaymentMethod.mobileMoney,
              PaymentMethod.cash,
            },
          ),
          useMock: true,
        ),
      );
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('package-request-currency-selector-row')),
      );
      await tester.tap(
        find.byKey(const Key('package-request-currency-selector-row')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Mobile money et espèces disponibles en XOF'),
        findsOneWidget,
      );
    });

    testWidgets(
      'devise verrouillée en édition : aucune ligne devise affichée',
      (tester) async {
        const seed = PackageRequestFormState(
          editingRequestId: 'pr-1',
          totalBudgetEur: 40,
        );
        await tester.pumpWidget(
          wrap(
            const Step3RecapBudget(currency: SupportedCurrency.eur),
            seed: seed,
            useMock: true,
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('package-request-currency-selector-row')),
          findsNothing,
        );
      },
    );

    // M5 : bout en bout avec le bloc réel (pas de seed injecté à la main) —
    // vérifie que le post-frame de initState émet bien
    // PackageRequestCurrencyChanged(xof) et que ça aboutit à l'état attendu,
    // pas seulement que le rendu d'un état posé manuellement est correct.
    testWidgets(
      'seed XOF au premier affichage : mobile money et espèces cochés, '
      'carte absente',
      (tester) async {
        await tester.pumpWidget(
          wrap(const Step3RecapBudget(currency: SupportedCurrency.xof)),
        );
        await tester.pump();

        final bloc = tester
            .element(find.byType(Step3RecapBudget))
            .read<PackageRequestFormBloc>();

        expect(bloc.state.currency, SupportedCurrency.xof);
        expect(bloc.state.acceptedPaymentMethods, {
          PaymentMethod.mobileMoney,
          PaymentMethod.cash,
        });
        expect(find.text('Mobile money'), findsOneWidget);
        expect(find.text('Espèces'), findsOneWidget);
        expect(find.text('Carte'), findsNothing);
      },
    );

    testWidgets('la suite de la publication est annoncée', (tester) async {
      await tester.pumpWidget(wrap(const Step3RecapBudget()));
      await tester.pump();
      expect(
        find.textContaining('les voyageurs sur ce trajet sont prévenus'),
        findsOneWidget,
      );
    });

    // FLUTTER-R6 : le taux de commission n'est plus affiché, seul son
    // montant, à droite du libellé.
    group('commission sans taux, montant seul', () {
      setUp(() => setDonyCommissionRate(0.125));
      tearDown(() => setDonyCommissionRate(kDonyCommissionRateDefault));

      testWidgets('fr : « Frais de service Yadony », sans pourcentage', (
        tester,
      ) async {
        const seed = PackageRequestFormState(totalBudgetEur: 40);
        await tester.pumpWidget(
          wrap(const Step3RecapBudget(), seed: seed, useMock: true),
        );
        await tester.pump();

        expect(find.text('Frais de service Yadony'), findsOneWidget);
        expect(find.textContaining('12,5'), findsNothing);
      });

      testWidgets('en : « Yadony service fee », sans pourcentage', (
        tester,
      ) async {
        useEnglish();
        const seed = PackageRequestFormState(totalBudgetEur: 40);
        await tester.pumpWidget(
          wrap(const Step3RecapBudget(), seed: seed, useMock: true),
        );
        await tester.pump();

        expect(find.text('Yadony service fee'), findsOneWidget);
        expect(find.textContaining('12.5'), findsNothing);
      });
    });
  });

  // Commission par paliers : sous grille, le budget public est un brut dont le
  // net est le plus grand net qui y tient ; un code promo baisse ce que paie
  // l'expéditeur (devis §5.4), il n'augmente plus le net du voyageur.
  group('Step3RecapBudget — sous grille de commission', () {
    String eur(double v) => CurrencyFormatter.format(v, SupportedCurrency.eur);

    NegotiationQuote quote({
      required double net,
      required double commission,
      required double total,
      bool promoApplied = false,
      bool minimumApplied = false,
      String? promoIneffectiveReason,
      String? gridId = kTestGridId,
    }) => NegotiationQuote(
      netEur: net,
      rate: 0.07,
      commissionEur: commission,
      totalEur: total,
      promoApplied: promoApplied,
      promoLabel: promoApplied ? 'Code PROMO appliqué' : null,
      minimumApplied: minimumApplied,
      minimumAmount: 1,
      commissionGridId: gridId,
      promoIneffectiveReason: promoIneffectiveReason,
    );

    void stubQuote(NegotiationQuote q) => when(
      () => repo.quote(
        any(),
        promoCode: any(named: 'promoCode'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async => q);

    Future<void> applyPromo(WidgetTester tester, String code) async {
      await tester.enterText(find.byKey(const Key('promo-code-input')), code);
      final apply = find.byKey(const Key('apply-promo-code-btn'));
      await tester.ensureVisible(apply);
      await tester.pump();
      await tester.tap(apply);
      await tester.pump();
      await tester.pump();
    }

    setUp(() {
      useTestCommissionGrid();
      getIt.registerSingleton<PackageRequestRepository>(repo);
    });

    tearDown(_unregisterRepos);

    testWidgets('budget 21,40 € sans devis : frais 1,40 €, le voyageur reçoit '
        '20,00 €', (tester) async {
      const seed = PackageRequestFormState(
        totalBudgetEur: 21.40,
        currency: SupportedCurrency.eur,
      );
      await tester.pumpWidget(
        wrap(const Step3RecapBudget(), seed: seed, useMock: true),
      );
      await tester.pump();

      expect(find.text('Frais de service Yadony'), findsOneWidget);
      expect(find.text(eur(1.40)), findsOneWidget);
      expect(find.text(eur(20)), findsOneWidget);
      expect(find.text('Vous paierez'), findsNothing);
      expect(find.text('Réduction du code promo'), findsNothing);
    });

    testWidgets('sans devis, budget 5 € : frais au minimum, suivis de '
        '« (minimum) »', (tester) async {
      const seed = PackageRequestFormState(
        totalBudgetEur: 5,
        currency: SupportedCurrency.eur,
      );
      await tester.pumpWidget(
        wrap(const Step3RecapBudget(), seed: seed, useMock: true),
      );
      await tester.pump();

      expect(find.text('${eur(1)} (minimum)'), findsOneWidget);
      expect(find.text(eur(4)), findsOneWidget);
    });

    testWidgets('devis avec promo (net 20, commission 1,00, total 21,00) : '
        'réduction −0,40 €, « Vous paierez 21,00 € », aucune ligne « le '
        'voyageur touche » de boost', (tester) async {
      stubQuote(
        quote(net: 20, commission: 1.00, total: 21.00, promoApplied: true),
      );
      const seed = PackageRequestFormState(
        totalBudgetEur: 21.40,
        currency: SupportedCurrency.eur,
      );
      await tester.pumpWidget(
        wrap(const Step3RecapBudget(), seed: seed, useMock: true),
      );
      await tester.pump();
      await applyPromo(tester, 'PROMO');

      expect(find.text('Réduction du code promo'), findsOneWidget);
      expect(find.text('−${eur(0.40)}'), findsOneWidget);
      expect(find.text('Vous paierez'), findsOneWidget);
      expect(find.text(eur(21)), findsOneWidget);
      expect(find.text(eur(1)), findsOneWidget);
      expect(find.text(eur(20)), findsOneWidget);
      expect(
        find.text('Grâce au code promo, le voyageur touche'),
        findsNothing,
      );
      expect(find.text('Code PROMO appliqué'), findsOneWidget);
    });

    testWidgets('devis minimumApplied : frais suivis de « (minimum) »', (
      tester,
    ) async {
      stubQuote(
        quote(net: 20, commission: 1.00, total: 21.00, minimumApplied: true),
      );
      const seed = PackageRequestFormState(
        totalBudgetEur: 21.40,
        currency: SupportedCurrency.eur,
      );
      await tester.pumpWidget(
        wrap(const Step3RecapBudget(), seed: seed, useMock: true),
      );
      await tester.pump();
      // Sans devis, 1,40 € de frais : pas de minimum.
      expect(find.textContaining('(minimum)'), findsNothing);

      await applyPromo(tester, 'PROMO');

      expect(find.text('${eur(1)} (minimum)'), findsOneWidget);
    });

    testWidgets('promo sans effet : message « Ce code ne change rien sur ce '
        'montant (frais minimum) »', (tester) async {
      stubQuote(
        quote(
          net: 4,
          commission: 1,
          total: 5,
          minimumApplied: true,
          promoIneffectiveReason: 'COMMISSION_MINIMUM',
        ),
      );
      const seed = PackageRequestFormState(
        totalBudgetEur: 5,
        currency: SupportedCurrency.eur,
      );
      await tester.pumpWidget(
        wrap(const Step3RecapBudget(), seed: seed, useMock: true),
      );
      await tester.pump();
      await applyPromo(tester, 'PROMO');

      expect(
        find.text('Ce code ne change rien sur ce montant (frais minimum)'),
        findsOneWidget,
      );
      expect(find.text('Réduction du code promo'), findsNothing);
      expect(find.text('Vous paierez'), findsNothing);
    });

    testWidgets('le devis part avec la devise de la demande (XOF)', (
      tester,
    ) async {
      stubQuote(quote(net: 12470, commission: 873, total: 13343));
      const seed = PackageRequestFormState(
        totalBudgetEur: 13343,
        currency: SupportedCurrency.xof,
        acceptedPaymentMethods: {PaymentMethod.cash},
      );
      await tester.pumpWidget(
        wrap(const Step3RecapBudget(), seed: seed, useMock: true),
      );
      await tester.pump();
      await applyPromo(tester, '');

      verify(() => repo.quote(13343, currency: 'XOF')).called(1);
    });

    testWidgets('budget 1,00 € : bouton Continuer bloqué et message du '
        'minimum', (tester) async {
      final canContinue = ValueNotifier<bool>(true);
      addTearDown(canContinue.dispose);
      await tester.pumpWidget(
        wrap(Step3RecapBudget(canContinueNotifier: canContinue)),
      );
      await tester.enterText(find.byKey(const Key('total-budget-input')), '1');
      await tester.pump();
      await tester.pump();

      expect(canContinue.value, isFalse);
      expect(
        find.text(
          'Le budget doit dépasser les frais de service minimum '
          '(${eur(1)}).',
        ),
        findsOneWidget,
      );
      // Le message des bornes ne s'y superpose pas.
      expect(find.textContaining('Entre '), findsNothing);
    });

    testWidgets('budget 1,01 € : publiable sous grille', (tester) async {
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);
      await tester.pumpWidget(
        wrap(Step3RecapBudget(canContinueNotifier: canContinue)),
      );
      await tester.enterText(
        find.byKey(const Key('total-budget-input')),
        '1,01',
      );
      await tester.pump();
      await tester.pump();

      expect(canContinue.value, isTrue);
    });

    group('édition : grille figée de la demande', () {
      // Grille plus ancienne que celle en vigueur : 10 % sur toute la tranche.
      final oldGrid = CommissionGrid(
        id: 'grid-old',
        effectiveFrom: DateTime.utc(2026, 9),
        tiers: const [CommissionTier(fromEur: 0, rate: 0.10)],
        minimums: const {'EUR': 1.00, 'XOF': 650},
      );

      const editSeed = PackageRequestFormState(
        editingRequestId: 'r-1',
        commissionGridId: 'grid-old',
        totalBudgetEur: 22,
        currency: SupportedCurrency.eur,
      );

      testWidgets('grille figée inconnue : lue par identifiant, puis les '
          'frais se calculent sur elle', (tester) async {
        final config = _MockConfigRepo();
        when(
          () => config.getCommissionGridById('grid-old'),
        ).thenAnswer((_) async => oldGrid);
        getIt.registerSingleton<IConfigRepository>(config);

        await tester.pumpWidget(
          wrap(const Step3RecapBudget(), seed: editSeed, useMock: true),
        );
        await tester.pump();
        await tester.pump();

        // 22 € sur la grille figée à 10 % : net 20, frais 2.
        expect(find.text(eur(2)), findsOneWidget);
        expect(find.text(eur(20)), findsOneWidget);
        verify(() => config.getCommissionGridById('grid-old')).called(1);
      });

      testWidgets('devis sur une autre grille : montants de la grille figée', (
        tester,
      ) async {
        CommissionGridStore.put(oldGrid);
        // Le devis du back suit la grille en vigueur, pas celle de la demande.
        stubQuote(quote(net: 20.56, commission: 1.44, total: 22));

        await tester.pumpWidget(
          wrap(const Step3RecapBudget(), seed: editSeed, useMock: true),
        );
        await tester.pump();
        await applyPromo(tester, '');

        expect(find.text(eur(2)), findsOneWidget);
        expect(find.text(eur(20)), findsOneWidget);
        expect(find.text(eur(20.56)), findsNothing);
      });
    });
  });

  group('Step3RecapBudget — sans grille de commission', () {
    setUp(() => getIt.registerSingleton<PackageRequestRepository>(repo));
    tearDown(_unregisterRepos);

    testWidgets('sans grille : décomposition et boost inchangés', (
      tester,
    ) async {
      when(
        () => repo.quote(
          any(),
          promoCode: any(named: 'promoCode'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer(
        (_) async => const NegotiationQuote(
          netEur: 39.22,
          rate: 0.05,
          commissionEur: 1.90,
          totalEur: 40,
          promoApplied: true,
          promoLabel: 'Code PROMO appliqué',
        ),
      );
      const seed = PackageRequestFormState(
        totalBudgetEur: 40,
        currency: SupportedCurrency.eur,
      );
      await tester.pumpWidget(
        wrap(const Step3RecapBudget(), seed: seed, useMock: true),
      );
      await tester.pump();
      String eur(double v) =>
          CurrencyFormatter.format(v, SupportedCurrency.eur);
      // Estimation locale au taux unique : 40 / 1,05.
      expect(find.text(eur(40 - 40 / 1.05)), findsOneWidget);

      await tester.enterText(find.byKey(const Key('promo-code-input')), 'P');
      final apply = find.byKey(const Key('apply-promo-code-btn'));
      await tester.ensureVisible(apply);
      await tester.pump();
      await tester.tap(apply);
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Grâce au code promo, le voyageur touche'),
        findsOneWidget,
      );
      expect(find.text('+${eur(39.22 - 40 / 1.05)}'), findsOneWidget);
      expect(find.text(eur(1.90)), findsOneWidget);
      expect(find.text(eur(39.22)), findsOneWidget);
      expect(find.text('Vous paierez'), findsNothing);
      expect(find.text('Réduction du code promo'), findsNothing);
    });
  });

  group('Step3RecapBudget — compte mobile money requis (FLUTTER-B2)', () {
    PackageRequestFormState cfaSeed(Set<PaymentMethod> methods) =>
        PackageRequestFormState(
          currentStep: 2,
          currency: SupportedCurrency.xof,
          totalBudgetEur: 10000,
          acceptedPaymentMethods: methods,
        );

    Future<ValueNotifier<bool>> pumpStep(
      WidgetTester tester, {
      required Set<PaymentMethod> methods,
      required bool? accountActive,
    }) async {
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);
      await tester.pumpWidget(
        wrap(
          Step3RecapBudget(
            canContinueNotifier: canContinue,
            currency: SupportedCurrency.xof,
            mobileMoneyAccountActive: accountActive,
          ),
          seed: cfaSeed(methods),
          useMock: true,
        ),
      );
      await tester.pump();
      return canContinue;
    }

    testWidgets(
      'mobile money coché sans compte : encart + lien, publication bloquée',
      (tester) async {
        final canContinue = await pumpStep(
          tester,
          methods: {PaymentMethod.mobileMoney, PaymentMethod.cash},
          accountActive: false,
        );
        expect(
          find.byKey(const Key('request-mobile-money-setup-notice')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('request-activate-mobile-money-cta')),
          findsOneWidget,
        );
        expect(canContinue.value, isFalse);
      },
    );

    testWidgets('compte mobile money actif : rien ne bloque', (tester) async {
      final canContinue = await pumpStep(
        tester,
        methods: {PaymentMethod.mobileMoney, PaymentMethod.cash},
        accountActive: true,
      );
      expect(
        find.byKey(const Key('request-mobile-money-setup-notice')),
        findsNothing,
      );
      expect(canContinue.value, isTrue);
    });

    testWidgets('mobile money décoché : publiable sans compte', (tester) async {
      final canContinue = await pumpStep(
        tester,
        methods: {PaymentMethod.cash},
        accountActive: false,
      );
      expect(
        find.byKey(const Key('request-mobile-money-setup-notice')),
        findsNothing,
      );
      expect(canContinue.value, isTrue);
    });
  });
}
