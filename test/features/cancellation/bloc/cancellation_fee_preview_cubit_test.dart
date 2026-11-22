import 'dart:async' hide TimeoutException;

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_preview/cancellation_fee_preview_cubit.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_preview_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CancellationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _t0 = DateTime.utc(2026, 12, 4, 10);

CancellationFeePreviewModel _preview({
  double fee = 20,
  double refund = 80,
  double rate = 0.2,
  DateTime? nextTierAt,
}) => CancellationFeePreviewModel(
  rate: rate,
  fee: fee,
  refundAmount: refund,
  currency: 'EUR',
  nextTierAt: nextTierAt,
);

DioException _dio(AppException error) => DioException(
  requestOptions: RequestOptions(path: '/x'),
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

  CancellationFeePreviewCubit build({Duration? timeout}) =>
      CancellationFeePreviewCubit(
        repo,
        analytics,
        clock: () => now,
        timeout: timeout ?? CancellationFeePreviewCubit.defaultTimeout,
      );

  void verifyFailure(String code, {String stage = 'load'}) => verify(
    () => analytics.logEvent(
      AnalyticsEvents.cancellationFeePreviewFailed,
      properties: {'error_code': code, 'stage': stage},
    ),
  ).called(1);

  group('états', () {
    test('initial : lecture en cours, bouton en attente, aucun frais', () {
      final cubit = build();
      expect(cubit.state, const CancellationFeePreviewLoading());
      expect(cubit.state.busy, isTrue);
      expect(cubit.state.shownFee, isNull);
      cubit.close();
    });

    test('indisponible : rien à montrer, bouton libre', () {
      const s = CancellationFeePreviewUnavailable();
      expect(s.busy, isFalse);
      expect(s.shownFee, isNull);
    });

    test('chargé : frais montrés seulement s\'ils sont positifs', () {
      final withFee = CancellationFeePreviewLoaded(_preview(), now: _t0);
      final noFee = CancellationFeePreviewLoaded(
        _preview(fee: 0, refund: 100, rate: 0),
        now: _t0,
      );
      expect(withFee.shownFee, _preview());
      expect(withFee.busy, isFalse);
      expect(noFee.shownFee, isNull);
      expect(
        CancellationFeePreviewLoaded(
          _preview(),
          now: _t0,
          refreshing: true,
        ).busy,
        isTrue,
      );
    });
  });

  group('load', () {
    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      'frais : aperçu chargé avec l\'heure de lecture',
      setUp: () => when(
        () => repo.getFeePreview('bid-1'),
      ).thenAnswer((_) async => _preview()),
      build: build,
      act: (c) => c.load('bid-1'),
      expect: () => [CancellationFeePreviewLoaded(_preview(), now: _t0)],
      verify: (_) => verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ),
    );

    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      'aucun frais (fonction éteinte) : chargé, rien à montrer',
      setUp: () => when(
        () => repo.getFeePreview('bid-1'),
      ).thenAnswer((_) async => _preview(fee: 0, refund: 100, rate: 0)),
      build: build,
      act: (c) => c.load('bid-1'),
      expect: () => [
        isA<CancellationFeePreviewLoaded>().having(
          (s) => s.shownFee,
          'shownFee',
          isNull,
        ),
      ],
    );

    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      'relecture : repasse par la lecture en cours',
      setUp: () => when(
        () => repo.getFeePreview('bid-1'),
      ).thenAnswer((_) async => _preview()),
      build: build,
      seed: () => const CancellationFeePreviewUnavailable(),
      act: (c) => c.load('bid-1'),
      expect: () => [
        const CancellationFeePreviewLoading(),
        CancellationFeePreviewLoaded(_preview(), now: _t0),
      ],
    );

    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      'back antérieur (404) : indisponible, rien de signalé',
      setUp: () => when(
        () => repo.getFeePreview('bid-1'),
      ).thenThrow(_dio(const NotFoundException())),
      build: build,
      act: (c) => c.load('bid-1'),
      expect: () => [const CancellationFeePreviewUnavailable()],
      verify: (_) => verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ),
    );

    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      '403 : indisponible, échec signalé avec son code',
      setUp: () => when(
        () => repo.getFeePreview('bid-1'),
      ).thenThrow(_dio(const ForbiddenException('Forbidden', 'forbidden'))),
      build: build,
      act: (c) => c.load('bid-1'),
      expect: () => [const CancellationFeePreviewUnavailable()],
      verify: (_) => verifyFailure('forbidden'),
    );

    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      'hors ligne : indisponible, OFFLINE',
      setUp: () => when(() => repo.getFeePreview('bid-1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      ),
      build: build,
      act: (c) => c.load('bid-1'),
      expect: () => [const CancellationFeePreviewUnavailable()],
      verify: (_) => verifyFailure('OFFLINE'),
    );

    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      'corps illisible : indisponible, invalid_payload',
      setUp: () => when(
        () => repo.getFeePreview('bid-1'),
      ).thenThrow(const FormatException('x')),
      build: build,
      act: (c) => c.load('bid-1'),
      expect: () => [const CancellationFeePreviewUnavailable()],
      verify: (_) => verifyFailure('invalid_payload'),
    );

    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      'erreur sans code : unknown',
      setUp: () => when(
        () => repo.getFeePreview('bid-1'),
      ).thenThrow(const NetworkException('boom')),
      build: build,
      act: (c) => c.load('bid-1'),
      expect: () => [const CancellationFeePreviewUnavailable()],
      verify: (_) => verifyFailure('unknown'),
    );

    blocTest<CancellationFeePreviewCubit, CancellationFeePreviewState>(
      'réponse trop lente : abandon au délai, TIMEOUT',
      setUp: () => when(
        () => repo.getFeePreview('bid-1'),
      ).thenAnswer((_) => Completer<CancellationFeePreviewModel>().future),
      build: () => build(timeout: const Duration(milliseconds: 20)),
      act: (c) => c.load('bid-1'),
      wait: const Duration(milliseconds: 60),
      expect: () => [const CancellationFeePreviewUnavailable()],
      verify: (_) => verifyFailure('TIMEOUT'),
    );

    test('dialogue fermé pendant la lecture : plus rien n\'est émis', () async {
      final completer = Completer<CancellationFeePreviewModel>();
      when(
        () => repo.getFeePreview('bid-1'),
      ).thenAnswer((_) => completer.future);
      final cubit = build();
      final states = <CancellationFeePreviewState>[];
      final sub = cubit.stream.listen(states.add);
      final pending = cubit.load('bid-1');
      await cubit.close();
      completer.complete(_preview());
      await pending;
      expect(states, isEmpty);
      await sub.cancel();
    });
  });

  group('confirm', () {
    test('lecture en cours : rien ne part', () async {
      final cubit = build();
      expect(await cubit.confirm(), isFalse);
      await cubit.close();
    });

    test('aperçu indisponible : l\'annulation part (jamais bloquée)', () async {
      when(
        () => repo.getFeePreview('bid-1'),
      ).thenThrow(_dio(const NotFoundException()));
      final cubit = build();
      await cubit.load('bid-1');
      expect(await cubit.confirm(), isTrue);
      verify(() => repo.getFeePreview('bid-1')).called(1);
      await cubit.close();
    });

    test('pas de hausse annoncée : part sans relire', () async {
      when(
        () => repo.getFeePreview('bid-1'),
      ).thenAnswer((_) async => _preview(rate: 0.3, fee: 30, refund: 70));
      final cubit = build();
      await cubit.load('bid-1');
      now = _t0.add(const Duration(days: 3));
      expect(await cubit.confirm(), isTrue);
      verify(() => repo.getFeePreview('bid-1')).called(1);
      await cubit.close();
    });

    test('palier pas encore passé : part sans relire', () async {
      when(() => repo.getFeePreview('bid-1')).thenAnswer(
        (_) async => _preview(nextTierAt: _t0.add(const Duration(minutes: 10))),
      );
      final cubit = build();
      await cubit.load('bid-1');
      now = _t0.add(const Duration(minutes: 10));
      expect(await cubit.confirm(), isTrue);
      verify(() => repo.getFeePreview('bid-1')).called(1);
      await cubit.close();
    });

    test('palier passé, frais relus à la hausse : nouveau montant, seconde '
        'confirmation', () async {
      final next = _t0.add(const Duration(minutes: 10));
      final fresh = _preview(rate: 0.3, fee: 30, refund: 70);
      var calls = 0;
      when(() => repo.getFeePreview('bid-1')).thenAnswer((_) async {
        calls++;
        return calls == 1 ? _preview(nextTierAt: next) : fresh;
      });
      final cubit = build();
      await cubit.load('bid-1');
      final states = <CancellationFeePreviewState>[];
      final sub = cubit.stream.listen(states.add);

      now = next.add(const Duration(seconds: 1));
      expect(await cubit.confirm(), isFalse);
      // Le flux du cubit livre ses états à la microtâche suivante.
      await Future<void>.delayed(Duration.zero);
      expect(states, [
        CancellationFeePreviewLoaded(
          _preview(nextTierAt: next),
          now: _t0,
          refreshing: true,
        ),
        CancellationFeePreviewLoaded(fresh, now: now, increased: true),
      ]);
      expect(cubit.state.shownFee?.fee, 30);

      // Seconde confirmation : plus de palier à venir, l'annulation part.
      expect(await cubit.confirm(), isTrue);
      expect(calls, 2);
      await sub.cancel();
      await cubit.close();
    });

    test('fenêtre gratuite (0 €) puis 10 % : les frais apparaissent avant '
        'de confirmer', () async {
      final next = _t0.add(const Duration(hours: 1));
      var calls = 0;
      when(() => repo.getFeePreview('bid-1')).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? _preview(rate: 0, fee: 0, refund: 100, nextTierAt: next)
            : _preview(rate: 0.1, fee: 10, refund: 90);
      });
      final cubit = build();
      await cubit.load('bid-1');
      expect(cubit.state.shownFee, isNull);

      now = next.add(const Duration(minutes: 1));
      expect(await cubit.confirm(), isFalse);
      final s = cubit.state as CancellationFeePreviewLoaded;
      expect(s.increased, isTrue);
      expect(s.shownFee?.fee, 10);
      await cubit.close();
    });

    test('palier passé, frais inchangés (plafond) : part', () async {
      final next = _t0.add(const Duration(minutes: 10));
      var calls = 0;
      when(() => repo.getFeePreview('bid-1')).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? _preview(fee: 30, refund: 170, nextTierAt: next)
            : _preview(rate: 0.3, fee: 30, refund: 170);
      });
      final cubit = build();
      await cubit.load('bid-1');
      now = next.add(const Duration(seconds: 1));
      expect(await cubit.confirm(), isTrue);
      final s = cubit.state as CancellationFeePreviewLoaded;
      expect(s.increased, isFalse);
      expect(s.preview.nextTierAt, isNull);
      await cubit.close();
    });

    test('palier passé, frais relus à la baisse : part', () async {
      final next = _t0.add(const Duration(minutes: 10));
      var calls = 0;
      when(() => repo.getFeePreview('bid-1')).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? _preview(nextTierAt: next)
            : _preview(rate: 0, fee: 0, refund: 100);
      });
      final cubit = build();
      await cubit.load('bid-1');
      now = next.add(const Duration(seconds: 1));
      expect(await cubit.confirm(), isTrue);
      await cubit.close();
    });

    test(
      'palier passé, relecture ratée : part quand même, échec signalé',
      () async {
        final next = _t0.add(const Duration(minutes: 10));
        var calls = 0;
        when(() => repo.getFeePreview('bid-1')).thenAnswer((_) async {
          calls++;
          if (calls == 1) return _preview(nextTierAt: next);
          throw _dio(const OfflineException());
        });
        final cubit = build();
        await cubit.load('bid-1');
        now = next.add(const Duration(seconds: 1));
        expect(await cubit.confirm(), isTrue);
        expect(
          cubit.state,
          CancellationFeePreviewLoaded(_preview(nextTierAt: next), now: _t0),
        );
        verifyFailure('OFFLINE', stage: 'refresh');
        await cubit.close();
      },
    );

    test('double appui pendant la relecture : un seul envoi', () async {
      final next = _t0.add(const Duration(minutes: 10));
      final second = Completer<CancellationFeePreviewModel>();
      var calls = 0;
      when(() => repo.getFeePreview('bid-1')).thenAnswer((_) {
        calls++;
        return calls == 1
            ? Future.value(_preview(nextTierAt: next))
            : second.future;
      });
      final cubit = build();
      await cubit.load('bid-1');
      now = next.add(const Duration(seconds: 1));
      final first = cubit.confirm();
      expect(cubit.state.busy, isTrue);
      expect(await cubit.confirm(), isFalse);
      second.complete(_preview());
      expect(await first, isTrue);
      expect(calls, 2);
      await cubit.close();
    });

    test('dialogue fermé pendant la relecture : rien ne part', () async {
      final next = _t0.add(const Duration(minutes: 10));
      final second = Completer<CancellationFeePreviewModel>();
      var calls = 0;
      when(() => repo.getFeePreview('bid-1')).thenAnswer((_) {
        calls++;
        return calls == 1
            ? Future.value(_preview(nextTierAt: next))
            : second.future;
      });
      final cubit = build();
      await cubit.load('bid-1');
      now = next.add(const Duration(seconds: 1));
      final pending = cubit.confirm();
      await cubit.close();
      second.complete(_preview());
      expect(await pending, isFalse);
    });
  });
}
