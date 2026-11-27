import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements KycRepository {}

class _MockReporter extends Mock implements ErrorReportingService {}

void main() {
  late _MockRepo repo;
  late _MockReporter reporter;

  setUp(() {
    repo = _MockRepo();
    reporter = _MockReporter();
    when(
      () => reporter.report(
        any(),
        operation: any(named: 'operation'),
        stackTrace: any(named: 'stackTrace'),
        context: any(named: 'context'),
      ),
    ).thenAnswer((_) async {});
  });

  KycBloc build() =>
      KycBloc(repo, makeDisabledAnalytics(MockAnalyticsBackend()), reporter);

  void verifyReported(String operation) => verify(
    () => reporter.report(
      any(),
      operation: operation,
      stackTrace: any(named: 'stackTrace'),
      context: {'feature': 'kyc'},
    ),
  ).called(1);

  blocTest<KycBloc, KycState>(
    'création de session : erreur hors réseau remontée à Sentry',
    build: () {
      when(() => repo.createSession()).thenThrow(StateError('json'));
      return build();
    },
    act: (b) => b.add(const KycSessionRequested()),
    expect: () => [const KycLoading(), isA<KycError>()],
    verify: (_) => verifyReported('kyc.create_session'),
  );

  blocTest<KycBloc, KycState>(
    'rafraîchissement du statut : erreur hors réseau remontée à Sentry',
    build: () {
      when(() => repo.getStatus()).thenThrow(StateError('json'));
      return build();
    },
    act: (b) => b.add(const KycStatusRefreshed()),
    expect: () => [isA<KycError>()],
    verify: (_) => verifyReported('kyc.refresh_status'),
  );

  group('abandon de session', () {
    blocTest<KycBloc, KycState>(
      'succès → appel au backend, aucun état émis',
      build: () {
        when(() => repo.abandonSession()).thenAnswer((_) async {});
        return build();
      },
      act: (b) => b.add(const KycSessionAbandoned()),
      expect: () => <KycState>[],
      verify: (_) {
        verify(() => repo.abandonSession()).called(1);
        verifyZeroInteractions(reporter);
      },
    );

    blocTest<KycBloc, KycState>(
      'erreur inattendue → silencieuse pour l’utilisateur, remontée à Sentry',
      build: () {
        when(() => repo.abandonSession()).thenThrow(StateError('boom'));
        return build();
      },
      act: (b) => b.add(const KycSessionAbandoned()),
      expect: () => <KycState>[],
      verify: (_) => verifyReported('kyc.abandon_session'),
    );

    blocTest<KycBloc, KycState>(
      'erreur réseau → silencieuse et non remontée (bruit attendu)',
      build: () {
        when(() => repo.abandonSession()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/kyc/session'),
            type: DioExceptionType.connectionError,
          ),
        );
        return build();
      },
      act: (b) => b.add(const KycSessionAbandoned()),
      expect: () => <KycState>[],
      verify: (_) => verifyZeroInteractions(reporter),
    );
  });

  group('raison d\u2019abandon', () {
    blocTest<KycBloc, KycState>(
      'succès \u2192 raison envoyée au backend, aucun \u00e9tat \u00e9mis',
      build: () {
        when(() => repo.sendAbandonReason(any())).thenAnswer((_) async {});
        return build();
      },
      act: (b) => b.add(const KycAbandonReasonSubmitted('TOO_LONG')),
      expect: () => <KycState>[],
      verify: (_) {
        verify(() => repo.sendAbandonReason('TOO_LONG')).called(1);
        verifyZeroInteractions(reporter);
      },
    );

    blocTest<KycBloc, KycState>(
      'erreur inattendue \u2192 silencieuse, remont\u00e9e \u00e0 Sentry',
      build: () {
        when(() => repo.sendAbandonReason(any())).thenThrow(StateError('x'));
        return build();
      },
      act: (b) => b.add(const KycAbandonReasonSubmitted('LATER')),
      expect: () => <KycState>[],
      verify: (_) => verifyReported('kyc.abandon_reason'),
    );

    blocTest<KycBloc, KycState>(
      'erreur r\u00e9seau \u2192 silencieuse et non remont\u00e9e',
      build: () {
        when(() => repo.sendAbandonReason(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/kyc/abandon-reason'),
            type: DioExceptionType.connectionError,
          ),
        );
        return build();
      },
      act: (b) => b.add(const KycAbandonReasonSubmitted('PRIVACY')),
      expect: () => <KycState>[],
      verify: (_) => verifyZeroInteractions(reporter),
    );
  });
}
