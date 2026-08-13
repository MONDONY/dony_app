import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/screens/connect_onboarding_pending_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectOnboardingBloc
    extends MockBloc<ConnectOnboardingEvent, ConnectOnboardingState>
    implements ConnectOnboardingBloc {}

/// Duration long enough to let all flutter_animate delays complete.
const _kSettle = Duration(milliseconds: 600);

Widget _wrap(ConnectOnboardingBloc bloc) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<ConnectOnboardingBloc>.value(
            value: bloc,
            child: const ConnectOnboardingPendingScreen(),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    ),
  );
}

void main() {
  late MockConnectOnboardingBloc mockBloc;

  setUpAll(() {
    registerFallbackValue(const ConnectOnboardingPollingRequested());
  });

  setUp(() {
    mockBloc = MockConnectOnboardingBloc();
    whenListen<ConnectOnboardingState>(
      mockBloc,
      Stream.value(const ConnectOnboardingPending()),
      initialState: const ConnectOnboardingPending(),
    );
  });

  group('ConnectOnboardingPendingScreen', () {
    testWidgets('renders waiting message and title', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(_kSettle);

      expect(find.text('Vérification en cours'), findsOneWidget);
      expect(find.text('Vérification en cours...'), findsOneWidget);
    });

    testWidgets(
      'shows loading indicator when state is ConnectOnboardingLoading',
      (tester) async {
        whenListen<ConnectOnboardingState>(
          mockBloc,
          Stream.value(const ConnectOnboardingLoading()),
          initialState: const ConnectOnboardingLoading(),
        );

        await tester.pumpWidget(_wrap(mockBloc));
        await tester.pump(_kSettle);

        expect(find.byType(CircularProgressIndicator), findsWidgets);
      },
    );

    testWidgets(
      'navigates to /home when BloC emits ConnectOnboardingComplete',
      (tester) async {
        final controller = StreamController<ConnectOnboardingState>();

        whenListen<ConnectOnboardingState>(
          mockBloc,
          controller.stream,
          initialState: const ConnectOnboardingPending(),
        );

        await tester.pumpWidget(_wrap(mockBloc));
        await tester.pump(_kSettle);

        // Verify we're on the pending screen
        expect(find.text('Vérification en cours...'), findsOneWidget);

        // Emit complete state
        controller.add(const ConnectOnboardingComplete());
        await tester.pumpAndSettle();

        // Should have navigated to home
        expect(find.text('Home'), findsOneWidget);

        await controller.close();
      },
    );

    testWidgets('dispatches ConnectOnboardingPollingRequested on init', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(_kSettle);

      verify(
        () => mockBloc.add(const ConnectOnboardingPollingRequested()),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
