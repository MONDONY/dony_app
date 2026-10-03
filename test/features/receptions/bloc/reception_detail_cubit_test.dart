import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/receptions/bloc/reception_detail_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReceptionRepository extends Mock implements ReceptionRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

const _id = 'b1';

const _pending = Reception(
  bidId: _id,
  linkStatus: 'PENDING',
  bidStatus: 'ACCEPTED',
);

const _confirmed = Reception(
  bidId: _id,
  linkStatus: 'CONFIRMED',
  bidStatus: 'ACCEPTED',
);

TypeMatcher<ReceptionDetailLoaded> _loaded(ReceptionAction action) =>
    isA<ReceptionDetailLoaded>().having((s) => s.action, 'action', action);

void main() {
  late MockReceptionRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockReceptionRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  group('load', () {
    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'charge le colis et mesure l\'ouverture une fois, même après un réessai',
      build: () {
        when(
          () => repository.getReception(_id),
        ).thenAnswer((_) async => _pending);
        return ReceptionDetailCubit(repository, analytics);
      },
      act: (cubit) async {
        await cubit.load(_id);
        await cubit.retry();
      },
      expect: () => [
        const ReceptionDetailLoading(),
        _loaded(ReceptionAction.idle),
        const ReceptionDetailLoading(),
        _loaded(ReceptionAction.idle),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.receptionOpened,
          properties: {'link_status': 'PENDING', 'bid_status': 'ACCEPTED'},
        ),
      ).called(1),
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      '404 : colis plus disponible',
      build: () {
        when(
          () => repository.getReception(_id),
        ).thenThrow(const NotFoundException());
        return ReceptionDetailCubit(repository, analytics);
      },
      act: (cubit) => cubit.load(_id),
      expect: () => [
        const ReceptionDetailLoading(),
        isA<ReceptionDetailError>().having((s) => s.notFound, 'notFound', true),
      ],
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'hors ligne : erreur à réessayer',
      build: () {
        when(
          () => repository.getReception(_id),
        ).thenThrow(const OfflineException());
        return ReceptionDetailCubit(repository, analytics);
      },
      act: (cubit) => cubit.load(_id),
      expect: () => [
        const ReceptionDetailLoading(),
        isA<ReceptionDetailError>().having(
          (s) => s.notFound,
          'notFound',
          false,
        ),
      ],
    );

    test('réessayer sans chargement préalable ne fait rien', () async {
      final cubit = ReceptionDetailCubit(repository, analytics);
      await cubit.retry();
      verifyNever(() => repository.getReception(any()));
      await cubit.close();
    });
  });

  group('confirm', () {
    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'succès : colis confirmé et événement',
      build: () {
        when(() => repository.confirm(_id)).thenAnswer((_) async => _confirmed);
        return ReceptionDetailCubit(repository, analytics);
      },
      seed: () => const ReceptionDetailLoaded(_pending),
      act: (cubit) => cubit.confirm(),
      expect: () => [
        _loaded(ReceptionAction.confirming),
        _loaded(
          ReceptionAction.confirmed,
        ).having((s) => s.reception.isConfirmed, 'confirmé', true),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.receptionConfirmed,
          properties: {'bid_status': 'ACCEPTED'},
        ),
      ).called(1),
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'échec réseau : erreur du geste, colis conservé',
      build: () {
        when(() => repository.confirm(_id)).thenThrow(const OfflineException());
        return ReceptionDetailCubit(repository, analytics);
      },
      seed: () => const ReceptionDetailLoaded(_pending),
      act: (cubit) => cubit.confirm(),
      expect: () => [
        _loaded(ReceptionAction.confirming),
        _loaded(ReceptionAction.failed)
            .having((s) => s.actionError, 'erreur', isA<OfflineException>())
            .having((s) => s.reception.isPending, 'en attente', true),
      ],
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      '404 pendant le geste : colis plus disponible',
      build: () {
        when(
          () => repository.confirm(_id),
        ).thenThrow(const NotFoundException());
        return ReceptionDetailCubit(repository, analytics);
      },
      seed: () => const ReceptionDetailLoaded(_pending),
      act: (cubit) => cubit.confirm(),
      expect: () => [
        _loaded(ReceptionAction.confirming),
        isA<ReceptionDetailError>().having((s) => s.notFound, 'notFound', true),
      ],
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'ignoré pendant un geste en cours ou sans colis chargé',
      build: () => ReceptionDetailCubit(repository, analytics),
      seed: () => const ReceptionDetailLoaded(
        _pending,
        action: ReceptionAction.declining,
      ),
      act: (cubit) async {
        await cubit.confirm();
        await cubit.decline();
      },
      expect: () => const <ReceptionDetailState>[],
      verify: (_) {
        verifyNever(() => repository.confirm(any()));
        verifyNever(() => repository.decline(any()));
      },
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'sans colis chargé : rien',
      build: () => ReceptionDetailCubit(repository, analytics),
      act: (cubit) async {
        await cubit.confirm();
        await cubit.decline();
      },
      expect: () => const <ReceptionDetailState>[],
    );
  });

  group('se retirer d\'un colis confirmé (FLUTTER-9F)', () {
    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'succès : retiré et événement reception_withdrawn',
      build: () {
        when(() => repository.decline(_id)).thenAnswer((_) async {});
        return ReceptionDetailCubit(repository, analytics);
      },
      seed: () => const ReceptionDetailLoaded(_confirmed),
      act: (cubit) => cubit.decline(),
      expect: () => [
        isA<ReceptionDetailLoaded>().having(
          (s) => s.action,
          'action',
          ReceptionAction.declining,
        ),
        isA<ReceptionDetailLoaded>().having(
          (s) => s.action,
          'action',
          ReceptionAction.withdrawn,
        ),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.receptionWithdrawn,
            properties: {'bid_status': 'ACCEPTED'},
          ),
        ).called(1);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.receptionDeclined,
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    test('possible tant que le colis est en cours, plus après', () {
      expect(_confirmed.canWithdraw, isTrue);
      expect(_pending.canWithdraw, isFalse);
      const delivered = Reception(
        bidId: _id,
        linkStatus: 'CONFIRMED',
        bidStatus: 'COMPLETED',
      );
      expect(delivered.canWithdraw, isFalse);
    });
  });

  group('decline', () {
    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'succès : refusé et événement',
      build: () {
        when(() => repository.decline(_id)).thenAnswer((_) async {});
        return ReceptionDetailCubit(repository, analytics);
      },
      seed: () => const ReceptionDetailLoaded(_pending),
      act: (cubit) => cubit.decline(),
      expect: () => [
        _loaded(ReceptionAction.declining),
        _loaded(ReceptionAction.declined),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.receptionDeclined,
          properties: {'bid_status': 'ACCEPTED'},
        ),
      ).called(1),
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      '409 déjà confirmé : l\'état réel est rechargé',
      build: () {
        when(() => repository.decline(_id)).thenThrow(
          const ConflictException(
            'déjà confirmé',
            code: 'reception-already-confirmed',
          ),
        );
        when(
          () => repository.getReception(_id),
        ).thenAnswer((_) async => _confirmed);
        return ReceptionDetailCubit(repository, analytics);
      },
      seed: () => const ReceptionDetailLoaded(_pending),
      act: (cubit) => cubit.decline(),
      expect: () => [
        _loaded(ReceptionAction.declining),
        _loaded(ReceptionAction.failed)
            .having((s) => s.reception.isConfirmed, 'confirmé', true)
            .having((s) => s.actionError, 'erreur', isA<ConflictException>()),
      ],
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      '409 puis rechargement raté : erreur du geste sur l\'ancien état',
      build: () {
        when(
          () => repository.decline(_id),
        ).thenThrow(const ConflictException('déjà confirmé'));
        when(
          () => repository.getReception(_id),
        ).thenThrow(const OfflineException());
        return ReceptionDetailCubit(repository, analytics);
      },
      seed: () => const ReceptionDetailLoaded(_pending),
      act: (cubit) => cubit.decline(),
      expect: () => [
        _loaded(ReceptionAction.declining),
        _loaded(
          ReceptionAction.failed,
        ).having((s) => s.reception.isPending, 'en attente', true),
      ],
    );

    blocTest<ReceptionDetailCubit, ReceptionDetailState>(
      'échec réseau : erreur du geste',
      build: () {
        when(() => repository.decline(_id)).thenThrow(const OfflineException());
        return ReceptionDetailCubit(repository, analytics);
      },
      seed: () => const ReceptionDetailLoaded(_pending),
      act: (cubit) => cubit.decline(),
      expect: () => [
        _loaded(ReceptionAction.declining),
        _loaded(ReceptionAction.failed),
      ],
    );
  });
}
