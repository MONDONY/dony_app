import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

const _testUser = UserModel(
  id: 'u1',
  roles: ['ROLE_TRAVELER', 'ROLE_SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

void main() {
  late MockAuthBloc mockBloc;

  setUp(() {
    mockBloc = MockAuthBloc();
  });

  tearDown(() => mockBloc.close());

  // Helper pour construire le widget avec un GoRouter de test
  Widget buildScreen(List<AuthState> states) {
    whenListen(
      mockBloc,
      Stream.fromIterable(states),
      initialState: const AuthOtpSent(
        verificationId: 'vid',
        phoneNumber: '+33600000000',
        secondsLeft: 60,
      ),
    );

    final router = GoRouter(
      initialLocation: '/auth/otp',
      routes: [
        GoRoute(
          path: '/auth/otp',
          builder: (_, __) => BlocProvider<AuthBloc>.value(
            value: mockBloc,
            child: const OtpVerificationScreen(),
          ),
        ),
        GoRoute(
          path: '/auth/local',
          builder: (_, __) => const Scaffold(body: Text('local-auth')),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets(
    'quand AuthOtpVerified est émis, dispatche AuthRegisterRequested',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildScreen([const AuthOtpVerified(phoneNumber: '+33600000000')]),
      );
      await tester.pump();
      verify(() => mockBloc.add(const AuthRegisterRequested())).called(1);
    },
  );

  testWidgets(
    'quand AuthAuthenticated est émis, navigue vers /auth/local',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildScreen([const AuthAuthenticated(_testUser)]));
      await tester.pumpAndSettle();
      expect(find.text('local-auth'), findsOneWidget);
    },
  );
}
