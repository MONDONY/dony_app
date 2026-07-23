import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/presentation/screens/publish_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

UserModel _user({required String kycStatus}) => UserModel.fromJson({
      'id': 'u1',
      'roles': ['SENDER', 'TRAVELER'],
      'kycStatus': kycStatus,
    });

late List<String> visited;

Future<void> _pump(
  WidgetTester tester, {
  required PublishIntroRole role,
  required String kycStatus,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  visited = [];
  final authBloc = _MockAuthBloc();
  when(() => authBloc.state).thenReturn(AuthAuthenticated(_user(kycStatus: kycStatus)));

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: PublishIntroScreen(role: role),
        ),
      ),
      GoRoute(
        path: '/trips/create',
        builder: (_, __) {
          visited.add('/trips/create');
          return const Scaffold(body: Text('Formulaire trajet'));
        },
      ),
      GoRoute(
        path: '/package-requests/new',
        builder: (_, __) {
          visited.add('/package-requests/new');
          return const Scaffold(body: Text('Wizard colis'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('PublishIntroScreen — trajet', () {
    testWidgets('vérifié : titre, engagements voyageur, callout vert, Continuer',
        (tester) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

      expect(find.text('Publier un trajet'), findsOneWidget);
      expect(find.text('Vos engagements de voyageur'), findsOneWidget);
      expect(find.textContaining('Identité vérifiée'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.text('Vérifier mon identité'), findsNothing);
    });

    testWidgets('non vérifié : bouton Vérifier + invite, pas de Continuer',
        (tester) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'NOT_STARTED',
      );

      expect(find.text('Vérifier mon identité'), findsOneWidget);
      expect(find.textContaining('Le bouton devient'), findsOneWidget);
      expect(find.text('Continuer'), findsNothing);
      expect(find.textContaining('identité doit être vérifiée'), findsOneWidget);
    });

    testWidgets('vérifié : Continuer ouvre le formulaire de trajet',
        (tester) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(visited, contains('/trips/create'));
    });
  });

  group('PublishIntroScreen — colis', () {
    testWidgets('vérifié : titre, engagements expéditeur, Continuer',
        (tester) async {
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      expect(find.text('Envoyer un colis'), findsOneWidget);
      expect(find.text('Vos engagements d\'expéditeur'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('vérifié : Continuer ouvre le wizard de demande d\'envoi',
        (tester) async {
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(visited, contains('/package-requests/new'));
    });
  });
}
