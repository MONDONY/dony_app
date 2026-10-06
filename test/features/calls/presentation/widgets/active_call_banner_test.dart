import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/calls/bloc/active_call_holder.dart';
import 'package:dony/features/calls/bloc/call_bloc.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/presentation/call_screen.dart';
import 'package:dony/features/calls/presentation/widgets/active_call_banner.dart';
import 'package:dony/features/calls/presentation/widgets/call_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockCallBloc extends MockBloc<CallEvent, CallState>
    implements CallBloc {}

void main() {
  setUpAll(() => registerFallbackValue(const CallHangUpRequested()));

  late _MockCallBloc bloc;
  late ActiveCallHolder holder;
  late int factoryCalls;

  setUp(() {
    bloc = _MockCallBloc();
    when(() => bloc.isClosed).thenReturn(false);
    when(() => bloc.isLive).thenReturn(true);
    when(() => bloc.state).thenReturn(
      const CallInProgress(phase: CallPhase.ringing, remoteName: 'Moussa K.'),
    );
    factoryCalls = 0;
    holder = ActiveCallHolder(() {
      factoryCalls++;
      return bloc;
    });
  });

  Future<int> pumpBanner(WidgetTester tester) async {
    var returned = 0;
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: Column(
            children: [
              ActiveCallBanner(
                holder: holder,
                onReturnToCall: () => returned++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return returned;
  }

  group('ActiveCallBanner', () {
    testWidgets('aucun appel : rien', (tester) async {
      await pumpBanner(tester);
      expect(find.byKey(const ValueKey('active-call-banner')), findsNothing);
    });

    testWidgets('appel réduit en sonnerie : nom, statut, toucher = retour', (
      tester,
    ) async {
      holder.blocFor(null);
      var returned = 0;
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Column(
              children: [
                ActiveCallBanner(
                  holder: holder,
                  onReturnToCall: () => returned++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('active-call-banner')), findsOneWidget);
      expect(find.text('Moussa K.'), findsOneWidget);
      expect(find.text('Ça sonne…'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('active-call-banner')));
      expect(returned, 1);
    });

    testWidgets('décroché : chronomètre de l\'appel', (tester) async {
      when(() => bloc.state).thenReturn(
        CallInProgress(
          phase: CallPhase.connected,
          remoteName: 'Moussa K.',
          connectedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        ),
      );
      holder.blocFor(null);
      await pumpBanner(tester);

      expect(find.byType(CallTimer), findsOneWidget);
    });

    testWidgets('écran d\'appel affiché : la barre se masque', (tester) async {
      holder.blocFor(null);
      holder.callScreenVisible.value = true;
      await pumpBanner(tester);

      expect(find.byKey(const ValueKey('active-call-banner')), findsNothing);
    });

    testWidgets('appel terminé : la barre disparaît', (tester) async {
      when(() => bloc.isLive).thenReturn(false);
      when(() => bloc.state).thenReturn(const CallEnded(reason: 'hangup'));
      holder.blocFor(null);
      await pumpBanner(tester);

      expect(find.byKey(const ValueKey('active-call-banner')), findsNothing);
    });
  });

  group('ActiveCallScope', () {
    testWidgets('bloc obtenu une seule fois, même si la page est rebâtie ; '
        'présence de l\'écran signalée', (tester) async {
      const args = CallScreenArgs(remoteName: 'Moussa K.');
      Widget scope() => localizedApp(
        ActiveCallScope(
          key: const ValueKey('scope'),
          args: args,
          holder: holder,
        ),
      );

      await tester.pumpWidget(scope());
      await tester.pumpWidget(scope());
      expect(factoryCalls, 1);
      expect(holder.callScreenVisible.value, isTrue);
      expect(find.text('Ça sonne…'), findsOneWidget);

      await tester.pumpWidget(localizedApp(const SizedBox()));
      expect(holder.callScreenVisible.value, isFalse);
      verifyNever(bloc.close);
    });
  });

  test('CallTimer.format : mm:ss', () {
    final t0 = DateTime(2026, 10, 6, 12);
    expect(CallTimer.format(t0, t0.add(const Duration(seconds: 65))), '01:05');
  });
}
