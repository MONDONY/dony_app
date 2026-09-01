import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/widgets/sender_public_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

SenderPublicProfile _sender({
  bool kycVerified = true,
  double averageRating = 4.8,
  int totalRatings = 12,
}) => SenderPublicProfile(
  id: 'sender-1',
  displayName: 'Fatou Diallo',
  averageRating: averageRating,
  totalRatings: totalRatings,
  kycVerified: kycVerified,
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
}
