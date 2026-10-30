// Fermeture automatique des sheets des tuiles « À traiter » : seulement quand
// le colis relu ne justifie plus la tuile et que le sheet est au premier plan.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late _MockBidBloc bidBloc;
  late StreamController<BidState> states;

  setUp(() {
    states = StreamController<BidState>.broadcast();
    addTearDown(states.close);
    bidBloc = _MockBidBloc();
    whenListen(bidBloc, states.stream, initialState: BidInitial());
  });

  /// Ouvre un sheet tenu ouvert tant que le colis `bid-1` est `ACCEPTED`.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<BidBloc>.value(
        value: bidBloc,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => BlocProvider<BidBloc>.value(
                  value: bidBloc,
                  child: CloseSheetWhenResolved(
                    bidId: 'bid-1',
                    stillNeeded: (bid) => bid.status == 'ACCEPTED',
                    child: Builder(
                      builder: (sheetContext) => TextButton(
                        onPressed: () => showDialog<void>(
                          context: sheetContext,
                          builder: (_) =>
                              const AlertDialog(content: Text('confirmation')),
                        ),
                        child: const Text('sheet'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsOneWidget);
  }

  Future<void> emit(WidgetTester tester, BidState state) async {
    states.add(state);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('le colis justifie encore la tuile : le sheet reste ouvert', (
    tester,
  ) async {
    await openSheet(tester);
    await emit(tester, BidDetailLoaded(_bid('bid-1', 'ACCEPTED')));
    expect(find.text('sheet'), findsOneWidget);
  });

  testWidgets('un autre colis relu ne ferme pas le sheet', (tester) async {
    await openSheet(tester);
    await emit(tester, BidDetailLoaded(_bid('bid-2', 'CANCELLED')));
    expect(find.text('sheet'), findsOneWidget);
  });

  testWidgets('la tuile n\'a plus lieu d\'être : le sheet se ferme', (
    tester,
  ) async {
    await openSheet(tester);
    await emit(tester, BidDetailLoaded(_bid('bid-1', 'CANCELLED')));
    expect(find.text('sheet'), findsNothing);
  });

  testWidgets('une confirmation par-dessus n\'est jamais refermée ; le sheet '
      'se ferme quand il revient au premier plan', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();
    expect(find.text('confirmation'), findsOneWidget);

    await emit(tester, BidDetailLoaded(_bid('bid-1', 'CANCELLED')));
    expect(find.text('confirmation'), findsOneWidget);
    expect(find.text('sheet'), findsOneWidget);

    // Fermeture de la confirmation : le sheet revient au premier plan.
    Navigator.of(tester.element(find.text('confirmation'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('confirmation'), findsNothing);
    expect(find.text('sheet'), findsNothing);
  });

  testWidgets('closeSheetIfOnTop ne ferme pas une route couverte', (
    tester,
  ) async {
    await openSheet(tester);
    final sheetContext = tester.element(find.text('sheet'));
    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();

    closeSheetIfOnTop(sheetContext);
    await tester.pumpAndSettle();
    expect(find.text('confirmation'), findsOneWidget);
    expect(find.text('sheet'), findsOneWidget);
  });
}
