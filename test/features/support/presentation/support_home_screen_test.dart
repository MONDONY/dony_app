import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class MockSupportBloc extends MockBloc<SupportEvent, SupportState>
    implements SupportBloc {}

const _reply = SupportPredefinedReply(
  code: 'payment-when-charged',
  category: 'PAYMENT',
  question: 'A quel moment suis-je debite ?',
  answer: 'Vous etes debite quand le voyageur accepte votre offre.',
);

const _ticket = SupportTicket(
  id: 'ticket-1',
  category: 'PAYMENT',
  subject: 'Paiement bloque',
  status: SupportTicketStatuses.waitingUser,
);

Widget _harness(SupportBloc bloc) {
  final router = GoRouter(
    initialLocation: '/support',
    routes: [
      GoRoute(
        path: '/support',
        builder: (_, _) => BlocProvider<SupportBloc>.value(
          value: bloc,
          child: const SupportHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/support/tickets/:id',
        builder: (_, _) => const Scaffold(body: Text('detail-stub')),
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

  testWidgets('affiche les réponses prédéfinies et déplie la réponse', (
    tester,
  ) async {
    stubState(
      const SupportState(
        homeStatus: SupportViewStatus.ready,
        replies: [_reply],
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Questions fréquentes'), findsOneWidget);
    expect(find.text('A quel moment suis-je debite ?'), findsOneWidget);

    await tester.tap(find.text('A quel moment suis-je debite ?'));
    await tester.pumpAndSettle();

    expect(
      find.text('Vous etes debite quand le voyageur accepte votre offre.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche le CTA de contact et ouvre la sheet de création', (
    tester,
  ) async {
    stubState(const SupportState(homeStatus: SupportViewStatus.ready));

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Contacter le support'), findsOneWidget);

    await tester.tap(find.text('Contacter le support'));
    await tester.pumpAndSettle();

    expect(find.text('Catégorie'), findsOneWidget);
    expect(find.text('Sujet'), findsOneWidget);
    expect(find.text('Envoyer'), findsOneWidget);
  });

  // Régression Sentry FLUTTER-18 (puis 17, 19, 1A en cascade) : après la
  // création du ticket, la sheet est refermée et le clavier se replie pendant
  // son animation de sortie. Ce repli rebâtit les champs de la sheet : leurs
  // contrôleurs, disposés dès la fermeture, faisaient planter la frame.
  testWidgets(
    'survit au repli du clavier pendant la fermeture de la sheet de création',
    (tester) async {
      final states = StreamController<SupportState>();
      addTearDown(states.close);
      const ready = SupportState(homeStatus: SupportViewStatus.ready);
      whenListen(bloc, states.stream, initialState: ready);

      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contacter le support'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Sujet'), 'Sujet');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pump();

      states.add(
        const SupportState(
          homeStatus: SupportViewStatus.ready,
          createStatus: SupportActionStatus.success,
          createdTicketId: 'ticket-1',
        ),
      );
      await tester.pump();
      // Le clavier se replie alors que la sheet est encore à l'écran.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('detail-stub'), findsOneWidget);
    },
  );

  testWidgets('affiche la liste des tickets avec statut traduit', (
    tester,
  ) async {
    stubState(
      const SupportState(
        homeStatus: SupportViewStatus.ready,
        tickets: [_ticket],
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Mes tickets'), findsOneWidget);
    expect(find.text('Paiement bloque'), findsOneWidget);
    // DonyBadge rend son libellé en majuscules.
    expect(find.text('RÉPONSE REÇUE'), findsOneWidget);
    expect(find.text('Paiement'), findsOneWidget);
  });

  testWidgets("affiche l'état d'erreur avec un bouton Réessayer", (
    tester,
  ) async {
    stubState(
      const SupportState(
        homeStatus: SupportViewStatus.failure,
        failure: SupportFailure.generic,
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger le support'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('anglais : titre, tickets et CTA traduits', (tester) async {
    useEnglish();
    stubState(
      const SupportState(
        homeStatus: SupportViewStatus.ready,
        tickets: [_ticket],
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Support'), findsOneWidget);
    expect(find.text('My tickets'), findsOneWidget);
    // DonyBadge rend son libellé en majuscules.
    expect(find.text('REPLY RECEIVED'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    // Avec une conversation, le bouton fixe devient « New request ».
    expect(find.text('New request'), findsOneWidget);
  });

  group('aperçu du dernier message dans la carte ticket', () {
    const withPreview = SupportTicket(
      id: 'ticket-3',
      category: 'PAYMENT',
      subject: 'Paiement bloque',
      status: SupportTicketStatuses.waitingUser,
      lastMessagePreview: 'Pouvez-vous envoyer une photo ?',
      lastMessageFromAdmin: true,
      unreadCount: 1,
    );

    testWidgets('affiche l aperçu préfixé et le point de non-lu', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      stubState(
        const SupportState(
          homeStatus: SupportViewStatus.ready,
          tickets: [withPreview],
        ),
      );

      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();

      expect(
        find.text('Yadony : Pouvez-vous envoyer une photo ?'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('support-ticket-unread-dot')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('1 message non lu')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('message de l utilisateur, tout lu : « Vous : », sans point', (
      tester,
    ) async {
      stubState(
        const SupportState(
          homeStatus: SupportViewStatus.ready,
          tickets: [
            SupportTicket(
              id: 'ticket-4',
              category: 'PAYMENT',
              subject: 'Paiement bloque',
              status: SupportTicketStatuses.waitingSupport,
              lastMessagePreview: 'Merci',
            ),
          ],
        ),
      );

      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Vous : Merci'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('support-ticket-unread-dot')),
        findsNothing,
      );
    });

    testWidgets('ancien back : pas de ligne d aperçu', (tester) async {
      stubState(
        const SupportState(
          homeStatus: SupportViewStatus.ready,
          tickets: [_ticket],
        ),
      );

      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();

      expect(find.textContaining('Yadony :'), findsNothing);
      expect(find.textContaining('Vous :'), findsNothing);
    });
  });

  group('écran avec des conversations', () {
    SupportTicket ticket(
      String id, {
      String status = SupportTicketStatuses.waitingSupport,
      DateTime? lastAt,
      DateTime? createdAt,
    }) => SupportTicket(
      id: id,
      category: 'PAYMENT',
      subject: 'Sujet $id',
      status: status,
      lastMessageAt: lastAt,
      createdAt: createdAt,
    );

    final replies = List.generate(
      6,
      (i) => SupportPredefinedReply(
        code: 'q$i',
        category: 'PAYMENT',
        question: 'Question fréquente $i',
        answer: 'Réponse $i',
      ),
    );

    testWidgets('non résolues d abord, puis par dernier message', (
      tester,
    ) async {
      stubState(
        SupportState(
          homeStatus: SupportViewStatus.ready,
          tickets: [
            ticket(
              'resolu',
              status: SupportTicketStatuses.resolved,
              lastAt: DateTime(2026, 9, 28),
            ),
            ticket('ancien', lastAt: DateTime(2026, 9, 20)),
            ticket('recent', lastAt: DateTime(2026, 9, 27)),
          ],
        ),
      );

      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();

      final recent = tester.getTopLeft(find.text('Sujet recent')).dy;
      final old = tester.getTopLeft(find.text('Sujet ancien')).dy;
      final resolved = tester.getTopLeft(find.text('Sujet resolu')).dy;
      expect(recent, lessThan(old));
      expect(old, lessThan(resolved));
    });

    testWidgets('les conversations passent avant l assistant, conservé', (
      tester,
    ) async {
      stubState(
        SupportState(
          homeStatus: SupportViewStatus.ready,
          replies: replies,
          tickets: [ticket('a')],
        ),
      );

      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Mes tickets')).dy,
        lessThan(tester.getTopLeft(find.text('Sujet a')).dy),
      );
      await tester.scrollUntilVisible(find.text('Questions fréquentes'), 200);
      expect(find.text('Questions fréquentes'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Sujet a')).dy,
        lessThan(tester.getTopLeft(find.text('Questions fréquentes')).dy),
      );
    });

    for (final count in [1, 3]) {
      testWidgets(
        '« Nouvelle demande » visible sans défiler avec $count conversation(s)',
        (tester) async {
          stubState(
            SupportState(
              homeStatus: SupportViewStatus.ready,
              replies: replies,
              tickets: [for (var i = 0; i < count; i++) ticket('t$i')],
            ),
          );

          await tester.pumpWidget(_harness(bloc));
          await tester.pumpAndSettle();

          expect(find.text('Nouvelle demande').hitTestable(), findsOneWidget);
          // L ancien bouton en bas de liste n existe plus dans ce cas.
          expect(find.text('Contacter le support'), findsNothing);

          // Le bouton reste en place après un défilement de la liste.
          await tester.drag(find.byType(ListView), const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(find.text('Nouvelle demande').hitTestable(), findsOneWidget);

          await tester.tap(find.text('Nouvelle demande'));
          await tester.pumpAndSettle();
          expect(find.text('Catégorie'), findsOneWidget);
          expect(find.text('Envoyer'), findsOneWidget);
        },
      );
    }

    testWidgets('sans conversation : pas de bouton fixe, écran inchangé', (
      tester,
    ) async {
      stubState(
        SupportState(homeStatus: SupportViewStatus.ready, replies: replies),
      );

      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle demande'), findsNothing);
      // L assistant reste en tête quand il n y a aucune conversation.
      expect(
        tester.getTopLeft(find.text('Questions fréquentes')).dy,
        lessThan(tester.getTopLeft(find.text('Question fréquente 0')).dy),
      );
      await tester.scrollUntilVisible(find.text('Contacter le support'), 200);
      expect(find.text('Contacter le support'), findsOneWidget);
    });
  });

  group('sortSupportTickets', () {
    test('non résolues d abord, puis dernier message décroissant', () {
      final sorted = sortSupportTickets([
        const SupportTicket(
          id: 'r',
          category: 'OTHER',
          subject: 'r',
          status: SupportTicketStatuses.resolved,
        ),
        SupportTicket(
          id: 'old',
          category: 'OTHER',
          subject: 'old',
          status: SupportTicketStatuses.newTicket,
          createdAt: DateTime(2026, 1, 2),
        ),
        SupportTicket(
          id: 'new',
          category: 'OTHER',
          subject: 'new',
          status: SupportTicketStatuses.waitingUser,
          lastMessageAt: DateTime(2026, 9, 2),
        ),
      ]);

      expect(sorted.map((t) => t.id), ['new', 'old', 'r']);
    });

    test('sans date, garde l ordre du serveur', () {
      const a = SupportTicket(
        id: 'a',
        category: 'OTHER',
        subject: 'a',
        status: SupportTicketStatuses.newTicket,
      );
      const b = SupportTicket(
        id: 'b',
        category: 'OTHER',
        subject: 'b',
        status: SupportTicketStatuses.newTicket,
      );

      expect(sortSupportTickets([a, b]).map((t) => t.id), ['a', 'b']);
    });
  });

  group('retirer un ticket résolu (FLUTTER-9W)', () {
    const resolved = SupportTicket(
      id: 'ticket-9',
      category: 'DELIVERY',
      subject: 'Colis en retard',
      status: SupportTicketStatuses.resolved,
    );

    testWidgets(
      'seul un ticket résolu propose « Retirer », après confirmation',
      (tester) async {
        stubState(
          const SupportState(
            homeStatus: SupportViewStatus.ready,
            tickets: [_ticket, resolved],
          ),
        );
        await tester.pumpWidget(_harness(bloc));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('support-ticket-hide-ticket-1')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const ValueKey('support-ticket-hide-ticket-9')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Retirer ce ticket ?'), findsOneWidget);

        await tester.tap(find.text('Retirer'));
        await tester.pumpAndSettle();
        verify(
          () => bloc.add(const SupportTicketHideRequested('ticket-9')),
        ).called(1);
      },
    );

    testWidgets('échec du retrait : message d\'erreur', (tester) async {
      whenListen(
        bloc,
        Stream.fromIterable([
          const SupportState(
            homeStatus: SupportViewStatus.ready,
            tickets: [resolved],
            hideStatus: SupportActionStatus.failure,
            failure: SupportFailure.hideFailed,
          ),
        ]),
        initialState: const SupportState(
          homeStatus: SupportViewStatus.ready,
          tickets: [resolved],
        ),
      );
      await tester.pumpWidget(_harness(bloc));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Impossible de retirer ce ticket pour le moment. Réessayez plus tard.',
        ),
        findsOneWidget,
      );
    });
  });
}
