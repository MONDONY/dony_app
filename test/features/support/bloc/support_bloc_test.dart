import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockSupportRepository extends Mock implements SupportRepository {}

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
  status: SupportTicketStatuses.newTicket,
);

const _resolvedTicket = SupportTicket(
  id: 'ticket-2',
  category: 'DELIVERY',
  subject: 'Colis en retard',
  status: SupportTicketStatuses.resolved,
);

// Helpers pour les tests d'attachements
const _readyAttachmentLocalId = 'local-img-1';
const _readyAttachmentKey = 'support/u1/1_a.jpg';

SupportState get stateWithOneReadyAttachment => const SupportState(
  pendingAttachments: [
    SupportAttachmentUpload(
      localId: _readyAttachmentLocalId,
      localPath: '/tmp/a.jpg',
      status: SupportUploadStatus.ready,
      remoteKey: _readyAttachmentKey,
    ),
  ],
);

SupportState get stateWithUploading => const SupportState(
  pendingAttachments: [
    SupportAttachmentUpload(
      localId: 'local-uploading',
      localPath: '/tmp/b.jpg',
      status: SupportUploadStatus.uploading,
    ),
  ],
);

SupportState get stateWithOnlyFailed => const SupportState(
  pendingAttachments: [
    SupportAttachmentUpload(
      localId: 'local-failed',
      localPath: '/tmp/c.jpg',
      status: SupportUploadStatus.failed,
    ),
  ],
);

const _message = SupportMessage(
  id: 'message-1',
  authorType: 'USER',
  content: 'Bonjour, mon paiement est bloque.',
);

