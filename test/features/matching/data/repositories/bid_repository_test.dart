import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBidRemoteDatasource extends Mock implements BidRemoteDatasource {}

BidModel _bid({String id = 'bid-001', String status = 'PENDING'}) => BidModel(
      id: id,
      announcementId: 'ann-001',
      senderId: 'sender-001',
      weightKg: 5.0,
      declaredValueEur: 100.0,
      description: 'Test',
      status: status,
      createdAt: DateTime(2024, 5, 1),
      updatedAt: DateTime(2024, 5, 1),
    );

void main() {
  late MockBidRemoteDatasource mockDs;
  late BidRepository repo;

  setUp(() {
    mockDs = MockBidRemoteDatasource();
    repo = BidRepository(mockDs);
  });

  group('BidRepository delegates to datasource', () {
    test('createBid delegates correctly', () async {
      when(() => mockDs.createBid(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            declaredValueEur: any(named: 'declaredValueEur'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
          )).thenAnswer((_) async => _bid());

      final result = await repo.createBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Test',
        contentCategory: 'OTHER',
        recipientName: 'Fatou',
        recipientPhone: '+221',
      );

      expect(result.id, 'bid-001');
    });

    test('getBidsForAnnouncement delegates correctly', () async {
      when(() => mockDs.getBidsForAnnouncement('ann-001'))
          .thenAnswer((_) async => [_bid(), _bid(id: 'bid-002')]);

      final results = await repo.getBidsForAnnouncement('ann-001');
      expect(results, hasLength(2));
    });

    test('getBidById delegates correctly', () async {
      when(() => mockDs.getBidById('bid-001'))
          .thenAnswer((_) async => _bid());

      final result = await repo.getBidById('bid-001');
      expect(result.id, 'bid-001');
    });

    test('getMyBids delegates correctly', () async {
      when(() => mockDs.getMyBids()).thenAnswer((_) async => [_bid()]);

      final results = await repo.getMyBids();
      expect(results, hasLength(1));
    });

    test('acceptBid delegates correctly', () async {
      when(() => mockDs.acceptBid('bid-001'))
          .thenAnswer((_) async => _bid(status: 'ACCEPTED'));

      final result = await repo.acceptBid('bid-001');
      expect(result.status, 'ACCEPTED');
    });

    test('rejectBid delegates correctly', () async {
      when(() => mockDs.rejectBid('bid-001', reason: any(named: 'reason')))
          .thenAnswer((_) async => _bid(status: 'REJECTED'));

      final result = await repo.rejectBid('bid-001', reason: 'Trop lourd');
      expect(result.status, 'REJECTED');
    });

    test('cancelBid without reason delegates to datasource with null reason',
        () async {
      when(() => mockDs.cancelBid('bid-001', reason: null))
          .thenAnswer((_) async => _bid(status: 'CANCELLED'));

      final result = await repo.cancelBid('bid-001');
      expect(result.status, 'CANCELLED');
      verify(() => mockDs.cancelBid('bid-001', reason: null)).called(1);
    });

    test('cancelBid with reason delegates to datasource with reason', () async {
      when(() => mockDs.cancelBid('bid-001', reason: 'Colis trop lourd'))
          .thenAnswer((_) async => _bid(status: 'CANCELLED'));

      final result =
          await repo.cancelBid('bid-001', reason: 'Colis trop lourd');
      expect(result.status, 'CANCELLED');
      verify(() => mockDs.cancelBid('bid-001', reason: 'Colis trop lourd'))
          .called(1);
    });

    test('hideBid delegates correctly', () async {
      when(() => mockDs.hideBid('bid-001')).thenAnswer((_) async {});

      await expectLater(repo.hideBid('bid-001'), completes);
    });

    test('dismissBidAsTraveler delegates correctly', () async {
      when(() => mockDs.dismissBidAsTraveler('bid-001'))
          .thenAnswer((_) async {});

      await expectLater(repo.dismissBidAsTraveler('bid-001'), completes);
    });

    test('confirmPresence delegates correctly', () async {
      when(() => mockDs.confirmPresence('bid-001'))
          .thenAnswer((_) async => _bid());

      final result = await repo.confirmPresence('bid-001');
      expect(result.id, 'bid-001');
    });

    test('checkoutBid delegates correctly', () async {
      final checkoutResponse = BidCheckoutResponseModel(
        bidId: 'bid-001',
        clientSecret: 'pi_secret_xxx',
        publishableKey: 'pk_test_xxx',
        expiresAt: DateTime(2030),
      );
      when(() => mockDs.checkoutBid(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            declaredValueEur: any(named: 'declaredValueEur'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
          )).thenAnswer((_) async => checkoutResponse);

      final result = await repo.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Test',
        contentCategory: 'OTHER',
        recipientName: 'Fatou',
        recipientPhone: '+221',
      );

      expect(result.bidId, 'bid-001');
      expect(result.clientSecret, 'pi_secret_xxx');
    });

    test('checkoutBid with gridItems delegates correctly', () async {
      final checkoutResponse = BidCheckoutResponseModel(
        bidId: 'bid-001',
        clientSecret: 'pi_secret_xxx',
        publishableKey: 'pk_test_xxx',
        expiresAt: DateTime(2030),
      );
      when(() => mockDs.checkoutBid(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            declaredValueEur: any(named: 'declaredValueEur'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
            gridItems: any(named: 'gridItems'),
          )).thenAnswer((_) async => checkoutResponse);

      final result = await repo.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Test',
        contentCategory: 'OTHER',
        recipientName: 'Fatou',
        recipientPhone: '+221',
        gridItems: [
          {'announcementGridItemId': 'item-1', 'quantity': 2}
        ],
      );

      expect(result.bidId, 'bid-001');
    });

    test('confirmPayment delegates correctly', () async {
      when(() => mockDs.confirmPayment('bid-001'))
          .thenAnswer((_) async => _bid(status: 'PENDING'));

      final result = await repo.confirmPayment('bid-001');
      expect(result.id, 'bid-001');
    });

    test('acceptBidWithCommission delegates correctly', () async {
      const response = AcceptanceResponse(status: AcceptanceStatus.accepted);
      when(() => mockDs.acceptBidWithCommission('bid-001'))
          .thenAnswer((_) async => response);

      final result = await repo.acceptBidWithCommission('bid-001');
      expect(result.status, AcceptanceStatus.accepted);
    });

    test('confirmCommissionAcceptance delegates correctly', () async {
      const response = ConfirmResponse(accepted: true);
      when(() => mockDs.confirmCommissionAcceptance('bid-001'))
          .thenAnswer((_) async => response);

      final result = await repo.confirmCommissionAcceptance('bid-001');
      expect(result.accepted, isTrue);
    });
  });
}
