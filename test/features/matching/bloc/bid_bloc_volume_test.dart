// BidBloc : réservation d'un trajet au m³ (lot 3, A4). Les dimensions vont au
// dépôt, l'analytics signale l'unité au m³ sans jamais les valeurs.

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';
import 'package:dony/features/matching/data/models/bid_volume_input.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockBidRepo extends Mock implements BidRepository {}

const _volume = BidVolumeInput(lengthCm: 100, widthCm: 50, heightCm: 40);

void main() {
  late _MockBidRepo repo;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(BidPaymentMethod.stripe);
    registerFallbackValue(_volume);
  });

  setUp(() {
    repo = _MockBidRepo();
    backend = MockAnalyticsBackend();
  });

  BidBloc makeBloc() {
    final a = makeEnabledAnalytics(backend)..onConfigured();
    return BidBloc(repo, a);
  }

  BidCheckoutRequested checkout({BidVolumeInput? volume}) =>
      BidCheckoutRequested(
        announcementId: 'ann1',
        weightKg: volume == null ? 5 : 0,
        description: 'd',
        contentCategory: 'OTHER',
        recipientName: 'Awa',
        recipientPhone: '+221700000000',
        volume: volume,
      );

  When<Future<BidCheckoutResponseModel>> stubCheckout() => when(
    () => repo.checkoutBid(
      announcementId: any(named: 'announcementId'),
      weightKg: any(named: 'weightKg'),
      description: any(named: 'description'),
      contentCategory: any(named: 'contentCategory'),
      recipientName: any(named: 'recipientName'),
      recipientPhone: any(named: 'recipientPhone'),
      photoKeys: any(named: 'photoKeys'),
      gridItems: any(named: 'gridItems'),
      itemSize: any(named: 'itemSize'),
      volume: any(named: 'volume'),
    ),
  );

  BidCheckoutResponseModel checkoutResponse() => BidCheckoutResponseModel(
    bidId: 'bid9',
    clientSecret: 'pi_9_secret_x',
    publishableKey: 'pk_test',
    expiresAt: DateTime(2026, 12),
    paymentMethodTypes: const ['card'],
  );

  test('checkout au m³ : dimensions transmises, price_unit m3', () async {
    stubCheckout().thenAnswer((_) async => checkoutResponse());
    final bloc = makeBloc()..add(checkout(volume: _volume));
    await bloc.stream.firstWhere((s) => s is BidCheckoutReady);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => repo.checkoutBid(
        announcementId: 'ann1',
        weightKg: 0,
        description: 'd',
        contentCategory: 'OTHER',
        recipientName: 'Awa',
        recipientPhone: '+221700000000',
        photoKeys: any(named: 'photoKeys', that: isNull),
        gridItems: any(named: 'gridItems', that: isNull),
        itemSize: any(named: 'itemSize', that: isNull),
        volume: _volume,
      ),
    ).called(1);
    verify(
      () => backend.capture(AnalyticsEvents.bidCheckoutStarted, {
        'announcement_id': 'ann1',
        'bid_id': 'bid9',
        'weight_kg': 0.0,
        'currency': 'EUR',
        'payment_method': 'card',
        'price_unit': 'm3',
      }),
    ).called(1);
  });

  test('checkout au kilo : aucun price_unit ni dimension', () async {
    stubCheckout().thenAnswer((_) async => checkoutResponse());
    final bloc = makeBloc()..add(checkout());
    await bloc.stream.firstWhere((s) => s is BidCheckoutReady);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.bidCheckoutStarted, {
        'announcement_id': 'ann1',
        'bid_id': 'bid9',
        'weight_kg': 5.0,
        'currency': 'EUR',
        'payment_method': 'card',
      }),
    ).called(1);
  });

  test(
    'offre au m³ (espèces) : dimensions transmises, price_unit m3',
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
          countryCode: any(named: 'countryCode'),
          promoCode: any(named: 'promoCode'),
          photoKeys: any(named: 'photoKeys'),
          gridItems: any(named: 'gridItems'),
          itemSize: any(named: 'itemSize'),
          volume: any(named: 'volume'),
        ),
      ).thenAnswer(
        (_) async => BidModel(
          id: 'bid1',
          announcementId: 'ann1',
          senderId: 's1',
          status: 'PENDING',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      final bloc = makeBloc()
        ..add(
          BidCreateRequested(
            announcementId: 'ann1',
            weightKg: 0,
            description: 'd',
            contentCategory: 'OTHER',
            recipientName: 'Awa',
            recipientPhone: '+221700000000',
            paymentMethod: BidPaymentMethod.cash,
            volume: _volume,
          ),
        );
      await bloc.stream.firstWhere((s) => s is BidCreated);
      await Future<void>.delayed(Duration.zero);

      final captured = verify(
        () => repo.createBid(
          announcementId: any(named: 'announcementId'),
          weightKg: any(named: 'weightKg'),
          description: any(named: 'description'),
          contentCategory: any(named: 'contentCategory'),
          recipientName: any(named: 'recipientName'),
          recipientPhone: any(named: 'recipientPhone'),
          paymentMethod: any(named: 'paymentMethod'),
          countryCode: any(named: 'countryCode'),
          promoCode: any(named: 'promoCode'),
          photoKeys: any(named: 'photoKeys'),
          gridItems: any(named: 'gridItems'),
          itemSize: any(named: 'itemSize'),
          volume: captureAny(named: 'volume'),
        ),
      ).captured;
      expect(captured.single, _volume);
      verify(
        () => backend.capture(AnalyticsEvents.bidSubmitted, {
          'announcement_id': 'ann1',
          'weight_kg': 0.0,
          'price_per_kg': 0.0,
          'payment_method': 'cash',
          'price_unit': 'm3',
        }),
      ).called(1);
    },
  );

  test('devis au m³ : dimensions transmises', () async {
    when(
      () => repo.quoteBid(
        announcementId: any(named: 'announcementId'),
        weightKg: any(named: 'weightKg'),
        promoCode: any(named: 'promoCode'),
        gridItems: any(named: 'gridItems'),
        volume: any(named: 'volume'),
      ),
    ).thenAnswer(
      (_) async => const BidQuoteResponse(
        netEur: 100,
        rate: 0.05,
        commissionEur: 5,
        totalEur: 105,
        promoApplied: false,
      ),
    );
    final bloc = makeBloc()
      ..add(BidQuoteRequested(announcementId: 'ann1', volume: _volume));
    final state = await bloc.stream.firstWhere((s) => s is BidQuoteLoaded);
    expect((state as BidQuoteLoaded).quote.totalEur, 105);
    verify(
      () => repo.quoteBid(
        announcementId: 'ann1',
        weightKg: any(named: 'weightKg', that: isNull),
        promoCode: any(named: 'promoCode', that: isNull),
        gridItems: any(named: 'gridItems', that: isNull),
        volume: _volume,
      ),
    ).called(1);
  });

  test('devis de fond au m³ : dimensions transmises, clé rendue', () async {
    when(
      () => repo.quoteBid(
        announcementId: any(named: 'announcementId'),
        weightKg: any(named: 'weightKg'),
        promoCode: any(named: 'promoCode'),
        gridItems: any(named: 'gridItems'),
        volume: any(named: 'volume'),
      ),
    ).thenAnswer(
      (_) async => const BidQuoteResponse(
        netEur: 100,
        rate: 0.05,
        commissionEur: 5,
        totalEur: 105,
        promoApplied: false,
      ),
    );
    final bloc = makeBloc()
      ..add(
        BidQuoteRequested(
          announcementId: 'ann1',
          volume: _volume,
          backgroundKey: 'k1',
        ),
      );
    final state = await bloc.stream.firstWhere((s) => s is BidQuoteLoaded);
    expect((state as BidQuoteLoaded).backgroundKey, 'k1');
    verify(
      () => repo.quoteBid(
        announcementId: 'ann1',
        weightKg: any(named: 'weightKg', that: isNull),
        promoCode: any(named: 'promoCode', that: isNull),
        gridItems: any(named: 'gridItems', that: isNull),
        volume: _volume,
      ),
    ).called(1);
  });

  test(
    'refus 422 du back : BidError avec le code, bid_submit_failed',
    () async {
      stubCheckout().thenThrow(
        const ValidationException('raw', code: 'insufficient-volume'),
      );
      final bloc = makeBloc()..add(checkout(volume: _volume));
      final state = await bloc.stream.firstWhere((s) => s is BidError);
      expect((state as BidError).error.code, 'insufficient-volume');
      await Future<void>.delayed(Duration.zero);
      verify(
        () => backend.capture(AnalyticsEvents.bidSubmitFailed, {
          'payment_method': 'card',
          'error_code': 'insufficient-volume',
        }),
      ).called(1);
    },
  );
}
