import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
import 'package:dony/features/cancellation/data/models/delivery_noshow_procedure_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements CancellationRepository {}

final _now = DateTime(2026, 10, 8, 12);

DeliveryNoShowProcedureModel _waiting({DateTime? availableAt}) =>
    DeliveryNoShowProcedureModel(
      bidId: 'b1',
      role: 'TRAVELER',
      bidStatus: 'ARRIVED',
      reportAvailableAt: availableAt ?? _now.add(const Duration(minutes: 30)),
    );

const _holding = DeliveryNoShowProcedureModel(
  bidId: 'b1',
  role: 'SENDER',
  bidStatus: 'ARRIVED',
  reported: true,
  canSetRetryAppointment: true,
);

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  DeliveryNoShowProcedureCubit build({DateTime Function()? clock}) {
    final analytics = makeEnabledAnalytics(backend)..onConfigured();
    return DeliveryNoShowProcedureCubit(
      repo,
      analytics,
      clock: clock ?? () => _now,
    );
  }

  blocTest<DeliveryNoShowProcedureCubit, DeliveryNoShowProcedureState>(
    'charge la procédure et calcule les minutes restantes',
    setUp: () => when(
      () => repo.getDeliveryNoShowProcedure('b1'),
    ).thenAnswer((_) async => _waiting()),
    build: build,
    act: (c) => c.load('b1'),
    expect: () => [
      isA<DeliveryNoShowProcedureLoaded>().having(
        (s) => s.remainingWaitMinutes,
        'remaining',
        30,
      ),
    ],
  );

  blocTest<DeliveryNoShowProcedureCubit, DeliveryNoShowProcedureState>(
    'back antérieur (404) : procédure indisponible',
    setUp: () => when(
      () => repo.getDeliveryNoShowProcedure('b1'),
    ).thenThrow(const NotFoundException()),
    build: build,
    act: (c) => c.load('b1'),
    expect: () => [isA<DeliveryNoShowProcedureUnavailable>()],
  );

  blocTest<DeliveryNoShowProcedureCubit, DeliveryNoShowProcedureState>(
    'autre erreur : état erreur, puis refresh relit',
    setUp: () => when(
      () => repo.getDeliveryNoShowProcedure('b1'),
    ).thenThrow(const NetworkException('down')),
    build: build,
    act: (c) async {
      await c.load('b1');
      await c.refresh();
    },
    expect: () => [
      isA<DeliveryNoShowProcedureError>(),
      isA<DeliveryNoShowProcedureError>(),
    ],
    verify: (_) =>
        verify(() => repo.getDeliveryNoShowProcedure('b1')).called(2),
  );

  test('compteur : tick par minute puis relecture au terme', () {
    fakeAsync((async) {
      var now = _now;
      when(() => repo.getDeliveryNoShowProcedure('b1')).thenAnswer(
        (_) async =>
            _waiting(availableAt: _now.add(const Duration(minutes: 2))),
      );
      final cubit = build(clock: () => now);
      cubit.load('b1');
      async.flushMicrotasks();
      expect(
        (cubit.state as DeliveryNoShowProcedureLoaded).remainingWaitMinutes,
        2,
      );

      now = _now.add(const Duration(minutes: 1));
      async.elapse(const Duration(minutes: 1));
      expect(
        (cubit.state as DeliveryNoShowProcedureLoaded).remainingWaitMinutes,
        1,
      );

      now = _now.add(const Duration(minutes: 2));
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      verify(() => repo.getDeliveryNoShowProcedure('b1')).called(2);
      cubit.close();
    });
  });

  test('remainingWaitMinutes vaut 0 une fois l attente écoulée', () {
    final state = DeliveryNoShowProcedureLoaded(
      _waiting(availableAt: _now.subtract(const Duration(minutes: 1))),
      now: _now,
    );
    expect(state.remainingWaitMinutes, 0);
  });

  blocTest<DeliveryNoShowProcedureCubit, DeliveryNoShowProcedureState>(
    'nouveau rendez-vous : envoi, succès et analytics',
    setUp: () {
      when(
        () => repo.getDeliveryNoShowProcedure('b1'),
      ).thenAnswer((_) async => _holding);
      when(
        () => repo.setRetryAppointment(
          'b1',
          appointmentAt: any(named: 'appointmentAt'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => _holding);
    },
    build: build,
    act: (c) async {
      await c.load('b1');
      await c.setRetryAppointment(
        appointmentAt: _now.add(const Duration(days: 1)),
        note: 'Gare',
      );
    },
    skip: 1,
    expect: () => [
      isA<DeliveryNoShowProcedureLoaded>().having(
        (s) => s.submitting,
        'submitting',
        true,
      ),
      isA<DeliveryNoShowProcedureLoaded>().having(
        (s) => s.appointmentSaved,
        'saved',
        true,
      ),
    ],
    verify: (_) => verify(
      () => backend.capture(AnalyticsEvents.deliveryRetryAppointmentSet, any()),
    ).called(1),
  );

  blocTest<DeliveryNoShowProcedureCubit, DeliveryNoShowProcedureState>(
    'nouveau rendez-vous refusé : erreur portée par l état',
    setUp: () {
      when(
        () => repo.getDeliveryNoShowProcedure('b1'),
      ).thenAnswer((_) async => _holding);
      when(
        () => repo.setRetryAppointment(
          'b1',
          appointmentAt: any(named: 'appointmentAt'),
          note: any(named: 'note'),
        ),
      ).thenThrow(const ValidationExceptionStub());
    },
    build: build,
    act: (c) async {
      await c.load('b1');
      await c.setRetryAppointment(appointmentAt: _now);
    },
    skip: 2,
    expect: () => [
      isA<DeliveryNoShowProcedureLoaded>().having(
        (s) => s.submitError,
        'error',
        isNotNull,
      ),
    ],
  );

  blocTest<DeliveryNoShowProcedureCubit, DeliveryNoShowProcedureState>(
    'nouveau rendez-vous ignoré hors état chargé',
    build: build,
    act: (c) => c.setRetryAppointment(appointmentAt: _now),
    expect: () => <DeliveryNoShowProcedureState>[],
  );
}

class ValidationExceptionStub extends AppException {
  const ValidationExceptionStub()
    : super('invalide', code: 'retry-appointment-out-of-hold');
}
