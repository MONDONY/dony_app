import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/auth_method_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Widget _app(AuthBloc bloc) => MaterialApp.router(
  theme: AppTheme.light(),
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const AuthMethodScreen(),
        ),
      ),
    ],
  ),
);

void main() {
  setUp(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  testWidgets('affiche la mascotte Yadony joyeuse à la place du papillon', (
    tester,
  ) async {
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final animated = tester.widget<DonyMascotteAnimated>(
      find.byType(DonyMascotteAnimated),
    );
    expect(animated.type, DonyMascotteType.joyeux);
    expect(animated.size, DonyMascotteSize.md);
    expect(find.byType(DonyHeroAvatar), findsNothing);
    expect(find.text('🦋'), findsNothing);

    await bloc.close();
  });

  testWidgets(
    'masque le bouton téléphone tant que le SMS OTP backend n\'est pas confirmé',
    (tester) async {
      final bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Continuer avec mon téléphone'), findsNothing);
      expect(find.text('Continuer avec Google'), findsOneWidget);

      await bloc.close();
    },
  );

  testWidgets(
    'affiche le bouton téléphone une fois le SMS OTP confirmé par le backend',
    (tester) async {
      setSmsAuthEnabled(true);
      final bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Continuer avec mon téléphone'), findsOneWidget);

      await bloc.close();
    },
  );
}
