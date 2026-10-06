import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/calls/bloc/call_bloc.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/data/models/started_call.dart';
import 'package:dony/features/calls/data/repositories/calls_repository.dart';
import 'package:dony/features/calls/data/ringback_tone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_call_gateway.dart';

class _MockCallsRepository extends Mock implements CallsRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

/// Trace les ordres donnés à la tonalité de retour d'appel.
class _FakeRingback implements RingbackTone {
  final log = <String>[];

  @override
  Future<void> start() async => log.add('start');

  @override
  Future<void> stop() async => log.add('stop');

  @override
  Future<void> dispose() async => log.add('dispose');
}

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

    // FLUTTER-A5/A6 : Stream refuse le haut-parleur tant que l'autre n'a
    // pas décroché ; le choix attend le décroché au lieu de planter.
    blocTest<CallBloc, CallState>(
      'haut-parleur pendant la sonnerie : retenu puis appliqué au décroché',
      build: build,
      seed: () =>
          const CallInProgress(phase: CallPhase.ringing, remoteName: 'Moussa'),
      act: (bloc) async {
        bloc.add(const CallSpeakerToggleRequested());
        await Future<void>.delayed(Duration.zero);
        expect(gateway.log, isEmpty);
        gateway.activeCallController.add(
          ActiveCallSnapshot(phase: CallPhase.connected, connectedAt: t0),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallInProgress>()
            .having((s) => s.speakerOn, 'speakerOn', true)
            .having((s) => s.phase, 'phase', CallPhase.ringing),
        isA<CallInProgress>()
            .having((s) => s.speakerOn, 'speakerOn', true)
            .having((s) => s.phase, 'phase', CallPhase.connected),
      ],
      verify: (_) => expect(gateway.log, ['speaker:true', 'hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'haut-parleur refusé par Stream : pas de plantage, bouton remis',
      build: build,
      setUp: () => gateway.throwOnSpeaker = StateError('Call not connected'),
      seed: () => const CallInProgress(
        phase: CallPhase.connected,
        remoteName: 'Moussa',
      ),
      act: (bloc) => bloc.add(const CallSpeakerToggleRequested()),
      expect: () => [
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', true),
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', false),
      ],
      errors: () => isEmpty,
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

  // FLUTTER-E1 : casque branché, le son restait sur le haut-parleur.
  group('sortie audio réelle', () {
    const speaker = CallAudioOutput(
      type: 'Speaker',
      speaker: true,
      external: false,
    );
    const receiver = CallAudioOutput(
      type: 'Receiver',
      speaker: false,
      external: false,
    );
    const headphones = CallAudioOutput(
      type: 'Headphones',
      speaker: false,
      external: true,
    );
    const connected = CallInProgress(
      phase: CallPhase.connected,
      remoteName: 'Moussa',
    );

    ActiveCallSnapshot live(CallAudioOutput? output) => ActiveCallSnapshot(
      phase: CallPhase.connected,
      connectedAt: t0,
      audioOutput: output,
    );

    blocTest<CallBloc, CallState>(
      'le bouton suit la route réelle à chaque changement',
      build: build,
      seed: () => connected,
      act: (bloc) async {
        gateway.activeCallController.add(live(speaker));
        await Future<void>.delayed(Duration.zero);
        gateway.activeCallController.add(live(headphones));
        await Future<void>.delayed(Duration.zero);
        // Route inconnue : le bouton ne bouge pas.
        gateway.activeCallController.add(live(null));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', true),
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', false),
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', false),
      ],
      verify: (_) => expect(gateway.log, ['hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'au décroché, le bouton reflète la sortie courante',
      build: build,
      seed: () =>
          const CallInProgress(phase: CallPhase.connecting, remoteName: 'Awa'),
      act: (bloc) async {
        gateway.activeCallController.add(live(speaker));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallInProgress>()
            .having((s) => s.phase, 'phase', CallPhase.connected)
            .having((s) => s.speakerOn, 'speakerOn', true),
      ],
      verify: (_) => expect(gateway.log, ['hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'HP choisi pendant la sonnerie, casque branché : le casque garde le son',
      build: build,
      seed: () => const CallInProgress(
        phase: CallPhase.ringing,
        remoteName: 'Moussa',
        speakerOn: true,
      ),
      act: (bloc) async {
        gateway.activeCallController.add(live(headphones));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallInProgress>()
            .having((s) => s.phase, 'phase', CallPhase.connected)
            .having((s) => s.speakerOn, 'speakerOn', false),
      ],
      verify: (_) => expect(gateway.log, ['hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'HP choisi pendant la sonnerie, pas de casque : appliqué au décroché',
      build: build,
      seed: () => const CallInProgress(
        phase: CallPhase.ringing,
        remoteName: 'Moussa',
        speakerOn: true,
      ),
      act: (bloc) async {
        gateway.activeCallController.add(live(receiver));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallInProgress>()
            .having((s) => s.phase, 'phase', CallPhase.connected)
            .having((s) => s.speakerOn, 'speakerOn', true),
      ],
      verify: (_) => expect(gateway.log, ['speaker:true', 'hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'HP de sonnerie refusé au décroché : bouton remis sur la sortie réelle',
      build: build,
      setUp: () => gateway.throwOnSpeaker = StateError('Call not connected'),
      seed: () => const CallInProgress(
        phase: CallPhase.ringing,
        remoteName: 'Moussa',
        speakerOn: true,
      ),
      act: (bloc) async {
        gateway.activeCallController.add(live(receiver));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', true),
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', false),
      ],
      errors: () => isEmpty,
    );

    blocTest<CallBloc, CallState>(
      'couper le HP : la bascule est demandée et la route la confirme',
      build: build,
      seed: () => connected.copyWith(speakerOn: true),
      act: (bloc) async {
        bloc.add(const CallSpeakerToggleRequested());
        await Future<void>.delayed(Duration.zero);
        gateway.activeCallController.add(live(headphones));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', false),
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', false),
      ],
      verify: (_) => expect(gateway.log, ['speaker:false', 'hangUp']),
    );

    blocTest<CallBloc, CallState>(
      'couper le HP sans sortie disponible : le bouton revient sur HP',
      build: build,
      setUp: () => gateway.throwOnSpeaker = StateError('No audio output'),
      seed: () => connected.copyWith(speakerOn: true),
      act: (bloc) => bloc.add(const CallSpeakerToggleRequested()),
      expect: () => [
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', false),
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', true),
      ],
      errors: () => isEmpty,
    );

    blocTest<CallBloc, CallState>(
      'pendant la bascule, l\'ancienne route ne remet pas le bouton',
      build: build,
      setUp: () => gateway.speakerGate = Completer<void>(),
      seed: () => connected,
      act: (bloc) async {
        bloc.add(const CallSpeakerToggleRequested());
        await Future<void>.delayed(Duration.zero);
        gateway.activeCallController.add(live(receiver));
        await Future<void>.delayed(Duration.zero);
        gateway.speakerGate!.complete();
        await Future<void>.delayed(Duration.zero);
        gateway.activeCallController.add(live(speaker));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', true),
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', true),
        isA<CallInProgress>().having((s) => s.speakerOn, 'speakerOn', true),
      ],
      verify: (_) => expect(gateway.log, ['speaker:true', 'hangUp']),
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
    test('écran fermé pendant la création de l\'appel : sonnerie annulée, '
        'jamais rejoint', () async {
      final created = Completer<StartedCall>();
      when(() => repository.startCall('c1')).thenAnswer((_) => created.future);
      final bloc = build()..add(const CallStartRequested('c1', 'Moussa'));
      await Future<void>.delayed(Duration.zero);
      await bloc.close();
      created.complete(const StartedCall(callId: 'x1', callType: 'audio_call'));
      await Future<void>.delayed(Duration.zero);
      expect(gateway.log, contains('cancel:x1'));
      expect(gateway.log, isNot(contains('join:x1')));
    });

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

  group('tonalité de retour d\'appel (FLUTTER-9V)', () {
    late _FakeRingback ringback;
    setUp(() => ringback = _FakeRingback());
    CallBloc buildWithTone() =>
        CallBloc(repository, gateway, analytics, ringback: ringback);

    blocTest<CallBloc, CallState>(
      'joue pendant que ça sonne, se tait au décroché',
      build: buildWithTone,
      setUp: backStarts,
      act: (bloc) async {
        bloc.add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(Duration.zero);
        expect(ringback.log.last, 'start');
        gateway.activeCallController.add(
          ActiveCallSnapshot(phase: CallPhase.connected, connectedAt: t0),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) => expect(ringback.log, [
        'stop', // CallStarting
        'start', // ça sonne
        // Appel rejoint : Stream reconfigure la session audio, la tonalité
        // est relancée pour ne pas rester muette.
        'stop',
        'start',
        'stop', // décroché
        'dispose', // écran fermé
      ]),
    );

    blocTest<CallBloc, CallState>(
      'se tait quand l\'autre refuse',
      build: buildWithTone,
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
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) => expect(ringback.log.sublist(ringback.log.length - 2), [
        'stop',
        'dispose',
      ]),
    );

    blocTest<CallBloc, CallState>(
      'appel entrant décroché : jamais de tonalité',
      build: buildWithTone,
      act: (bloc) => bloc.add(const CallIncomingAcceptRequested('x9', 'Awa')),
      verify: (_) => expect(ringback.log, isNot(contains('start'))),
    );
  });

  // FLUTTER-DF : raccrocher pendant la création ou la connexion de l'appel.
  group('raccrocher pendant la mise en place', () {
    blocTest<CallBloc, CallState>(
      'pendant la connexion : la sonnerie ne réapparaît pas et l\'appel '
      'rejoint après coup est quitté',
      build: build,
      setUp: () {
        backStarts();
        gateway.joinGate = Completer<void>();
      },
      act: (bloc) async {
        bloc.add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CallHangUpRequested());
        await Future<void>.delayed(Duration.zero);
        gateway.joinGate!.complete();
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<CallStarting>(),
        isA<CallInProgress>(),
        isA<CallEnded>().having((s) => s.reason, 'reason', 'hangup'),
      ],
      verify: (_) => expect(gateway.log.where((e) => e == 'hangUp').length, 2),
    );

    blocTest<CallBloc, CallState>(
      'pendant la création par le back : l\'appel créé est annulé, sans '
      'sonnerie',
      build: build,
      setUp: () {
        final created = Completer<StartedCall>();
        when(
          () => repository.startCall('c1'),
        ).thenAnswer((_) => created.future);
        addTearDown(() {
          if (!created.isCompleted) {
            created.complete(
              const StartedCall(callId: 'x1', callType: 'audio_call'),
            );
          }
        });
        _pendingStart = created;
      },
      act: (bloc) async {
        bloc.add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CallHangUpRequested());
        await Future<void>.delayed(Duration.zero);
        _pendingStart!.complete(
          const StartedCall(callId: 'x1', callType: 'audio_call'),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [isA<CallStarting>(), isA<CallEnded>()],
      verify: (_) {
        expect(gateway.log, contains('cancel:x1'));
        expect(gateway.log, isNot(contains('join:x1')));
      },
    );
  });

  // FLUTTER-DF : une connexion qui traîne laissait sonner sans fin.
  group('sonnerie bornée', () {
    CallBloc buildQuick() => CallBloc(
      repository,
      gateway,
      analytics,
      ringTimeout: const Duration(milliseconds: 30),
    );

    blocTest<CallBloc, CallState>(
      'sans réponse après le délai : raccroché, « sans réponse »',
      build: buildQuick,
      setUp: backStarts,
      act: (bloc) async {
        bloc.add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      },
      expect: () => [
        isA<CallStarting>(),
        isA<CallInProgress>(),
        isA<CallEnded>().having((s) => s.reason, 'reason', 'missed'),
      ],
      verify: (_) => expect(gateway.log, contains('hangUp')),
    );

    blocTest<CallBloc, CallState>(
      'décroché avant le délai : l\'appel continue',
      build: buildQuick,
      setUp: backStarts,
      act: (bloc) async {
        bloc.add(const CallStartRequested('c1', 'Moussa'));
        await Future<void>.delayed(Duration.zero);
        gateway.activeCallController.add(
          ActiveCallSnapshot(phase: CallPhase.connected, connectedAt: t0),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
      },
      // Aucun CallEnded : le délai n'a pas raccroché un appel décroché.
      expect: () => [
        isA<CallStarting>(),
        isA<CallInProgress>().having(
          (s) => s.phase,
          'phase',
          CallPhase.ringing,
        ),
        isA<CallInProgress>().having(
          (s) => s.phase,
          'phase',
          CallPhase.connected,
        ),
      ],
      verify: (bloc) => expect(bloc.isLive, isTrue),
    );
  });

  test('isLive : faux au repos et après la fin', () async {
    final bloc = build();
    expect(bloc.isLive, isFalse);
    await bloc.close();
  });
}

Completer<StartedCall>? _pendingStart;
