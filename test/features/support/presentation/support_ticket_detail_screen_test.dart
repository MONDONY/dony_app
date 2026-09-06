import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:dony/features/support/presentation/screens/support_ticket_detail_screen.dart';
import 'package:dony/features/support/presentation/widgets/support_attachment_picker.dart';
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

// Pièces jointes pendantes pour les nouveaux tests
const _uploadingAttachment = SupportAttachmentUpload(
  localId: 'local-1',
  localPath: '/tmp/test.jpg',
  status: SupportUploadStatus.uploading,
);

const _readyAttachment = SupportAttachmentUpload(
  localId: 'local-2',
  localPath: '/tmp/test2.jpg',
  status: SupportUploadStatus.ready,
  remoteKey: 'remote/key.jpg',
);

const _failedAttachment = SupportAttachmentUpload(
  localId: 'local-3',
  localPath: '/tmp/test3.jpg',
  status: SupportUploadStatus.failed,
);

// Message avec pièces jointes (URLs factices pour le test widget)
const _attachedMessage = SupportMessage(
  id: 'message-3',
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
);

const _ticketWithAttachedMessage = SupportTicket(
  id: 'ticket-1',
  category: 'PAYMENT',
  subject: 'Paiement bloque',
  status: SupportTicketStatuses.waitingUser,
  messages: [_attachedMessage],
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

  // ---------------------------------------------------------------------------
  // Nouveaux tests Task 11 : pièces jointes
  // ---------------------------------------------------------------------------

  testWidgets('le bouton d envoi reste inerte pendant un upload', (
    tester,
  ) async {
    // État : une image en cours d'upload => envoi bloqué
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _openTicket,
        pendingAttachments: [_uploadingAttachment],
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    // Pas de pumpAndSettle : le CircularProgressIndicator tourne en continu
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Le bouton Envoyer doit être inactif (onPressed null) car upload en cours
    final sendFinder = find.byTooltip('Envoyer');
    expect(sendFinder, findsOneWidget);
    final sendParent =
        tester.widget(
              find
                  .ancestor(of: sendFinder, matching: find.byType(IconButton))
                  .first,
            )
            as IconButton;
    expect(sendParent.onPressed, isNull);
  });

  testWidgets('le bouton s active avec une image prete et aucun texte', (
    tester,
  ) async {
    // État : une image prête, champ texte vide => envoi actif
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _openTicket,
        pendingAttachments: [_readyAttachment],
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pump();

    // Le bouton doit être actif grâce à l'image prête
    final sendFinder = find.byTooltip('Envoyer');
    expect(sendFinder, findsOneWidget);
    final sendParent =
        tester.widget(
              find
                  .ancestor(of: sendFinder, matching: find.byType(IconButton))
                  .first,
            )
            as IconButton;
    expect(sendParent.onPressed, isNotNull);
  });

  testWidgets('une image en echec est retirable et ne bloque pas l envoi', (
    tester,
  ) async {
    // État : une image en échec => bouton de retrait présent
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _openTicket,
        pendingAttachments: [_failedAttachment],
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pump();

    // Vérifier qu'un bouton de retrait est présent
    expect(find.byKey(const Key('remove-attachment-local-3')), findsOneWidget);

    // Taper dans le champ pour activer le bouton d'envoi
    await tester.enterText(find.byType(TextField), 'un message');
    await tester.pump();

    // Bouton d'envoi doit être actif (texte saisi + image en échec ne bloque pas)
    final sendFinder = find.byTooltip('Envoyer');
    expect(sendFinder, findsOneWidget);
    final sendParent =
        tester.widget(
              find
                  .ancestor(of: sendFinder, matching: find.byType(IconButton))
                  .first,
            )
            as IconButton;
    expect(sendParent.onPressed, isNotNull);
  });

  testWidgets('un ticket resolu n offre ni champ ni trombone', (tester) async {
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _resolvedTicket,
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    // Ni champ de saisie ni trombone
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SupportAttachmentPicker), findsNothing);
  });

  testWidgets('affiche les images d un message en grille', (tester) async {
    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _ticketWithAttachedMessage,
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pumpAndSettle();

    // Deux images réseau doivent être rendues (via Image.network ou CachedNetworkImage)
    expect(find.byKey(const Key('support-attachment-att-1')), findsOneWidget);
    expect(find.byKey(const Key('support-attachment-att-2')), findsOneWidget);
  });

  testWidgets(
    'quatre vignettes au-dessus du champ ne debordent pas sur 375 pt',
    (tester) async {
      // Reproduit la largeur d'un iPhone standard (375 points logiques).
      // Avant le fix, les vignettes étaient dans la même Row que le champ :
      // 4 × (64 + 8) = 288 px + bouton trombone (48) + bouton envoi (48) +
      // espacements > 375 → overflow garanti.
      tester.view.physicalSize = const Size(375 * 3, 812 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const fourAttachments = [
        SupportAttachmentUpload(
          localId: 'a1',
          localPath: '/tmp/1.jpg',
          status: SupportUploadStatus.ready,
          remoteKey: 'k1',
        ),
        SupportAttachmentUpload(
          localId: 'a2',
          localPath: '/tmp/2.jpg',
          status: SupportUploadStatus.ready,
          remoteKey: 'k2',
        ),
        SupportAttachmentUpload(
          localId: 'a3',
          localPath: '/tmp/3.jpg',
          status: SupportUploadStatus.ready,
          remoteKey: 'k3',
        ),
        SupportAttachmentUpload(
          localId: 'a4',
          localPath: '/tmp/4.jpg',
          status: SupportUploadStatus.ready,
          remoteKey: 'k4',
        ),
      ];

      stubState(
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _openTicket,
          pendingAttachments: fourAttachments,
        ),
      );

      await tester.pumpWidget(_harness(bloc));
      await tester.pump();

      // Aucune exception de débordement (overflow RenderFlex).
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('le trombone se desactive a quatre images', (tester) async {
    const fourAttachments = [
      SupportAttachmentUpload(
        localId: 'a1',
        localPath: '/tmp/1.jpg',
        status: SupportUploadStatus.ready,
        remoteKey: 'k1',
      ),
      SupportAttachmentUpload(
        localId: 'a2',
        localPath: '/tmp/2.jpg',
        status: SupportUploadStatus.ready,
        remoteKey: 'k2',
      ),
      SupportAttachmentUpload(
        localId: 'a3',
        localPath: '/tmp/3.jpg',
        status: SupportUploadStatus.ready,
        remoteKey: 'k3',
      ),
      SupportAttachmentUpload(
        localId: 'a4',
        localPath: '/tmp/4.jpg',
        status: SupportUploadStatus.ready,
        remoteKey: 'k4',
      ),
    ];

    stubState(
      const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _openTicket,
        pendingAttachments: fourAttachments,
      ),
    );

    await tester.pumpWidget(_harness(bloc));
    await tester.pump();

    // A 4 images, le trombone doit être absent du widget tree car canAdd == false.
    // Le SupportAttachmentPicker n'affiche le bouton inline que si canAdd.
    final addButtonFinder = find.byTooltip('Joindre une image');
    expect(addButtonFinder, findsNothing);
  });
}
