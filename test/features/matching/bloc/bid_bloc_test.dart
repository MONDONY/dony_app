import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBidRepository extends Mock implements BidRepository {}

BidModel buildBid({String id = 'bid-001', String status = 'PENDING'}) => BidModel(
      id: id,
      announcementId: 'ann-001',
      senderId: 'sender-001',
      weightKg: 5.0,
      declaredValueEur: 100.0,
      description: 'Vêtements',
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  late MockBidRepository mockRepo;

  setUp(() {
    mockRepo = MockBidRepository();
  });

  BidBloc buildBloc() => BidBloc(mockRepo);

  // ─── État initial ────────────────────────────────────────────────────────────

  group('État initial', () {
    test('état initial est BidInitial', () {
      expect(buildBloc().state, isA<BidInitial>());
    });
  });

  // ─── BidCreateRequested ──────────────────────────────────────────────────────

  group('BidCreateRequested', () {
    blocTest<BidBloc, BidState>(
      'création réussie → [Loading, BidCreated]',
      build: () {
        when(() => mockRepo.createBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
            )).thenAnswer((_) async => buildBid());
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCreateRequested(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Vêtements',
        contentCategory: 'CLOTHING',
        recipientName: 'Aminata Diallo',
        recipientPhone: '+221701234567',
      )),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidCreated && s.bid.id == 'bid-001'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'DioException avec detail → [Loading, BidError avec message detail]',
      build: () {
        when(() => mockRepo.createBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids'),
            statusCode: 422,
            data: {'detail': 'Valeur maximum : 500 €'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCreateRequested(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 501.0,
        description: 'Bijoux',
        contentCategory: 'JEWELRY',
        recipientName: 'Recip',
        recipientPhone: '+221',
      )),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidError && s.message == 'Valeur maximum : 500 €'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.createBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
            )).thenThrow(Exception('Server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCreateRequested(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Desc',
        contentCategory: 'OTHER',
        recipientName: 'Recip',
        recipientPhone: '+221',
      )),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidListRequested ────────────────────────────────────────────────────────

  group('BidListRequested', () {
    blocTest<BidBloc, BidState>(
      'liste bids chargée → [Loading, BidListLoaded]',
      build: () {
        when(() => mockRepo.getBidsForAnnouncement('ann-001'))
            .thenAnswer((_) async => [buildBid(), buildBid(id: 'bid-002')]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidListRequested('ann-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidListLoaded && s.bids.length == 2),
      ],
    );

    blocTest<BidBloc, BidState>(
      'DioException liste → [Loading, BidError]',
      build: () {
        when(() => mockRepo.getBidsForAnnouncement(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids'),
            statusCode: 403,
            data: {'detail': 'Accès refusé'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidListRequested('ann-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidError && s.message == 'Accès refusé'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.getBidsForAnnouncement(any()))
            .thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidListRequested('ann-001')),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidMyListRequested ──────────────────────────────────────────────────────

  group('BidMyListRequested', () {
    blocTest<BidBloc, BidState>(
      'mes bids chargés → [Loading, BidListLoaded]',
      build: () {
        when(() => mockRepo.getMyBids())
            .thenAnswer((_) async => [buildBid()]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidMyListRequested()),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidListLoaded && s.bids.length == 1),
      ],
    );

    blocTest<BidBloc, BidState>(
      'DioException → [Loading, BidError]',
      build: () {
        when(() => mockRepo.getMyBids()).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/me'),
            statusCode: 500,
            data: {'detail': 'Serveur indisponible'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidMyListRequested()),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidError && s.message == 'Serveur indisponible'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.getMyBids()).thenThrow(Exception('connection lost'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidMyListRequested()),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidDetailRequested ──────────────────────────────────────────────────────

  group('BidDetailRequested', () {
    blocTest<BidBloc, BidState>(
      'détail bid chargé → [BidDetailLoaded] sans Loading (refresh silencieux)',
      build: () {
        when(() => mockRepo.getBidById('bid-001'))
            .thenAnswer((_) async => buildBid());
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidDetailRequested('bid-001')),
      expect: () => [
        predicate<BidState>((s) => s is BidDetailLoaded && s.bid.id == 'bid-001'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur détail DioException → aucun changement d\'état (silent fail)',
      build: () {
        when(() => mockRepo.getBidById(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-999'),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidDetailRequested('bid-999')),
      expect: () => [],
    );
  });

  // ─── BidAcceptRequested ──────────────────────────────────────────────────────

  group('BidAcceptRequested', () {
    blocTest<BidBloc, BidState>(
      'acceptation réussie → [Loading, BidAccepted]',
      build: () {
        when(() => mockRepo.acceptBid('bid-001'))
            .thenAnswer((_) async => buildBid(status: 'ACCEPTED'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidAcceptRequested('bid-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) =>
            s is BidAccepted && s.bid.status == 'ACCEPTED'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur acceptation → [Loading, BidError]',
      build: () {
        when(() => mockRepo.acceptBid(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001/accept'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001/accept'),
            statusCode: 409,
            data: {'detail': 'Capacité insuffisante'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidAcceptRequested('bid-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidError && s.message == 'Capacité insuffisante'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.acceptBid(any())).thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidAcceptRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidRejectRequested ──────────────────────────────────────────────────────

  group('BidRejectRequested', () {
    blocTest<BidBloc, BidState>(
      'rejet réussi → [Loading, BidRejected]',
      build: () {
        when(() => mockRepo.rejectBid('bid-001', reason: any(named: 'reason')))
            .thenAnswer((_) async => buildBid(status: 'REJECTED'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidRejectRequested('bid-001', reason: 'Trop lourd')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidRejected && s.bid.status == 'REJECTED'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'DioException → [Loading, BidError avec detail]',
      build: () {
        when(() => mockRepo.rejectBid(any(), reason: any(named: 'reason')))
            .thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001/reject'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001/reject'),
            statusCode: 409,
            data: {'detail': 'Déjà rejeté'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidRejectRequested('bid-001', reason: 'reason')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidError && s.message == 'Déjà rejeté'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.rejectBid(any(), reason: any(named: 'reason')))
            .thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidRejectRequested('bid-001', reason: 'reason')),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidCancelRequested ──────────────────────────────────────────────────────

  group('BidCancelRequested', () {
    blocTest<BidBloc, BidState>(
      'annulation sans motif → [Loading, BidCancelled]',
      build: () {
        when(() => mockRepo.cancelBid('bid-001', reason: null))
            .thenAnswer((_) async => buildBid(status: 'CANCELLED'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCancelRequested('bid-001')),
      verify: (_) {
        verify(() => mockRepo.cancelBid('bid-001', reason: null)).called(1);
      },
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) =>
            s is BidCancelled && s.bid.status == 'CANCELLED'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'annulation avec motif → [Loading, BidCancelled]',
      build: () {
        when(() => mockRepo.cancelBid('bid-001', reason: 'Colis trop lourd'))
            .thenAnswer((_) async => buildBid(status: 'CANCELLED'));
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(BidCancelRequested('bid-001', reason: 'Colis trop lourd')),
      verify: (_) {
        verify(() => mockRepo.cancelBid('bid-001', reason: 'Colis trop lourd'))
            .called(1);
      },
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) =>
            s is BidCancelled && s.bid.status == 'CANCELLED'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur annulation → [Loading, BidError avec detail]',
      build: () {
        when(() => mockRepo.cancelBid(any(), reason: any(named: 'reason')))
            .thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001/cancel'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001/cancel'),
            statusCode: 409,
            data: {'detail': 'Bid déjà terminé'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCancelRequested('bid-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>(
            (s) => s is BidError && s.message == 'Bid déjà terminé'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.cancelBid(any(), reason: any(named: 'reason')))
            .thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCancelRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidHideRequested ────────────────────────────────────────────────────────

  group('BidHideRequested', () {
    blocTest<BidBloc, BidState>(
      'masquage réussi → [Loading, BidHidden]',
      build: () {
        when(() => mockRepo.hideBid('bid-001')).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidHideRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidHidden>()],
    );

    blocTest<BidBloc, BidState>(
      'DioException → [Loading, BidError avec detail]',
      build: () {
        when(() => mockRepo.hideBid(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001/me'),
            statusCode: 404,
            data: {'detail': 'Bid introuvable'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidHideRequested('bid-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidError && s.message == 'Bid introuvable'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.hideBid(any())).thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidHideRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidTravelerDismissRequested ─────────────────────────────────────────────

  group('BidTravelerDismissRequested', () {
    blocTest<BidBloc, BidState>(
      'dismiss réussi → [Loading, BidDeleted]',
      build: () {
        when(() => mockRepo.dismissBidAsTraveler('bid-001'))
            .thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidTravelerDismissRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidDeleted>()],
    );

    blocTest<BidBloc, BidState>(
      'DioException → [Loading, BidError avec detail]',
      build: () {
        when(() => mockRepo.dismissBidAsTraveler(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001/traveler'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001/traveler'),
            statusCode: 403,
            data: {'detail': 'Action non autorisée'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidTravelerDismissRequested('bid-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidError && s.message == 'Action non autorisée'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.dismissBidAsTraveler(any()))
            .thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidTravelerDismissRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidHandoverRequested ────────────────────────────────────────────────────

  group('BidHandoverRequested', () {
    blocTest<BidBloc, BidState>(
      'handover défini → [Loading, BidHandoverSet]',
      build: () {
        when(() => mockRepo.setHandover(
              bidId: any(named: 'bidId'),
              location: any(named: 'location'),
              windowStart: any(named: 'windowStart'),
              windowEnd: any(named: 'windowEnd'),
            )).thenAnswer((_) async => buildBid(status: 'ACCEPTED'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidHandoverRequested(
        bidId: 'bid-001',
        location: 'Gare du Nord',
        windowStart: DateTime.now().add(const Duration(days: 5)),
        windowEnd: DateTime.now().add(const Duration(days: 5, hours: 2)),
      )),
      expect: () => [isA<BidLoading>(), isA<BidHandoverSet>()],
    );

    blocTest<BidBloc, BidState>(
      'DioException → [Loading, BidError avec detail]',
      build: () {
        when(() => mockRepo.setHandover(
              bidId: any(named: 'bidId'),
              location: any(named: 'location'),
              windowStart: any(named: 'windowStart'),
              windowEnd: any(named: 'windowEnd'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001/handover'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001/handover'),
            statusCode: 422,
            data: {'detail': 'Fenêtre invalide'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidHandoverRequested(
        bidId: 'bid-001',
        location: 'Gare du Nord',
        windowStart: DateTime.now(),
        windowEnd: DateTime.now().add(const Duration(hours: 2)),
      )),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>((s) => s is BidError && s.message == 'Fenêtre invalide'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.setHandover(
              bidId: any(named: 'bidId'),
              location: any(named: 'location'),
              windowStart: any(named: 'windowStart'),
              windowEnd: any(named: 'windowEnd'),
            )).thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidHandoverRequested(
        bidId: 'bid-001',
        location: 'Gare du Nord',
        windowStart: DateTime.now(),
        windowEnd: DateTime.now().add(const Duration(hours: 2)),
      )),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidConfirmPresenceRequested ─────────────────────────────────────────────

  group('BidConfirmPresenceRequested', () {
    blocTest<BidBloc, BidState>(
      'confirmation présence réussie → [Loading, BidPresenceConfirmed]',
      build: () {
        when(() => mockRepo.confirmPresence('bid-001'))
            .thenAnswer((_) async => buildBid(status: 'PRESENT'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidConfirmPresenceRequested('bid-001')),
      expect: () => [
        isA<BidLoading>(),
        isA<BidPresenceConfirmed>(),
      ],
    );

    blocTest<BidBloc, BidState>(
      'DioException → [Loading, BidError avec detail]',
      build: () {
        when(() => mockRepo.confirmPresence(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001/presence'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001/presence'),
            statusCode: 409,
            data: {'detail': 'Présence déjà confirmée'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidConfirmPresenceRequested('bid-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>(
            (s) => s is BidError && s.message == 'Présence déjà confirmée'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.confirmPresence(any()))
            .thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidConfirmPresenceRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidDeleteRequested ──────────────────────────────────────────────────────

  group('BidDeleteRequested', () {
    blocTest<BidBloc, BidState>(
      'suppression réussie → [Loading, BidDeleted]',
      build: () {
        when(() => mockRepo.hideBid('bid-001')).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidDeleteRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidDeleted>()],
    );

    blocTest<BidBloc, BidState>(
      'DioException → [Loading, BidError]',
      build: () {
        when(() => mockRepo.hideBid(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001'),
            statusCode: 404,
            data: {'detail': 'Bid introuvable'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidDeleteRequested('bid-001')),
      expect: () => [
        isA<BidLoading>(),
        predicate<BidState>(
            (s) => s is BidError && s.message == 'Bid introuvable'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.hideBid(any())).thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidDeleteRequested('bid-001')),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidMyListAutoRefreshRequested ───────────────────────────────────────────

  group('BidMyListAutoRefreshRequested', () {
    blocTest<BidBloc, BidState>(
      'sans données existantes → comportement identique à BidMyListRequested',
      build: () {
        when(() => mockRepo.getMyBids())
            .thenAnswer((_) async => [buildBid()]);
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const BidMyListAutoRefreshRequested(force: false)),
      expect: () => [
        isA<BidLoading>(),
        isA<BidListLoaded>(),
      ],
    );

    blocTest<BidBloc, BidState>(
      'données fraîches sans force → aucun état émis',
      build: () => buildBloc(),
      seed: () => BidListLoaded([buildBid()],
          fetchedAt: DateTime.now().subtract(const Duration(minutes: 1))),
      act: (bloc) =>
          bloc.add(const BidMyListAutoRefreshRequested(force: false)),
      expect: () => [],
    );

    blocTest<BidBloc, BidState>(
      'données périmées → refresh silencieux, émet isRefreshing puis liste fraîche',
      build: () {
        when(() => mockRepo.getMyBids())
            .thenAnswer((_) async => [buildBid(id: 'new-bid')]);
        return buildBloc();
      },
      seed: () => BidListLoaded([buildBid()],
          fetchedAt:
              DateTime.now().subtract(const Duration(minutes: 5))),
      act: (bloc) =>
          bloc.add(const BidMyListAutoRefreshRequested(force: false)),
      expect: () => [
        predicate<BidState>((s) => s is BidListLoaded && s.isRefreshing),
        predicate<BidState>((s) =>
            s is BidListLoaded &&
            !s.isRefreshing &&
            s.bids.first.id == 'new-bid'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'force=true avec données fraîches → force le refresh',
      build: () {
        when(() => mockRepo.getMyBids())
            .thenAnswer((_) async => [buildBid(id: 'forced')]);
        return buildBloc();
      },
      seed: () => BidListLoaded([buildBid()],
          fetchedAt: DateTime.now().subtract(const Duration(seconds: 30))),
      act: (bloc) => bloc.add(const BidMyListAutoRefreshRequested(force: true)),
      expect: () => [
        predicate<BidState>((s) => s is BidListLoaded && s.isRefreshing),
        predicate<BidState>((s) =>
            s is BidListLoaded &&
            !s.isRefreshing &&
            s.bids.first.id == 'forced'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'données périmées + DioException → conserve anciennes données',
      build: () {
        when(() => mockRepo.getMyBids()).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/my'),
        ));
        return buildBloc();
      },
      seed: () => BidListLoaded(
        [buildBid(id: 'old')],
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      act: (bloc) =>
          bloc.add(const BidMyListAutoRefreshRequested(force: false)),
      expect: () => [
        predicate<BidState>((s) => s is BidListLoaded && s.isRefreshing),
        predicate<BidState>((s) =>
            s is BidListLoaded &&
            !s.isRefreshing &&
            s.bids.first.id == 'old'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'sans données + DioException → émet BidError',
      build: () {
        when(() => mockRepo.getMyBids()).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/my'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/my'),
            statusCode: 503,
            data: {'detail': 'Service unavailable'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const BidMyListAutoRefreshRequested(force: false)),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );

    blocTest<BidBloc, BidState>(
      'données périmées + erreur générique → conserve anciennes données',
      build: () {
        when(() => mockRepo.getMyBids()).thenThrow(Exception('timeout'));
        return buildBloc();
      },
      seed: () => BidListLoaded(
        [buildBid(id: 'old')],
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      act: (bloc) =>
          bloc.add(const BidMyListAutoRefreshRequested(force: false)),
      expect: () => [
        predicate<BidState>((s) => s is BidListLoaded && s.isRefreshing),
        predicate<BidState>(
            (s) => s is BidListLoaded && s.bids.first.id == 'old'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'sans données + erreur générique → émet BidError',
      build: () {
        when(() => mockRepo.getMyBids()).thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const BidMyListAutoRefreshRequested(force: false)),
      expect: () => [isA<BidLoading>(), isA<BidError>()],
    );
  });

  // ─── BidListRequested — 404 ──────────────────────────────────────────────────

  group('BidListRequested — 404', () {
    blocTest<BidBloc, BidState>(
      '404 annonce supprimée → [Loading, BidNotFound]',
      build: () {
        when(() => mockRepo.getBidsForAnnouncement(any()))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/announcements/missing/bids'),
              error: const NotFoundException(),
            ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidListRequested('missing')),
      expect: () => [
        isA<BidLoading>(),
        isA<BidNotFound>(),
      ],
    );
  });

  // ─── BidDetailRequested — 404 (refresh silencieux) ───────────────────────────

  group('BidDetailRequested — 404', () {
    blocTest<BidBloc, BidState>(
      '404 bid supprimé → [BidNotFound] sans BidLoading préalable',
      build: () {
        when(() => mockRepo.getBidById(any()))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/bids/missing'),
              error: const NotFoundException(),
            ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidDetailRequested('missing')),
      expect: () => [isA<BidNotFound>()],
    );

    blocTest<BidBloc, BidState>(
      'erreur réseau sur BidDetailRequested → aucun état émis (silence)',
      build: () {
        when(() => mockRepo.getBidById(any()))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/bids/bid-001'),
              type: DioExceptionType.connectionTimeout,
            ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidDetailRequested('bid-001')),
      expect: () => [],
    );
  });

  // ─── BidModel helpers ────────────────────────────────────────────────────────

  group('BidModel.resolvedSenderName', () {
    test('avec senderName → retourne le nom', () {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        senderName: 'Amadou Diallo',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Test',
        status: 'PENDING',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(bid.resolvedSenderName, 'Amadou Diallo');
    });

    test('sans senderName avec senderPhone → retourne le téléphone', () {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        senderPhone: '+33612345678',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Test',
        status: 'PENDING',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(bid.resolvedSenderName, '+33612345678');
    });
  });
}
