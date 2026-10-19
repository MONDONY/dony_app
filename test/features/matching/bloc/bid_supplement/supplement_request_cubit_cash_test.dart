import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockMediaService extends Mock implements DonyMediaService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

BidModel _bid({BidPaymentMethod paymentMethod = BidPaymentMethod.cash}) =>
    BidModel(
      id: 'bid-1',
      announcementId: 'ann-1',
      senderId: 'sender-1',
      status: 'ACCEPTED',
      paymentMethod: paymentMethod,
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
    );

const _kg = SupplementSuggestion(kind: SupplementSuggestion.kindKg, unitNet: 8);
const _options = SupplementOptions(
  currency: 'EUR',
  minNet: 1,
  maxNet: 300,
  suggestions: [_kg],
  rail: 'CASH',
);

BidSupplement _sup(
  BidSupplementStatus status, {
  String? secret,
  String? commissionStatus,
}) => BidSupplement(
  id: 'sup-1',
  status: status,
  rail: 'CASH',
  netAmount: 8,
  commissionAmount: 1,
  grossAmount: 9,
  commissionStatus: commissionStatus,
  commissionClientSecret: secret,
  blocksHandover: status.isOpen,
);

final _proposedCharged = _sup(
  BidSupplementStatus.proposed,
  commissionStatus: SupplementCommissionStatus.charged,
);

const _unfundedError = ValidationException(
  'd',
  code: 'supplement-commission-unfunded',
  extensions: {
    'availableBalance': 0.2,
    'requiredCommission': 1,
    'shortfall': 0.8,
    'hasCard': false,
    'currency': 'EUR',
    'bidCurrency': 'EUR',
    'alternatives': [
      {'currency': 'XOF', 'balance': 5000, 'required': 656},
    ],
  },
);

