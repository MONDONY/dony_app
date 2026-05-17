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

  Widget wrap({DateTime? initialDate}) => MaterialApp.router(
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
  });
}
