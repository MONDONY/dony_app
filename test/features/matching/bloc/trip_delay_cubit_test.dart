// Annonce d'un retard (TripDelayCubit) : succès, refus 409 et 422 traduits
// par le catalogue, double envoi, message vide, analytics sans PII.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/trip_delay/trip_delay_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepository extends Mock implements AnnouncementRepository {}

AnnouncementModel _trip({TransportMode? mode = TransportMode.boat}) =>
    AnnouncementModel(
      id: 'trip-1',
      travelerId: 'trav-1',
      departureCity: 'Le Havre',
      arrivalCity: 'Abidjan',
      departureDate: DateTime(2026, 12, 2),
      availableKg: 0,
      totalKg: 0,
      status: 'IN_PROGRESS',
      transportMode: mode,
      createdAt: DateTime(2026, 11),
      updatedAt: DateTime(2026, 11),
    );

final _from = DateTime(2027, 1, 11);
final _to = DateTime(2027, 1, 18);

TripDelayInfo _delay({String? message}) => TripDelayInfo(
  id: 'delay-1',
  reason: 'PORT_CONGESTION',
  arrivalDate: _from,
  arrivalDateMax: _to,
  message: message,
  announcedAt: DateTime.utc(2026, 12, 20, 9),
);

void main() {
  late _MockRepository repository;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(TripDelayReason.other);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() async {
    repository = _MockRepository();
    backend = MockAnalyticsBackend();
  });

  Future<TripDelayCubit> build({
    TransportMode? mode = TransportMode.boat,
  }) async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    return TripDelayCubit(_trip(mode: mode), repository, analytics);
  }

  void stubAnnounce(Future<TripDelayInfo> Function() answer) => when(
    () => repository.announceDelay(
      announcementId: any(named: 'announcementId'),
      reason: any(named: 'reason'),
      arrivalDate: any(named: 'arrivalDate'),
      arrivalDateMax: any(named: 'arrivalDateMax'),
      message: any(named: 'message'),
    ),
  ).thenAnswer((_) => answer());

  Map<String, dynamic> captured(String event) =>
      verify(() => backend.capture(event, captureAny())).captured.single
          as Map<String, dynamic>;

  group('succès', () {
    blocTest<TripDelayCubit, TripDelayState>(
      'Loading puis Success avec le retard du serveur',
      setUp: () => stubAnnounce(() async => _delay(message: 'Attente')),
      build: () =>
          TripDelayCubit(_trip(), repository, makeEnabledAnalytics(backend)),
      act: (cubit) => cubit.submit(
        reason: TripDelayReason.portCongestion,
        arrivalDate: _from,
        arrivalDateMax: _to,
        message: '  Attente  ',
      ),
      expect: () => [
        const TripDelayLoading(),
        TripDelaySuccess(_delay(message: 'Attente')),
      ],
      verify: (_) => verify(
        () => repository.announceDelay(
          announcementId: 'trip-1',
          reason: TripDelayReason.portCongestion,
          arrivalDate: _from,
          arrivalDateMax: _to,
          message: 'Attente',
        ),
      ).called(1),
    );

    test('message blanc : envoyé nul', () async {
      stubAnnounce(() async => _delay());
      final cubit = await build();
      await cubit.submit(
        reason: TripDelayReason.weather,
        arrivalDate: _from,
        arrivalDateMax: _to,
        message: '   ',
      );
      verify(
        () => repository.announceDelay(
          announcementId: 'trip-1',
          reason: TripDelayReason.weather,
          arrivalDate: _from,
          arrivalDateMax: _to,
        ),
      ).called(1);
      await cubit.close();
    });

    test(
      'trip_delay_announced : motif, mode, largeur, sans date ni texte',
      () async {
        stubAnnounce(() async => _delay(message: 'Attente à Tanger Med'));
        final cubit = await build();
        await cubit.submit(
          reason: TripDelayReason.portCongestion,
          arrivalDate: _from,
          arrivalDateMax: _to,
          message: 'Attente à Tanger Med',
        );
        final props = captured(AnalyticsEvents.tripDelayAnnounced);
        expect(props, {
          'reason': 'port_congestion',
          'transport_mode': 'boat',
          'range_days': 7,
          'has_message': true,
        });
        expect(props.values, isNot(contains('Attente à Tanger Med')));
        await cubit.close();
      },
    );

    test(
      'mode absent (ancienne donnée) : mesuré avion ; bus : route',
      () async {
        stubAnnounce(() async => _delay());
        for (final (mode, expected) in [
          (null, 'plane'),
          (TransportMode.bus, 'car'),
        ]) {
          clearInteractions(backend);
          final cubit = await build(mode: mode);
          await cubit.submit(
            reason: TripDelayReason.other,
            arrivalDate: _from,
            arrivalDateMax: _from,
          );
          final props = captured(AnalyticsEvents.tripDelayAnnounced);
          expect(props['transport_mode'], expected);
          expect(props['range_days'], 0);
          expect(props['has_message'], isFalse);
          await cubit.close();
        }
      },
    );

    test('second envoi pendant le premier : ignoré', () async {
      final reply = Completer<TripDelayInfo>();
      stubAnnounce(() => reply.future);
      final cubit = await build();
      unawaited(
        cubit.submit(
          reason: TripDelayReason.weather,
          arrivalDate: _from,
          arrivalDateMax: _to,
        ),
      );
      await cubit.submit(
        reason: TripDelayReason.weather,
        arrivalDate: _from,
        arrivalDateMax: _to,
      );
      reply.complete(_delay());
      await Future<void>.delayed(Duration.zero);
      verify(
        () => repository.announceDelay(
          announcementId: any(named: 'announcementId'),
          reason: any(named: 'reason'),
          arrivalDate: any(named: 'arrivalDate'),
          arrivalDateMax: any(named: 'arrivalDateMax'),
          message: any(named: 'message'),
        ),
      ).called(1);
      expect(cubit.state, isA<TripDelaySuccess>());
      await cubit.close();
    });
  });

  group('erreurs', () {
    blocTest<TripDelayCubit, TripDelayState>(
      '409 trip-delay-not-allowed : message du catalogue',
      setUp: () => stubAnnounce(
        () async => throw const ConflictException(
          'raw',
          code: 'trip-delay-not-allowed',
        ),
      ),
      build: () =>
          TripDelayCubit(_trip(), repository, makeEnabledAnalytics(backend)),
      act: (cubit) => cubit.submit(
        reason: TripDelayReason.weather,
        arrivalDate: _from,
        arrivalDateMax: _to,
      ),
      expect: () => [
        const TripDelayLoading(),
        const TripDelayError(
          'Un retard ne peut être annoncé que sur un trajet en cours : il '
          'doit être parti et ne pas être terminé.',
          code: 'trip-delay-not-allowed',
        ),
      ],
    );

    blocTest<TripDelayCubit, TripDelayState>(
      '422 arrival-range-invalid : le detail du serveur est relayé',
      setUp: () => stubAnnounce(
        () async => throw const ValidationException(
          "La fin de l'arrivée estimée est déjà passée.",
          code: 'arrival-range-invalid',
        ),
      ),
      build: () =>
          TripDelayCubit(_trip(), repository, makeEnabledAnalytics(backend)),
      act: (cubit) => cubit.submit(
        reason: TripDelayReason.weather,
        arrivalDate: _from,
        arrivalDateMax: _to,
      ),
      expect: () => [
        const TripDelayLoading(),
        const TripDelayError(
          "La fin de l'arrivée estimée est déjà passée.",
          code: 'arrival-range-invalid',
        ),
      ],
    );

    test('422 sans detail lisible : repli du catalogue', () async {
      stubAnnounce(
        () async =>
            throw const ValidationException('', code: 'arrival-range-invalid'),
      );
      final cubit = await build();
      await cubit.submit(
        reason: TripDelayReason.weather,
        arrivalDate: _from,
        arrivalDateMax: _to,
      );
      expect(
        cubit.state,
        const TripDelayError(
          "Vérifiez l'arrivée estimée : elle ne peut pas précéder le départ, "
          'et la fin ne peut être ni avant le début ni dans le passé.',
          code: 'arrival-range-invalid',
        ),
      );
      await cubit.close();
    });

    test(
      'trip_delay_announce_failed : error_code, jamais le message',
      () async {
        stubAnnounce(
          () async => throw const ConflictException(
            'Trop de retards',
            code: 'trip-delay-too-frequent',
          ),
        );
        final cubit = await build(mode: TransportMode.car);
        await cubit.submit(
          reason: TripDelayReason.transportDisruption,
          arrivalDate: _from,
          arrivalDateMax: _to,
        );
        expect(captured(AnalyticsEvents.tripDelayAnnounceFailed), {
          'reason': 'transport_disruption',
          'transport_mode': 'car',
          'error_code': 'trip-delay-too-frequent',
        });
        verifyNever(
          () => backend.capture(AnalyticsEvents.tripDelayAnnounced, any()),
        );
        await cubit.close();
      },
    );

    test('erreur sans code : unknown, puis nouvel essai possible', () async {
      var calls = 0;
      stubAnnounce(() async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return _delay();
      });
      final cubit = await build();
      await cubit.submit(
        reason: TripDelayReason.other,
        arrivalDate: _from,
        arrivalDateMax: _to,
      );
      expect(cubit.state, isA<TripDelayError>());
      expect(
        captured(AnalyticsEvents.tripDelayAnnounceFailed)['error_code'],
        'unknown',
      );
      await cubit.submit(
        reason: TripDelayReason.other,
        arrivalDate: _from,
        arrivalDateMax: _to,
      );
      expect(cubit.state, isA<TripDelaySuccess>());
      await cubit.close();
    });
  });
}
