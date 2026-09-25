import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';
import 'package:dony/features/settings/presentation/screens/blocked_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class MockBlockedUsersBloc
    extends MockBloc<BlockedUsersEvent, BlockedUsersState>
    implements BlockedUsersBloc {}

Widget _wrap(BlockedUsersState state) {
  final mockBloc = MockBlockedUsersBloc();
  when(() => mockBloc.state).thenReturn(state);
  whenListen<BlockedUsersState>(
    mockBloc,
    const Stream.empty(),
    initialState: state,
  );
  return MaterialApp(
    home: BlocProvider<BlockedUsersBloc>.value(
      value: mockBloc,
      child: const BlockedUsersScreen(),
    ),
  );
}

BlockedUserModel _blockedAgo(Duration ago, {String displayName = 'Fatou D.'}) =>
    BlockedUserModel(
      userId: 'u1',
      displayName: displayName,
      blockedAt: DateTime.now().subtract(ago),
    );

void main() {
  // ── Dates relatives : fr (texte identique à l'ancien) ───────────────────────

  group('BlockedUsersScreen — dates relatives (fr)', () {
    testWidgets('aujourd\'hui', (tester) async {
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(Duration.zero)])),
      );
      await tester.pumpAndSettle();
      expect(find.text("Bloqué aujourd'hui"), findsOneWidget);
    });

    testWidgets('hier', (tester) async {
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 1))])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bloqué hier'), findsOneWidget);
    });

    testWidgets('3 jours', (tester) async {
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 3))])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bloqué il y a 3 jours'), findsOneWidget);
    });

    testWidgets('8 jours → 1 semaine', (tester) async {
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 8))])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bloqué il y a 1 semaine'), findsOneWidget);
    });

    testWidgets('20 jours → 2 semaines', (tester) async {
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 20))])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bloqué il y a 2 semaines'), findsOneWidget);
    });

    testWidgets('au-delà de 29 jours : date complète', (tester) async {
      final date = DateTime.now().subtract(const Duration(days: 40));
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 40))])),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Bloqué le ${DateFormat.yMMMd('fr').format(date)}'),
        findsOneWidget,
      );
    });
  });

  // ── Dates relatives : anglais ────────────────────────────────────────────

  group('BlockedUsersScreen — dates relatives (en)', () {
    testWidgets('today', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(Duration.zero)])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Blocked today'), findsOneWidget);
    });

    testWidgets('yesterday', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 1))])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Blocked yesterday'), findsOneWidget);
    });

    testWidgets('3 days', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 3))])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Blocked 3 days ago'), findsOneWidget);
    });

    testWidgets('8 days → 1 week', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 8))])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Blocked 1 week ago'), findsOneWidget);
    });

    testWidgets('20 days → 2 weeks', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 20))])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Blocked 2 weeks ago'), findsOneWidget);
    });

    testWidgets('beyond 29 days : full date', (tester) async {
      useEnglish();
      final date = DateTime.now().subtract(const Duration(days: 40));
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 40))])),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Blocked on ${DateFormat.yMMMd('en').format(date)}'),
        findsOneWidget,
      );
    });
  });

  // ── Écran : traductions générales (anglais), sert de test anglais pour
  // blocked_users_screen.dart en l'absence d'un autre fichier de test dédié ──

  group('BlockedUsersScreen — anglais (écran)', () {
    testWidgets('titre, bandeau et bouton Débloquer traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(BlockedUsersLoaded([_blockedAgo(const Duration(days: 3))])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blocked users'), findsOneWidget);
      expect(
        find.textContaining('A blocked person no longer sees your listings'),
        findsOneWidget,
      );
      expect(find.text('Unblock'), findsOneWidget);
    });

    testWidgets('état vide traduit', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap(const BlockedUsersLoaded([])));
      await tester.pumpAndSettle();

      expect(find.text("You haven't blocked anyone"), findsOneWidget);
      expect(find.text('People you block will appear here.'), findsOneWidget);
    });

    testWidgets('état d\'erreur traduit, avec réessayer', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap(const BlockedUsersError()));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load blocked users"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  // ── Nom de repli quand le serveur ne renvoie aucun displayName ──────────────

  group('Nom de repli utilisateur bloqué', () {
    test('BlockedUserModel.fromJson garde une chaîne vide', () {
      final model = BlockedUserModel.fromJson({
        'userId': 'u1',
        'blockedAt': '2026-05-20T00:00:00.000Z',
      });
      expect(model.displayName, '');
    });

    testWidgets('l\'écran affiche "Utilisateur" quand le nom est vide', (
      tester,
    ) async {
      final user = BlockedUserModel.fromJson({
        'userId': 'u1',
        'blockedAt': DateTime.now().toIso8601String(),
      });
      await tester.pumpWidget(_wrap(BlockedUsersLoaded([user])));
      await tester.pumpAndSettle();

      expect(find.text('Utilisateur'), findsOneWidget);
    });

    testWidgets('en anglais : "User"', (tester) async {
      useEnglish();
      final user = BlockedUserModel.fromJson({
        'userId': 'u1',
        'blockedAt': DateTime.now().toIso8601String(),
      });
      await tester.pumpWidget(_wrap(BlockedUsersLoaded([user])));
      await tester.pumpAndSettle();

      expect(find.text('User'), findsOneWidget);
    });
  });
}
