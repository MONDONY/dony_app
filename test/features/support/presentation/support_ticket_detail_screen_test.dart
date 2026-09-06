import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:dony/features/support/presentation/screens/support_ticket_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockSupportBloc extends MockBloc<SupportEvent, SupportState>
    implements SupportBloc {}

class MockSupportRepository extends Mock implements SupportRepository {}

const _userMessage = SupportMessage(
  id: 'message-1',
  authorType: 'USER',
  content: 'Bonjour, mon paiement est bloque.',
);

const _adminMessage = SupportMessage(
  id: 'message-2',
  authorType: 'ADMIN',
  content: 'Bonjour, on regarde ca tout de suite.',
);

const _openTicket = SupportTicket(
  id: 'ticket-1',
  category: 'PAYMENT',
  subject: 'Paiement bloque',
  status: SupportTicketStatuses.waitingUser,
  messages: [_userMessage, _adminMessage],
);

const _openTicketWithUnread = SupportTicket(
  id: 'ticket-1',
  category: 'PAYMENT',
  subject: 'Paiement bloque',
  status: SupportTicketStatuses.waitingUser,
  messages: [_userMessage, _adminMessage],
  unreadCount: 2,
);

const _resolvedTicket = SupportTicket(
  id: 'ticket-1',
  category: 'PAYMENT',
  subject: 'Paiement bloque',
  status: SupportTicketStatuses.resolved,
  messages: [_userMessage, _adminMessage],
);

Widget _harness(SupportBloc bloc) {
  final router = GoRouter(
    initialLocation: '/support/tickets/ticket-1',
    routes: [
      GoRoute(
        path: '/support/tickets/:id',
        builder: (_, state) => BlocProvider<SupportBloc>.value(
          value: bloc,
          child: SupportTicketDetailScreen(
            ticketId: state.pathParameters['id']!,
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late MockSupportBloc bloc;

  setUp(() {
    bloc = MockSupportBloc();
  });

  void stubState(SupportState state) {
    whenListen(bloc, const Stream<SupportState>.empty(), initialState: state);
  }

  // ---------------------------------------------------------------------------
  // Groupe dédié au décrément one-shot de la pastille (Task 10 — fix critique)
  // ---------------------------------------------------------------------------
  group('décrément de la pastille SupportUnreadCubit', () {
    late SupportUnreadCubit unreadCubit;
    late MockSupportRepository mockRepo;

    setUp(() async {
      mockRepo = MockSupportRepository();
      unreadCubit = SupportUnreadCubit(mockRepo);
      // Seed du cubit à 2 non-lus (= unreadCount du ticket).
      when(() => mockRepo.loadUnreadCount()).thenAnswer((_) async => 2);
      await unreadCubit.refresh();

      if (getIt.isRegistered<SupportUnreadCubit>()) {
        getIt.unregister<SupportUnreadCubit>();
      }
      getIt.registerSingleton<SupportUnreadCubit>(unreadCubit);
    });

    tearDown(() async {
      if (getIt.isRegistered<SupportUnreadCubit>()) {
        getIt.unregister<SupportUnreadCubit>();
      }
      await unreadCubit.close();
    });

    testWidgets('decrementBy est appelé exactement une fois meme si le BLoC emet '
        'plusieurs etats ready (cycle send)', (tester) async {
      // Le BLoC part d'un état `loading` et émet deux fois `ready` pour
      // simuler : (1) chargement initial, (2) rechargement après envoi de
      // réponse. Sans le fix, le 2e état `ready` déclencherait un 2e décrément.
      const loadingState = SupportState(
        detailStatus: SupportViewStatus.loading,
      );
      const readyState = SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _openTicketWithUnread,
      );
      final controller = StreamController<SupportState>();
      whenListen(bloc, controller.stream, initialState: loadingState);

      await tester.pumpWidget(_harness(bloc));
      await tester.pump();

      // Pastille encore intacte : l'état est `loading`.
      expect(unreadCubit.state, 2);

      // Premier passage à ready → décrément unique.
      controller.add(readyState);
      await tester.pumpAndSettle();

      expect(unreadCubit.state, 0);

      // Recharge le compteur à 3 pour vérifier que le 2e ready ne le retouche pas.
      when(() => mockRepo.loadUnreadCount()).thenAnswer((_) async => 3);
      await unreadCubit.refresh();
      expect(unreadCubit.state, 3);

      // Deuxième passage à ready (même contenu) → le flag doit bloquer.
      controller.add(readyState);
      await tester.pumpAndSettle();

      expect(unreadCubit.state, 3); // inchangé — le décrément n'a pas rejoué

      await controller.close();
    });

    testWidgets('decrementBy n est pas appele si unreadCount vaut 0', (
      tester,
    ) async {
      // Ticket sans non-lus : le cubit reste inchangé.
      when(() => mockRepo.loadUnreadCount()).thenAnswer((_) async => 5);
      await unreadCubit.refresh();
      expect(unreadCubit.state, 5);

      stubState(
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _openTicket, // unreadCount = 0
        ),
      );

      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();

      // Le cubit reste à 5 : aucun décrément déclenché.
      expect(unreadCubit.state, 5);
    });
  });

  testWidgets('affiche le fil de messages des deux auteurs', (tester) async {
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _openTicket,
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Paiement bloque'), findsOneWidget); // titre app bar
    expect(find.text('Bonjour, mon paiement est bloque.'), findsOneWidget);
    expect(find.text('Bonjour, on regarde ca tout de suite.'), findsOneWidget);
    expect(find.text('Support Yadony'), findsOneWidget);
  });

  testWidgets('propose le champ de réponse quand le ticket est ouvert', (
    tester,
  ) async {
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _openTicket,
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Votre message'), findsOneWidget);
    expect(find.byTooltip('Envoyer'), findsOneWidget);
  });

  testWidgets('masque la saisie sur un ticket résolu', (tester) async {
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _resolvedTicket,
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Votre message'), findsNothing);
    expect(find.byTooltip('Envoyer'), findsNothing);
    expect(find.textContaining('Ce ticket est résolu'), findsOneWidget);
    // DonyBadge rend son libellé en majuscules.
    expect(find.text('RÉSOLU'), findsOneWidget);
  });

  testWidgets("affiche l'erreur avec Réessayer quand le ticket ne charge pas", (
    tester,
  ) async {
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.failure,
        errorMessage: 'Ticket support introuvable',
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Ticket introuvable'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
