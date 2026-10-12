import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/corridor_alerts/bloc/trip_space_alert_cubit.dart';
import 'package:dony/features/corridor_alerts/data/trip_space_alert_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements TripSpaceAlertRepository {}

AppException _problem(int status, String code) => switch (status) {
  409 => ConflictException('x', code: code),
  404 => const NotFoundException(),
  _ => const ServerException(),
};

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  TripSpaceAlertCubit build() => TripSpaceAlertCubit(
    repo,
    makeEnabledAnalytics(backend)..onConfigured(),
    announcementId: 'a1',
  );

  group('load', () {
    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      'abonné quand le trajet figure dans la liste',
      setUp: () => when(
        () => repo.getSubscribedTripIds(),
      ).thenAnswer((_) async => {'a1', 'b2'}),
      build: build,
      act: (c) => c.load(),
      expect: () => [
        const TripSpaceAlertState(status: TripSpaceAlertStatus.subscribed),
      ],
    );

    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      'pas abonné sinon',
      setUp: () => when(
        () => repo.getSubscribedTripIds(),
      ).thenAnswer((_) async => {'b2'}),
      build: build,
      act: (c) => c.load(),
      expect: () => [
        const TripSpaceAlertState(status: TripSpaceAlertStatus.notSubscribed),
      ],
    );

    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      'échec (back antérieur sans endpoint) : bouton proposé',
      setUp: () => when(
        () => repo.getSubscribedTripIds(),
      ).thenThrow(_problem(404, 'not-found')),
      build: build,
      act: (c) => c.load(),
      expect: () => [
        const TripSpaceAlertState(status: TripSpaceAlertStatus.notSubscribed),
      ],
    );
  });

  group('subscribe', () {
    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      'succès : en cours puis abonné',
      setUp: () => when(() => repo.subscribe('a1')).thenAnswer((_) async {}),
      build: build,
      act: (c) => c.subscribe(),
      expect: () => [
        const TripSpaceAlertState(isSubmitting: true),
        const TripSpaceAlertState(status: TripSpaceAlertStatus.subscribed),
      ],
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.tripSpaceAlertSubscribed, null),
      ).called(1),
    );

    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      '409 trip-not-full : la place est revenue',
      setUp: () => when(
        () => repo.subscribe('a1'),
      ).thenThrow(_problem(409, 'trip-not-full')),
      build: build,
      act: (c) => c.subscribe(),
      expect: () => [
        const TripSpaceAlertState(isSubmitting: true),
        const TripSpaceAlertState(status: TripSpaceAlertStatus.spaceAvailable),
      ],
      verify: (_) => verifyNever(
        () => backend.capture(AnalyticsEvents.tripSpaceAlertSubscribed, any()),
      ),
    );

    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      'autre échec : signalé, état conservé',
      setUp: () =>
          when(() => repo.subscribe('a1')).thenThrow(_problem(500, 'internal')),
      build: build,
      seed: () =>
          const TripSpaceAlertState(status: TripSpaceAlertStatus.notSubscribed),
      act: (c) => c.subscribe(),
      expect: () => [
        const TripSpaceAlertState(
          status: TripSpaceAlertStatus.notSubscribed,
          isSubmitting: true,
        ),
        const TripSpaceAlertState(
          status: TripSpaceAlertStatus.notSubscribed,
          failed: true,
        ),
      ],
    );

    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      'ignoré pendant une action en cours',
      build: build,
      seed: () => const TripSpaceAlertState(isSubmitting: true),
      act: (c) async {
        await c.subscribe();
        await c.unsubscribe();
      },
      expect: () => <TripSpaceAlertState>[],
      verify: (_) {
        verifyNever(() => repo.subscribe(any()));
        verifyNever(() => repo.unsubscribe(any()));
      },
    );
  });

  group('unsubscribe', () {
    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      'succès : plus abonné',
      setUp: () => when(() => repo.unsubscribe('a1')).thenAnswer((_) async {}),
      build: build,
      seed: () =>
          const TripSpaceAlertState(status: TripSpaceAlertStatus.subscribed),
      act: (c) => c.unsubscribe(),
      expect: () => [
        const TripSpaceAlertState(
          status: TripSpaceAlertStatus.subscribed,
          isSubmitting: true,
        ),
        const TripSpaceAlertState(status: TripSpaceAlertStatus.notSubscribed),
      ],
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.tripSpaceAlertUnsubscribed, null),
      ).called(1),
    );

    blocTest<TripSpaceAlertCubit, TripSpaceAlertState>(
      'échec : reste abonné, signalé',
      setUp: () => when(
        () => repo.unsubscribe('a1'),
      ).thenThrow(_problem(500, 'internal')),
      build: build,
      seed: () =>
          const TripSpaceAlertState(status: TripSpaceAlertStatus.subscribed),
      act: (c) => c.unsubscribe(),
      expect: () => [
        const TripSpaceAlertState(
          status: TripSpaceAlertStatus.subscribed,
          isSubmitting: true,
        ),
        const TripSpaceAlertState(
          status: TripSpaceAlertStatus.subscribed,
          failed: true,
        ),
      ],
    );
  });
}
