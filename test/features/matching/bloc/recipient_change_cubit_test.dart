import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBidRepository extends Mock implements BidRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

BidModel _bid({
  String status = 'IN_TRANSIT',
  String? recipientName = 'Fatou Sow',
  String? recipientPhone = '+221771234567',
}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  recipientName: recipientName,
  recipientPhone: recipientPhone,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late MockBidRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockBidRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  void stubChange(Future<BidModel> Function() answer) {
    when(
      () => repository.changeRecipient(
        any(),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
      ),
    ).thenAnswer((_) => answer());
  }

  group('submit', () {
    blocTest<RecipientChangeCubit, RecipientChangeState>(
      'nouveau numéro : envoie le numéro normalisé, succès avec phoneChanged',
      build: () {
        stubChange(() async => _bid(recipientPhone: '+221781112233'));
        return RecipientChangeCubit(repository, analytics);
      },
      act: (cubit) => cubit.submit(
        _bid(),
        name: '  Awa Ndiaye ',
        phone: '+221 78 111 22 33',
      ),
      expect: () => [
        isA<RecipientChangeSubmitting>(),
        isA<RecipientChangeSuccess>()
            .having((s) => s.phoneChanged, 'phoneChanged', isTrue)
            .having((s) => s.bid.recipientPhone, 'phone', '+221781112233'),
      ],
      verify: (_) {
        verify(
          () => repository.changeRecipient(
            'bid-1',
            recipientName: 'Awa Ndiaye',
            recipientPhone: '+221781112233',
          ),
        ).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.bidRecipientChanged,
            properties: {'phone_changed': true, 'status': 'IN_TRANSIT'},
          ),
        ).called(1);
      },
    );

    blocTest<RecipientChangeCubit, RecipientChangeState>(
      'même numéro écrit autrement : seul le nom change',
      build: () {
        stubChange(() async => _bid(recipientName: 'Fatou Diop'));
        return RecipientChangeCubit(repository, analytics);
      },
      act: (cubit) =>
          cubit.submit(_bid(), name: 'Fatou Diop', phone: '00221 77 123 45 67'),
      expect: () => [
        isA<RecipientChangeSubmitting>(),
        isA<RecipientChangeSuccess>().having(
          (s) => s.phoneChanged,
          'phoneChanged',
          isFalse,
        ),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidRecipientChanged,
          properties: {'phone_changed': false, 'status': 'IN_TRANSIT'},
        ),
      ).called(1),
    );

    blocTest<RecipientChangeCubit, RecipientChangeState>(
      '409 : conflit, aucun événement analytics',
      build: () {
        stubChange(
          () async =>
              throw const ConflictException('recipient-change-not-allowed'),
        );
        return RecipientChangeCubit(repository, analytics);
      },
      act: (cubit) => cubit.submit(_bid(), name: 'Awa', phone: '+221781112233'),
      expect: () => [
        isA<RecipientChangeSubmitting>(),
        isA<RecipientChangeConflict>(),
      ],
      verify: (_) => verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ),
    );

    blocTest<RecipientChangeCubit, RecipientChangeState>(
      'autre erreur : échec avec l\'erreur déballée',
      build: () {
        stubChange(
          () async => throw DioException(
            requestOptions: RequestOptions(path: '/bids/bid-1/recipient'),
            type: DioExceptionType.connectionError,
          ),
        );
        return RecipientChangeCubit(repository, analytics);
      },
      act: (cubit) => cubit.submit(_bid(), name: 'Awa', phone: '+221781112233'),
      expect: () => [
        isA<RecipientChangeSubmitting>(),
        isA<RecipientChangeFailure>().having(
          (s) => s.error,
          'error',
          isA<OfflineException>(),
        ),
      ],
    );

    test('un second envoi pendant le premier est ignoré', () async {
      final completer = Completer<BidModel>();
      stubChange(() => completer.future);
      final cubit = RecipientChangeCubit(repository, analytics);

      final first = cubit.submit(_bid(), name: 'Awa', phone: '+221781112233');
      await cubit.submit(_bid(), name: 'Awa', phone: '+221781112233');
      completer.complete(_bid());
      await first;

      verify(
        () => repository.changeRecipient(
          any(),
          recipientName: any(named: 'recipientName'),
          recipientPhone: any(named: 'recipientPhone'),
        ),
      ).called(1);
      await cubit.close();
    });

    test('cubit fermé pendant l\'appel : aucun état émis', () async {
      final completer = Completer<BidModel>();
      stubChange(() => completer.future);
      final cubit = RecipientChangeCubit(repository, analytics);

      final pending = cubit.submit(_bid(), name: 'Awa', phone: '+221781112233');
      await cubit.close();
      completer.complete(_bid());
      await pending;

      expect(cubit.state, isA<RecipientChangeSubmitting>());
    });
  });

  group('isPhoneChanged', () {
    test('compare après normalisation', () {
      expect(
        RecipientChangeCubit.isPhoneChanged(_bid(), '+221 77 123 45 67'),
        isFalse,
      );
      expect(
        RecipientChangeCubit.isPhoneChanged(_bid(), '+221781112233'),
        isTrue,
      );
      expect(
        RecipientChangeCubit.isPhoneChanged(
          _bid(recipientPhone: null),
          '+221781112233',
        ),
        isTrue,
      );
    });
  });

  group('normalizeRecipientPhone', () {
    test('retire espaces, tirets, points et parenthèses', () {
      expect(normalizeRecipientPhone(' +221 (77) 123-45.67 '), '+221771234567');
    });

    test('remplace le préfixe 00 par +', () {
      expect(normalizeRecipientPhone('0033612345678'), '+33612345678');
    });

    test('laisse un numéro déjà propre', () {
      expect(normalizeRecipientPhone('+221771234567'), '+221771234567');
    });
  });
}
