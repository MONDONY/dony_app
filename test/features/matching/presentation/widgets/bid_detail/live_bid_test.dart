import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/live_bid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

BidModel _bid({String id = 'bid-001', String? recipientName = 'Awa'}) =>
    BidModel(
      id: id,
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: 'ACCEPTED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      recipientName: recipientName,
    );

void main() {
  late _MockBidBloc bloc;
  late StreamController<BidState> states;

  setUp(() {
    bloc = _MockBidBloc();
    states = StreamController<BidState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: BidInitial());
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool live,
    bool withBloc = true,
  }) async {
    final child = LiveBid(
      bid: _bid(),
      live: live,
      builder: (_, bid) => Text(bid.recipientName ?? '-'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: withBloc
            ? BlocProvider<BidBloc>.value(value: bloc, child: child)
            : child,
      ),
    );
  }

  testWidgets(
    'sans BidBloc (live faux) : rendu statique du colis d\'ouverture',
    (tester) async {
      await pump(tester, live: false, withBloc: false);

      expect(tester.takeException(), isNull);
      expect(find.text('Awa'), findsOneWidget);
    },
  );

  testWidgets('live faux : ignore les rechargements même avec un BidBloc', (
    tester,
  ) async {
    await pump(tester, live: false);

    states.add(BidDetailLoaded(_bid(recipientName: 'Fatou')));
    await tester.pump();

    expect(find.text('Awa'), findsOneWidget);
  });

  testWidgets('suit le colis rechargé par le BidBloc', (tester) async {
    await pump(tester, live: true);
    expect(find.text('Awa'), findsOneWidget);

    states.add(BidDetailLoaded(_bid(recipientName: 'Fatou')));
    await tester.pump();

    expect(find.text('Fatou'), findsOneWidget);
    expect(find.text('Awa'), findsNothing);
  });

  testWidgets('un colis d\'un autre id est ignoré', (tester) async {
    await pump(tester, live: true);

    states.add(BidDetailLoaded(_bid(id: 'bid-other', recipientName: 'Fatou')));
    await tester.pump();

    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Fatou'), findsNothing);
  });

  testWidgets(
    'un état qui n\'est pas un BidDetailLoaded garde le dernier colis',
    (tester) async {
      await pump(tester, live: true);
      states.add(BidDetailLoaded(_bid(recipientName: 'Fatou')));
      await tester.pump();

      states.add(BidLoading());
      await tester.pump();

      expect(find.text('Fatou'), findsOneWidget);
    },
  );
}
