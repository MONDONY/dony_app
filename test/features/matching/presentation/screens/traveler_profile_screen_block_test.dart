import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockFavoriteRepository extends Mock implements FavoriteRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Laisse les délais de flutter_animate se terminer.
const _kSettle = Duration(milliseconds: 600);

/// [withTraveler] : le backend ne renvoie pas toujours le profil du voyageur
/// avec l'annonce (réponse tronquée, cache ancien).
AnnouncementModel _announcement({bool withTraveler = true}) {
  final now = DateTime(2026, 7, 20);
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'traveler-001',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: now.add(const Duration(days: 10)),
    availableKg: 20,
    totalKg: 20,
    pricePerKg: 10,
    status: 'OPEN',
    createdAt: now,
    updatedAt: now,
    traveler: withTraveler
        ? const TravelerProfile(id: 'traveler-001', displayName: 'Awa Ndiaye')
        : null,
  );
}

UserModel _fakeUser(String id) => UserModel(
  id: id,
  phoneNumber: '+33600000001',
  roles: const ['ROLE_SENDER'],
  kycStatus: 'APPROVED',
  status: 'ACTIVE',
);

/// [authUserId] : compte connecté. `null` = pas d'AuthBloc dans l'arbre, cas
/// de la consultation par deep link avant résolution de la session.
Widget _wrap(
  AnnouncementModel announcement,
  FavoriteIdsCubit cubit, {
  String? authUserId,
}) {
  final app = BlocProvider<FavoriteIdsCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                TravelerProfileScreen(announcement: announcement),
          ),
        ],
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
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  group('TravelerProfileScreen — blocage du voyageur', () {
    late FavoriteIdsCubit cubit;
    late MockFavoriteRepository mockRepo;

    setUp(() {
      mockRepo = MockFavoriteRepository();
      cubit = FavoriteIdsCubit(mockRepo);
    });

    tearDown(() {
      cubit.close();
    });

    testWidgets('menu ⋯ présent et propose « Bloquer <nom du voyageur> »', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_announcement(), cubit, authUserId: 'sender-99'),
      );
      await tester.pump(_kSettle);

      expect(find.byTooltip("Plus d'options"), findsOneWidget);

      await tester.tap(find.byTooltip("Plus d'options"));
      await tester.pumpAndSettle();

      expect(find.text('Bloquer Awa Ndiaye'), findsOneWidget);
    });

    testWidgets('menu ⋯ absent sur son propre trajet', (tester) async {
      await tester.pumpWidget(
        _wrap(_announcement(), cubit, authUserId: 'traveler-001'),
      );
      await tester.pump(_kSettle);

      expect(find.byTooltip("Plus d'options"), findsNothing);
    });

    testWidgets(
      'menu ⋯ absent quand l\'annonce ne porte pas le profil du voyageur',
      (tester) async {
        // Sans TravelerProfile, aucun nom à afficher dans « Bloquer X » : on
        // n'invente pas de libellé.
        await tester.pumpWidget(
          _wrap(
            _announcement(withTraveler: false),
            cubit,
            authUserId: 'sender-99',
          ),
        );
        await tester.pump(_kSettle);

        expect(find.byTooltip("Plus d'options"), findsNothing);
      },
    );
  });
}
