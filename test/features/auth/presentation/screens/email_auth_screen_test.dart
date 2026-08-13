import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Widget _wrap(Widget child, {required AuthBloc bloc}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              BlocProvider<AuthBloc>.value(value: bloc, child: child),
        ),
        GoRoute(
          path: '/auth/email-otp',
          builder: (_, _) => const Scaffold(body: Text('OTP Screen')),
        ),
      ],
    ),
  );
}

void main() {
  late MockAuthBloc mockBloc;

  setUp(() {
    mockBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(const AuthInitial());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche le champ email et le bouton désactivé à vide', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Envoyer le code'), findsOneWidget);
    final btn = tester.widget<DonyButton>(find.byType(DonyButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('active le bouton quand un email valide est saisi', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.pump();

    final btn = tester.widget<DonyButton>(find.byType(DonyButton));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('dispatche AuthEmailOtpSendRequested sur submit', (tester) async {
    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.pump();
    await tester.tap(find.text('Envoyer le code'));

    verify(
      () => mockBloc.add(const AuthEmailOtpSendRequested('user@example.com')),
    ).called(1);
  });

  testWidgets('navigue vers /auth/email-otp quand AuthEmailOtpSent émis', (
    tester,
  ) async {
    whenListen(
      mockBloc,
      Stream.fromIterable([
        const AuthLoading(),
        const AuthEmailOtpSent('user@example.com'),
      ]),
      initialState: const AuthInitial(),
    );

    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();

    expect(find.text('OTP Screen'), findsOneWidget);
  });
}