void main() {
  late MockSupportRepository repository;
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUp(() async {
    repository = MockSupportRepository();
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
  });

  SupportBloc buildBloc() => SupportBloc(repository, analytics);

  group('SupportHomeRequested', () {
    blocTest<SupportBloc, SupportState>(
      'charge les réponses prédéfinies et les tickets',
      build: () {
        when(() => repository.loadReplies()).thenAnswer((_) async => [_reply]);
        when(() => repository.loadTickets()).thenAnswer((_) async => [_ticket]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SupportHomeRequested()),
      expect: () => [
        const SupportState(homeStatus: SupportViewStatus.loading),
        const SupportState(
          homeStatus: SupportViewStatus.ready,
          replies: [_reply],
          tickets: [_ticket],
        ),
      ],
    );

    blocTest<SupportBloc, SupportState>(
      'passe en échec avec un message quand le chargement casse',
      build: () {
        when(
          () => repository.loadReplies(),
        ).thenThrow(Exception('réseau indisponible'));
        when(() => repository.loadTickets()).thenAnswer((_) async => [_ticket]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SupportHomeRequested()),
      expect: () => [
        const SupportState(homeStatus: SupportViewStatus.loading),
        const SupportState(
          homeStatus: SupportViewStatus.failure,
          errorMessage: 'Une erreur est survenue. Réessayez.',
        ),
      ],
    );
  });

  group('SupportTicketCreateRequested', () {
    blocTest<SupportBloc, SupportState>(
      'crée le ticket, expose son id et le met en tête de liste',
      build: () {
        when(
          () => repository.createTicket(
            category: 'PAYMENT',
            subject: 'Paiement bloque',
            message: 'Bonjour, mon paiement est bloque.',
          ),
        ).thenAnswer((_) async => _ticket);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SupportTicketCreateRequested(
          category: 'PAYMENT',
          subject: 'Paiement bloque',
          message: 'Bonjour, mon paiement est bloque.',
        ),
      ),
      expect: () => [
        const SupportState(createStatus: SupportActionStatus.submitting),
        const SupportState(
          createStatus: SupportActionStatus.success,
          createdTicketId: 'ticket-1',
          tickets: [_ticket],
        ),
      ],
    );

    test('trace la création avec la seule catégorie', () async {
      when(
        () => repository.createTicket(
          category: 'PAYMENT',
          subject: 'Paiement bloque',
          message: 'Bonjour, mon paiement est bloque.',
        ),
      ).thenAnswer((_) async => _ticket);
      final bloc = buildBloc();

      bloc.add(
        const SupportTicketCreateRequested(
          category: 'PAYMENT',
          subject: 'Paiement bloque',
          message: 'Bonjour, mon paiement est bloque.',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.supportTicketCreated, {
          'category': 'PAYMENT',
        }),
      ).called(1);
      await bloc.close();
    });

    blocTest<SupportBloc, SupportState>(
      'remonte le detail RFC 7807 du backend en cas de refus',
      build: () {
        when(
          () => repository.createTicket(
            category: 'PAYMENT',
            subject: 'Paiement bloque',
            message: 'Bonjour, mon paiement est bloque.',
          ),
        ).thenThrow(Exception('categorie inconnue'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SupportTicketCreateRequested(
          category: 'PAYMENT',
          subject: 'Paiement bloque',
          message: 'Bonjour, mon paiement est bloque.',
        ),
      ),
      expect: () => [
        const SupportState(createStatus: SupportActionStatus.submitting),
        const SupportState(
          createStatus: SupportActionStatus.failure,
          errorMessage: 'Une erreur est survenue. Réessayez.',
        ),
      ],
    );
  });

  group('SupportTicketDetailRequested', () {
    blocTest<SupportBloc, SupportState>(
      'charge le fil de messages du ticket',
      build: () {
        when(() => repository.loadTicket('ticket-1')).thenAnswer(
          (_) async => const SupportTicket(
            id: 'ticket-1',
            category: 'PAYMENT',
            subject: 'Paiement bloque',
            status: SupportTicketStatuses.waitingUser,
            messages: [_message],
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SupportTicketDetailRequested('ticket-1')),
      expect: () => [
        const SupportState(detailStatus: SupportViewStatus.loading),
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: SupportTicket(
            id: 'ticket-1',
            category: 'PAYMENT',
            subject: 'Paiement bloque',
            status: SupportTicketStatuses.waitingUser,
            messages: [_message],
          ),
        ),
      ],
    );

    blocTest<SupportBloc, SupportState>(
      'passe en échec quand le ticket est introuvable',
      build: () {
        when(
          () => repository.loadTicket('ticket-404'),
        ).thenThrow(Exception('404'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SupportTicketDetailRequested('ticket-404')),
      expect: () => [
        const SupportState(detailStatus: SupportViewStatus.loading),
        const SupportState(
          detailStatus: SupportViewStatus.failure,
          errorMessage: 'Une erreur est survenue. Réessayez.',
        ),
      ],
    );
  });

  group('SupportMessageSendRequested', () {
    blocTest<SupportBloc, SupportState>(
      'envoie le message puis recharge le fil (statut serveur fait foi)',
      build: () {
        when(
          () => repository.sendMessage('ticket-1', 'Merci !', const []),
        ).thenAnswer((_) async => _message);
        when(() => repository.loadTicket('ticket-1')).thenAnswer(
          (_) async => const SupportTicket(
            id: 'ticket-1',
            category: 'PAYMENT',
            subject: 'Paiement bloque',
            status: SupportTicketStatuses.waitingSupport,
            messages: [_message],
          ),
        );
        return buildBloc();
      },
      seed: () => const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _ticket,
      ),
      act: (bloc) => bloc.add(
        const SupportMessageSendRequested(
          ticketId: 'ticket-1',
          content: 'Merci !',
        ),
      ),
      expect: () => [
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _ticket,
          sendStatus: SupportActionStatus.submitting,
        ),
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          sendStatus: SupportActionStatus.success,
          ticket: SupportTicket(
            id: 'ticket-1',
            category: 'PAYMENT',
            subject: 'Paiement bloque',
            status: SupportTicketStatuses.waitingSupport,
            messages: [_message],
          ),
        ),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.supportTicketMessageSent, null),
        ).called(1);
      },
    );

    blocTest<SupportBloc, SupportState>(
      'refuse localement un envoi sur ticket résolu, sans appel réseau',
      build: buildBloc,
      seed: () => const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _resolvedTicket,
      ),
      act: (bloc) => bloc.add(
        const SupportMessageSendRequested(
          ticketId: 'ticket-2',
          content: 'Encore un souci',
        ),
      ),
      expect: () => [
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _resolvedTicket,
          sendStatus: SupportActionStatus.failure,
          errorMessage:
              'Ce ticket est résolu. Ouvrez-en un nouveau pour un autre problème.',
        ),
      ],
      verify: (_) {
        verifyNever(() => repository.sendMessage(any(), any(), any()));
      },
    );

    blocTest<SupportBloc, SupportState>(
      "passe l'envoi en échec quand le backend refuse",
      build: () {
        when(
          () => repository.sendMessage('ticket-1', 'Merci !', const []),
        ).thenThrow(Exception('422'));
        return buildBloc();
      },
      seed: () => const SupportState(
        detailStatus: SupportViewStatus.ready,
        ticket: _ticket,
      ),
      act: (bloc) => bloc.add(
        const SupportMessageSendRequested(
          ticketId: 'ticket-1',
          content: 'Merci !',
        ),
      ),
      expect: () => [
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _ticket,
          sendStatus: SupportActionStatus.submitting,
        ),
        const SupportState(
          detailStatus: SupportViewStatus.ready,
          ticket: _ticket,
          sendStatus: SupportActionStatus.failure,
          errorMessage: 'Une erreur est survenue. Réessayez.',
        ),
      ],
    );
  });

  group('SupportTicketDetailRequested — marquage de lecture', () {
    blocTest<SupportBloc, SupportState>(
      'marque le fil lu à l ouverture du détail',
      build: () {
        when(() => repository.markRead('ticket-1')).thenAnswer((_) async {});
        when(
          () => repository.loadTicket('ticket-1'),
        ).thenAnswer((_) async => _ticket);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SupportTicketDetailRequested('ticket-1')),
      verify: (_) => verify(() => repository.markRead('ticket-1')).called(1),
    );

    blocTest<SupportBloc, SupportState>(
      'n échoue pas si le marquage de lecture échoue',
      build: () {
        when(
          () => repository.markRead('ticket-1'),
        ).thenThrow(Exception('réseau'));
        when(
          () => repository.loadTicket('ticket-1'),
        ).thenAnswer((_) async => _ticket);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SupportTicketDetailRequested('ticket-1')),
      verify: (_) => verify(() => repository.loadTicket('ticket-1')).called(1),
    );

    // Correction critique : le backend recalcule unreadCount depuis
    // user_last_read_at. Si markRead est appelé AVANT loadTicket, la réponse
    // porte toujours unreadCount = 0 et la pastille ne s'éteint jamais.
    blocTest<SupportBloc, SupportState>(
      'charge le fil avant de le marquer lu, sinon unreadCount revient toujours a zero',
      build: () {
        when(() => repository.markRead('t1')).thenAnswer((_) async {});
        when(
          () => repository.loadTicket('t1'),
        ).thenAnswer((_) async => _ticket);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SupportTicketDetailRequested('t1')),
      verify: (_) {
        verifyInOrder([
          () => repository.loadTicket('t1'),
          () => repository.markRead('t1'),
        ]);
      },
    );
  });

  group('SupportAttachmentPickRequested', () {
    blocTest<SupportBloc, SupportState>(
      'passe une image de uploading à ready puis autorise l envoi',
      build: () {
        when(
          () => repository.uploadAttachment('/tmp/a.jpg'),
        ).thenAnswer((_) async => 'support/u1/1_a.jpg');
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const SupportAttachmentPickRequested('/tmp/a.jpg')),
      expect: () => [
        isA<SupportState>().having(
          (s) => s.pendingAttachments.single.status,
          'status uploading',
          SupportUploadStatus.uploading,
        ),
        isA<SupportState>()
            .having(
              (s) => s.pendingAttachments.single.status,
              'status ready',
              SupportUploadStatus.ready,
            )
            .having(
              (s) => s.pendingAttachments.single.remoteKey,
              'remoteKey',
              'support/u1/1_a.jpg',
            ),
      ],
    );

    blocTest<SupportBloc, SupportState>(
      'marque l image en échec quand l upload échoue',
      build: () {
        when(
          () => repository.uploadAttachment(any()),
        ).thenThrow(Exception('boom'));
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const SupportAttachmentPickRequested('/tmp/a.jpg')),
      expect: () => [
        isA<SupportState>().having(
          (s) => s.pendingAttachments.single.status,
          'status uploading',
          SupportUploadStatus.uploading,
        ),
        isA<SupportState>().having(
          (s) => s.pendingAttachments.single.status,
          'status failed',
          SupportUploadStatus.failed,
        ),
      ],
    );

    test('fire l event analytics après un upload réussi', () async {
      when(
        () => repository.uploadAttachment('/tmp/a.jpg'),
      ).thenAnswer((_) async => 'support/u1/1_a.jpg');
      final bloc = buildBloc();
      bloc.add(const SupportAttachmentPickRequested('/tmp/a.jpg'));
      await Future<void>.delayed(Duration.zero);
      verify(
        () => backend.capture(AnalyticsEvents.supportAttachmentAdded, null),
      ).called(1);
      await bloc.close();
    });
  });

  group('SupportAttachmentRemoved', () {
    blocTest<SupportBloc, SupportState>(
      'retire une image de la liste',
      build: () => buildBloc(),
      seed: () => stateWithOneReadyAttachment,
      act: (bloc) =>
          bloc.add(const SupportAttachmentRemoved(_readyAttachmentLocalId)),
      expect: () => [
        isA<SupportState>().having(
          (s) => s.pendingAttachments,
          'pendingAttachments vide',
          isEmpty,
        ),
      ],
    );
  });

  group('SupportMessageSendRequested — avec images', () {
    blocTest<SupportBloc, SupportState>(
      'envoie les clés des images prêtes puis vide la liste',
      build: () {
        when(
          () => repository.sendMessage('ticket-1', 'Voici', const [
            _readyAttachmentKey,
          ]),
        ).thenAnswer((_) async => _message);
        when(
          () => repository.loadTicket('ticket-1'),
        ).thenAnswer((_) async => _ticket);
        return buildBloc();
      },
      seed: () => stateWithOneReadyAttachment,
      act: (bloc) => bloc.add(
        const SupportMessageSendRequested(
          ticketId: 'ticket-1',
          content: 'Voici',
        ),
      ),
      verify: (_) {
        verify(
          () => repository.sendMessage('ticket-1', 'Voici', const [
            _readyAttachmentKey,
          ]),
        ).called(1);
      },
    );

    blocTest<SupportBloc, SupportState>(
      'refuse d envoyer sur un ticket résolu sans appeler le réseau',
      build: () => buildBloc(),
      seed: () => const SupportState(ticket: _resolvedTicket),
      act: (bloc) => bloc.add(
        const SupportMessageSendRequested(
          ticketId: 'ticket-2',
          content: 'Bonjour',
        ),
      ),
      verify: (_) =>
          verifyNever(() => repository.sendMessage(any(), any(), any())),
    );
  });

  group('canSendWith', () {
    test('exige du texte ou une image prête, et aucun upload en cours', () {
      const vide = SupportState();

      // pas de texte, pas d'image → impossible
      expect(vide.canSendWith(''), isFalse);

      // un upload en cours bloque même avec du texte
      expect(stateWithUploading.canSendWith('hello'), isFalse);

      // une image prête suffit sans texte
      expect(stateWithOneReadyAttachment.canSendWith(''), isTrue);

      // une image en échec ne bloque pas mais ne suffit pas non plus
      expect(stateWithOnlyFailed.canSendWith(''), isFalse);

      // texte seul suffit (pas d'images)
      expect(vide.canSendWith('bonjour'), isTrue);
    });
  });
}
