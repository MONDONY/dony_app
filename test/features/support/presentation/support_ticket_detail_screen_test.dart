import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_ticket_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class MockSupportBloc extends MockBloc<SupportEvent, SupportState>
    implements SupportBloc {}

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
    whenListen(
      bloc,
      const Stream<SupportState>.empty(),
      initialState: state,
    );
  }

  testWidgets('affiche le fil de messages des deux auteurs', (tester) async {
    stubState(const SupportState(
      detailStatus: SupportViewStatus.ready,
      ticket: _openTicket,
    ));

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Paiement bloque'), findsOneWidget); // titre app bar
    expect(find.text('Bonjour, mon paiement est bloque.'), findsOneWidget);
    expect(find.text('Bonjour, on regarde ca tout de suite.'), findsOneWidget);
    expect(find.text('Support Yadony'), findsOneWidget);
  });

  testWidgets('propose le champ de réponse quand le ticket est ouvert',
      (tester) async {
    stubState(const SupportState(
      detailStatus: SupportViewStatus.ready,
      ticket: _openTicket,
    ));

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Votre message'), findsOneWidget);
    expect(find.byTooltip('Envoyer'), findsOneWidget);
  });

  testWidgets('masque la saisie sur un ticket résolu', (tester) async {
    stubState(const SupportState(
      detailStatus: SupportViewStatus.ready,
      ticket: _resolvedTicket,
    ));

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Votre message'), findsNothing);
    expect(find.byTooltip('Envoyer'), findsNothing);
    expect(
      find.textContaining('Ce ticket est résolu'),
      findsOneWidget,
    );
    // DonyBadge rend son libellé en majuscules.
    expect(find.text('RÉSOLU'), findsOneWidget);
  });

  testWidgets("affiche l'erreur avec Réessayer quand le ticket ne charge pas",
      (tester) async {
    stubState(const SupportState(
      detailStatus: SupportViewStatus.failure,
      errorMessage: 'Ticket support introuvable',
    ));

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Ticket introuvable'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
