import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockPriceEstimationRepository extends Mock
    implements PriceEstimationRepository {}

void main() {
  late _MockNegotiationBloc negoBloc;
  late _MockPriceEstimationRepository priceRepo;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    registerFallbackValue(NegotiationStartRequested(
      packageRequestId: 'x',
      proposedPriceEur: 1,
      travelerTravelDate: DateTime(2026),
      travelerAvailableKg: 1,
    ));
  });

  setUp(() {
    negoBloc = _MockNegotiationBloc();
    priceRepo = _MockPriceEstimationRepository();

    when(() => negoBloc.state).thenReturn(const NegotiationInitial());
    when(() => negoBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
    when(() => priceRepo.estimate(
          from: any(named: 'from'),
          to: any(named: 'to'),
          weight: any(named: 'weight'),
        )).thenThrow(Exception('no estimate'));

    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    if (getIt.isRegistered<PriceEstimationRepository>()) {
      getIt.unregister<PriceEstimationRepository>();
    }
    getIt.registerFactory<NegotiationBloc>(() => negoBloc);
    getIt.registerLazySingleton<PriceEstimationRepository>(() => priceRepo);
  });

  tearDown(() async {
    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    if (getIt.isRegistered<PriceEstimationRepository>()) {
      getIt.unregister<PriceEstimationRepository>();
    }
  });

  Widget wrap({
    DateTime? initialDate,
    bool isFirmPrice = false,
    double? targetPriceEur,
  }) =>
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (ctx, state) => Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () => MakeOfferBottomSheet.show(
                    innerCtx,
                    packageRequestId: 'pr-1',
                    weightKg: 5,
                    departureCity: 'Paris',
                    arrivalCity: 'Dakar',
                    initialDate: initialDate,
                    isFirmPrice: isFirmPrice,
                    targetPriceEur: targetPriceEur,
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
            GoRoute(
              path: '/negotiations/:id',
              builder: (_, __) =>
                  const Scaffold(body: Text('Négociation')),
            ),
          ],
        ),
        theme: AppTheme.light,
      );

  group('MakeOfferBottomSheet — garde-fou de sortie', () {
    /// Ouvre la feuille et laisse passer les deux post-frames qui figent la
    /// signature de référence.
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();
    }

    /// Saisit un message : modification utilisateur incontestable.
    Future<void> typeSomething(WidgetTester tester) async {
      await tester.enterText(
        find.byType(TextFormField).last,
        'Je peux prendre ce colis',
      );
      await tester.pumpAndSettle();
    }

    /// Simule le retour système (Android) / swipe back (iOS).
    Future<void> systemBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    testWidgets(
      'sans saisie, le retour système ferme la feuille sans confirmation',
      (tester) async {
        await open(tester);
        expect(find.text('Faire une offre'), findsOneWidget);

        await systemBack(tester);

        expect(find.text('Quitter sans enregistrer ?'), findsNothing);
        expect(find.text('Faire une offre'), findsNothing);
      },
    );

    testWidgets(
      'après saisie, le retour système demande confirmation',
      (tester) async {
        await open(tester);
        await typeSomething(tester);

        await systemBack(tester);

        expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
        expect(find.textContaining('ne seront pas'), findsOneWidget);
        // La feuille est toujours là tant qu'on n'a pas confirmé.
        expect(find.text('Faire une offre'), findsOneWidget);
      },
    );

    testWidgets(
      'après saisie, le glissement vers le bas ne ferme pas la feuille',
      (tester) async {
        // `ModalBottomSheetRoute` n'honore PAS `PopScope` pour le glissement
        // (vérifié sur Flutter 3.44 : la feuille se fermait malgré le garde).
        // La feuille est donc ouverte avec `enableDrag: false`, et ce test
        // verrouille cette décision.
        await open(tester);
        await typeSomething(tester);

        await tester.drag(
          find.text('Faire une offre'),
          const Offset(0, 600),
        );
        await tester.pumpAndSettle();

        expect(find.text('Faire une offre'), findsOneWidget);
      },
    );

    testWidgets(
      'après saisie, la croix de la feuille demande aussi confirmation',
      (tester) async {
        // `Navigator.pop()` ne consulte pas `PopScope` : sans le détour par
        // `onCloseRequested`, la croix viderait la saisie sans rien demander.
        await open(tester);
        await typeSomething(tester);

        final closeBtn = find.ancestor(
          of: find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
          matching: find.byType(IconButton),
        );
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
        expect(find.text('Faire une offre'), findsOneWidget);
      },
    );

    testWidgets(
      '« Quitter » confirmé ferme bien la feuille',
      (tester) async {
        await open(tester);
        await typeSomething(tester);
        await systemBack(tester);

        await tester.tap(find.text('Quitter'));
        await tester.pumpAndSettle();

        expect(find.text('Faire une offre'), findsNothing);
      },
    );
  });

  group('MakeOfferBottomSheet', () {
    testWidgets(
        'initialDate fourni → champ date affiche la valeur formatée',
        (tester) async {
      await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('12 juin 2026'), findsOneWidget);
      expect(find.text('Sélectionner…'), findsNothing);
    });

    testWidgets(
        'sans initialDate → champ date affiche Sélectionner',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Sélectionner…'), findsOneWidget);
    });

    testWidgets(
        'prix ferme → champ verrouillé + envoie le prix EXACT (pas arrondi)',
        (tester) async {
      await tester.pumpWidget(wrap(
        initialDate: DateTime(2026, 6, 12),
        isFirmPrice: true,
        targetPriceEur: 35.5,
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      // Framing « prendre » et non « négocier ».
      expect(find.text('Prendre ce colis'), findsOneWidget);
      expect(find.text('PRIX FERME'), findsOneWidget);
      expect(find.text('Faire une offre'), findsNothing);
      // Prix affiché EXACT (35,50), jamais arrondi à 36.
      expect(find.text('35.50'), findsOneWidget);
      expect(find.text('Prendre à 35,50 €'), findsOneWidget);

      // Soumission → événement avec le prix EXACT (régression firm-price-must-match).
      await tester.tap(find.text('Prendre à 35,50 €'));
      await tester.pump();
      verify(() => negoBloc.add(any(
            that: isA<NegotiationStartRequested>()
                .having((e) => e.proposedPriceEur, 'proposedPriceEur', 35.5)
                .having((e) => e.isFirmPrice, 'isFirmPrice', true),
          ))).called(1);
    });
  });
}
