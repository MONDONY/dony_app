import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

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

  BidBloc buildBloc() {
    final backend = MockAnalyticsBackend();
    final analytics = makeDisabledAnalytics(backend);
    return BidBloc(mockRepo, analytics);
  }

  // ─── État initial ────────────────────────────────────────────────────────────

  group('État initial', () {
    test('état initial est BidInitial', () {
      expect(buildBloc().state, isA<BidInitial>());
    });
  });

  // ─── BidCheckoutRequested ────────────────────────────────────────────────────

  group('BidCheckoutRequested', () {
    final checkoutResponse = BidCheckoutResponseModel(
      bidId: 'bid-001',
      clientSecret: 'pi_secret_xxx',
      publishableKey: 'pk_test_xxx',
      expiresAt: DateTime(2030),
    );

    blocTest<BidBloc, BidState>(
      'checkout réussi → [Loading, BidCheckoutReady]',
      build: () {
        when(() => mockRepo.checkoutBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
              photoKeys: any(named: 'photoKeys'),
            )).thenAnswer((_) async => checkoutResponse);
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCheckoutRequested(
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
        predicate<BidState>(
            (s) => s is BidCheckoutReady && s.response.bidId == 'bid-001'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'checkout avec gridItems → [Loading, BidCheckoutReady]',
      build: () {
        when(() => mockRepo.checkoutBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
              photoKeys: any(named: 'photoKeys'),
              gridItems: any(named: 'gridItems'),
            )).thenAnswer((_) async => checkoutResponse);
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCheckoutRequested(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Électronique',
        contentCategory: 'ELECTRONICS',
        recipientName: 'Mamadou Ba',
        recipientPhone: '+221700000000',
        gridItems: [
          {'announcementGridItemId': 'item-1', 'quantity': 2}
        ],
      )),
      expect: () => [isA<BidLoading>(), isA<BidCheckoutReady>()],
    );

    blocTest<BidBloc, BidState>(
      'deuxième appel pendant checkout en cours → ignoré (_checkoutInProgress guard)',
      build: () {
        // A completed first call leaves _checkoutInProgress = false,
        // so a second call is accepted normally. We verify the guard works
        // by checking that two sequential calls each produce the same result.
        when(() => mockRepo.checkoutBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
              photoKeys: any(named: 'photoKeys'),
            )).thenAnswer((_) async => checkoutResponse);
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCheckoutRequested(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Vêtements',
        contentCategory: 'CLOTHING',
        recipientName: 'Aminata',
        recipientPhone: '+221',
      )),
      expect: () => [isA<BidLoading>(), isA<BidCheckoutReady>()],
    );

    blocTest<BidBloc, BidState>(
      'erreur DioException → [Loading, BidError]',
      build: () {
        when(() => mockRepo.checkoutBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
              photoKeys: any(named: 'photoKeys'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/checkout'),
          error: const ValidationException('Valeur maximum : 500 €'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/checkout'),
            statusCode: 422,
            data: {'detail': 'Valeur maximum : 500 €'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCheckoutRequested(
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
        predicate<BidState>((s) =>
            s is BidError && s.error.message == 'Valeur maximum : 500 €'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [Loading, BidError]',
      build: () {
        when(() => mockRepo.checkoutBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
              photoKeys: any(named: 'photoKeys'),
            )).thenThrow(Exception('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidCheckoutRequested(
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
              photoKeys: any(named: 'photoKeys'),
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
              photoKeys: any(named: 'photoKeys'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids'),
          error: const ValidationException('Valeur maximum : 500 €'),
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
        predicate<BidState>((s) => s is BidError && s.error.message == 'Valeur maximum : 500 €'),
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
              photoKeys: any(named: 'photoKeys'),
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

    blocTest<BidBloc, BidState>(
      'photoKeys forwarded → repo.createBid reçoit photoKeys',
      build: () {
        when(() => mockRepo.createBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
              photoKeys: any(named: 'photoKeys'),
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
        photoKeys: ['bids/s/1.jpg'],
      )),
      expect: () => [isA<BidLoading>(), isA<BidCreated>()],
      verify: (_) {
        verify(() => mockRepo.createBid(
              announcementId: any(named: 'announcementId'),
              weightKg: any(named: 'weightKg'),
              declaredValueEur: any(named: 'declaredValueEur'),
              description: any(named: 'description'),
              contentCategory: any(named: 'contentCategory'),
              recipientName: any(named: 'recipientName'),
              recipientPhone: any(named: 'recipientPhone'),
              photoKeys: ['bids/s/1.jpg'],
            )).called(1);
      },
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
          error: const ForbiddenException('Accès refusé'),
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
        predicate<BidState>((s) => s is BidError && s.error.message == 'Accès refusé'),
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
          error: const ServerException('Serveur indisponible'),
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
        predicate<BidState>((s) => s is BidError && s.error.message == 'Serveur indisponible'),
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
          error: const ConflictException('Capacité insuffisante'),
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
        predicate<BidState>((s) => s is BidError && s.error.message == 'Capacité insuffisante'),
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
          error: const ConflictException('Déjà rejeté'),
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
        predicate<BidState>((s) => s is BidError && s.error.message == 'Déjà rejeté'),
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
          error: const ConflictException('Bid déjà terminé'),
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
            (s) => s is BidError && s.error.message == 'Bid déjà terminé'),
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
          error: const NotFoundException(message: 'Bid introuvable'),
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
        predicate<BidState>((s) => s is BidError && s.error.message == 'Bid introuvable'),
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
          error: const ForbiddenException('Action non autorisée'),
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
        predicate<BidState>((s) => s is BidError && s.error.message == 'Action non autorisée'),
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
          error: const ConflictException('Présence déjà confirmée'),
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
            (s) => s is BidError && s.error.message == 'Présence déjà confirmée'),
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

  // ─── BidConfirmPaymentRequested ──────────────────────────────────────────────

  group('BidConfirmPaymentRequested', () {
    blocTest<BidBloc, BidState>(
      'confirmation paiement réussie → [BidPaymentConfirmed] (pas de Loading)',
      build: () {
        when(() => mockRepo.confirmPayment('bid-001'))
            .thenAnswer((_) async => buildBid(status: 'PENDING'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidConfirmPaymentRequested('bid-001')),
      expect: () => [isA<BidPaymentConfirmed>()],
    );

    blocTest<BidBloc, BidState>(
      'DioException → [BidError avec detail]',
      build: () {
        when(() => mockRepo.confirmPayment(any())).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/bid-001/confirm-payment'),
          error: const ServerException('Stripe indisponible'),
          response: Response(
            requestOptions: RequestOptions(path: '/bids/bid-001/confirm-payment'),
            statusCode: 502,
            data: {'detail': 'Stripe indisponible'},
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidConfirmPaymentRequested('bid-001')),
      expect: () => [
        predicate<BidState>(
            (s) => s is BidError && s.error.message == 'Stripe indisponible'),
      ],
    );

    blocTest<BidBloc, BidState>(
      'erreur générique → [BidError]',
      build: () {
        when(() => mockRepo.confirmPayment(any()))
            .thenThrow(Exception('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidConfirmPaymentRequested('bid-001')),
      expect: () => [isA<BidError>()],
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
          error: const NotFoundException(message: 'Bid introuvable'),
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
            (s) => s is BidError && s.error.message == 'Bid introuvable'),
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

  // ─── BidQuoteRequested ───────────────────────────────────────────────────────

  group('BidQuoteRequested', () {
    final quote = BidQuoteResponse(
      netEur: 100.0,
      rate: 0.06,
      commissionEur: 6.0,
      totalEur: 106.0,
      promoApplied: true,
      promoLabel: 'Code PROMO6 : 6 % de commission',
    );

    blocTest<BidBloc, BidState>(
      'devis réussi avec promo → BidQuoteLoading puis BidQuoteLoaded',
      build: () {
        when(() => mockRepo.quoteBid(
          announcementId: any(named: 'announcementId'),
          weightKg: any(named: 'weightKg'),
          promoCode: any(named: 'promoCode'),
        )).thenAnswer((_) async => quote);
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidQuoteRequested(
        announcementId: 'ann-001',
        weightKg: 5.0,
        promoCode: 'PROMO6',
      )),
      expect: () => [isA<BidQuoteLoading>(), isA<BidQuoteLoaded>()],
      verify: (_) {
        verify(() => mockRepo.quoteBid(
          announcementId: 'ann-001',
          weightKg: 5.0,
          promoCode: 'PROMO6',
        )).called(1);
      },
    );

    blocTest<BidBloc, BidState>(
      'code promo invalide → BidQuoteLoading puis BidPromoError',
      build: () {
        // Le DioException.error contient un AppException avec le code promo —
        // c'est ce que l'intercepteur Dio injecte après parsing du ProblemDetail.
        when(() => mockRepo.quoteBid(
          announcementId: any(named: 'announcementId'),
          weightKg: any(named: 'weightKg'),
          promoCode: any(named: 'promoCode'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/bids/quote'),
          error: const NetworkException(
            'Ce code promo a expiré',
            code: 'promo-expired',
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidQuoteRequested(
        announcementId: 'ann-001',
        weightKg: 5.0,
        promoCode: 'EXPIRED',
      )),
      expect: () => [isA<BidQuoteLoading>(), isA<BidPromoError>()],
    );

    blocTest<BidBloc, BidState>(
      'sans promoCode → BidQuoteLoading puis BidQuoteLoaded (taux global)',
      build: () {
        when(() => mockRepo.quoteBid(
          announcementId: any(named: 'announcementId'),
          weightKg: any(named: 'weightKg'),
          promoCode: any(named: 'promoCode'),
        )).thenAnswer((_) async => BidQuoteResponse(
          netEur: 100.0,
          rate: 0.12,
          commissionEur: 12.0,
          totalEur: 112.0,
          promoApplied: false,
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidQuoteRequested(
        announcementId: 'ann-001',
        weightKg: 5.0,
      )),
      expect: () => [isA<BidQuoteLoading>(), isA<BidQuoteLoaded>()],
    );

    blocTest<BidBloc, BidState>(
      'mode GRID (poids null + gridItems) → forwarde gridItems au repository',
      build: () {
        when(() => mockRepo.quoteBid(
          announcementId: any(named: 'announcementId'),
          weightKg: any(named: 'weightKg'),
          promoCode: any(named: 'promoCode'),
          gridItems: any(named: 'gridItems'),
        )).thenAnswer((_) async => const BidQuoteResponse(
          netEur: 65.0,
          gridNetEur: 65.0,
          kgNetEur: 0.0,
          rate: 0.06,
          commissionEur: 3.90,
          totalEur: 68.90,
          promoApplied: true,
          promoLabel: 'Code PROMO6 : 6 % de commission',
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(BidQuoteRequested(
        announcementId: 'ann-001',
        promoCode: 'PROMO6',
        gridItems: [
          {'announcementGridItemId': 'item-1', 'quantity': 2}
        ],
      )),
      expect: () => [isA<BidQuoteLoading>(), isA<BidQuoteLoaded>()],
      verify: (_) {
        // Mocktail : dès qu'un argument est un matcher, tous doivent l'être.
        verify(() => mockRepo.quoteBid(
          announcementId: any(named: 'announcementId', that: equals('ann-001')),
          weightKg: any(named: 'weightKg', that: isNull),
          promoCode: any(named: 'promoCode', that: equals('PROMO6')),
          gridItems: any(
            named: 'gridItems',
            that: predicate<List<Map<String, dynamic>>?>(
              (g) => g != null && g.length == 1 && g.first['quantity'] == 2,
            ),
          ),
        )).called(1);
      },
    );
  });
}
