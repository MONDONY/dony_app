import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/media_service.dart';
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

BidModel _bid({BidPaymentMethod paymentMethod = BidPaymentMethod.stripe}) =>
    BidModel(
      id: 'bid-1',
      announcementId: 'ann-1',
      senderId: 'sender-1',
      status: 'ACCEPTED',
      paymentMethod: paymentMethod,
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
    );

const _phone = SupplementSuggestion(
  kind: SupplementSuggestion.kindGridItem,
  label: 'Téléphone',
  unitNet: 15,
);
const _kg = SupplementSuggestion(kind: SupplementSuggestion.kindKg, unitNet: 8);
const _options = SupplementOptions(
  currency: 'EUR',
  minNet: 1,
  maxNet: 300,
  suggestions: [_phone, _kg],
  rail: 'STRIPE',
);
const _quote = SupplementQuote(
  netAmount: 15,
  commissionAmount: 1.8,
  grossAmount: 16.8,
  currency: 'EUR',
);
const _created = BidSupplement(
  id: 'sup-1',
  status: BidSupplementStatus.proposed,
  grossAmount: 16.8,
  blocksHandover: true,
);

void main() {
  late _MockRepository repository;
  late _MockMediaService media;
  late _MockAnalyticsService analytics;

  setUpAll(() {
    registerFallbackValue(ImageSource.camera);
    registerFallbackValue(BidSupplementReason.other);
  });

  setUp(() {
    repository = _MockRepository();
    media = _MockMediaService();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repository.options(any())).thenAnswer((_) async => _options);
    when(() => repository.quote(any(), any())).thenAnswer((_) async => _quote);
    when(
      () => repository.uploadPhoto(any(), any()),
    ).thenAnswer((_) async => 'tracking/bid-1/supplement.jpg');
  });

  SupplementRequestCubit build() => SupplementRequestCubit(
    repository,
    media,
    analytics,
    quoteDebounce: Duration.zero,
  );

  void stubCreate(Future<BidSupplement> Function() answer) => when(
    () => repository.create(
      any(),
      netAmount: any(named: 'netAmount'),
      reason: any(named: 'reason'),
      reasonText: any(named: 'reasonText'),
      gridItemLabel: any(named: 'gridItemLabel'),
      photoKey: any(named: 'photoKey'),
    ),
  ).thenAnswer((_) => answer());

  /// Cubit chargé, suggestion « Téléphone » choisie, photo prise.
  Future<SupplementRequestCubit> ready() async {
    when(
      () => media.pick(source: any(named: 'source')),
    ).thenAnswer((_) async => XFile('/tmp/supplement.jpg'));
    final cubit = build();
    await cubit.load(_bid());
    cubit.selectSuggestion(_phone);
    await cubit.takePhoto();
    return cubit;
  }

  group('parseSupplementAmount', () {
    test('virgule, point, espaces et montants invalides', () {
      expect(parseSupplementAmount('15'), 15);
      expect(parseSupplementAmount('15,5'), 15.5);
      expect(parseSupplementAmount('1 500'), 1500);
      expect(parseSupplementAmount(' 2 000 '), 2000);
      expect(parseSupplementAmount(''), isNull);
      expect(parseSupplementAmount('abc'), isNull);
      expect(parseSupplementAmount('0'), isNull);
      expect(parseSupplementAmount('-3'), isNull);
    });
  });

  group('SupplementRequestState', () {
    test('canSubmit exige montant dans les bornes, motif et photo', () {
      const base = SupplementRequestState(
        status: SupplementRequestStatus.editing,
        options: _options,
        amount: 15,
        reason: BidSupplementReason.extraWeight,
        photoPath: '/tmp/p.jpg',
      );
      expect(base.canSubmit, isTrue);
      expect(base.copyWith(amount: () => 301).canSubmit, isFalse);
      expect(base.copyWith(amount: () => 301).amountOutOfRange, isTrue);
      expect(base.copyWith(amount: () => null).canSubmit, isFalse);
      expect(base.copyWith(amount: () => null).amountOutOfRange, isFalse);
      expect(base.copyWith(photoPath: () => null).canSubmit, isFalse);
      expect(
        base.copyWith(reason: BidSupplementReason.other).canSubmit,
        isFalse,
        reason: '« Autre » exige un détail',
      );
      expect(
        base
            .copyWith(reason: BidSupplementReason.other, reasonText: 'Lourd')
            .canSubmit,
        isTrue,
      );
      expect(
        base.copyWith(status: SupplementRequestStatus.submitting).canSubmit,
        isFalse,
      );
      expect(
        const SupplementRequestState(
          status: SupplementRequestStatus.loadFailed,
          amount: 15,
          reason: BidSupplementReason.extraWeight,
          photoPath: '/tmp/p.jpg',
        ).canSubmit,
        isFalse,
      );
    });
  });

  group('load', () {
    blocTest<SupplementRequestCubit, SupplementRequestState>(
      'charge les options et trace l\'ouverture',
      build: build,
      act: (c) => c.load(_bid(paymentMethod: BidPaymentMethod.mobileMoney)),
      expect: () => [
        isA<SupplementRequestState>().having(
          (s) => s.status,
          'status',
          SupplementRequestStatus.loading,
        ),
        isA<SupplementRequestState>()
            .having((s) => s.status, 'status', SupplementRequestStatus.editing)
            .having((s) => s.options, 'options', _options),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementSheetOpened,
          properties: {'payment_method': 'mobileMoney', 'status': 'ACCEPTED'},
        ),
      ).called(1),
    );

    blocTest<SupplementRequestCubit, SupplementRequestState>(
      'échec du chargement : loadFailed avec l\'erreur',
      setUp: () => when(
        () => repository.options(any()),
      ).thenThrow(const OfflineException()),
      build: build,
      act: (c) => c.load(_bid()),
      skip: 1,
      expect: () => [
        isA<SupplementRequestState>()
            .having(
              (s) => s.status,
              'status',
              SupplementRequestStatus.loadFailed,
            )
            .having((s) => s.error, 'error', isA<OfflineException>()),
      ],
    );
  });

  group('montant et devis', () {
    test('une suggestion fixe le montant, le motif, puis le devis', () async {
      final cubit = build();
      await cubit.load(_bid());

      cubit.selectSuggestion(_kg);
      expect(cubit.state.amount, 8);
      expect(cubit.state.reason, BidSupplementReason.extraWeight);
      expect(cubit.state.suggestion, _kg);

      cubit.selectSuggestion(_phone);
      expect(cubit.state.reason, BidSupplementReason.gridItem);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.quote, _quote);
      verify(() => repository.quote('bid-1', 15)).called(1);
      await cubit.close();
    });

    test(
      'saisir le montant de la suggestion la garde, un autre la retire',
      () async {
        final cubit = build();
        await cubit.load(_bid());
        cubit.selectSuggestion(_phone);

        cubit.amountChanged('15,00');
        expect(cubit.state.suggestion, _phone);

        cubit.amountChanged('20');
        expect(cubit.state.amount, 20);
        expect(cubit.state.suggestion, isNull);
        expect(cubit.state.reason, BidSupplementReason.gridItem);
        await cubit.close();
      },
    );

    test('hors bornes : aucun devis demandé', () async {
      final cubit = build();
      await cubit.load(_bid());

      cubit.amountChanged('500');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.amountOutOfRange, isTrue);
      expect(cubit.state.quote, isNull);
      verifyNever(() => repository.quote(any(), any()));
      await cubit.close();
    });

    test('un devis en échec est ignoré', () async {
      when(
        () => repository.quote(any(), any()),
      ).thenThrow(const OfflineException());
      final cubit = build();
      await cubit.load(_bid());

      cubit.amountChanged('12');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.quote, isNull);
      expect(cubit.state.status, SupplementRequestStatus.editing);
      await cubit.close();
    });

    test('un devis périmé par une frappe plus récente est ignoré', () async {
      final cubit = SupplementRequestCubit(
        repository,
        media,
        analytics,
        quoteDebounce: const Duration(milliseconds: 20),
      );
      await cubit.load(_bid());

      cubit.amountChanged('12');
      cubit.amountChanged('13');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      verify(() => repository.quote('bid-1', 13)).called(1);
      verifyNever(() => repository.quote('bid-1', 12));
      await cubit.close();
    });

    test('motif et détail', () async {
      final cubit = build();
      cubit.selectReason(BidSupplementReason.other);
      cubit.reasonTextChanged('Deux colis au lieu d\'un');
      expect(cubit.state.reason, BidSupplementReason.other);
      expect(cubit.state.reasonText, 'Deux colis au lieu d\'un');
      await cubit.close();
    });
  });

  group('photo', () {
    test('prise puis retirée', () async {
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => XFile('/tmp/a.jpg'));
      final cubit = build();

      await cubit.takePhoto();
      expect(cubit.state.photoPath, '/tmp/a.jpg');

      cubit.removePhoto();
      expect(cubit.state.photoPath, isNull);
      await cubit.close();
    });

    test('annulée : rien ne change', () async {
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => null);
      final cubit = build();

      await cubit.takePhoto();
      expect(cubit.state.photoPath, isNull);
      await cubit.close();
    });

    test('illisible : photoFailed', () async {
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenThrow(Exception('boom'));
      final cubit = build();

      await cubit.takePhoto();
      expect(cubit.state.status, SupplementRequestStatus.photoFailed);
      await cubit.close();
    });

    test('pendant un chargement raté, la saisie garde loadFailed', () async {
      when(() => repository.options(any())).thenThrow(const OfflineException());
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => XFile('/tmp/a.jpg'));
      final cubit = build();
      await cubit.load(_bid());

      await cubit.takePhoto();
      expect(cubit.state.status, SupplementRequestStatus.loadFailed);
      await cubit.close();
    });
  });

  group('submit', () {
    test('envoie la photo puis la demande, et trace la réussite', () async {
      stubCreate(() async => _created);
      final cubit = await ready();
      cubit.reasonTextChanged('  Un iPhone  ');

      await cubit.submit();

      expect(cubit.state.status, SupplementRequestStatus.success);
      expect(cubit.state.created, _created);
      verify(() => repository.uploadPhoto('bid-1', '/tmp/supplement.jpg'));
      verify(
        () => repository.create(
          'bid-1',
          netAmount: 15,
          reason: BidSupplementReason.gridItem,
          reasonText: 'Un iPhone',
          gridItemLabel: 'Téléphone',
          photoKey: 'tracking/bid-1/supplement.jpg',
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementRequested,
          properties: {
            'reason': 'grid_item',
            'suggestion': 'grid_item',
            'amount_bracket': '<20',
            'currency': 'EUR',
            'payment_method': 'stripe',
          },
        ),
      ).called(1);
      await cubit.close();
    });

    test('montant saisi : suggestion custom, sans article', () async {
      stubCreate(() async => _created);
      final cubit = await ready();
      cubit.amountChanged('60');
      cubit.selectReason(BidSupplementReason.extraWeight);

      await cubit.submit();

      verify(
        () => repository.create(
          'bid-1',
          netAmount: 60,
          reason: BidSupplementReason.extraWeight,
          photoKey: any(named: 'photoKey'),
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementRequested,
          properties: any(
            named: 'properties',
            that: allOf(
              containsPair('suggestion', 'custom'),
              containsPair('amount_bracket', '50-100'),
            ),
          ),
        ),
      ).called(1);
      await cubit.close();
    });

    test('détail rogné à 500 caractères', () async {
      stubCreate(() async => _created);
      final cubit = await ready();
      cubit.reasonTextChanged('a' * 600);

      await cubit.submit();

      final text =
          verify(
                () => repository.create(
                  any(),
                  netAmount: any(named: 'netAmount'),
                  reason: any(named: 'reason'),
                  reasonText: captureAny(named: 'reasonText'),
                  gridItemLabel: any(named: 'gridItemLabel'),
                  photoKey: any(named: 'photoKey'),
                ),
              ).captured.single
              as String;
      expect(text.length, kSupplementReasonTextMaxLength);
      await cubit.close();
    });

    test('échec réseau : failure, photo gardée pour le nouvel essai', () async {
      stubCreate(() async => throw const OfflineException());
      final cubit = await ready();

      await cubit.submit();

      expect(cubit.state.status, SupplementRequestStatus.failure);
      expect(cubit.state.photoKey, 'tracking/bid-1/supplement.jpg');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementRequestFailed,
          properties: {'reason': 'grid_item', 'error_code': 'OFFLINE'},
        ),
      ).called(1);

      stubCreate(() async => _created);
      await cubit.submit();
      expect(cubit.state.status, SupplementRequestStatus.success);
      verify(() => repository.uploadPhoto(any(), any())).called(1);
      await cubit.close();
    });

    test('demande devenue impossible : closed', () async {
      stubCreate(
        () async =>
            throw const ConflictException('locked', code: 'supplement-locked'),
      );
      final cubit = await ready();

      await cubit.submit();

      expect(cubit.state.status, SupplementRequestStatus.closed);
      expect(cubit.state.error?.code, 'supplement-locked');
      await cubit.close();
    });

    test(
      'montant refusé par le serveur : failure, formulaire ouvert',
      () async {
        stubCreate(
          () async => throw const ValidationException(
            'range',
            code: 'supplement-amount-out-of-range',
          ),
        );
        final cubit = await ready();

        await cubit.submit();

        expect(cubit.state.status, SupplementRequestStatus.failure);
        await cubit.close();
      },
    );

    test('échec sans code : error_code unknown', () async {
      stubCreate(() async => throw StateError('boom'));
      final cubit = await ready();

      await cubit.submit();

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementRequestFailed,
          properties: any(
            named: 'properties',
            that: containsPair('error_code', isNotNull),
          ),
        ),
      ).called(1);
      await cubit.close();
    });

    test('formulaire incomplet : rien n\'est envoyé', () async {
      final cubit = build();
      await cubit.load(_bid());

      await cubit.submit();

      verifyNever(() => repository.uploadPhoto(any(), any()));
      await cubit.close();
    });

    test('sans chargement : rien n\'est envoyé', () async {
      final cubit = build();
      await cubit.submit();
      verifyNever(() => repository.uploadPhoto(any(), any()));
      await cubit.close();
    });
  });
}
