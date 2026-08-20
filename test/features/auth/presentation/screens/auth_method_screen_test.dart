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
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Recherche avec carte')),
      ),
    ],
  ),
);

void main() {
  setUp(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  testWidgets('affiche le logo Yadony et les messages rassurants', (
    tester,
  ) async {
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(DonyLogo), findsOneWidget);
    expect(find.text('Sécurisé'), findsOneWidget);
    expect(find.text('Connecte-toi en toute confiance'), findsOneWidget);
    expect(
      find.text(
        'Tes échanges, ton paiement et ton suivi colis sont protégés à chaque étape.',
      ),
      findsOneWidget,
    );
    expect(find.text('Parcourir sans compte'), findsOneWidget);
    expect(
      find.text(
        'Accès limité : recherche uniquement. Connexion requise pour publier, contacter, réserver ou payer.',
      ),
      findsOneWidget,
    );
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
      expect(find.text('Continuer avec mon email'), findsOneWidget);
      expect(find.text('Parcourir sans compte'), findsOneWidget);

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

  testWidgets('Parcourir sans compte ouvre la vraie recherche avec carte', (
    tester,
  ) async {
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Parcourir sans compte'));
    await tester.pumpAndSettle();

    expect(find.text('Recherche avec carte'), findsOneWidget);

    await bloc.close();
  });
}
