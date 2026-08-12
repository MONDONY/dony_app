import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

BidModel _makeBid(BidPaymentMethod method) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  weightKg: 5,
  status: 'PAYMENT_ESCROWED',
  paymentMethod: method,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget _wrap(BidModel bid, MockBidBloc bidBloc, MockBidAcceptanceBloc accBloc) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<BidAcceptanceBloc>.value(value: accBloc),
            ],
            // Mirror la vraie hiérarchie : la barre est le bottomNavigationBar
            // d'un Scaffold plein écran atteint via GoRouter.
            child: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: TravelerPendingBar(
                bid: bid,
                isLoading: false,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(BidRejectRequested('fallback'));
    registerFallbackValue(BidAcceptRequested('fallback'));
    registerFallbackValue(ace.BidAcceptRequested('fallback'));
  });

  late MockBidBloc bidBloc;
  late MockBidAcceptanceBloc accBloc;

  setUp(() {
    bidBloc = MockBidBloc();
    accBloc = MockBidAcceptanceBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => accBloc.state).thenReturn(acs.BidAcceptanceInitial());
  });

  tearDown(() {
    bidBloc.close();
    accBloc.close();
  });

  group('TravelerPendingBar — Refuser (bid carte / PAYMENT_ESCROWED)', () {
    testWidgets('tap Refuser ouvre la feuille de raison', (tester) async {
      await tester.pumpWidget(
        _wrap(_makeBid(BidPaymentMethod.stripe), bidBloc, accBloc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Refuser'));
      await tester.pumpAndSettle();

      expect(find.text('Refuser la demande'), findsOneWidget);
      expect(find.text('Confirmer le refus'), findsOneWidget);
    });

    testWidgets(
      'Confirmer le refus dispatch BidRejectRequested et ferme la feuille',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_makeBid(BidPaymentMethod.stripe), bidBloc, accBloc),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Refuser'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmer le refus'));
        await tester.pumpAndSettle();

        // La feuille doit être fermée…
        expect(find.text('Refuser la demande'), findsNothing);
        // …et l'événement de refus dispatché.
        verify(
          () => bidBloc.add(any(that: isA<BidRejectRequested>())),
        ).called(1);
      },
    );

    testWidgets('Accepter (carte) dispatch BidAcceptRequested sur BidBloc', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_makeBid(BidPaymentMethod.stripe), bidBloc, accBloc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Accepter'));
      await tester.pump();

      verify(() => bidBloc.add(any(that: isA<BidAcceptRequested>()))).called(1);
    });
  });
}
