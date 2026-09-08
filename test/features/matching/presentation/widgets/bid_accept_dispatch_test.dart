import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_accept_dispatch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
  status: 'PENDING',
  paymentMethod: method,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() {
    registerFallbackValue(BidAcceptRequested('fallback'));
    registerFallbackValue(BidAcceptMobileMoneyRequested('fallback'));
    registerFallbackValue(ace.BidAcceptRequested('fallback'));
  });

  late MockBidBloc bidBloc;
  late MockBidAcceptanceBloc accBloc;
  late BuildContext capturedContext;

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

  // Fournit BidBloc et BidAcceptanceBloc puis capture un BuildContext
  // descendant, pour appeler dispatchBidAccept directement (fonction pure
  // de branchement, pas besoin de passer par un bouton/tap).
  Future<void> pumpProviders(WidgetTester tester) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<BidBloc>.value(value: bidBloc),
        BlocProvider<BidAcceptanceBloc>.value(value: accBloc),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  group('dispatchBidAccept', () {
    testWidgets(
      'espèces : BidAcceptRequested sur BidAcceptanceBloc, jamais sur BidBloc',
      (tester) async {
        await pumpProviders(tester);

        dispatchBidAccept(capturedContext, _makeBid(BidPaymentMethod.cash));

        verify(
          () => accBloc.add(any(that: isA<ace.BidAcceptRequested>())),
        ).called(1);
        verifyNever(() => bidBloc.add(any()));
      },
    );

    testWidgets(
      'mobile money : BidAcceptMobileMoneyRequested sur BidBloc, jamais sur '
      'BidAcceptanceBloc',
      (tester) async {
        await pumpProviders(tester);

        dispatchBidAccept(
          capturedContext,
          _makeBid(BidPaymentMethod.mobileMoney),
        );

        verify(
          () => bidBloc.add(any(that: isA<BidAcceptMobileMoneyRequested>())),
        ).called(1);
        verifyNever(() => accBloc.add(any()));
      },
    );

    testWidgets(
      'stripe (et tout autre mode) : BidAcceptRequested sur BidBloc, jamais '
      'sur BidAcceptanceBloc',
      (tester) async {
        await pumpProviders(tester);

        dispatchBidAccept(capturedContext, _makeBid(BidPaymentMethod.stripe));

        verify(
          () => bidBloc.add(any(that: isA<BidAcceptRequested>())),
        ).called(1);
        verifyNever(() => accBloc.add(any()));
      },
    );
  });
}
