import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/presentation/screens/publish_intro_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

UserModel _user({required String kycStatus}) => UserModel.fromJson({
  'id': 'u1',
  'roles': const ['SENDER', 'TRAVELER'],
  'kycStatus': kycStatus,
});

late List<String> visited;

Future<void> _pump(
  WidgetTester tester, {
  required PublishIntroRole role,
  required String kycStatus,
  String stripeStatus = 'ONBOARDING_COMPLETE',
  bool connectAvailable = true,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  if (!getIt.isRegistered<AnalyticsService>()) {
    final analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
  }
  addTearDown(getIt.reset);

  visited = [];
  final authBloc = _MockAuthBloc();
  when(
    () => authBloc.state,
  ).thenReturn(AuthAuthenticated(_user(kycStatus: kycStatus)));

  final stripeBloc = _MockStripeAccountBloc();
  when(() => stripeBloc.state).thenReturn(
    StripeAccountReady(
      ConnectAccountStatus.fromJson({
        'stripeAccountStatus': stripeStatus,
        'connectAvailableInCountry': connectAvailable,
      }),
    ),
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
          ],
          child: PublishIntroScreen(role: role),
        ),
      ),
      GoRoute(
        path: '/connect/onboarding/intro',
        builder: (_, _) {
          visited.add('/connect/onboarding/intro');
          return const Scaffold(body: Text('Onboarding Stripe'));
        },
      ),
      GoRoute(
        path: '/trips/create',
        builder: (_, _) {
          visited.add('/trips/create');
          return const Scaffold(body: Text('Formulaire trajet'));
        },
      ),
      GoRoute(
        path: '/package-requests/new',
        builder: (_, _) {
          visited.add('/package-requests/new');
          return const Scaffold(body: Text('Wizard colis'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('PublishIntroScreen — trajet', () {
    testWidgets(
      'vérifié : titre, engagements voyageur, callout vert, Continuer',
      (tester) async {
        await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

        expect(find.text('Publier un trajet'), findsOneWidget);
        expect(find.text('Vos engagements de voyageur'), findsOneWidget);
        expect(find.textContaining('Identité vérifiée'), findsOneWidget);
        expect(find.text('Continuer'), findsOneWidget);
        expect(find.text('Vérifier mon identité'), findsNothing);
      },
    );

    testWidgets('non vérifié : bouton Vérifier + invite, pas de Continuer', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'NOT_STARTED',
      );

      expect(find.text('Vérifier mon identité'), findsOneWidget);
      expect(find.textContaining('Le bouton devient'), findsOneWidget);
      expect(find.text('Continuer'), findsNothing);
      expect(
        find.textContaining('identité doit être vérifiée'),
        findsOneWidget,
      );
    });

    testWidgets('vérifié : Continuer ouvre le formulaire de trajet', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(visited, contains('/trips/create'));
    });

    testWidgets('rappel Stripe visible si compte non configuré, et navigue', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        stripeStatus: 'NOT_CREATED',
      );

      expect(find.text('Activez les paiements par carte'), findsOneWidget);

      await tester.tap(find.text('Activez les paiements par carte'));
      await tester.pumpAndSettle();

      expect(visited, contains('/connect/onboarding/intro'));
    });

    testWidgets('rappel Stripe masqué si compte déjà opérationnel', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

      expect(find.text('Activez les paiements par carte'), findsNothing);
    });

    testWidgets('rappel Stripe masqué si Stripe ne couvre pas le pays', (
      tester,
    ) async {
      // Compte non configuré, donc le rappel s'afficherait normalement : c'est
      // bien le pays qui le masque. Un tap ne pourrait jamais convertir.
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        stripeStatus: 'NOT_CREATED',
        connectAvailable: false,
      );

      expect(find.text('Activez les paiements par carte'), findsNothing);
    });
  });

  group('PublishIntroScreen — colis', () {
    testWidgets('vérifié : titre, engagements expéditeur, Continuer', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      expect(find.text('Publier un colis'), findsOneWidget);
      expect(find.text('Vos engagements d\'expéditeur'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      // Le rappel Stripe est réservé au voyageur : absent côté expéditeur.
      expect(find.text('Activez les paiements par carte'), findsNothing);
    });

    testWidgets('vérifié : Continuer ouvre le wizard de demande d\'envoi', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(visited, contains('/package-requests/new'));
    });
  });
}
