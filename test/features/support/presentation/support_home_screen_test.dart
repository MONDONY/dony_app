import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
    whenListen(
      bloc,
      const Stream<SupportState>.empty(),
      initialState: state,
    );
  }

  testWidgets('affiche les réponses prédéfinies et déplie la réponse',
      (tester) async {
    stubState(const SupportState(
      homeStatus: SupportViewStatus.ready,
      replies: [_reply],
    ));

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

  testWidgets('affiche le CTA de contact et ouvre la sheet de création',
      (tester) async {
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

  testWidgets('affiche la liste des tickets avec statut traduit',
      (tester) async {
    stubState(const SupportState(
      homeStatus: SupportViewStatus.ready,
      tickets: [_ticket],
    ));

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Mes tickets'), findsOneWidget);
    expect(find.text('Paiement bloque'), findsOneWidget);
    // DonyBadge rend son libellé en majuscules.
    expect(find.text('RÉPONSE REÇUE'), findsOneWidget);
    expect(find.text('Paiement'), findsOneWidget);
  });

  testWidgets("affiche l'état d'erreur avec un bouton Réessayer",
      (tester) async {
    stubState(const SupportState(
      homeStatus: SupportViewStatus.failure,
      errorMessage: 'Une erreur est survenue. Réessayez.',
    ));

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger le support'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