void main() {
  late _MockRepository repository;
  late _MockMediaService media;
  late _MockAnalyticsService analytics;
  late List<String> secrets;
  late bool failAuth;

  setUpAll(() {
    registerFallbackValue(ImageSource.camera);
    registerFallbackValue(BidSupplementReason.other);
    registerFallbackValue(SupplementCommissionSource.wallet);
  });

  setUp(() {
    repository = _MockRepository();
    media = _MockMediaService();
    analytics = _MockAnalyticsService();
    secrets = [];
    failAuth = false;
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repository.options(any())).thenAnswer((_) async => _options);
    when(() => repository.quote(any(), any())).thenAnswer(
      (_) async => const SupplementQuote(
        netAmount: 8,
        commissionAmount: 1,
        grossAmount: 9,
        currency: 'EUR',
      ),
    );
    when(
      () => repository.uploadPhoto(any(), any()),
    ).thenAnswer((_) async => 'tracking/bid-1/supplement.jpg');
    when(
      () => media.pick(source: any(named: 'source')),
    ).thenAnswer((_) async => XFile('/tmp/supplement.jpg'));
  });

  SupplementRequestCubit build() => SupplementRequestCubit(
    repository,
    media,
    analytics,
    quoteDebounce: Duration.zero,
    commissionFlow: SupplementCommissionFlow(
      repository,
      analytics,
      nextAction: (secret) async {
        secrets.add(secret);
        if (failAuth) throw StateError('canceled');
      },
    ),
  );

  void stubCreate(Future<BidSupplement> Function(Invocation) answer) => when(
    () => repository.create(
      any(),
      netAmount: any(named: 'netAmount'),
      reason: any(named: 'reason'),
      reasonText: any(named: 'reasonText'),
      gridItemLabel: any(named: 'gridItemLabel'),
      photoKey: any(named: 'photoKey'),
      commissionSource: any(named: 'commissionSource'),
      fundingCurrency: any(named: 'fundingCurrency'),
    ),
  ).thenAnswer(answer);

  Future<SupplementRequestCubit> ready({
    BidPaymentMethod paymentMethod = BidPaymentMethod.cash,
  }) async {
    final cubit = build();
    await cubit.load(_bid(paymentMethod: paymentMethod));
    cubit.selectSuggestion(_kg);
    await cubit.takePhoto();
    return cubit;
  }

  /// Envoi tel que l'écran le fait en espèces : vérification locale puis
  /// envoi.
  Future<void> authorizedSubmit(SupplementRequestCubit cubit) async {
    expect(cubit.beginAuthorization(), isTrue);
    await cubit.submit();
  }

  test('load : colis en espèces reconnu (moyen du colis ou rail)', () async {
    final cubit = build();
    await cubit.load(_bid());
    expect(cubit.state.isCash, isTrue);
    expect(cubit.state.commissionSource, SupplementCommissionSource.wallet);

    final card = build();
    await card.load(_bid(paymentMethod: BidPaymentMethod.stripe));
    expect(card.state.isCash, isTrue, reason: 'rail CASH des options');
  });

  test('carte : la source et la devise ne partent pas', () async {
    when(() => repository.options(any())).thenAnswer(
      (_) async =>
          const SupplementOptions(currency: 'EUR', minNet: 1, maxNet: 300),
    );
    stubCreate((_) async => _sup(BidSupplementStatus.proposed));
    final cubit = await ready(paymentMethod: BidPaymentMethod.stripe);
    expect(cubit.state.isCash, isFalse);

    await cubit.submit();

    final captured = verify(
      () => repository.create(
        any(),
        netAmount: any(named: 'netAmount'),
        reason: any(named: 'reason'),
        reasonText: any(named: 'reasonText'),
        gridItemLabel: any(named: 'gridItemLabel'),
        photoKey: any(named: 'photoKey'),
        commissionSource: captureAny(named: 'commissionSource'),
        fundingCurrency: captureAny(named: 'fundingCurrency'),
      ),
    ).captured;
    expect(captured, [null, null]);
    expect(cubit.state.status, SupplementRequestStatus.success);
  });

  test('solde couvert : PROPOSED, commission tracée une fois', () async {
    stubCreate((_) async => _proposedCharged);
    final cubit = await ready();

    await authorizedSubmit(cubit);

    expect(cubit.state.status, SupplementRequestStatus.success);
    expect(cubit.state.created, _proposedCharged);
    final captured = verify(
      () => repository.create(
        'bid-1',
        netAmount: 8,
        reason: BidSupplementReason.extraWeight,
        reasonText: any(named: 'reasonText'),
        gridItemLabel: any(named: 'gridItemLabel'),
        photoKey: 'tracking/bid-1/supplement.jpg',
        commissionSource: captureAny(named: 'commissionSource'),
        fundingCurrency: captureAny(named: 'fundingCurrency'),
      ),
    ).captured;
    expect(captured, [SupplementCommissionSource.wallet, null]);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidSupplementRequested,
        properties: any(
          named: 'properties',
          that: containsPair('commission_source', 'wallet'),
        ),
      ),
    ).called(1);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.paymentSucceeded,
        properties: any(
          named: 'properties',
          that: allOf(
            containsPair('method', 'wallet_balance'),
            containsPair('context', 'bid_supplement_commission'),
          ),
        ),
      ),
    ).called(1);
    expect(secrets, isEmpty);
  });

  test('carte avec 3DS : authentification puis confirmation', () async {
    stubCreate(
      (_) async =>
          _sup(BidSupplementStatus.commissionPending, secret: 'pi_secret'),
    );
    when(
      () => repository.confirmCommission('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _proposedCharged);
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);

    await authorizedSubmit(cubit);

    expect(secrets, ['pi_secret']);
    expect(cubit.state.status, SupplementRequestStatus.success);
    expect(cubit.state.awaitingCommission, isFalse);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.paymentSucceeded,
        properties: any(
          named: 'properties',
          that: containsPair('method', 'card'),
        ),
      ),
    ).called(1);
  });

  test(
    '3DS abandonnée puis « Réessayer » : confirm, jamais un second POST',
    () async {
      failAuth = true;
      stubCreate(
        (_) async =>
            _sup(BidSupplementStatus.commissionPending, secret: 'pi_secret'),
      );
      final cubit = await ready();
      cubit.selectCommissionSource(SupplementCommissionSource.card);

      await authorizedSubmit(cubit);

      expect(cubit.state.status, SupplementRequestStatus.commissionRetry);
      expect(cubit.state.awaitingCommission, isTrue);
      expect(cubit.state.pending?.id, 'sup-1');
      expect(cubit.state.error, isNull);
      expect(cubit.state.canSubmit, isFalse);
      expect(cubit.state.isLocked, isTrue);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementRequestFailed,
          properties: {
            'reason': 'extra_weight',
            'error_code': 'commission/3ds-interrupted',
          },
        ),
      ).called(1);

      failAuth = false;
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer(
        (_) async =>
            _sup(BidSupplementStatus.commissionPending, secret: 'pi_2'),
      );
      var confirms = 0;
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer((
        _,
      ) async {
        confirms++;
        return confirms == 1
            ? _sup(BidSupplementStatus.commissionPending, secret: 'pi_2')
            : _proposedCharged;
      });
      expect(cubit.beginAuthorization(), isTrue);
      await cubit.retryCommission();

      expect(cubit.state.status, SupplementRequestStatus.success);
      expect(secrets, ['pi_secret', 'pi_2']);
      verify(
        () => repository.create(
          any(),
          netAmount: any(named: 'netAmount'),
          reason: any(named: 'reason'),
          reasonText: any(named: 'reasonText'),
          gridItemLabel: any(named: 'gridItemLabel'),
          photoKey: any(named: 'photoKey'),
          commissionSource: any(named: 'commissionSource'),
          fundingCurrency: any(named: 'fundingCurrency'),
        ),
      ).called(1);
      verifyNever(() => repository.current(any()));
    },
  );

  test('502 commission-charge-failed : « Réessayer » retrouve la demande et '
      'la confirme', () async {
    stubCreate(
      (_) async => throw const ServiceUnavailableException(
        'd',
        'supplement-commission-charge-failed',
      ),
    );
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);

    await authorizedSubmit(cubit);

    expect(cubit.state.status, SupplementRequestStatus.commissionRetry);
    expect(cubit.state.awaitingCommission, isTrue);
    expect(cubit.state.pending, isNull);
    expect(cubit.state.error?.code, 'supplement-commission-charge-failed');

    when(
      () => repository.current('bid-1'),
    ).thenAnswer((_) async => _sup(BidSupplementStatus.commissionPending));
    when(
      () => repository.confirmCommission('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _proposedCharged);

    await cubit.retryCommission();

    expect(cubit.state.status, SupplementRequestStatus.success);
    verify(() => repository.confirmCommission('bid-1', 'sup-1')).called(1);
  });

  test('503 sans demande créée : « Réessayer » renvoie la demande', () async {
    var calls = 0;
    stubCreate((_) async {
      calls++;
      if (calls == 1) {
        throw const ServiceUnavailableException('d', 'stripe-unavailable');
      }
      return _proposedCharged;
    });
    when(() => repository.current('bid-1')).thenAnswer((_) async => null);
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);
    await authorizedSubmit(cubit);
    expect(cubit.state.awaitingCommission, isTrue);

    await cubit.retryCommission();

    expect(calls, 2);
    expect(cubit.state.status, SupplementRequestStatus.success);
  });

  test('reprise : demande déjà partie chez l\'expéditeur → succès', () async {
    stubCreate((_) async => throw const TimeoutException());
    when(
      () => repository.current('bid-1'),
    ).thenAnswer((_) async => _proposedCharged);
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);
    await authorizedSubmit(cubit);

    await cubit.retryCommission();

    expect(cubit.state.status, SupplementRequestStatus.success);
    verifyNever(() => repository.confirmCommission(any(), any()));
  });

  test('reprise en échec réseau : reste à réessayer', () async {
    failAuth = true;
    stubCreate(
      (_) async =>
          _sup(BidSupplementStatus.commissionPending, secret: 'pi_secret'),
    );
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);
    await authorizedSubmit(cubit);
    when(
      () => repository.confirmCommission('bid-1', 'sup-1'),
    ).thenThrow(const OfflineException());

    await cubit.retryCommission();

    expect(cubit.state.status, SupplementRequestStatus.commissionRetry);
    expect(cubit.state.awaitingCommission, isTrue);
    expect(cubit.state.pending?.id, 'sup-1');
  });

  test('reprise : carte refusée → feuille close', () async {
    failAuth = true;
    stubCreate(
      (_) async =>
          _sup(BidSupplementStatus.commissionPending, secret: 'pi_secret'),
    );
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);
    await authorizedSubmit(cubit);
    when(() => repository.confirmCommission('bid-1', 'sup-1')).thenThrow(
      const ValidationException(
        'd',
        code: 'supplement-commission-card-declined',
      ),
    );

    await cubit.retryCommission();

    expect(cubit.state.status, SupplementRequestStatus.closed);
    expect(cubit.state.awaitingCommission, isFalse);
  });

  test('reprise : demande close entre-temps → la demande repart', () async {
    stubCreate(
      (_) async => throw const ServiceUnavailableException(
        'd',
        'supplement-commission-charge-failed',
      ),
    );
    when(
      () => repository.uploadPhoto(any(), any()),
    ).thenAnswer((_) async => 'k');
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);
    await authorizedSubmit(cubit);
    when(
      () => repository.current('bid-1'),
    ).thenAnswer((_) async => _sup(BidSupplementStatus.declined));

    await cubit.retryCommission();

    // La photo a été envoyée au premier essai : la demande repart (et
    // retombe ici sur le même 502).
    expect(cubit.state.status, SupplementRequestStatus.commissionRetry);
    verify(() => repository.uploadPhoto(any(), any())).called(1);
  });

  test('« Réessayer » hors attente : sans effet', () async {
    final cubit = await ready();
    await cubit.retryCommission();
    expect(cubit.state.status, SupplementRequestStatus.editing);
    verifyNever(() => repository.current(any()));
  });

  test('carte refusée à la création : feuille close, payment_failed', () async {
    stubCreate(
      (_) async => throw const ValidationException(
        'd',
        code: 'supplement-commission-card-declined',
      ),
    );
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);

    await authorizedSubmit(cubit);

    expect(cubit.state.status, SupplementRequestStatus.closed);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.paymentFailed,
        properties: any(
          named: 'properties',
          that: containsPair('reason', 'declined'),
        ),
      ),
    ).called(1);
  });

  test(
    '422 solde insuffisant : alternatives, puis autre portefeuille',
    () async {
      var calls = 0;
      stubCreate((_) async {
        calls++;
        if (calls == 1) throw _unfundedError;
        return _proposedCharged;
      });
      final cubit = await ready();

      await authorizedSubmit(cubit);

      expect(cubit.state.status, SupplementRequestStatus.unfunded);
      expect(cubit.state.unfunded?.alternatives.single.currency, 'XOF');
      expect(cubit.state.unfunded?.hasCard, isFalse);
      expect(cubit.state.canSubmit, isTrue);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.paymentFailed,
          properties: any(
            named: 'properties',
            that: containsPair('reason', 'insufficient_balance'),
          ),
        ),
      ).called(1);

      cubit.selectCommissionSource(
        SupplementCommissionSource.wallet,
        fundingCurrency: 'XOF',
      );
      expect(cubit.state.status, SupplementRequestStatus.unfunded);
      expect(cubit.state.fundingCurrency, 'XOF');

      await authorizedSubmit(cubit);

      expect(cubit.state.status, SupplementRequestStatus.success);
      final captured = verify(
        () => repository.create(
          any(),
          netAmount: any(named: 'netAmount'),
          reason: any(named: 'reason'),
          reasonText: any(named: 'reasonText'),
          gridItemLabel: any(named: 'gridItemLabel'),
          photoKey: any(named: 'photoKey'),
          commissionSource: captureAny(named: 'commissionSource'),
          fundingCurrency: captureAny(named: 'fundingCurrency'),
        ),
      ).captured;
      expect(captured, [
        SupplementCommissionSource.wallet,
        null,
        SupplementCommissionSource.wallet,
        'XOF',
      ]);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.commissionFundingCurrencyChosen,
          properties: {'currency': 'XOF', 'context': 'bid_supplement'},
        ),
      ).called(1);
    },
  );

  test('montant modifié : le refus et la devise choisie s\'effacent', () async {
    stubCreate((_) async => throw _unfundedError);
    final cubit = await ready();
    await authorizedSubmit(cubit);
    cubit.selectCommissionSource(
      SupplementCommissionSource.wallet,
      fundingCurrency: 'XOF',
    );

    cubit.amountChanged('12');

    expect(cubit.state.unfunded, isNull);
    expect(cubit.state.fundingCurrency, isNull);
  });

  test('carte choisie : la devise de complément tombe', () async {
    final cubit = await ready();
    cubit.selectCommissionSource(
      SupplementCommissionSource.wallet,
      fundingCurrency: 'XOF',
    );
    cubit.selectCommissionSource(
      SupplementCommissionSource.card,
      fundingCurrency: 'XOF',
    );
    expect(cubit.state.fundingCurrency, isNull);
    expect(cubit.state.commissionSource, SupplementCommissionSource.card);
  });

  test('422 carte commission manquante : cardMissing', () async {
    stubCreate(
      (_) async => throw const ValidationException(
        'd',
        code: 'commission-method-missing',
      ),
    );
    final cubit = await ready();
    cubit.selectCommissionSource(SupplementCommissionSource.card);

    await authorizedSubmit(cubit);

    expect(cubit.state.status, SupplementRequestStatus.cardMissing);
    expect(cubit.state.canSubmit, isTrue);
    cubit.selectCommissionSource(SupplementCommissionSource.wallet);
    expect(cubit.state.status, SupplementRequestStatus.cardMissing);
  });

  test('422 devise de complément refusée : échec, devise effacée', () async {
    stubCreate(
      (_) async => throw const ValidationException(
        'd',
        code: 'funding-currency-invalid',
      ),
    );
    final cubit = await ready();
    cubit.selectCommissionSource(
      SupplementCommissionSource.wallet,
      fundingCurrency: 'ABC',
    );

    await authorizedSubmit(cubit);

    expect(cubit.state.status, SupplementRequestStatus.failure);
    expect(cubit.state.fundingCurrency, isNull);
  });

  test(
    'ancien back : COMMISSION_PENDING sans secret → succès en attente',
    () async {
      stubCreate((_) async => _sup(BidSupplementStatus.commissionPending));
      final cubit = await ready();
      cubit.selectCommissionSource(SupplementCommissionSource.card);

      await authorizedSubmit(cubit);

      expect(cubit.state.status, SupplementRequestStatus.success);
      expect(
        cubit.state.created?.status,
        BidSupplementStatus.commissionPending,
      );
      expect(secrets, isEmpty);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.paymentSucceeded,
          properties: any(named: 'properties'),
        ),
      );
    },
  );

  test('ancien back : PROPOSED sans commissionStatus → pas de paiement '
      'tracé', () async {
    stubCreate((_) async => _sup(BidSupplementStatus.proposed));
    final cubit = await ready();

    await authorizedSubmit(cubit);

    expect(cubit.state.status, SupplementRequestStatus.success);
    verifyNever(
      () => analytics.logEvent(
        AnalyticsEvents.paymentSucceeded,
        properties: any(named: 'properties'),
      ),
    );
  });

  test('photo non envoyée : échec, rien de créé', () async {
    when(
      () => repository.uploadPhoto(any(), any()),
    ).thenThrow(const OfflineException());
    final cubit = await ready();

    await authorizedSubmit(cubit);

    expect(cubit.state.status, SupplementRequestStatus.failure);
    verifyNever(
      () => repository.create(
        any(),
        netAmount: any(named: 'netAmount'),
        reason: any(named: 'reason'),
        photoKey: any(named: 'photoKey'),
      ),
    );
  });

  group('vérification locale', () {
    test('refusée : retour à l\'état précédent, rien n\'est envoyé', () async {
      stubCreate((_) async => throw _unfundedError);
      final cubit = await ready();
      await authorizedSubmit(cubit);
      expect(cubit.state.status, SupplementRequestStatus.unfunded);

      expect(cubit.beginAuthorization(), isTrue);
      expect(cubit.state.status, SupplementRequestStatus.authorizing);
      expect(cubit.state.isBusy, isTrue);
      expect(cubit.state.canSubmit, isFalse);
      expect(cubit.beginAuthorization(), isFalse, reason: 'double tap');
      cubit.authorizationDenied();

      expect(cubit.state.status, SupplementRequestStatus.unfunded);
      expect(cubit.state.unfunded, isNotNull);
      cubit.authorizationDenied();
      expect(cubit.state.status, SupplementRequestStatus.unfunded);
    });

    test('formulaire figé : la source ne change pas', () async {
      final cubit = await ready();
      expect(cubit.beginAuthorization(), isTrue);
      cubit.selectCommissionSource(SupplementCommissionSource.card);
      expect(cubit.state.commissionSource, SupplementCommissionSource.wallet);
    });
  });
}
