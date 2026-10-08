import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/widgets/sender_public_profile_sheet.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

SenderPublicProfile _sender({
  bool kycVerified = true,
  double averageRating = 4.8,
  int totalRatings = 12,
  int incidentCount = 0,
}) => SenderPublicProfile(
  id: 'sender-1',
  displayName: 'Fatou Diallo',
  averageRating: averageRating,
  totalRatings: totalRatings,
  kycVerified: kycVerified,
  incidentCount: incidentCount,
);

UserModel _fakeUser(String id) => UserModel(
  id: id,
  phoneNumber: '+33600000001',
  roles: const ['ROLE_TRAVELER'],
  kycStatus: 'APPROVED',
  status: 'ACTIVE',
);

/// [authUserId] : identifiant du compte connecté. `null` = pas d'AuthBloc dans
/// l'arbre, ce que la feuille doit tolérer (elle est ouverte depuis la
/// recherche, où la session peut ne pas être encore résolue).
Widget _buildApp(SenderPublicProfile sender, {String? authUserId}) {
  final app = MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          key: const Key('open'),
          onPressed: () => showSenderPublicProfileSheet(ctx, sender),
          child: const Text('Ouvrir'),
        ),
      ),
    ),
  );

  if (authUserId == null) return app;

  final authBloc = MockAuthBloc();
  final state = AuthAuthenticated(_fakeUser(authUserId));
  when(() => authBloc.state).thenReturn(state);
  when(() => authBloc.stream).thenAnswer((_) => Stream.value(state));
  return BlocProvider<AuthBloc>.value(value: authBloc, child: app);
}

void main() {
  group('SenderPublicProfileSheet', () {
    testWidgets('fiabilité de l expéditeur affichée (FLUTTER-E0/E6)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_sender(incidentCount: 1)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('1 annulation ou absence'), findsOneWidget);
    });

    testWidgets('fiabilité masquée à zéro', (tester) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sender-reliability-label')), findsNothing);
    });

    testWidgets('shows "Profil expéditeur" title', (tester) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Profil expéditeur'), findsOneWidget);
    });

    testWidgets('shows sender display name', (tester) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Fatou Diallo'), findsWidgets);
    });

    testWidgets('shows "Identité vérifiée" when kycVerified=true', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Identité vérifiée'), findsOneWidget);
    });

    testWidgets('hides "Identité vérifiée" when kycVerified=false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_sender(kycVerified: false)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Identité vérifiée'), findsNothing);
    });

    testWidgets('shows average rating and review count when totalRatings > 0', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('· 12 avis'), findsOneWidget);
    });

    testWidgets('shows "Nouveau membre" when totalRatings = 0', (tester) async {
      await tester.pumpWidget(_buildApp(_sender(totalRatings: 0)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau membre'), findsOneWidget);
    });
  });

  group('SenderPublicProfileSheet — blocage', () {
    testWidgets('menu ⋯ présent et propose « Bloquer <nom> »', (tester) async {
      await tester.pumpWidget(_buildApp(_sender(), authUserId: 'traveler-99'));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.byTooltip("Plus d'options"), findsOneWidget);

      await tester.tap(find.byTooltip("Plus d'options"));
      await tester.pumpAndSettle();

      expect(find.text('Bloquer Fatou Diallo'), findsOneWidget);
    });

    testWidgets('menu ⋯ absent quand on consulte son propre profil', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_sender(), authUserId: 'sender-1'));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.byTooltip("Plus d'options"), findsNothing);
    });

    testWidgets('menu ⋯ absent pour un expéditeur sans identifiant (invité)', (
      tester,
    ) async {
      // SenderPublicProfile.guest ne porte pas d'id : rien à bloquer.
      await tester.pumpWidget(
        _buildApp(SenderPublicProfile.guest('Fatou Diallo')),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.byTooltip("Plus d'options"), findsNothing);
    });
  });

  group('SenderPublicProfileSheet — anglais', () {
    testWidgets('titre, identité vérifiée et avis traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(_buildApp(_sender()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Sender profile'), findsOneWidget);
      expect(find.text('Verified identity'), findsOneWidget);
      expect(find.text('· 12 reviews'), findsOneWidget);
    });

    testWidgets('« Nouveau membre » devient « New member »', (tester) async {
      useEnglish();
      await tester.pumpWidget(_buildApp(_sender(totalRatings: 0)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('New member'), findsOneWidget);
    });

    testWidgets('nom de repli « Yadony user » sans displayName', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(_buildApp(SenderPublicProfile.guest(null)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Yadony user'), findsWidgets);
    });
  });

  // FLUTTER-EB : le résumé n'avait ni « S'abonner » ni avis. « Voir le
  // profil » mène au profil public complet qui les porte.
  group('SenderPublicProfileSheet — voir le profil (FLUTTER-EB)', () {
    const button = Key('sender-profile-open-full');

    testWidgets('bouton visible pour le profil d\'un autre', (tester) async {
      await tester.pumpWidget(_buildApp(_sender(), authUserId: 'traveler-99'));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(button), findsOneWidget);
      expect(find.text('Voir le profil'), findsOneWidget);
    });

    testWidgets('bouton absent sur mon propre profil', (tester) async {
      await tester.pumpWidget(_buildApp(_sender(), authUserId: 'sender-1'));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(button), findsNothing);
    });

    testWidgets('bouton absent pour un invité sans identifiant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(SenderPublicProfile.guest('Fatou Diallo')),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(button), findsNothing);
    });

    testWidgets('anglais : « View profile »', (tester) async {
      useEnglish();
      await tester.pumpWidget(_buildApp(_sender(), authUserId: 'traveler-99'));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('View profile'), findsOneWidget);
    });

    testWidgets('ferme la feuille et ouvre /profile/public sur l\'expéditeur', (
      tester,
    ) async {
      Object? pushedExtra;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showSenderPublicProfileSheet(ctx, _sender()),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/profile/public',
            builder: (_, state) {
              pushedExtra = state.extra;
              return const Scaffold(body: Text('profil public'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();

      expect(find.text('profil public'), findsOneWidget);
      expect(find.text('Profil expéditeur'), findsNothing);
      expect(pushedExtra, isA<ProfilePublicArgs>());
      expect((pushedExtra! as ProfilePublicArgs).userId, 'sender-1');
    });
  });
}
