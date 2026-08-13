import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _FakeCancellationEvent extends Fake implements CancellationEvent {}

BidModel _inTransitBid() => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: 'IN_TRANSIT',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  departureAt: DateTime.now().subtract(const Duration(days: 1)),
);

Widget _harness(Widget child, CancellationBloc bloc) => MaterialApp(
  home: Scaffold(
    body: BlocProvider<CancellationBloc>.value(value: bloc, child: child),
  ),
);

void main() {
  late _MockBloc bloc;

  setUpAll(() {
    registerFallbackValue(_FakeCancellationEvent());
  });

  setUp(() {
    bloc = _MockBloc();
    whenListen(
      bloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
  });

  testWidgets('voyageur : cellule visible si canReportDeliveryNoShow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        DeliveryNoShowCtaCell(bid: _inTransitBid(), isSender: false),
        bloc,
      ),
    );
    expect(find.text("Signaler l'absence du destinataire"), findsOneWidget);
  });

  testWidgets('expéditeur : cellule visible avec le libellé symétrique', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        DeliveryNoShowCtaCell(bid: _inTransitBid(), isSender: true),
        bloc,
      ),
    );
    expect(find.text('Le voyageur ne livre pas'), findsOneWidget);
  });

  testWidgets(
    'masquée si un signalement existe déjà (canReportDeliveryNoShow=false)',
    (tester) async {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        departureAt: DateTime.now().subtract(const Duration(days: 1)),
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
      );
      await tester.pumpWidget(
        _harness(DeliveryNoShowCtaCell(bid: bid, isSender: false), bloc),
      );
      expect(find.byType(DeliveryNoShowCtaCell), findsOneWidget);
      expect(find.text("Signaler l'absence du destinataire"), findsNothing);
    },
  );

  testWidgets(
    'tap voyageur → confirmer → dispatch DeliveryNoShowReportRequested',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          DeliveryNoShowCtaCell(bid: _inTransitBid(), isSender: false),
          bloc,
        ),
      );
      await tester.tap(find.text("Signaler l'absence du destinataire"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer le signalement'));
      await tester.pumpAndSettle();
      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured.single, isA<DeliveryNoShowReportRequested>());
      expect((captured.single as DeliveryNoShowReportRequested).bidId, 'b1');
    },
  );

  testWidgets(
    'tap expéditeur → confirmer → dispatch TravelerDeliveryNoShowReportRequested',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          DeliveryNoShowCtaCell(bid: _inTransitBid(), isSender: true),
          bloc,
        ),
      );
      await tester.tap(find.text('Le voyageur ne livre pas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer le signalement'));
      await tester.pumpAndSettle();
      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured.single, isA<TravelerDeliveryNoShowReportRequested>());
      expect(
        (captured.single as TravelerDeliveryNoShowReportRequested).bidId,
        'b1',
      );
    },
  );
}
