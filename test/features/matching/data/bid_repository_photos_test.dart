import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBidRemoteDatasource extends Mock implements BidRemoteDatasource {}

BidModel _bid() => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  weightKg: 5.0,
  description: 'Colis test',
  status: 'PENDING',
  createdAt: DateTime(2024, 5, 1),
  updatedAt: DateTime(2024, 5, 1),
);

void main() {
  late MockBidRemoteDatasource ds;
  late BidRepository repo;

  setUp(() {
    ds = MockBidRemoteDatasource();
    repo = BidRepository(ds);
    registerFallbackValue(BidPaymentMethod.stripe);
  });

  test('uploadBidPhoto forwards to datasource', () async {
    when(
      () => ds.uploadBidPhoto(any()),
    ).thenAnswer((_) async => 'bids/s/1.jpg');

    final key = await repo.uploadBidPhoto('/tmp/a.jpg');

    expect(key, 'bids/s/1.jpg');
    verify(() => ds.uploadBidPhoto('/tmp/a.jpg')).called(1);
  });

  test('createBid forwards photoKeys to datasource', () async {
    when(
      () => ds.createBid(
        announcementId: any(named: 'announcementId'),
        weightKg: any(named: 'weightKg'),
        description: any(named: 'description'),
        contentCategory: any(named: 'contentCategory'),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
        paymentMethod: any(named: 'paymentMethod'),
        phoneNumber: any(named: 'phoneNumber'),
        countryCode: any(named: 'countryCode'),
        promoCode: any(named: 'promoCode'),
        photoKeys: any(named: 'photoKeys'),
        gridItems: any(named: 'gridItems'),
      ),
    ).thenAnswer((_) async => _bid());

    await repo.createBid(
      announcementId: 'ann-001',
      weightKg: 5.0,
      description: 'Colis test',
      contentCategory: 'OTHER',
      recipientName: 'Fatou',
      recipientPhone: '+221777000000',
      photoKeys: ['bids/s/1.jpg'],
    );

    verify(
      () => ds.createBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        description: 'Colis test',
        contentCategory: 'OTHER',
        recipientName: 'Fatou',
        recipientPhone: '+221777000000',
        paymentMethod: BidPaymentMethod.stripe,
        phoneNumber: null,
        countryCode: null,
        promoCode: null,
        photoKeys: ['bids/s/1.jpg'],
        gridItems: null,
      ),
    ).called(1);
  });

  test('checkoutBid forwards photoKeys to datasource', () async {
    when(
      () => ds.checkoutBid(
        announcementId: any(named: 'announcementId'),
        weightKg: any(named: 'weightKg'),
        description: any(named: 'description'),
        contentCategory: any(named: 'contentCategory'),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
        photoKeys: any(named: 'photoKeys'),
        gridItems: any(named: 'gridItems'),
      ),
    ).thenAnswer(
      (_) async => throw UnimplementedError('checkoutBid not mocked fully'),
    );

    // We only verify the forwarding — the datasource stub throws for the result,
    // so we catch and verify the call was made with the right photoKeys arg.
    try {
      await repo.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        description: 'Colis test',
        contentCategory: 'OTHER',
        recipientName: 'Fatou',
        recipientPhone: '+221777000000',
        photoKeys: ['bids/s/photo.jpg'],
      );
    } catch (_) {}

    verify(
      () => ds.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        description: 'Colis test',
        contentCategory: 'OTHER',
        recipientName: 'Fatou',
        recipientPhone: '+221777000000',
        photoKeys: ['bids/s/photo.jpg'],
        gridItems: null,
      ),
    ).called(1);
  });
}
