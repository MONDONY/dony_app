import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

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

    testWidgets('la suite de la publication est annoncée', (tester) async {
      await tester.pumpWidget(wrap(const Step3RecapBudget()));
      await tester.pump();
      expect(
        find.textContaining('les voyageurs sur ce trajet sont prévenus'),
        findsOneWidget,
      );
    });
  });
}
