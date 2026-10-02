import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/calls/bloc/call_bloc.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/data/models/started_call.dart';
import 'package:dony/features/calls/data/repositories/calls_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_call_gateway.dart';

class _MockCallsRepository extends Mock implements CallsRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockCallsRepository repository;
  late FakeCallGateway gateway;
  late _MockAnalytics analytics;
  final t0 = DateTime(2026, 10, 2, 12);

  setUp(() {
    repository = _MockCallsRepository();
    gateway = FakeCallGateway();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => gateway.dispose());

  CallBloc build() => CallBloc(repository, gateway, analytics);

  void backStarts() => when(() => repository.startCall('c1')).thenAnswer(
    (_) async => const StartedCall(callId: 'x1', callType: 'audio_call'),
  );

  group('appel sortant', () {
    blocTest<CallBloc, CallState>(
      'le back crée l\'appel, l\'app le rejoint et sonne',
      build: build,
      setUp: backStarts,
      act: (bloc) => bloc.add(const CallStartRequested('c1', 'Moussa')),
      expect: () => [
        isA<CallStarting>(),
        isA<CallInProgress>()
            .having((s) => s.phase, 'phase', CallPhase.ringing)
            .having((s) => s.remoteName, 'remoteName', 'Moussa'),
      ],
      verify: (_) {
        // close() (fin du blocTest) raccroche l'appel encore en cours.
        expect(gateway.log, ['mic-check', 'join:x1', 'hangUp']);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.callStarted,
            properties: any(named: 'properties'),
          ),
        ).called(1);
      },
    );

    blocTest<CallBloc, CallState>(
      'l\'autre décroche : connecté, avec l\'heure de début',
      build: build,
      setUp: backStarts,
      act: (bloc) async {
        bloc.add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(Duration.zero);
        gateway.activeCallController.add(
          ActiveCallSnapshot(
            phase: CallPhase.connected,
            connectedAt: t0,
            remoteName: 'Moussa K.',
          ),
        );
      },
      skip: 2,
      expect: () => [
        isA<CallInProgress>()
            .having((s) => s.phase, 'phase', CallPhase.connected)
            .having((s) => s.connectedAt, 'connectedAt', t0)
            .having((s) => s.remoteName, 'remoteName', 'Moussa K.'),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.callConnected,
          properties: any(named: 'properties'),
        ),
      ).called(1),
    );

    blocTest<CallBloc, CallState>(
      'l\'autre refuse : appel terminé, raison rejected',
      build: build,
      setUp: backStarts,
      act: (bloc) async {
        bloc.add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(Duration.zero);
        gateway.activeCallController.add(
          const ActiveCallSnapshot(
            phase: CallPhase.ended,
            endReason: 'rejected',
          ),
        );
      },
      skip: 2,
      expect: () => [
        isA<CallEnded>().having((s) => s.reason, 'reason', 'rejected'),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.callEnded,
          properties: {'reason': 'rejected'},
        ),
      ).called(1),
    );

    for (final (code, exception) in [
      (
        'call-already-in-progress',
        const ConflictException('déjà', code: 'call-already-in-progress'),
      ),
      (
        'call-out-of-window',
        const ValidationException('hors', code: 'call-out-of-window'),
      ),
      (
        'call-provider-unavailable',
        const ServerException('ko', 'call-provider-unavailable'),
      ),
    ]) {
      blocTest<CallBloc, CallState>(
        'refus du back $code : échec, aucun join',
        build: build,
        setUp: () =>
            when(() => repository.startCall('c1')).thenThrow(exception),
        act: (bloc) => bloc.add(const CallStartRequested('c1', 'Moussa')),
        expect: () => [
          isA<CallStarting>(),
          isA<CallFailure>().having((s) => s.error.code, 'code', code),
        ],
        verify: (_) {
          expect(gateway.log, ['mic-check']);
          verify(
            () => analytics.logEvent(
              AnalyticsEvents.callFailed,
              properties: {'code': code},
            ),
          ).called(1);
        },
      );
    }

    blocTest<CallBloc, CallState>(
      'échec du join : on raccroche et on signale l\'échec',
      build: build,
      setUp: () {
        backStarts();
        gateway.throwOnJoin = StateError('webrtc');
      },
      act: (bloc) => bloc.add(const CallStartRequested('c1', 'Moussa')),
      expect: () => [
        isA<CallStarting>(),
        isA<CallInProgress>(),
        isA<CallFailure>(),
      ],
      verify: (_) => expect(gateway.log, ['mic-check', 'join:x1', 'hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'double tap : un seul appel',
      build: build,
      setUp: backStarts,
      act: (bloc) => bloc
        ..add(const CallStartRequested('c1', 'Moussa'))
        ..add(const CallStartRequested('c1', 'Moussa')),
      verify: (_) => verify(() => repository.startCall('c1')).called(1),
    );
  });

  group('pendant l\'appel', () {
    blocTest<CallBloc, CallState>(
      'couper puis réactiver le micro',
      build: build,
      seed: () => const CallInProgress(
        phase: CallPhase.connected,
        remoteName: 'Moussa',
      ),
      act: (bloc) => bloc
        ..add(const CallMuteToggleRequested())
        ..add(const CallMuteToggleRequested()),
      expect: () => [
        isA<CallInProgress>().having((s) => s.muted, 'muted', true),
        isA<CallInProgress>().having((s) => s.muted, 'muted', false),
      ],
      verify: (_) => expect(gateway.log, ['mic:false', 'mic:true', 'hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'haut-parleur',
      build: build,
      seed: () => const CallInProgress(
        phase: CallPhase.connected,
        remoteName: 'Moussa',
      ),
      act: (bloc) => bloc.add(const CallSpeakerToggleRequested()),
      expect: () => [
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', true),
      ],
      verify: (_) => expect(gateway.log, ['speaker:true', 'hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'raccrocher',
      build: build,
      seed: () => const CallInProgress(
        phase: CallPhase.connected,
        remoteName: 'Moussa',
      ),
      act: (bloc) => bloc.add(const CallHangUpRequested()),
      expect: () => [
        isA<CallEnded>().having((s) => s.reason, 'reason', 'hangup'),
      ],
      verify: (_) => expect(gateway.log, ['hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'micro et haut-parleur sans appel : ignorés',
      build: build,
      act: (bloc) => bloc
        ..add(const CallMuteToggleRequested())
        ..add(const CallSpeakerToggleRequested()),
      expect: () => <CallState>[],
    );
  });

  group('appel entrant', () {
    blocTest<CallBloc, CallState>(
      'décrocher depuis l\'app',
      build: build,
      act: (bloc) => bloc.add(const CallIncomingAcceptRequested('x2', 'Awa')),
      expect: () => [
        isA<CallInProgress>()
            .having((s) => s.phase, 'phase', CallPhase.connecting)
            .having((s) => s.remoteName, 'remoteName', 'Awa'),
      ],
      verify: (_) {
        expect(gateway.log, ['mic-check', 'accept:x2', 'hangUp']);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.callIncomingAccepted,
            properties: any(named: 'properties'),
          ),
        ).called(1);
      },
    );

    blocTest<CallBloc, CallState>(
      'décroché depuis CallKit : l\'appel est quand même rejoint',
      build: build,
      act: (bloc) => bloc.add(
        const CallIncomingAcceptRequested('x2', 'Awa', acceptedNatively: true),
      ),
      expect: () => [isA<CallInProgress>()],
      // L'adaptateur saute l'accept déjà fait par CallKit, mais rejoint l'appel.
      verify: (_) => expect(gateway.log, ['mic-check', 'accept:x2', 'hangUp']),
    );
  });

  test('fermer l\'écran pendant un appel raccroche', () async {
    final bloc = build()
      ..emit(
        const CallInProgress(phase: CallPhase.connected, remoteName: 'Moussa'),
      );
    await bloc.close();
    expect(gateway.log, ['hangUp']);
  });

  test('fermer après la fin : rien', () async {
    final bloc = build()..emit(const CallEnded(reason: 'hangup'));
    await bloc.close();
    expect(gateway.log, isEmpty);
  });

  group('micro refusé', () {
    blocTest<CallBloc, CallState>(
      'sortant : échec avant de faire sonner l\'autre',
      build: build,
      setUp: () => gateway.microphoneAllowed = false,
      act: (bloc) => bloc.add(const CallStartRequested('c1', 'Moussa')),
      expect: () => [
        isA<CallStarting>(),
        isA<CallFailure>().having(
          (s) => s.error.code,
          'code',
          'microphone-denied',
        ),
      ],
      verify: (_) {
        verifyNever(() => repository.startCall(any()));
        expect(gateway.log, ['mic-check']);
      },
    );

    blocTest<CallBloc, CallState>(
      'entrant : échec, l\'appel n\'est pas décroché',
      build: build,
      setUp: () => gateway.microphoneAllowed = false,
      act: (bloc) => bloc.add(const CallIncomingAcceptRequested('x2', 'Awa')),
      expect: () => [
        isA<CallFailure>().having(
          (s) => s.error,
          'error',
          isA<CallPermissionDeniedException>(),
        ),
      ],
      verify: (_) => expect(gateway.log, ['mic-check', 'reject:x2']),
    );
  });

  group('revue finale', () {
    test(
      'écran fermé pendant la création de l\'appel : sonnerie annulée, '
      'jamais rejoint',
      () async {
        final created = Completer<StartedCall>();
        when(
          () => repository.startCall('c1'),
        ).thenAnswer((_) => created.future);
        final bloc = build()..add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(Duration.zero);
        await bloc.close();
        created.complete(
          const StartedCall(callId: 'x1', callType: 'audio_call'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(gateway.log, contains('cancel:x1'));
        expect(gateway.log, isNot(contains('join:x1')));
      },
    );

    blocTest<CallBloc, CallState>(
      'raccrocher soi-même journalise call_ended (hangup)',
      build: build,
      setUp: backStarts,
      act: (bloc) async {
        bloc.add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CallHangUpRequested());
      },
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.callEnded,
          properties: {'reason': 'hangup'},
        ),
      ).called(1),
    );
  });
}
