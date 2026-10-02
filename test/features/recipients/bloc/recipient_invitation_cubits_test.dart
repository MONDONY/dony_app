import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/features/recipients/bloc/incoming_invitations_cubit.dart';
import 'package:dony/features/recipients/bloc/invite_recipient_cubit.dart';
import 'package:dony/features/recipients/bloc/sent_invitations_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInvitationRepository extends Mock
    implements RecipientInvitationRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

DioException _dio(AppException e) => DioException(
  requestOptions: RequestOptions(path: '/recipient-invitations'),
  error: e,
);

const _sentPending = SentRecipientInvitation(
  id: 's1',
  channel: 'PHONE',
  maskedTarget: '+221 •• •• •• 12',
  status: 'PENDING',
);

const _sentAccepted = SentRecipientInvitation(
  id: 's2',
  channel: 'EMAIL',
  maskedTarget: 'a••••@gmail.com',
  status: 'ACCEPTED',
);

const _sentPendingNamed = SentRecipientInvitation(
  id: 's3',
  channel: 'PHONE',
  maskedTarget: '+225 •• •• •• 34',
  status: 'PENDING',
  name: 'Fatou Koné',
);

const _pending = IncomingRecipientInvitation(
  id: 'p1',
  inviterFirstName: 'Awa',
  status: 'PENDING',
);

const _accepted = IncomingRecipientInvitation(
  id: 'a1',
  inviterFirstName: 'Moussa',
  status: 'ACCEPTED',
);

