import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/widgets/support_conversation_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/l10n_test_helpers.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

SupportSummaryTicket _latest({
  String id = 'ticket-1',
  String? preview = 'Nous regardons votre dossier',
  bool fromAdmin = true,
  DateTime? at,
  int unread = 0,
}) => SupportSummaryTicket(
  id: id,
  subject: 'Colis bloqué',
  lastMessagePreview: preview,
  lastMessageAt: at,
  lastMessageFromAdmin: fromAdmin,
  unreadCount: unread,
);

/// Monte la tuile sous un GoRouter pour vérifier la route ouverte au tap.
Widget _routed(Widget tile) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: tile),
      ),
      GoRoute(
        path: '/support',
        builder: (_, _) => const Scaffold(body: Text('liste-support')),
      ),
      GoRoute(
        path: '/support/tickets/:id',
        builder: (_, state) =>
            Scaffold(body: Text('fil-${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('affiche la ligne meme sans aucun ticket, avec une invitation', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const SupportConversationTile(unreadCount: 0)),
    );

    expect(find.text('Support Yadony'), findsOneWidget);
    expect(find.textContaining('Une question'), findsOneWidget);
  });

  testWidgets('affiche l aperçu du dernier message quand il y en a un', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(SupportConversationTile(unreadCount: 0, latestTicket: _latest())),
    );

    expect(find.text('Yadony : Nous regardons votre dossier'), findsOneWidget);
    expect(find.textContaining('Une question'), findsNothing);
  });

  testWidgets('préfixe « Vous : » quand l utilisateur a écrit en dernier', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SupportConversationTile(
          unreadCount: 0,
          latestTicket: _latest(preview: 'Merci !', fromAdmin: false),
        ),
      ),
    );

    expect(find.text('Vous : Merci !'), findsOneWidget);
  });

  testWidgets('un aperçu absent retombe sur l invitation', (tester) async {
    await tester.pumpWidget(
      wrap(
        SupportConversationTile(
          unreadCount: 0,
          latestTicket: _latest(preview: null),
        ),
      ),
    );

    expect(find.textContaining('Une question'), findsOneWidget);
  });

  testWidgets('un aperçu multiligne tient sur une ligne', (tester) async {
    await tester.pumpWidget(
      wrap(
        SupportConversationTile(
          unreadCount: 0,
          latestTicket: _latest(preview: 'Bonjour\n\nVotre colis'),
        ),
      ),
    );

    expect(find.text('Yadony : Bonjour Votre colis'), findsOneWidget);
  });

  testWidgets('affiche l heure du dernier message', (tester) async {
    await tester.pumpWidget(
      wrap(
        SupportConversationTile(
          unreadCount: 0,
          latestTicket: _latest(at: DateTime.now()),
        ),
      ),
    );

    // Moins d'une minute : même libellé que les autres conversations.
    expect(find.text('maintenant'), findsOneWidget);
  });

  testWidgets('affiche la pastille quand il y a des non-lus', (tester) async {
    await tester.pumpWidget(
      wrap(SupportConversationTile(unreadCount: 2, latestTicket: _latest())),
    );

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('n affiche aucune pastille a zero non-lu', (tester) async {
    await tester.pumpWidget(
      wrap(SupportConversationTile(unreadCount: 0, latestTicket: _latest())),
    );

    expect(find.text('0'), findsNothing);
  });

  testWidgets('annonce le nombre de non-lus aux lecteurs d écran', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(SupportConversationTile(unreadCount: 3, latestTicket: _latest())),
    );

    expect(
      find.bySemanticsLabel(RegExp('Support Yadony.*3 messages non lus')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('anglais : invitation par défaut traduite', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      wrap(const SupportConversationTile(unreadCount: 0)),
    );

    expect(find.text('Yadony Support'), findsOneWidget);
    expect(
      find.text('A question? Our team will get back to you here.'),
      findsOneWidget,
    );
  });

  testWidgets('anglais : préfixes de l aperçu traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      wrap(
        SupportConversationTile(
          unreadCount: 0,
          latestTicket: _latest(preview: 'Hello', fromAdmin: false),
        ),
      ),
    );

    expect(find.text('You: Hello'), findsOneWidget);
  });

  group('tap', () {
    testWidgets('une seule conversation ouverte : ouvre directement le fil', (
      tester,
    ) async {
      await tester.pumpWidget(
        _routed(
          SupportConversationTile(
            unreadCount: 1,
            openTicketCount: 1,
            latestTicket: _latest(id: 'abc'),
          ),
        ),
      );

      await tester.tap(find.byType(SupportConversationTile));
      await tester.pumpAndSettle();

      expect(find.text('fil-abc'), findsOneWidget);
    });

    testWidgets('plusieurs conversations ouvertes : ouvre la liste', (
      tester,
    ) async {
      await tester.pumpWidget(
        _routed(
          SupportConversationTile(
            unreadCount: 0,
            openTicketCount: 2,
            latestTicket: _latest(),
          ),
        ),
      );

      await tester.tap(find.byType(SupportConversationTile));
      await tester.pumpAndSettle();

      expect(find.text('liste-support'), findsOneWidget);
    });

    testWidgets('aucune conversation ouverte : ouvre la liste', (tester) async {
      await tester.pumpWidget(
        _routed(
          SupportConversationTile(unreadCount: 0, latestTicket: _latest()),
        ),
      );

      await tester.tap(find.byType(SupportConversationTile));
      await tester.pumpAndSettle();

      expect(find.text('liste-support'), findsOneWidget);
    });

    testWidgets('ancien back (sans résumé) : ouvre la liste', (tester) async {
      await tester.pumpWidget(
        _routed(const SupportConversationTile(unreadCount: 0)),
      );

      await tester.tap(find.byType(SupportConversationTile));
      await tester.pumpAndSettle();

      expect(find.text('liste-support'), findsOneWidget);
    });

    testWidgets('au retour, prévient l appelant pour rafraîchir', (
      tester,
    ) async {
      var returned = 0;
      await tester.pumpWidget(
        _routed(
          SupportConversationTile(unreadCount: 0, onReturned: () => returned++),
        ),
      );

      await tester.tap(find.byType(SupportConversationTile));
      await tester.pumpAndSettle();
      expect(returned, 0);

      GoRouter.of(tester.element(find.text('liste-support'))).pop();
      await tester.pumpAndSettle();

      expect(returned, 1);
    });
  });

  group('supportTileRoute', () {
    test('règle d ouverture directe', () {
      expect(supportTileRoute(1, _latest(id: 'x')), '/support/tickets/x');
      expect(supportTileRoute(2, _latest(id: 'x')), '/support');
      expect(supportTileRoute(0, _latest(id: 'x')), '/support');
      expect(supportTileRoute(1, null), '/support');
    });
  });
}
