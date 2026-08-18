import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BidNegotiationRepository {}

BidNegotiationSummary _summary({
  String bidId = 'bid1',
  String status = 'NEGOTIATING',
  bool myTurn = true,
  bool hasUnread = true,
}) => BidNegotiationSummary(
  bidId: bidId,
  announcementId: 'ann1',
  status: status,
  myTurn: myTurn,
  hasUnread: hasUnread,
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'le chargement passe par loading puis loaded',
    build: () {
      when(() => repo.myNegotiations()).thenAnswer((_) async => [_summary()]);
      return BidNegotiationListBloc(repo);
    },
    act: (bloc) => bloc.add(const BidNegotiationListFetchRequested()),
    expect: () => [
      isA<BidNegotiationListState>().having(
        (s) => s.status,
        'status',
        BidNegotiationListStatus.loading,
      ),
      isA<BidNegotiationListState>()
          .having((s) => s.status, 'status', BidNegotiationListStatus.loaded)
          .having((s) => s.summaries, 'summaries', hasLength(1)),
    ],
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'une erreur porte un message',
    build: () {
      when(() => repo.myNegotiations()).thenThrow(const OfflineException());
      return BidNegotiationListBloc(repo);
    },
    act: (bloc) => bloc.add(const BidNegotiationListFetchRequested()),
    expect: () => [
      isA<BidNegotiationListState>().having(
        (s) => s.status,
        'status',
        BidNegotiationListStatus.loading,
      ),
      isA<BidNegotiationListState>()
          .having((s) => s.status, 'status', BidNegotiationListStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
  );

  blocTest<BidNegotiationListBloc, BidNegotiationListState>(
    'le refresh garde les donnees visibles, sans etat de chargement',
    build: () {
      when(() => repo.myNegotiations()).thenAnswer((_) async => [_summary()]);
      return BidNegotiationListBloc(repo);
    },
    act: (bloc) => bloc.add(const BidNegotiationListRefreshRequested()),
    expect: () => [
      isA<BidNegotiationListState>().having(
        (s) => s.status,
        'status',
        BidNegotiationListStatus.loaded,
      ),
    ],
  );

  test('les compteurs comptent les fils ouverts et les non-lus', () {
    final state = BidNegotiationListState(
      status: BidNegotiationListStatus.loaded,
      summaries: [
        _summary(),
        _summary(bidId: 'bid2', myTurn: false, hasUnread: false),
        _summary(bidId: 'bid3', status: 'ACCEPTED'),
      ],
    );

    expect(state.activeCount, 2);
    expect(state.actionableCount, 1);
  });
}
