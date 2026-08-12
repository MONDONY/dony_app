import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockKycRepository extends Mock implements KycRepository {}

void main() {
  late MockKycRepository mockRepo;

  setUp(() {
    mockRepo = MockKycRepository();
  });

  KycBloc buildBloc() {
    final backend = MockAnalyticsBackend();
    final analytics = makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return KycBloc(mockRepo, analytics);
  }

  // ── KycSessionRequested ──────────────────────────────────────────────────────

  group('KycSessionRequested', () {
    blocTest<KycBloc, KycState>(
      'emits [Loading, SessionCreated] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession()).thenAnswer(
          (_) async => {
            'stripeUrl': 'https://verify.stripe.com/session/test',
            'sessionId': 'sess_123',
          },
        );
      },
      act: (b) => b.add(const KycSessionRequested()),
      expect: () => [
        const KycLoading(),
        isA<KycSessionCreated>()
            .having(
              (s) => s.stripeUrl,
              'stripeUrl',
              'https://verify.stripe.com/session/test',
            )
            .having((s) => s.sessionId, 'sessionId', 'sess_123'),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Loading, Error] on generic exception',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.createSession(),
        ).thenThrow(Exception('network error'));
      },
      act: (b) => b.add(const KycSessionRequested()),
      expect: () => [const KycLoading(), isA<KycError>()],
    );

    blocTest<KycBloc, KycState>(
      'emits [Loading, Error with ConflictException] on DioException 409',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            error: const ConflictException('Identité déjà vérifiée'),
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
          (s) => s.error,
          'error',
          isA<ConflictException>(),
        ),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Loading, Error with ServerException] on DioException 503',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            error: const ServerException('Service indisponible'),
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
        isA<KycError>().having((s) => s.error, 'error', isA<ServerException>()),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Loading, Error with UnauthorizedException] on DioException 401',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createSession()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            error: const UnauthorizedException('Session expirée'),
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
          (s) => s.error,
          'error',
          isA<UnauthorizedException>(),
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
        when(() => mockRepo.getStatus()).thenAnswer(
          (_) async => {
            'kycStatus': 'VERIFIED',
            'verificationStatus': 'verified',
          },
        );
      },
      act: (b) => b.add(const KycStatusRefreshed()),
      expect: () => [
        isA<KycStatusLoaded>()
            .having((s) => s.kycStatus, 'kycStatus', 'VERIFIED')
            .having(
              (s) => s.verificationStatus,
              'verificationStatus',
              'verified',
            ),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Error] on generic exception',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getStatus()).thenThrow(Exception('timeout'));
      },
      act: (b) => b.add(const KycStatusRefreshed()),
      expect: () => [isA<KycError>()],
    );

    blocTest<KycBloc, KycState>(
      'emits [Error] wrapping raw exception containing 503',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getStatus(),
        ).thenThrow(Exception('HTTP 503 SERVICE_UNAVAILABLE'));
      },
      act: (b) => b.add(const KycStatusRefreshed()),
      expect: () => [
        isA<KycError>().having(
          (s) => s.error.message,
          'message',
          contains('503'),
        ),
      ],
    );

    blocTest<KycBloc, KycState>(
      'emits [Error] wrapping raw exception containing CONFLICT',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getStatus(),
        ).thenThrow(Exception('409 CONFLICT already exists'));
      },
      act: (b) => b.add(const KycStatusRefreshed()),
      expect: () => [
        isA<KycError>().having(
          (s) => s.error.message,
          'message',
          contains('CONFLICT'),
        ),
      ],
    );
  });
}
