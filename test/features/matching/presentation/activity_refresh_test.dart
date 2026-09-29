import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/presentation/activity_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockTravelerBidsBloc
    extends MockBloc<TravelerBidsEvent, TravelerBidsState>
    implements TravelerBidsBloc {}

class _MockBidNegotiationListBloc
    extends MockBloc<BidNegotiationListEvent, BidNegotiationListState>
    implements BidNegotiationListBloc {}

void main() {
  late _MockTravelerBidsBloc travelerBids;
  late _MockBidNegotiationListBloc negotiations;
  late EnvoisRefreshNotifier notifier;
  late int notified;

  setUp(() {
    GetIt.I.reset();
    travelerBids = _MockTravelerBidsBloc();
    negotiations = _MockBidNegotiationListBloc();
    notifier = EnvoisRefreshNotifier();
    notified = 0;
    notifier.addListener(() => notified++);
    GetIt.I.registerSingleton<TravelerBidsBloc>(travelerBids);
    GetIt.I.registerSingleton<BidNegotiationListBloc>(negotiations);
    GetIt.I.registerSingleton<EnvoisRefreshNotifier>(notifier);
  });

  tearDown(() => GetIt.I.reset());

  test('sans contexte : recharge les singletons et notifie le hub', () {
    refreshActivityAfterBidChange();

    verify(
      () => travelerBids.add(const TravelerBidsRequested(force: true)),
    ).called(1);
    verify(
      () => negotiations.add(const BidNegotiationListFetchRequested()),
    ).called(1);
    expect(notified, 1);
  });

  testWidgets('avec contexte : recharge aussi le BidBloc global', (
    tester,
  ) async {
    final bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    late BuildContext captured;
    await tester.pumpWidget(
      BlocProvider<BidBloc>.value(
        value: bidBloc,
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    refreshActivityAfterBidChange(captured);

    verify(
      () => bidBloc.add(const BidMyListAutoRefreshRequested(force: true)),
    ).called(1);
  });

  testWidgets('sans BidBloc dans l\'arbre ni singletons : aucune erreur', (
    tester,
  ) async {
    await GetIt.I.reset();
    late BuildContext captured;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );

    expect(() => refreshActivityAfterBidChange(captured), returnsNormally);
  });
}
