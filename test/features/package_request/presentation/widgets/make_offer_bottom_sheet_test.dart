import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
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
