import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/ask_question/ask_question_cubit.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements ConversationRepository {}

const _conv = ConversationModel(
  id: 'conv-q',
  firestoreConversationId: 'conv_q',
  otherParticipant: ParticipantModel(id: 't1', name: 'Ibrahima'),
  kind: ConversationModel.kindInquiry,
  announcementId: 'a1',
  inquiryMessageLimit: 10,
);

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;
  var session = true;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.inquiryUnsupported).thenReturn(false);
    backend = MockAnalyticsBackend();
    session = true;
  });

  AskQuestionCubit build() {
    final analytics = makeEnabledAnalytics(backend);
    unawaited(analytics.onConfigured());
    return AskQuestionCubit(repo, analytics, hasRealSession: () => session);
  }

  void expectFailed(String code) => verify(
    () => backend.capture(AnalyticsEvents.inquiryOpenFailed, {
      'error_code': code,
    }),
  ).called(1);

  group('back sans les questions (I1)', () {
    test('déjà constaté : tuile masquée d\'emblée, sans message', () async {
      when(() => repo.inquiryUnsupported).thenReturn(true);
      final cubit = build();
      expect(cubit.state, isA<AskQuestionHidden>());
      await cubit.ask('a1', knownKycStatus: 'VERIFIED');
      verifyNever(() => repo.openInquiry(any()));
      await cubit.close();
    });

    blocTest<AskQuestionCubit, AskQuestionState>(
      'premier appui : message neutre puis tuile retirée',
      setUp: () => when(
        () => repo.openInquiry('a1'),
      ).thenAnswer((_) async => throw const InquiryUnsupportedException()),
      build: build,
      act: (c) => c.ask('a1'),
      expect: () => [
        isA<AskQuestionLoading>(),
        isA<AskQuestionUnsupported>(),
        isA<AskQuestionHidden>(),
      ],
      verify: (_) => expectFailed('inquiry-unsupported'),
    );
  });

  group('ask', () {
    blocTest<AskQuestionCubit, AskQuestionState>(
      'visiteur : feuille de connexion, aucun appel, échec auth-required',
      setUp: () => session = false,
      build: build,
      act: (c) => c.ask('a1', knownKycStatus: 'VERIFIED'),
      expect: () => [isA<AskQuestionAuthRequired>(), isA<AskQuestionIdle>()],
      verify: (_) {
        verifyNever(() => repo.openInquiry(any()));
        expectFailed('auth-required');
      },
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'identité connue non vérifiée : feuille KYC sans appel',
      build: build,
      act: (c) => c.ask('a1', knownKycStatus: 'PENDING'),
      expect: () => [
        isA<AskQuestionKycRequired>().having(
          (s) => s.kycStatus,
          'kycStatus',
          'PENDING',
        ),
        isA<AskQuestionIdle>(),
      ],
      verify: (_) {
        verifyNever(() => repo.openInquiry(any()));
        expectFailed('kyc-required');
      },
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'succès : chargement, conversation prête, inquiry_opened',
      setUp: () =>
          when(() => repo.openInquiry('a1')).thenAnswer((_) async => _conv),
      build: build,
      act: (c) => c.ask('a1', knownKycStatus: 'VERIFIED'),
      expect: () => [
        isA<AskQuestionLoading>(),
        isA<AskQuestionChatReady>().having(
          (s) => s.conversation.id,
          'conversation',
          'conv-q',
        ),
        isA<AskQuestionIdle>(),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.inquiryOpened, any()),
        ).called(1);
        verifyNever(
          () => backend.capture(AnalyticsEvents.inquiryOpenFailed, any()),
        );
      },
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'fil supprimé de mon côté : restauré, le chat s\'ouvre en écriture (I3)',
      setUp: () {
        when(() => repo.openInquiry('a1')).thenAnswer(
          (_) async => const ConversationModel(
            id: 'conv-q',
            firestoreConversationId: 'conv_q',
            otherParticipant: ParticipantModel(id: 't1', name: 'Ibrahima'),
            kind: ConversationModel.kindInquiry,
            announcementId: 'a1',
            deletedBySelf: true,
          ),
        );
        when(
          () => repo.restoreConversation('conv-q'),
        ).thenAnswer((_) async => _conv);
      },
      build: build,
      act: (c) => c.ask('a1'),
      expect: () => [
        isA<AskQuestionLoading>(),
        isA<AskQuestionChatReady>().having(
          (s) => s.conversation.deletedBySelf,
          'deletedBySelf',
          isFalse,
        ),
        isA<AskQuestionIdle>(),
      ],
      verify: (_) {
        verify(() => repo.restoreConversation('conv-q')).called(1);
        verify(
          () => backend.capture(AnalyticsEvents.inquiryOpened, {
            'restored': true,
          }),
        ).called(1);
      },
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'fil actif : aucune restauration, restored faux',
      setUp: () =>
          when(() => repo.openInquiry('a1')).thenAnswer((_) async => _conv),
      build: build,
      act: (c) => c.ask('a1'),
      verify: (_) {
        verifyNever(() => repo.restoreConversation(any()));
        verify(
          () => backend.capture(AnalyticsEvents.inquiryOpened, {
            'restored': false,
          }),
        ).called(1);
      },
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'restauration en échec : présentée, tuile gardée',
      setUp: () {
        when(() => repo.openInquiry('a1')).thenAnswer(
          (_) async => const ConversationModel(
            id: 'conv-q',
            firestoreConversationId: 'conv_q',
            otherParticipant: ParticipantModel(id: 't1', name: 'Ibrahima'),
            kind: ConversationModel.kindInquiry,
            deletedBySelf: true,
          ),
        );
        when(
          () => repo.restoreConversation('conv-q'),
        ).thenAnswer((_) async => throw const ServerException('boom'));
      },
      build: build,
      act: (c) => c.ask('a1'),
      expect: () => [
        isA<AskQuestionLoading>(),
        isA<AskQuestionFailed>(),
        isA<AskQuestionIdle>(),
      ],
      verify: (_) => verifyNever(
        () => backend.capture(AnalyticsEvents.inquiryOpened, any()),
      ),
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'statut inconnu : le serveur tranche (403 kyc-required)',
      setUp: () => when(
        () => repo.openInquiry('a1'),
      ).thenAnswer((_) async => throw const InquiryKycRequiredException()),
      build: build,
      act: (c) => c.ask('a1'),
      expect: () => [
        isA<AskQuestionLoading>(),
        isA<AskQuestionKycRequired>().having(
          (s) => s.kycStatus,
          'kycStatus',
          'NOT_STARTED',
        ),
        isA<AskQuestionIdle>(),
      ],
      verify: (_) => expectFailed('kyc-required'),
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'trajet fermé : message puis tuile retirée, code du back',
      setUp: () => when(() => repo.openInquiry('a1')).thenAnswer(
        (_) async =>
            throw const InquiryUnavailableException(kInquiryAnnouncementClosed),
      ),
      build: build,
      act: (c) => c.ask('a1'),
      expect: () => [
        isA<AskQuestionLoading>(),
        isA<AskQuestionUnavailable>(),
        isA<AskQuestionHidden>(),
      ],
      verify: (_) => expectFailed('inquiry-announcement-closed'),
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'erreur serveur : présentée, tuile gardée, code métier',
      setUp: () => when(() => repo.openInquiry('a1')).thenAnswer(
        (_) async => throw const ForbiddenException('muted', 'messaging-muted'),
      ),
      build: build,
      act: (c) => c.ask('a1'),
      expect: () => [
        isA<AskQuestionLoading>(),
        isA<AskQuestionFailed>(),
        isA<AskQuestionIdle>(),
      ],
      verify: (_) => expectFailed('messaging-muted'),
    );

    blocTest<AskQuestionCubit, AskQuestionState>(
      'erreur sans code : unknown',
      setUp: () => when(
        () => repo.openInquiry('a1'),
      ).thenAnswer((_) async => throw StateError('x')),
      build: build,
      act: (c) => c.ask('a1'),
      expect: () => [
        isA<AskQuestionLoading>(),
        isA<AskQuestionFailed>(),
        isA<AskQuestionIdle>(),
      ],
      verify: (_) => expectFailed('unknown'),
    );

    test('appui pendant une ouverture : ignoré', () async {
      final pending = Completer<ConversationModel>();
      when(() => repo.openInquiry('a1')).thenAnswer((_) => pending.future);
      final cubit = build();
      unawaited(cubit.ask('a1'));
      unawaited(cubit.ask('a1'));
      await pumpEventQueue();
      verify(() => repo.openInquiry('a1')).called(1);
      pending.complete(_conv);
      await pumpEventQueue();
      await cubit.close();
    });

    test('fermé pendant l\'appel : rien d\'émis ensuite', () async {
      final pending = Completer<ConversationModel>();
      when(() => repo.openInquiry('a1')).thenAnswer((_) => pending.future);
      final cubit = build();
      final states = <AskQuestionState>[];
      final sub = cubit.stream.listen(states.add);
      unawaited(cubit.ask('a1'));
      await pumpEventQueue();
      await cubit.close();
      pending.complete(_conv);
      await pumpEventQueue();
      expect(states, [isA<AskQuestionLoading>()]);
      await sub.cancel();
    });
  });
}
