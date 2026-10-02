import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/calls/bloc/call_bloc.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/presentation/call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockCallBloc extends MockBloc<CallEvent, CallState>
    implements CallBloc {}

void main() {
  late _MockCallBloc bloc;
  late int closed;

  setUpAll(() => registerFallbackValue(const CallHangUpRequested()));

  setUp(() {
    bloc = _MockCallBloc();
    closed = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    CallState state, {
    Stream<CallState>? states,
  }) async {
    if (states != null) {
      whenListen(bloc, states, initialState: state);
    } else {
      when(() => bloc.state).thenReturn(state);
    }
    await tester.pumpWidget(
      localizedApp(
        BlocProvider<CallBloc>.value(
          value: bloc,
          child: CallScreen(
            args: const CallScreenArgs(remoteName: 'Moussa K.'),
            onClose: () => closed++,
          ),
        ),
      ),
    );
  }

  testWidgets('sonnerie : nom et « Ça sonne… »', (tester) async {
    await pump(
      tester,
      const CallInProgress(phase: CallPhase.ringing, remoteName: 'Moussa K.'),
    );
    expect(find.text('Moussa K.'), findsOneWidget);
    expect(find.text('Ça sonne…'), findsOneWidget);
  });

  testWidgets('demande en cours : « Connexion… »', (tester) async {
    await pump(tester, const CallStarting());
    expect(find.text('Connexion…'), findsOneWidget);
  });

  testWidgets('connecté : chronomètre qui avance', (tester) async {
    final start = DateTime.now().subtract(const Duration(seconds: 65));
    await pump(
      tester,
      CallInProgress(
        phase: CallPhase.connected,
        remoteName: 'Moussa K.',
        connectedAt: start,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining(RegExp(r'^01:0[5-7]$')), findsOneWidget);
  });

  testWidgets('micro, haut-parleur et raccrocher envoient leurs événements', (
    tester,
  ) async {
    await pump(
      tester,
      const CallInProgress(phase: CallPhase.connected, remoteName: 'Moussa K.'),
    );
    await tester.tap(find.bySemanticsLabel('Couper le micro'));
    await tester.tap(find.bySemanticsLabel('Haut-parleur'));
    await tester.tap(find.bySemanticsLabel('Raccrocher'));
    verify(() => bloc.add(any(that: isA<CallMuteToggleRequested>()))).called(1);
    verify(
      () => bloc.add(any(that: isA<CallSpeakerToggleRequested>())),
    ).called(1);
    verify(() => bloc.add(any(that: isA<CallHangUpRequested>()))).called(1);
  });

  testWidgets('micro coupé : le bouton propose de le réactiver', (
    tester,
  ) async {
    await pump(
      tester,
      const CallInProgress(
        phase: CallPhase.connected,
        remoteName: 'Moussa K.',
        muted: true,
      ),
    );
    expect(find.bySemanticsLabel('Réactiver le micro'), findsOneWidget);
  });

  testWidgets('refusé : « Appel refusé » puis fermeture', (tester) async {
    await pump(
      tester,
      const CallInProgress(phase: CallPhase.ringing, remoteName: 'Moussa K.'),
      states: Stream.value(const CallEnded(reason: 'rejected')),
    );
    await tester.pump();
    expect(find.text('Appel refusé'), findsOneWidget);
    expect(closed, 0);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(closed, 1);
  });

  testWidgets('pas de réponse : « Pas de réponse »', (tester) async {
    await pump(tester, const CallEnded(reason: 'missed'));
    expect(find.text('Pas de réponse'), findsOneWidget);
  });

  testWidgets('échec du back : message du catalogue puis fermeture', (
    tester,
  ) async {
    await pump(
      tester,
      const CallStarting(),
      states: Stream.value(
        const CallFailure(
          ConflictException('x', code: 'call-already-in-progress'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(closed, 1);
  });

  testWidgets('en anglais', (tester) async {
    enableEnglish();
    when(() => bloc.state).thenReturn(
      const CallInProgress(phase: CallPhase.ringing, remoteName: 'Moussa K.'),
    );
    await tester.pumpWidget(
      localizedApp(
        BlocProvider<CallBloc>.value(
          value: bloc,
          child: CallScreen(
            args: const CallScreenArgs(remoteName: 'Moussa K.'),
            onClose: () {},
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    expect(find.text('Ringing…'), findsOneWidget);
  });

  group('CallScreenArgs.initialEvent', () {
    test('sortant : lancer l\'appel depuis la conversation', () {
      final e = const CallScreenArgs(
        remoteName: 'Moussa',
        conversationId: 'c1',
      ).initialEvent;
      expect(
        e,
        isA<CallStartRequested>().having(
          (e) => e.conversationId,
          'conversationId',
          'c1',
        ),
      );
    });

    test('entrant : décrocher', () {
      final e = const CallScreenArgs(
        remoteName: 'Awa',
        incomingCallId: 'x2',
        acceptedNatively: true,
      ).initialEvent;
      expect(
        e,
        isA<CallIncomingAcceptRequested>()
            .having((e) => e.callId, 'callId', 'x2')
            .having((e) => e.acceptedNatively, 'acceptedNatively', true),
      );
    });

    test('sans conversation ni appel : rien', () {
      expect(const CallScreenArgs(remoteName: 'X').initialEvent, isNull);
    });
  });

  test('CallScreenArgs.incoming : décroché natif, rejoint à l\'ouverture', () {
    final args = CallScreenArgs.incoming(
      const IncomingCall(
        callId: 'x3',
        callerName: 'Awa D.',
        callerImageUrl: 'u',
        acceptedNatively: true,
      ),
    );
    expect(args.remoteName, 'Awa D.');
    expect(args.remoteAvatarUrl, 'u');
    expect(args.incomingCallId, 'x3');
    expect(
      args.initialEvent,
      isA<CallIncomingAcceptRequested>().having(
        (e) => e.acceptedNatively,
        'native',
        true,
      ),
    );
  });

  testWidgets(
    'micro refusé : explication, lien vers les réglages, pas de fermeture automatique',
    (tester) async {
      await pump(tester, const CallFailure(CallPermissionDeniedException()));
      expect(
        find.text('Autorisez le micro dans les réglages pour appeler.'),
        findsOneWidget,
      );
      expect(find.text('Ouvrir les réglages'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(closed, 0);

      await tester.tap(find.bySemanticsLabel('Raccrocher'));
      expect(closed, 1);
    },
  );

  testWidgets('deux fins successives : l\'écran ne se ferme qu\'une fois', (
    tester,
  ) async {
    await pump(
      tester,
      const CallInProgress(phase: CallPhase.ringing, remoteName: 'Moussa K.'),
      states: Stream.fromIterable(const [
        CallEnded(reason: 'rejected'),
        CallEnded(reason: 'hangup'),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(closed, 1);
  });

  group('route d\'un appel entrant (porte des liens profonds)', () {
    test('aller-retour par l\'URL : nom, avatar, décroché natif', () {
      final location = CallScreenArgs.incomingLocation(
        const IncomingCall(
          callId: 'abc-1',
          callerName: 'Awa D. & co',
          callerImageUrl: 'https://img/a.png?x=1',
          acceptedNatively: true,
        ),
      );
      final uri = Uri.parse(location);
      expect(uri.path, '/calls/abc-1');

      final args = CallScreenArgs.fromRoute('abc-1', uri.queryParameters);
      expect(args.remoteName, 'Awa D. & co');
      expect(args.remoteAvatarUrl, 'https://img/a.png?x=1');
      final event = args.initialEvent! as CallIncomingAcceptRequested;
      expect(event.callId, 'abc-1');
      expect(event.acceptedNatively, isTrue);
    });

    test('sans paramètres : aucun événement (route inconnue)', () {
      expect(CallScreenArgs.fromRoute('x', const {}).initialEvent, isNull);
    });
  });
}
