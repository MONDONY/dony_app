import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Widget _buildEmail({required AuthBloc bloc}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<AuthBloc>.value(
            value: bloc,
            child: const OtpVerificationScreen(
              mode: OtpMode.email,
              contact: 'user@example.com',
            ),
          ),
        ),
        GoRoute(path: '/onboarding/role', builder: (_, __) => const Scaffold(body: Text('Role Screen'))),
        GoRoute(path: '/auth/local', builder: (_, __) => const Scaffold(body: Text('Local Auth'))),
      ],
    ),
  );
}

void main() {
  late MockAuthBloc mockBloc;

  setUp(() {
    mockBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(AuthEmailOtpSent('user@example.com'));
  });

  testWidgets('mode email — affiche "Vérifie ton email" et l\'adresse', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Vérifie ton email'), findsOneWidget);
    expect(find.textContaining('user@example.com'), findsOneWidget);
  });

  testWidgets('mode email — dispatche AuthEmailOtpVerifyRequested sur vérifier', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pump();

    final fields = find.byType(TextFormField);
    for (int i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '$i');
    }
    await tester.tap(find.text('Vérifier'));

    verify(() => mockBloc.add(
          AuthEmailOtpVerifyRequested(email: 'user@example.com', code: '012345'),
        )).called(1);
  });

  testWidgets('mode email — navigue vers /onboarding/role quand AuthEmailOtpVerified', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    whenListen(
      mockBloc,
      Stream.fromIterable([const AuthLoading(), AuthEmailOtpVerified('user@example.com')]),
      initialState: AuthEmailOtpSent('user@example.com'),
    );
    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pumpAndSettle();

    expect(find.text('Role Screen'), findsOneWidget);
  });

  testWidgets('mode email — affiche le timer du state AuthEmailOtpSent', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => mockBloc.state).thenReturn(AuthEmailOtpSent('user@example.com', secondsLeft: 42));
    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('42'), findsOneWidget);
  });
}
