import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

const _threadJson = <String, dynamic>{
  'id': 'th-1',
  'packageRequestId': 'pr-1',
  'travelerId': 'tr-1',
  'travelerAnnouncementId': null,
  'travelerTravelDate': '2026-06-15',
  'travelerAvailableKg': 10.0,
  'status': 'OPEN',
  'currentPriceEur': 30.0,
  'roundsCount': 1,
  'lastActivityAt': '2026-05-10T10:00:00Z',
  'createdAt': '2026-05-10T10:00:00Z',
  'messages': <dynamic>[],
  'paymentIntentClientSecret': null,
};

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late NegotiationRepository repo;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repo = NegotiationRepository(mockClient);
  });

  group('start', () {
    test('POSTs to /negotiations and returns NegotiationThread', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _ok(_threadJson, '/negotiations'));

      final thread = await repo.start(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30.0,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10.0,
      );

      expect(thread.id, 'th-1');
      expect(thread.status, NegotiationThreadStatus.open);
      expect(thread.currentPriceEur, 30.0);
    });

    test('sends createDedicatedTrip payload when provided', () async {
      Map<String, dynamic>? sentData;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        sentData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
        return _ok(_threadJson, '/negotiations');
      });

      await repo.start(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30.0,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10.0,
        createDedicatedTrip: true,
        dedicatedTripPayload: {
          'departureDate': '2026-06-15',
          'pickupAddress': {'label': 'Pickup', 'lat': 48.8, 'lng': 2.3},
          'deliveryAddress': {'label': 'Delivery', 'lat': 5.3, 'lng': -4.0},
          'useCardForCommission': false,
        },
      );

      expect(sentData?['createDedicatedTrip'], isTrue);
      expect(sentData?['dedicatedTrip'], isA<Map<String, dynamic>>());
    });

    test('defaults createDedicatedTrip to false and omits dedicatedTrip '
        'when not provided', () async {
      Map<String, dynamic>? sentData;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        sentData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
        return _ok(_threadJson, '/negotiations');
      });

      await repo.start(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30.0,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10.0,
      );

      expect(sentData?['createDedicatedTrip'], isFalse);
      expect(sentData?.containsKey('dedicatedTrip'), isFalse);
    });
  });

  group('findMine', () {
    test('GETs /negotiations/me and returns list of threads', () async {
      when(() => mockDio.get<List<dynamic>>('/negotiations/me')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          data: [_threadJson],
          statusCode: 200,
          requestOptions: RequestOptions(path: '/negotiations/me'),
        ),
      );

      final threads = await repo.findMine();

      expect(threads.length, 1);
      expect(threads.first.packageRequestId, 'pr-1');
    });
  });

  group('counter', () {
    test(
      'POSTs to /negotiations/:id/counter and returns updated thread',
      () async {
        final counterJson = {
          ..._threadJson,
          'currentPriceEur': 28.0,
          'roundsCount': 2,
        };

        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/negotiations/th-1/counter',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => _ok(counterJson, '/negotiations/th-1/counter'),
        );

        final thread = await repo.counter('th-1', proposedPriceEur: 28.0);

        expect(thread.currentPriceEur, 28.0);
        expect(thread.roundsCount, 2);
      },
    );
  });

  group('accept', () {
    test(
      'POSTs to /negotiations/:id/accept and returns accepted thread',
      () async {
        final acceptedJson = {
          ..._threadJson,
          'status': 'ACCEPTED',
          'paymentIntentClientSecret': 'pi_secret_123',
        };

        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/negotiations/th-1/accept',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => _ok(acceptedJson, '/negotiations/th-1/accept'),
        );

        final thread = await repo.accept('th-1');

        expect(thread.status, NegotiationThreadStatus.accepted);
        expect(thread.paymentIntentClientSecret, 'pi_secret_123');
      },
    );
  });

  group('reject', () {
    test('POSTs to /negotiations/:id/reject', () async {
      when(
        () => mockDio.post<void>(
          '/negotiations/th-1/reject',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(path: '/negotiations/th-1/reject'),
        ),
      );

      await expectLater(
        repo.reject('th-1', reason: 'Not convenient'),
        completes,
      );
    });
  });

  group('cancel', () {
    test('POSTs to /negotiations/:id/cancel', () async {
      when(
        () => mockDio.post<void>(
          '/negotiations/th-1/cancel',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(path: '/negotiations/th-1/cancel'),
        ),
      );

      await expectLater(
        repo.cancel('th-1', reason: 'Changed my mind'),
        completes,
      );
    });

    test('POSTs with no data when reason is null', () async {
      when(() => mockDio.post<void>('/negotiations/th-1/cancel')).thenAnswer(
        (_) async => Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(path: '/negotiations/th-1/cancel'),
        ),
      );

      await expectLater(repo.cancel('th-1'), completes);
    });
  });

  group('getById', () {
    test('GETs /negotiations/:id and returns NegotiationThread', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>('/negotiations/th-1'),
      ).thenAnswer((_) async => _ok(_threadJson, '/negotiations/th-1'));

      final thread = await repo.getById('th-1');
      expect(thread.id, 'th-1');
    });
  });

  group('submitTrip', () {
    test(
      'POSTs to /negotiations/:id/submit-trip and returns updated thread',
      () async {
        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/negotiations/th-1/submit-trip',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => _ok(_threadJson, '/negotiations/th-1/submit-trip'),
        );

        final thread = await repo.submitTrip(
          'th-1',
          travelerAnnouncementId: 'ann-1',
          paymentMethod: PaymentMethod.stripe,
        );
        expect(thread.id, 'th-1');
      },
    );

    test('sends useCardForCommission in the body', () async {
      Map<String, dynamic>? sentData;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/submit-trip',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        sentData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
        return _ok(_threadJson, '/negotiations/th-1/submit-trip');
      });

      await repo.submitTrip(
        'th-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.cash,
        useCardForCommission: true,
      );

      expect(sentData?['useCardForCommission'], true);
    });
  });

  group('createDedicatedTrip', () {
    test(
      'POSTs to /negotiations/:id/create-dedicated-trip and returns updated thread',
      () async {
        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/negotiations/th-1/create-dedicated-trip',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async =>
              _ok(_threadJson, '/negotiations/th-1/create-dedicated-trip'),
        );

        final thread = await repo.createDedicatedTrip(
          'th-1',
          departureDate: DateTime(2026, 7),
          pickupAddress: const {'label': 'Paris'},
          deliveryAddress: const {'label': 'Dakar'},
          paymentMethod: PaymentMethod.stripe,
        );
        expect(thread.id, 'th-1');
      },
    );

    test('sends useCardForCommission in the body', () async {
      Map<String, dynamic>? sentData;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/create-dedicated-trip',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        sentData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
        return _ok(_threadJson, '/negotiations/th-1/create-dedicated-trip');
      });

      await repo.createDedicatedTrip(
        'th-1',
        departureDate: DateTime(2026, 7),
        pickupAddress: const {'label': 'Paris'},
        deliveryAddress: const {'label': 'Dakar'},
        paymentMethod: PaymentMethod.cash,
        useCardForCommission: true,
      );

      expect(sentData?['useCardForCommission'], true);
    });

    test('defaults useCardForCommission to false in the body', () async {
      Map<String, dynamic>? sentData;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/create-dedicated-trip',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        sentData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
        return _ok(_threadJson, '/negotiations/th-1/create-dedicated-trip');
      });

      await repo.createDedicatedTrip(
        'th-1',
        departureDate: DateTime(2026, 7),
        pickupAddress: const {'label': 'Paris'},
        deliveryAddress: const {'label': 'Dakar'},
        paymentMethod: PaymentMethod.stripe,
      );

      expect(sentData?['useCardForCommission'], false);
    });
  });

  group('initiatePayment', () {
    test(
      'POSTs to /negotiations/:id/initiate-payment and returns secrets',
      () async {
        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/negotiations/th-1/initiate-payment',
          ),
        ).thenAnswer(
          (_) async => _ok({
            'clientSecret': 'pi_test_secret',
            'stripePaymentIntentId': 'pi_test_id',
            'amount': 45.0,
            'currency': 'CAD',
            'paymentMethodTypes': ['card', 'paypal'],
          }, '/negotiations/th-1/initiate-payment'),
        );

        final result = await repo.initiatePayment('th-1');
        expect(result.clientSecret, 'pi_test_secret');
        expect(result.paymentIntentId, 'pi_test_id');
        expect(result.amountEur, 45.0);
        expect(result.currencyCode, 'CAD');
        expect(result.paymentMethodTypes, ['card', 'paypal']);
      },
    );

    test('sends promoCode as query param when provided', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/initiate-payment',
          queryParameters: {'promoCode': 'WELCOME6'},
        ),
      ).thenAnswer(
        (_) async => _ok({
          'clientSecret': 'pi_test_secret',
          'stripePaymentIntentId': 'pi_test_id',
          'amount': 42.40,
          'paymentMethodTypes': ['card'],
        }, '/negotiations/th-1/initiate-payment'),
      );

      final result = await repo.initiatePayment('th-1', promoCode: 'WELCOME6');
      expect(result.amountEur, 42.40);
    });
  });

  group('quote', () {
    test('GETs /negotiations/:id/quote and returns NegotiationQuote', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>('/negotiations/th-1/quote'),
      ).thenAnswer(
        (_) async => _ok({
          'netEur': 40.0,
          'rate': 0.05,
          'commissionEur': 2.0,
          'totalEur': 42.0,
          'promoApplied': false,
          'promoLabel': null,
        }, '/negotiations/th-1/quote'),
      );

      final quote = await repo.quote('th-1');
      expect(quote.netEur, 40.0);
      expect(quote.rate, 0.05);
      expect(quote.commissionEur, 2.0);
      expect(quote.totalEur, 42.0);
      expect(quote.promoApplied, false);
      expect(quote.promoLabel, isNull);
    });

    test(
      'sends promoCode as query param and reflects an applied promo',
      () async {
        when(
          () => mockDio.get<Map<String, dynamic>>(
            '/negotiations/th-1/quote',
            queryParameters: {'promoCode': 'WELCOME6'},
          ),
        ).thenAnswer(
          (_) async => _ok({
            'netEur': 40.0,
            'rate': 0.12,
            'commissionEur': 4.80,
            'totalEur': 42.40,
            'promoApplied': true,
            'promoLabel': 'Code WELCOME6 : 6 % de réduction',
          }, '/negotiations/th-1/quote'),
        );

        final quote = await repo.quote('th-1', promoCode: 'WELCOME6');
        expect(quote.promoApplied, true);
        expect(quote.promoLabel, 'Code WELCOME6 : 6 % de réduction');
        expect(quote.totalEur, 42.40);
      },
    );
  });

  group('checkout', () {
    test('POSTs to /negotiations/:id/checkout and returns thread', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/checkout',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(_threadJson, '/negotiations/th-1/checkout'),
      );

      final thread = await repo.checkout('th-1', paymentIntentId: 'pi_test_id');
      expect(thread.id, 'th-1');
    });

    test('includes paymentMethod in the body when provided', () async {
      Map<String, dynamic>? sentData;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/checkout',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        sentData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
        return _ok(_threadJson, '/negotiations/th-1/checkout');
      });

      await repo.checkout(
        'th-1',
        paymentIntentId: 'CASH',
        paymentMethod: PaymentMethod.cash,
      );

      expect(sentData?['paymentIntentId'], 'CASH');
      expect(sentData?['paymentMethod'], PaymentMethod.cash.wireName);
    });

    test('omits paymentMethod from the body when not provided', () async {
      Map<String, dynamic>? sentData;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/checkout',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        sentData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
        return _ok(_threadJson, '/negotiations/th-1/checkout');
      });

      await repo.checkout('th-1', paymentIntentId: 'pi_test_id');

      expect(sentData?.containsKey('paymentMethod'), isFalse);
    });
  });

  group('refuseTrip', () {
    test('POSTs to /negotiations/:id/refuse-trip and returns thread', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/refuse-trip',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(_threadJson, '/negotiations/th-1/refuse-trip'),
      );

      final thread = await repo.refuseTrip('th-1', reason: 'Wrong date');
      expect(thread.id, 'th-1');
    });

    test(
      'POSTs to /negotiations/:id/refuse-trip with no data when reason is null',
      () async {
        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/negotiations/th-1/refuse-trip',
          ),
        ).thenAnswer(
          (_) async => _ok(_threadJson, '/negotiations/th-1/refuse-trip'),
        );

        final thread = await repo.refuseTrip('th-1');
        expect(thread.id, 'th-1');
      },
    );
  });

  group('nudge', () {
    test(
      'POSTs to /negotiations/:id/nudge and returns updated thread',
      () async {
        final nudgedJson = {..._threadJson, 'canNudge': false};

        when(
          () => mockDio.post<Map<String, dynamic>>('/negotiations/th-1/nudge'),
        ).thenAnswer((_) async => _ok(nudgedJson, '/negotiations/th-1/nudge'));

        final thread = await repo.nudge('th-1');
        expect(thread.id, 'th-1');
        expect(thread.canNudge, isFalse);
      },
    );
  });

  // ── settleCommission ─────────────────────────────────────────────────────────

  group('settleCommission', () {
    test('POSTs to /negotiations/:id/settle-commission and returns '
        'AcceptanceResponse on success (200 ACCEPTED)', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/settle-commission',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async =>
            _ok({'status': 'ACCEPTED'}, '/negotiations/th-1/settle-commission'),
      );

      final result = await repo.settleCommission('th-1');
      expect(result.status, AcceptanceStatus.accepted);
    });

    test('sends WALLET_FIRST commissionSource by default', () async {
      dynamic capturedQuery;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/settle-commission',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((inv) async {
        capturedQuery = inv.namedArguments[const Symbol('queryParameters')];
        return _ok({
          'status': 'ACCEPTED',
        }, '/negotiations/th-1/settle-commission');
      });

      await repo.settleCommission('th-1');

      expect((capturedQuery as Map)['commissionSource'], 'WALLET_FIRST');
    });

    test('forwards CARD commissionSource when specified', () async {
      dynamic capturedQuery;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/settle-commission',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((inv) async {
        capturedQuery = inv.namedArguments[const Symbol('queryParameters')];
        return _ok({
          'status': 'ACCEPTED',
        }, '/negotiations/th-1/settle-commission');
      });

      await repo.settleCommission('th-1', commissionSource: 'CARD');

      expect((capturedQuery as Map)['commissionSource'], 'CARD');
    });

    test(
      'parses 409 DioException body as insufficientWallet AcceptanceResponse '
      'with the amounts to display',
      () async {
        final insufficientJson = {
          'status': 'INSUFFICIENT_WALLET',
          'availableBalance': 1.0,
          'requiredCommission': 5.0,
          'hasCard': true,
          'currency': 'EUR',
        };
        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/negotiations/th-1/settle-commission',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(
              path: '/negotiations/th-1/settle-commission',
            ),
            response: Response(
              requestOptions: RequestOptions(
                path: '/negotiations/th-1/settle-commission',
              ),
              statusCode: 409,
              data: insufficientJson,
            ),
          ),
        );

        final result = await repo.settleCommission('th-1');
        expect(result.status, AcceptanceStatus.insufficientWallet);
        expect(result.availableBalance, 1.0);
        expect(result.requiredCommission, 5.0);
        expect(result.hasCard, isTrue);
        expect(result.currency, 'EUR');
      },
    );

    test('parses 422 DioException body as failed AcceptanceResponse', () async {
      final failedJson = {'status': 'FAILED', 'error': 'Carte refusée'};
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/settle-commission',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/negotiations/th-1/settle-commission',
          ),
          response: Response(
            requestOptions: RequestOptions(
              path: '/negotiations/th-1/settle-commission',
            ),
            statusCode: 422,
            data: failedJson,
          ),
        ),
      );

      final result = await repo.settleCommission('th-1');
      expect(result.status, AcceptanceStatus.failed);
      expect(result.error, 'Carte refusée');
    });

    test('rethrows a 409 race-guard RFC 7807 body cleanly instead of crashing '
        'or masking it as an AcceptanceResponse — plusieurs voyageurs peuvent '
        'régler en même temps, le corps porte un `status` NUMÉRIQUE (409, pas '
        "'INSUFFICIENT_WALLET') qui ne doit jamais atteindre "
        'AcceptanceResponse.fromJson', () async {
      final raceGuardJson = {
        'type': 'about:blank',
        'title': 'Conflict',
        'status': 409,
        'detail': 'La demande a déjà été acceptée par un autre voyageur.',
        'code': 'request/already-accepted',
      };
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/settle-commission',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/negotiations/th-1/settle-commission',
          ),
          response: Response(
            requestOptions: RequestOptions(
              path: '/negotiations/th-1/settle-commission',
            ),
            statusCode: 409,
            data: raceGuardJson,
          ),
        ),
      );

      await expectLater(
        repo.settleCommission('th-1'),
        throwsA(isA<DioException>()),
      );
    });

    test('rethrows DioException non-409-422', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/settle-commission',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/negotiations/th-1/settle-commission',
          ),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        repo.settleCommission('th-1'),
        throwsA(isA<DioException>()),
      );
    });
  });

  // ── confirmCommission ────────────────────────────────────────────────────────

  group('confirmCommission', () {
    test('POSTs to /negotiations/:id/confirm-commission and returns '
        'ConfirmResponse accepted on success', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/confirm-commission',
        ),
      ).thenAnswer(
        (_) async =>
            _ok({'accepted': true}, '/negotiations/th-1/confirm-commission'),
      );

      final result = await repo.confirmCommission('th-1');
      expect(result.accepted, isTrue);
    });

    test('parses 422 DioException body as ConfirmResponse when confirmation '
        'fails post-3DS', () async {
      final failedJson = {
        'accepted': false,
        'error': 'Confirmation refusée par la banque',
      };
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/confirm-commission',
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/negotiations/th-1/confirm-commission',
          ),
          response: Response(
            requestOptions: RequestOptions(
              path: '/negotiations/th-1/confirm-commission',
            ),
            statusCode: 422,
            data: failedJson,
          ),
        ),
      );

      final result = await repo.confirmCommission('th-1');
      expect(result.accepted, isFalse);
      expect(result.error, 'Confirmation refusée par la banque');
    });

    test('rethrows DioException non-422', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/confirm-commission',
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/negotiations/th-1/confirm-commission',
          ),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        repo.confirmCommission('th-1'),
        throwsA(isA<DioException>()),
      );
    });
  });

  // ── declineCommission ────────────────────────────────────────────────────────

  group('declineCommission', () {
    test('POSTs to /negotiations/:id/decline-commission', () async {
      when(
        () => mockDio.post<void>('/negotiations/th-1/decline-commission'),
      ).thenAnswer(
        (_) async => Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(
            path: '/negotiations/th-1/decline-commission',
          ),
        ),
      );

      await expectLater(repo.declineCommission('th-1'), completes);
    });
  });
}
