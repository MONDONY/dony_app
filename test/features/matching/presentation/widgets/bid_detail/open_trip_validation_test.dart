import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/open_trip_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

final _bid = BidModel(
  id: 'bid-1',
  announcementId: 'trip-1',
  senderId: 's1',
  status: 'ACCEPTED',
  cancellationNoShowStatus: 'PENDING_CONFIRMATION',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  setUpAll(() => registerFallbackValue(BidDetailRequested('x')));

  // Le scan de départ lève une déclaration d'absence encore en attente
  // (RESOLVED côté back) : au retour du Suivi, le colis est relu et
  // l'alerte « Absence signalée » disparaît.
  testWidgets('retour du mode Valider : le colis est relu', (tester) async {
    final bloc = _MockBidBloc();
    when(() => bloc.state).thenReturn(BidInitial());
    when(() => bloc.isClosed).thenReturn(false);
    String? opened;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => BlocProvider<BidBloc>.value(
            value: bloc,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => openTripValidation(context, _bid),
                child: const Text('scan'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/tracking/validate',
          builder: (context, state) {
            opened = state.uri.toString();
            return TextButton(
              onPressed: () => context.pop(),
              child: const Text('retour'),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(opened, '/tracking/validate?trip=trip-1');
    verifyNever(() => bloc.add(any()));

    await tester.tap(find.text('retour'));
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(
        any(
          that: isA<BidDetailRequested>().having(
            (e) => e.bidId,
            'bidId',
            'bid-1',
          ),
        ),
      ),
    ).called(1);
  });
}
