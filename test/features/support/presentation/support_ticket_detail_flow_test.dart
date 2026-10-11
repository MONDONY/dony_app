import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_ticket_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockSupportBloc extends MockBloc<SupportEvent, SupportState>
    implements SupportBloc {}

const _ticket = SupportTicket(
  id: 'ticket-1',
  category: 'PAYMENT',
  subject: 'Paiement bloque',
  status: SupportTicketStatuses.waitingUser,
  messages: [SupportMessage(id: 'm-1', authorType: 'USER', content: 'Bonjour')],
);

const _photos = SupportTicket(
  id: 'ticket-1',
  category: 'PAYMENT',
  subject: 'Paiement bloque',
  status: SupportTicketStatuses.waitingUser,
  messages: [
    SupportMessage(
      id: 'm-2',
      authorType: 'USER',
      content: 'Voici les photos.',
      attachments: [
        SupportAttachment(
          id: 'att-1',
          url: 'https://example.com/img1.jpg',
          contentType: 'image/jpeg',
        ),
        SupportAttachment(
          id: 'att-2',
          url: 'https://example.com/img2.jpg',
          contentType: 'image/jpeg',
        ),
      ],
    ),
  ],
);

const _ready = SupportState(
  detailStatus: SupportViewStatus.ready,
  ticket: _ticket,
);

void main() {
  late _MockSupportBloc bloc;
  late StreamController<SupportState> states;

  setUpAll(
    () => registerFallbackValue(const SupportTicketDetailRequested('x')),
  );

  setUp(() {
    useEnglish();
    DonySnackbar.clearDedup();
    bloc = _MockSupportBloc();
    states = StreamController<SupportState>.broadcast();
  });

  tearDown(() => states.close());

  Future<void> pump(WidgetTester tester, SupportState initial) async {
    whenListen(bloc, states.stream, initialState: initial);
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
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
  }

  group('envoi d\'une réponse', () {
    testWidgets('bouton Send : le texte part sans espaces superflus', (
      tester,
    ) async {
      await pump(tester, _ready);
      IconButton sendButton() => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Send'),
          matching: find.byType(IconButton),
        ),
      );
      expect(sendButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  Merci  ');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      verify(
        () => bloc.add(
          const SupportMessageSendRequested(
            ticketId: 'ticket-1',
            content: 'Merci',
          ),
        ),
      ).called(1);
    });

    testWidgets('validation au clavier : même envoi', (tester) async {
      await pump(tester, _ready);
      await tester.enterText(find.byType(TextField), 'Toujours bloqué');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verify(
        () => bloc.add(
          const SupportMessageSendRequested(
            ticketId: 'ticket-1',
            content: 'Toujours bloqué',
          ),
        ),
      ).called(1);
    });

    testWidgets('validation d\'un champ vide : aucun envoi', (tester) async {
      await pump(tester, _ready);
      await tester.showKeyboard(find.byType(TextField));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('envoi en cours : indicateur à la place du bouton', (
      tester,
    ) async {
      await pump(
        tester,
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _ticket,
          sendStatus: SupportActionStatus.submitting,
        ),
      );
      expect(find.byTooltip('Send'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('échec : avis d\'erreur localisé', (tester) async {
      await pump(tester, _ready);
      states.add(
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _ticket,
          sendStatus: SupportActionStatus.failure,
          failure: SupportFailure.generic,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('échec sans cause : pas d\'avis', (tester) async {
      await pump(tester, _ready);
      states.add(
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _ticket,
          sendStatus: SupportActionStatus.failure,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('succès : le champ est vidé', (tester) async {
      await pump(tester, _ready);
      await tester.enterText(find.byType(TextField), 'Réponse');
      await tester.pump();
      states.add(
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _ticket,
          sendStatus: SupportActionStatus.success,
        ),
      );
      await tester.pump();
      expect(find.text('Réponse'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  });

  testWidgets('ticket introuvable : Réessayer relance le chargement', (
    tester,
  ) async {
    await pump(
      tester,
      const SupportState(
        detailStatus: SupportViewStatus.failure,
        failure: SupportFailure.generic,
      ),
    );
    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    verify(
      () => bloc.add(const SupportTicketDetailRequested('ticket-1')),
    ).called(1);
    // Laisse finir l'animation de l'état vide.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('prêt sans ticket : repli en chargement', (tester) async {
    await pump(
      tester,
      const SupportState(detailStatus: SupportViewStatus.ready),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Support ticket'), findsOneWidget);
  });

  group('visionneuse des images', () {
    testWidgets('ouvre la photo touchée, glisse et se ferme', (tester) async {
      await pump(
        tester,
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _photos,
        ),
      );
      await tester.tap(find.byKey(const Key('support-attachment-att-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Photo 2 of 2'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      // Deux pastilles de page : la courante est allongée.
      final dots = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => c.constraints?.maxWidth)
          .toList();
      expect(dots, [7, 20]);

      await tester.drag(find.byType(PageView), const Offset(600, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Photo 1 of 2'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('toucher hors de la carte ferme la visionneuse', (
      tester,
    ) async {
      await pump(
        tester,
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _photos,
        ),
      );
      await tester.tap(find.byKey(const Key('support-attachment-att-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Photo 1 of 2'), findsOneWidget);

      // Toucher dans la carte ne ferme rien.
      await tester.tap(find.text('Photo 1 of 2'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PageView), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('image injoignable : icône de remplacement', (tester) async {
      await pump(
        tester,
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _photos,
        ),
      );
      // Le client HTTP de test répond 400 : le chargement échoue.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('support-attachment-att-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(3));
    });
  });
}
