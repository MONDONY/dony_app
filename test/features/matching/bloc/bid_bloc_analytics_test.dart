import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockBidRepo extends Mock implements BidRepository {}

void _setUpFallbacks() {
  registerFallbackValue(BidPaymentMethod.stripe);
}

BidModel _buildBid({
  String id = 'bid1',
  String announcementId = 'ann1',
  double? weightKg = 5.0,
  double? pricePerKg = 12.0,
}) => BidModel(
  id: id,
  announcementId: announcementId,
  senderId: 'sender1',
  weightKg: weightKg,
  pricePerKg: pricePerKg,
  status: 'PENDING',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  late _MockBidRepo repo;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    _setUpFallbacks();
  });

  setUp(() {
    repo = _MockBidRepo();
    backend = MockAnalyticsBackend();
  });

  BidBloc makeBloc({bool enabled = true}) {
    final a = enabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    a.onConfigured();
    return BidBloc(repo, a);
  }

  test(
    'bid_submitted fires with correct properties on BidCreateRequested',
    () async {
      when(
        () => repo.createBid(
          announcementId: any(named: 'announcementId'),
          weightKg: any(named: 'weightKg'),
          description: any(named: 'description'),
          contentCategory: any(named: 'contentCategory'),
          recipientName: any(named: 'recipientName'),
          recipientPhone: any(named: 'recipientPhone'),
          paymentMethod: any(named: 'paymentMethod'),
          phoneNumber: any(named: 'phoneNumber'),
          countryCode: any(named: 'countryCode'),
          gridItems: any(named: 'gridItems'),
        ),
      ).thenAnswer(
        (_) async =>
            _buildBid(announcementId: 'ann1', weightKg: 5.0, pricePerKg: 12.0),
      );

      final bloc = makeBloc();
      bloc.add(
        BidCreateRequested(
          announcementId: 'ann1',
          weightKg: 5.0,
          description: 'test',
          contentCategory: 'OTHER',
          recipientName: 'Test',
          recipientPhone: '+221700000000',
        ),
      );
      await bloc.stream.firstWhere((s) => s is BidCreated);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.bidSubmitted, {
          'announcement_id': 'ann1',
          'weight_kg': 5.0,
          'price_per_kg': 12.0,
        }),
      ).called(1);
    },
  );

  test('bid_accepted fires on BidAcceptRequested', () async {
    when(
      () => repo.acceptBid('bid1'),
    ).thenAnswer((_) async => _buildBid(id: 'bid1'));

    final bloc = makeBloc();
    bloc.add(BidAcceptRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is BidAccepted);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.bidAccepted, {'bid_id': 'bid1'}),
    ).called(1);
  });

  test('bid_rejected fires on BidRejectRequested', () async {
    when(
      () => repo.rejectBid('bid1', reason: any(named: 'reason')),
    ).thenAnswer((_) async => _buildBid(id: 'bid1'));

    final bloc = makeBloc();
    bloc.add(BidRejectRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is BidRejected);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.bidRejected, {'bid_id': 'bid1'}),
    ).called(1);
  });

  test('no events when disabled', () async {
    when(
      () => repo.createBid(
        announcementId: any(named: 'announcementId'),
        weightKg: any(named: 'weightKg'),
        description: any(named: 'description'),
        contentCategory: any(named: 'contentCategory'),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
        paymentMethod: any(named: 'paymentMethod'),
        phoneNumber: any(named: 'phoneNumber'),
        countryCode: any(named: 'countryCode'),
        gridItems: any(named: 'gridItems'),
      ),
    ).thenAnswer(
      (_) async =>
          _buildBid(announcementId: 'ann1', weightKg: 5.0, pricePerKg: 12.0),
    );
    final bloc = makeBloc(enabled: false);
    bloc.add(
      BidCreateRequested(
        announcementId: 'ann1',
        weightKg: 5.0,
        description: 'test',
        contentCategory: 'OTHER',
        recipientName: 'Test',
        recipientPhone: '+221700000000',
      ),
    );
    await bloc.stream.firstWhere((s) => s is BidCreated);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
