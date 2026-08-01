import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
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
    await initializeDateFormatting('fr_FR', null);
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

    testWidgets('validation budget — refuse > 500', (tester) async {
      final key = GlobalKey<Step3RecapBudgetState>();
      await tester.pumpWidget(wrap(Step3RecapBudget(key: key)));
      await tester.enterText(find.byType(TextFormField).first, '600');
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Entre 0 et 500€'), findsOneWidget);
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
      'prix ferme sans montant : publication bloquée, et annoncée comme telle',
      (tester) async {
        // Le budget était annoncé « optionnel » puis refusé au clic sur
        // « Publier ». La règle est maintenant portée par le choix.
        final canContinue = ValueNotifier<bool>(true);
        addTearDown(canContinue.dispose);

        await tester.pumpWidget(
          wrap(Step3RecapBudget(canContinueNotifier: canContinue)),
        );
        await tester.pump();

        // Par défaut « J'ouvre aux offres » : rien n'est requis.
        expect(canContinue.value, isTrue);
        expect(find.text('Budget indicatif (optionnel)'), findsOneWidget);

        await tester.tap(find.byKey(const Key('price-mode-fixed')));
        await tester.pumpAndSettle();

        expect(canContinue.value, isFalse);
        expect(find.text('Ton prix'), findsOneWidget);
        expect(find.byKey(const Key('budget-error')), findsOneWidget);
      },
    );

    testWidgets(
      'prix ferme puis montant saisi : le bouton se dégrise',
      (tester) async {
        // Régression : le bouton restait grisé après saisie du prix car
        // canContinueNotifier n'était resynchronisé qu'au toggle de mode,
        // jamais à la frappe dans le champ prix.
        final canContinue = ValueNotifier<bool>(true);
        addTearDown(canContinue.dispose);

        await tester.pumpWidget(
          wrap(Step3RecapBudget(canContinueNotifier: canContinue)),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('price-mode-fixed')));
        await tester.pumpAndSettle();
        expect(canContinue.value, isFalse);

        await tester.enterText(find.byType(TextFormField).first, '32');
        await tester.pumpAndSettle();

        expect(canContinue.value, isTrue);
      },
    );

    testWidgets(
      'prix tapé puis effacé : le bouton se regrise et l\'erreur revient',
      (tester) async {
        // Régression : effacer le prix ne remettait pas totalBudgetEur à
        // null côté bloc (copyWith `??`), donc le bouton restait actif et
        // l'erreur restait masquée malgré un champ visuellement vide.
        final canContinue = ValueNotifier<bool>(true);
        addTearDown(canContinue.dispose);

        await tester.pumpWidget(
          wrap(Step3RecapBudget(canContinueNotifier: canContinue)),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('price-mode-fixed')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '40');
        await tester.pumpAndSettle();
        expect(canContinue.value, isTrue);

        await tester.enterText(find.byType(TextFormField).first, '');
        await tester.pumpAndSettle();

        expect(canContinue.value, isFalse);
        expect(find.byKey(const Key('budget-error')), findsOneWidget);
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
