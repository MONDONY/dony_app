import 'dart:async' hide TimeoutException;

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/config/cancellation_fee_flag.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_config/cancellation_fee_config_cubit.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CancellationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _t0 = DateTime.utc(2026, 12, 20, 10);

final _active = CancellationFeeConfigModel(
  effectiveFrom: DateTime.utc(2026, 12, 15),
  capEur: 30,
);

DioException _dio(AppException error) => DioException(
  requestOptions: RequestOptions(path: '/config/cancellation-fee'),
  type: DioExceptionType.badResponse,
  error: error,
);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  late DateTime now;

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    now = _t0;
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  tearDown(resetCancellationFeeFlagForTest);

  CancellationFeeConfigCubit build({Duration? timeout}) =>
      CancellationFeeConfigCubit(
        repo,
        analytics,
        clock: () => now,
        timeout: timeout ?? CancellationFeeConfigCubit.defaultTimeout,
      );

  void verifyFailure(String code) => verify(
    () => analytics.logEvent(
      AnalyticsEvents.cancellationFeeConfigFailed,
      properties: {'error_code': code},
    ),
  ).called(1);

  group('états', () {
    test('initial : rien de lu, configuration éteinte', () {
      final cubit = build();
      expect(cubit.state, const CancellationFeeConfigInitial());
      expect(cubit.state.config, CancellationFeeConfigModel.inactive);
      cubit.close();
    });

    test('lecture : garde la configuration précédente', () {
      expect(CancellationFeeConfigLoading(_active).config, _active);
    });

    test('indisponible : configuration éteinte', () {
      expect(
        CancellationFeeConfigUnavailable(failedAt: _t0).config,
        CancellationFeeConfigModel.inactive,
      );
    });
  });

  group('ensureLoaded', () {
    blocTest<CancellationFeeConfigCubit, CancellationFeeConfigState>(
      'frais allumés : lecture puis configuration allumée, drapeau levé',
      setUp: () => when(repo.getFeeConfig).thenAnswer((_) async => _active),
      build: build,
      act: (c) => c.ensureLoaded(),
      expect: () => [
        const CancellationFeeConfigLoading(CancellationFeeConfigModel.inactive),
        CancellationFeeConfigLoaded(_active, fetchedAt: _t0),
      ],
      verify: (c) {
        expect(c.state.config.active, isTrue);
        expect(cancellationFeeActive, isTrue);
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );

    blocTest<CancellationFeeConfigCubit, CancellationFeeConfigState>(
      'frais éteints : configuration éteinte, drapeau baissé',
      setUp: () => when(
        repo.getFeeConfig,
      ).thenAnswer((_) async => CancellationFeeConfigModel.inactive),
      build: build,
      act: (c) => c.ensureLoaded(),
      expect: () => [
        const CancellationFeeConfigLoading(CancellationFeeConfigModel.inactive),
        CancellationFeeConfigLoaded(
          CancellationFeeConfigModel.inactive,
          fetchedAt: _t0,
        ),
      ],
      verify: (_) => expect(cancellationFeeActive, isFalse),
    );

    blocTest<CancellationFeeConfigCubit, CancellationFeeConfigState>(
      '404 (back antérieur) : éteint, jamais signalé',
      setUp: () =>
          when(repo.getFeeConfig).thenThrow(_dio(const NotFoundException())),
      build: build,
      act: (c) => c.ensureLoaded(),
      expect: () => [
        const CancellationFeeConfigLoading(CancellationFeeConfigModel.inactive),
        CancellationFeeConfigUnavailable(failedAt: _t0),
      ],
      verify: (c) {
        expect(c.state.config, CancellationFeeConfigModel.inactive);
        expect(cancellationFeeActive, isFalse);
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );

    for (final (label, Object error, code) in [
      ('hors ligne', _dio(const OfflineException()), 'OFFLINE'),
      ('serveur', _dio(const ServerException()), 'SERVER_ERROR'),
      ('corps illisible', const FormatException('x'), 'invalid_payload'),
      ('erreur sans code', StateError('x'), 'unknown'),
    ]) {
      blocTest<CancellationFeeConfigCubit, CancellationFeeConfigState>(
        'échec ($label) : éteint, signalé avec son code',
        setUp: () => when(repo.getFeeConfig).thenThrow(error),
        build: build,
        act: (c) => c.ensureLoaded(),
        expect: () => [
          const CancellationFeeConfigLoading(
            CancellationFeeConfigModel.inactive,
          ),
          CancellationFeeConfigUnavailable(failedAt: _t0),
        ],
        verify: (_) => verifyFailure(code),
      );
    }

    blocTest<CancellationFeeConfigCubit, CancellationFeeConfigState>(
      'réponse trop lente : abandon au délai, éteint, TIMEOUT',
      setUp: () => when(
        repo.getFeeConfig,
      ).thenAnswer((_) => Completer<CancellationFeeConfigModel>().future),
      build: () => build(timeout: const Duration(milliseconds: 20)),
      act: (c) => c.ensureLoaded(),
      wait: const Duration(milliseconds: 60),
      expect: () => [
        const CancellationFeeConfigLoading(CancellationFeeConfigModel.inactive),
        CancellationFeeConfigUnavailable(failedAt: _t0),
      ],
      verify: (_) => verifyFailure('TIMEOUT'),
    );
  });

  group('cache de session', () {
    test('une seule lecture tant que la configuration est fraîche', () async {
      when(repo.getFeeConfig).thenAnswer((_) async => _active);
      final cubit = build();

      await cubit.ensureLoaded();
      now = _t0.add(const Duration(minutes: 29));
      await cubit.ensureLoaded();
      await cubit.ensureLoaded();

      verify(repo.getFeeConfig).called(1);
      expect(cubit.state.config, _active);
      await cubit.close();
    });

    test('une seule lecture à la fois : les appels simultanés partagent la '
        'même', () async {
      final pending = Completer<CancellationFeeConfigModel>();
      when(repo.getFeeConfig).thenAnswer((_) => pending.future);
      final cubit = build();

      final a = cubit.ensureLoaded();
      final b = cubit.ensureLoaded();
      pending.complete(_active);
      await Future.wait([a, b]);

      verify(repo.getFeeConfig).called(1);
      expect(cubit.state.config, _active);
      await cubit.close();
    });

    test('relue passé refreshAfter, sans repasser par une configuration '
        'éteinte', () async {
      when(repo.getFeeConfig).thenAnswer((_) async => _active);
      final cubit = build();
      await cubit.ensureLoaded();

      now = _t0.add(CancellationFeeConfigCubit.refreshAfter);
      final states = <CancellationFeeConfigState>[];
      final sub = cubit.stream.listen(states.add);
      await cubit.ensureLoaded();
      await sub.cancel();

      verify(repo.getFeeConfig).called(2);
      expect(states.map((s) => s.config), everyElement(_active));
      expect(cubit.state, CancellationFeeConfigLoaded(_active, fetchedAt: now));
      await cubit.close();
    });

    test('relecture ratée : la configuration lue est gardée', () async {
      when(repo.getFeeConfig).thenAnswer((_) async => _active);
      final cubit = build();
      await cubit.ensureLoaded();

      when(repo.getFeeConfig).thenThrow(_dio(const OfflineException()));
      now = _t0.add(CancellationFeeConfigCubit.refreshAfter);
      await cubit.ensureLoaded();

      expect(cubit.state, CancellationFeeConfigLoaded(_active, fetchedAt: _t0));
      expect(cancellationFeeActive, isTrue);
      verifyFailure('OFFLINE');
      await cubit.close();
    });

    test('échec : nouvel essai seulement passé retryAfter', () async {
      when(repo.getFeeConfig).thenThrow(_dio(const OfflineException()));
      final cubit = build();
      await cubit.ensureLoaded();

      now = _t0.add(const Duration(seconds: 59));
      await cubit.ensureLoaded();
      verify(repo.getFeeConfig).called(1);

      when(repo.getFeeConfig).thenAnswer((_) async => _active);
      now = _t0.add(CancellationFeeConfigCubit.retryAfter);
      await cubit.ensureLoaded();

      verify(repo.getFeeConfig).called(1);
      expect(cubit.state.config, _active);
      await cubit.close();
    });

    test('404 : réinterrogé seulement passé refreshAfter', () async {
      when(repo.getFeeConfig).thenThrow(_dio(const NotFoundException()));
      final cubit = build();
      await cubit.ensureLoaded();

      now = _t0.add(const Duration(minutes: 10));
      await cubit.ensureLoaded();
      verify(repo.getFeeConfig).called(1);

      now = _t0.add(CancellationFeeConfigCubit.refreshAfter);
      await cubit.ensureLoaded();
      verify(repo.getFeeConfig).called(1);
      await cubit.close();
    });

    test('fermé pendant la lecture : rien n\'est émis', () async {
      final pending = Completer<CancellationFeeConfigModel>();
      when(repo.getFeeConfig).thenAnswer((_) => pending.future);
      final cubit = build();

      final future = cubit.ensureLoaded();
      await cubit.close();
      pending.complete(_active);
      await future;

      expect(cubit.state, isA<CancellationFeeConfigLoading>());
      expect(cubit.ensureLoaded(), completes);
    });

    test('fermé pendant une lecture qui échoue : rien n\'est émis', () async {
      final pending = Completer<CancellationFeeConfigModel>();
      when(repo.getFeeConfig).thenAnswer((_) => pending.future);
      final cubit = build();

      final future = cubit.ensureLoaded();
      await cubit.close();
      pending.completeError(_dio(const OfflineException()));
      await future;

      expect(cubit.state, isA<CancellationFeeConfigLoading>());
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    });
  });
}