void main() {
  late MockInvitationRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockInvitationRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  group('InviteRecipientCubit', () {
    InviteRecipientCubit build() => InviteRecipientCubit(repository, analytics);

    test('numéro : validation E.164 après normalisation', () {
      final cubit = build()..inputChanged('77 12');
      expect(cubit.state.isValid, isFalse);
      // Erreur cachée tant que le champ n'a pas perdu le focus.
      expect(cubit.state.showsError, isFalse);
      cubit.fieldBlurred();
      expect(cubit.state.showsError, isTrue);
      cubit
        ..fieldBlurred()
        ..inputChanged('00221 77 123 45 67');
      expect(cubit.state.target, '+221771234567');
      expect(cubit.state.isValid, isTrue);
      expect(cubit.state.showsError, isFalse);
    });

    test('bascule vers email : saisie et erreur remises à zéro', () {
      final cubit = build()
        ..inputChanged('77')
        ..fieldBlurred()
        ..selectChannel(InvitationChannel.email);
      expect(cubit.state.channel, InvitationChannel.email);
      expect(cubit.state.input, '');
      expect(cubit.state.touched, isFalse);
      cubit.inputChanged(' Awa@Example.com ');
      expect(cubit.state.target, 'awa@example.com');
      expect(cubit.state.isValid, isTrue);
      // Même canal : rien ne change.
      cubit.selectChannel(InvitationChannel.email);
      expect(cubit.state.input, ' Awa@Example.com ');
    });

    blocTest<InviteRecipientCubit, InviteRecipientState>(
      'envoi par numéro : sent + événement sans PII',
      setUp: () =>
          when(() => repository.sendToPhone(any())).thenAnswer((_) async {}),
      build: build,
      act: (c) async {
        c.inputChanged('+221 77 123 45 67');
        await c.submit();
      },
      skip: 1,
      expect: () => [
        isA<InviteRecipientState>().having(
          (s) => s.status,
          'status',
          InviteRecipientStatus.submitting,
        ),
        isA<InviteRecipientState>().having(
          (s) => s.status,
          'status',
          InviteRecipientStatus.sent,
        ),
      ],
      verify: (_) {
        verify(() => repository.sendToPhone('+221771234567')).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.recipientInvitationSent,
            properties: {'channel': 'phone'},
          ),
        ).called(1);
      },
    );

    blocTest<InviteRecipientCubit, InviteRecipientState>(
      'envoi par email',
      setUp: () =>
          when(() => repository.sendToEmail(any())).thenAnswer((_) async {}),
      build: build,
      act: (c) async {
        c
          ..selectChannel(InvitationChannel.email)
          ..inputChanged('awa@example.com');
        await c.submit();
      },
      verify: (c) {
        expect(c.state.status, InviteRecipientStatus.sent);
        verify(() => repository.sendToEmail('awa@example.com')).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.recipientInvitationSent,
            properties: {'channel': 'email'},
          ),
        ).called(1);
      },
    );

    blocTest<InviteRecipientCubit, InviteRecipientState>(
      'saisie invalide : rien n\'est envoyé',
      build: build,
      act: (c) async {
        c.inputChanged('123');
        await c.submit();
      },
      verify: (_) => verifyNever(() => repository.sendToPhone(any())),
    );

    blocTest<InviteRecipientCubit, InviteRecipientState>(
      '429 : quota signalé, aucun événement',
      setUp: () => when(
        () => repository.sendToPhone(any()),
      ).thenThrow(_dio(const RateLimitException())),
      build: build,
      act: (c) async {
        c.inputChanged('+221771234567');
        await c.submit();
        // Pendant l'envoi, la saisie est figée ; après, elle reprend.
        c.inputChanged('+221771234568');
      },
      verify: (c) {
        expect(c.state.status, InviteRecipientStatus.editing);
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
      expect: () => [
        isA<InviteRecipientState>(),
        isA<InviteRecipientState>(),
        isA<InviteRecipientState>()
            .having((s) => s.status, 's', InviteRecipientStatus.failed)
            .having((s) => s.isQuotaExceeded, 'quota', isTrue),
        isA<InviteRecipientState>(),
      ],
    );

    test(
      'nom renseigné : envoyé avec le numéro, sans espaces autour',
      () async {
        when(
          () => repository.sendToPhone(any(), name: any(named: 'name')),
        ).thenAnswer((_) async {});
        final cubit = build()
          ..inputChanged('+221771234567')
          ..nameChanged('  Awa Diallo ');
        await cubit.submit();
        verify(
          () => repository.sendToPhone('+221771234567', name: 'Awa Diallo'),
        ).called(1);
      },
    );

    test('nom vide : non envoyé', () async {
      when(
        () => repository.sendToEmail(any(), name: any(named: 'name')),
      ).thenAnswer((_) async {});
      final cubit = build()
        ..selectChannel(InvitationChannel.email)
        ..inputChanged('awa@example.com')
        ..nameChanged('   ');
      expect(cubit.state.trimmedName, isNull);
      await cubit.submit();
      verify(() => repository.sendToEmail('awa@example.com')).called(1);
    });

    test('nom de plus de 100 caractères : envoi bloqué', () async {
      final cubit = build()
        ..inputChanged('+221771234567')
        ..nameChanged('a' * 101);
      expect(cubit.state.nameTooLong, isTrue);
      expect(cubit.state.isValid, isFalse);
      expect(cubit.state.showsError, isFalse);
      await cubit.submit();
      verifyNever(
        () => repository.sendToPhone(any(), name: any(named: 'name')),
      );
      cubit.nameChanged('a' * 100);
      expect(cubit.state.isValid, isTrue);
    });

    test('le nom survit au changement de moyen', () {
      final cubit = build()
        ..nameChanged('Awa')
        ..selectChannel(InvitationChannel.email);
      expect(cubit.state.name, 'Awa');
    });

    test(
      'contact au format national : numéro internationalisé, nom repris',
      () {
        final cubit = build()
          ..selectChannel(InvitationChannel.email)
          ..contactPicked(
            const PickedContact(fullName: 'Awa Diallo', phone: '0612345678'),
            countryCode: 'FR',
          );
        expect(cubit.state.channel, InvitationChannel.phone);
        expect(cubit.state.input, '+33612345678');
        expect(cubit.state.name, 'Awa Diallo');
        expect(cubit.state.isValid, isTrue);
      },
    );

    test('contact ivoirien : le zéro national est gardé', () {
      final cubit = build()
        ..contactPicked(
          const PickedContact(fullName: 'Koffi', phone: '0707070707'),
          countryCode: 'CI',
        );
      expect(cubit.state.input, '+2250707070707');
    });

    test('contact sans numéro : seul le nom est repris', () {
      final cubit = build()
        ..inputChanged('+221771234567')
        ..contactPicked(const PickedContact(fullName: 'Awa'));
      expect(cubit.state.input, '+221771234567');
      expect(cubit.state.name, 'Awa');
    });

    test('contact au nom trop long : tronqué à 100 caractères', () {
      final cubit = build()
        ..contactPicked(
          PickedContact(fullName: 'b' * 150, phone: '+221771234567'),
        );
      expect(cubit.state.name.length, 100);
      expect(cubit.state.isValid, isTrue);
    });

    test('autre erreur : failed sans quota', () async {
      when(
        () => repository.sendToPhone(any()),
      ).thenThrow(_dio(const ServerException()));
      final cubit = build()..inputChanged('+221771234567');
      await cubit.submit();
      expect(cubit.state.status, InviteRecipientStatus.failed);
      expect(cubit.state.isQuotaExceeded, isFalse);
    });
  });

  group('SentInvitationsCubit', () {
    SentInvitationsCubit build() => SentInvitationsCubit(repository, analytics);

    blocTest<SentInvitationsCubit, SentInvitationsState>(
      'chargement',
      setUp: () => when(
        () => repository.getSent(),
      ).thenAnswer((_) async => [_sentPending, _sentAccepted]),
      build: build,
      act: (c) => c.load(),
      // FLUTTER-7V : l'invitation acceptée n'est plus listée, la personne
      // figure déjà dans le carnet.
      expect: () => [
        isA<SentInvitationsState>()
            .having((s) => s.status, 's', SentInvitationsStatus.loaded)
            .having((s) => s.invitations.map((i) => i.id), 'ids', ['s1']),
      ],
    );

    blocTest<SentInvitationsCubit, SentInvitationsState>(
      'ancien back (404) : unsupported',
      setUp: () => when(
        () => repository.getSent(),
      ).thenThrow(_dio(const NotFoundException())),
      build: build,
      act: (c) => c.load(),
      verify: (c) => expect(c.state.isUnsupported, isTrue),
    );

    blocTest<SentInvitationsCubit, SentInvitationsState>(
      'autre échec : error ; rafraîchissement raté garde la liste',
      setUp: () {
        var calls = 0;
        when(() => repository.getSent()).thenAnswer((_) async {
          calls++;
          if (calls == 1) throw _dio(const ServerException());
          if (calls == 2) return [_sentPending];
          throw _dio(const ServerException());
        });
      },
      build: build,
      act: (c) async {
        await c.load();
        expect(c.state.status, SentInvitationsStatus.error);
        expect(c.state.isUnsupported, isFalse);
        await c.load();
        await c.load();
      },
      verify: (c) => expect(c.state.invitations, hasLength(1)),
    );

    blocTest<SentInvitationsCubit, SentInvitationsState>(
      'annulation : retirée de la liste + événement inviter',
      setUp: () {
        when(() => repository.getSent()).thenAnswer(
          (_) async => [_sentPending, _sentAccepted, _sentPendingNamed],
        );
        when(() => repository.revoke(any())).thenAnswer((_) async {});
      },
      build: build,
      act: (c) async {
        await c.load();
        await c.revoke('s1');
      },
      verify: (c) {
        expect(c.state.invitations.map((i) => i.id), ['s3']);
        expect(c.state.busyId, isNull);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.recipientInvitationRevoked,
            properties: {'side': 'inviter'},
          ),
        ).called(1);
      },
    );

    blocTest<SentInvitationsCubit, SentInvitationsState>(
      'annulation ratée : erreur signalée, liste intacte',
      setUp: () {
        when(
          () => repository.getSent(),
        ).thenAnswer((_) async => [_sentPending]);
        when(
          () => repository.revoke(any()),
        ).thenThrow(_dio(const ServerException()));
      },
      build: build,
      act: (c) async {
        await c.load();
        await c.revoke('s1');
      },
      verify: (c) {
        expect(c.state.invitations, hasLength(1));
        expect(c.state.actionError, isA<ServerException>());
      },
    );

    test('annulation déjà en cours : ignorée', () async {
      when(() => repository.getSent()).thenAnswer((_) async => [_sentPending]);
      when(() => repository.revoke(any())).thenAnswer(
        (_) => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      final cubit = build();
      await cubit.load();
      final first = cubit.revoke('s1');
      await cubit.revoke('s1');
      await first;
      verify(() => repository.revoke('s1')).called(1);
    });
  });

  group('IncomingInvitationsCubit', () {
    IncomingInvitationsCubit build() =>
        IncomingInvitationsCubit(repository, analytics);

    setUp(
      () => when(
        () => repository.getIncoming(),
      ).thenAnswer((_) async => [_pending, _accepted]),
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'chargement : en attente et autorisés séparés',
      build: build,
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.pending.single.id, 'p1');
        expect(c.state.accepted.single.id, 'a1');
      },
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'échec du premier chargement : error ; ensuite la liste reste',
      setUp: () {
        var calls = 0;
        when(() => repository.getIncoming()).thenAnswer((_) async {
          calls++;
          if (calls == 2) return [_pending];
          throw _dio(const NotFoundException());
        });
      },
      build: build,
      act: (c) async {
        await c.load();
        expect(c.state.status, IncomingInvitationsStatus.error);
        await c.load();
        await c.load();
      },
      verify: (c) {
        expect(c.state.status, IncomingInvitationsStatus.loaded);
        expect(c.state.pending, hasLength(1));
      },
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'accepter : passe en autorisé, outcome accepted + événement',
      setUp: () =>
          when(() => repository.accept(any())).thenAnswer((_) async {}),
      build: build,
      act: (c) async {
        await c.load();
        await c.accept('p1');
      },
      verify: (c) {
        expect(c.state.pending, isEmpty);
        expect(c.state.accepted, hasLength(2));
        expect(c.state.outcome, IncomingInvitationOutcome.accepted);
        expect(c.state.outcomeName, 'Awa');
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.recipientInvitationAnswered,
            properties: {'answer': 'accepted'},
          ),
        ).called(1);
      },
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'accepter sans téléphone (409) : outcome phoneRequired, rien ne change',
      setUp: () => when(() => repository.accept(any())).thenThrow(
        _dio(
          const ConflictException(
            'phone',
            code: 'recipient-invitation-phone-required',
          ),
        ),
      ),
      build: build,
      act: (c) async {
        await c.load();
        await c.accept('p1');
      },
      verify: (c) {
        expect(c.state.outcome, IncomingInvitationOutcome.phoneRequired);
        expect(c.state.pending, hasLength(1));
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'autre 409 : outcome failed',
      setUp: () => when(
        () => repository.accept(any()),
      ).thenThrow(_dio(const ConflictException('déjà'))),
      build: build,
      act: (c) async {
        await c.load();
        await c.accept('p1');
      },
      verify: (c) => expect(c.state.outcome, IncomingInvitationOutcome.failed),
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'refuser : retirée + événement declined',
      setUp: () =>
          when(() => repository.decline(any())).thenAnswer((_) async {}),
      build: build,
      act: (c) async {
        await c.load();
        await c.decline('p1');
      },
      verify: (c) {
        expect(c.state.pending, isEmpty);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.recipientInvitationAnswered,
            properties: {'answer': 'declined'},
          ),
        ).called(1);
      },
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'refus raté : outcome failed',
      setUp: () => when(
        () => repository.decline(any()),
      ).thenThrow(_dio(const ServerException())),
      build: build,
      act: (c) async {
        await c.load();
        await c.decline('p1');
      },
      verify: (c) => expect(c.state.outcome, IncomingInvitationOutcome.failed),
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'retirer un expéditeur : retiré + événement invitee',
      setUp: () =>
          when(() => repository.revoke(any())).thenAnswer((_) async {}),
      build: build,
      act: (c) async {
        await c.load();
        await c.revoke('a1');
      },
      verify: (c) {
        expect(c.state.accepted, isEmpty);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.recipientInvitationRevoked,
            properties: {'side': 'invitee'},
          ),
        ).called(1);
      },
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'retrait raté : outcome failed',
      setUp: () => when(
        () => repository.revoke(any()),
      ).thenThrow(_dio(const ServerException())),
      build: build,
      act: (c) async {
        await c.load();
        await c.revoke('a1');
      },
      verify: (c) => expect(c.state.outcome, IncomingInvitationOutcome.failed),
    );

    blocTest<IncomingInvitationsCubit, IncomingInvitationsState>(
      'identifiant inconnu : aucune requête',
      build: build,
      act: (c) async {
        await c.load();
        await c.accept('x');
        await c.decline('x');
        await c.revoke('x');
      },
      verify: (_) {
        verifyNever(() => repository.accept(any()));
        verifyNever(() => repository.decline(any()));
        verifyNever(() => repository.revoke(any()));
      },
    );
  });
}
