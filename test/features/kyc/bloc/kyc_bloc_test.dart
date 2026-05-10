import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockKycRepository extends Mock implements KycRepository {}

void main() {
  late MockKycRepository mockRepo;

  setUp(() {
    mockRepo = MockKycRepository();
  });

  KycBloc buildBloc() => KycBloc(mockRepo);

  // ── KycSessionRequested ──────────────────────────────────────────────────────

  group('KycSessionRequested', () {
    blocTest<KycBloc, KycState>(
      'emits [Loading, SessionCreated] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession()).thenAnswer((_) async => {
              'stripeUrl': 'https://verify.stripe.com/session/test',
              'sessionId': 'sess_123',
            });
      },
      act: (b) => b.add(const KycSessionRequested()),
      expect: () => [
        const KycLoading(),
        isA<KycSessionCreated>()
            .having((s) => s.stripeUrl, 'stripeUrl',
                'https://verify.stripe.com/session/test')
            .having((s) => s.sessionId, 'sessionId', 'sess_123'),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Loading, Error] on generic exception',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession())
            .thenThrow(Exception('network error'));
      },
      act: (b) => b.add(const KycSessionRequested()),
      expect: () => [
        const KycLoading(),
        isA<KycError>(),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Loading, Error with conflict message] on DioException 409',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: 409,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(const KycSessionRequested()),
      expect: () => [
        const KycLoading(),
        isA<KycError>().having(
          (s) => s.error.message,
          'message',
          contains('déjà vérifiée'),
        ),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Loading, Error with unavailable message] on DioException 503',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: 503,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(const KycSessionRequested()),
      expect: () => [
        const KycLoading(),
        isA<KycError>().having(
          (s) => s.error.message,
          'message',
          contains('indisponible'),
        ),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Loading, Error with session message] on DioException 401',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(const KycSessionRequested()),
      expect: () => [
        const KycLoading(),
        isA<KycError>().having(
          (s) => s.error.message,
          'message',
          contains('Session expirée'),
        ),
      ],
    );
  });

  // ── KycStatusRefreshed ───────────────────────────────────────────────────────

  group('KycStatusRefreshed', () {
    blocTest<KycBloc, KycState>(
      'emits [StatusLoaded] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getStatus()).thenAnswer((_) async => {
              'kycStatus': 'VERIFIED',
              'verificationStatus': 'verified',
            });
      },
      act: (b) => b.add(const KycStatusRefreshed()),
      expect: () => [
        isA<KycStatusLoaded>()
            .having((s) => s.kycStatus, 'kycStatus', 'VERIFIED')
            .having((s) => s.verificationStatus, 'verificationStatus',
                'verified'),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Error] on generic exception',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getStatus()).thenThrow(Exception('timeout'));
      },
      act: (b) => b.add(const KycStatusRefreshed()),
      expect: () => [
        isA<KycError>(),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Error with unavailable] on string containing 503',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getStatus())
            .thenThrow(Exception('HTTP 503 SERVICE_UNAVAILABLE'));
      },
      act: (b) => b.add(const KycStatusRefreshed()),
      expect: () => [
        isA<KycError>().having(
          (s) => s.error.message,
          'message',
          contains('indisponible'),
        ),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Error with already verified] on string containing CONFLICT',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getStatus())
            .thenThrow(Exception('409 CONFLICT already exists'));
      },
      act: (b) => b.add(const KycStatusRefreshed()),
      expect: () => [
        isA<KycError>().having(
          (s) => s.error.message,
          'message',
          contains('déjà vérifiée'),
        ),
      ],
    );
  });
}
