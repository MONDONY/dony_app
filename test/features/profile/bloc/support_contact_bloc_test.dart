import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/support_contact_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

void main() {
  late SupportContactBloc bloc;
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    bloc = SupportContactBloc(analytics);
  });
  tearDown(() => bloc.close());

  test('initial state is empty and invalid', () {
    expect(bloc.state.category, isEmpty);
    expect(bloc.state.subject, isEmpty);
    expect(bloc.state.message, isEmpty);
    expect(bloc.state.isValid, isFalse);
    expect(bloc.state.submitStatus, SupportSubmitStatus.idle);
  });

  group('SupportCategorySelected', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'updates category',
      build: () => bloc,
      act: (b) => b.add(const SupportCategorySelected('Paiement')),
      expect: () => [
        predicate<SupportContactState>((s) => s.category == 'Paiement'),
      ],
    );
  });

  group('SupportSubjectChanged', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'updates subject',
      build: () => bloc,
      act: (b) => b.add(const SupportSubjectChanged('Mon sujet')),
      expect: () => [
        predicate<SupportContactState>((s) => s.subject == 'Mon sujet'),
      ],
    );
  });

  group('SupportMessageChanged', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'updates message',
      build: () => bloc,
      act: (b) => b.add(const SupportMessageChanged('Un message détaillé')),
      expect: () => [
        predicate<SupportContactState>(
          (s) => s.message == 'Un message détaillé',
        ),
      ],
    );
  });

  group('isValid', () {
    test('returns false when only category is set', () {
      bloc.add(const SupportCategorySelected('Paiement'));
      expect(bloc.state.isValid, isFalse);
    });

    test('returns false when subject is too short (< 5 chars)', () {
      bloc
        ..add(const SupportCategorySelected('Paiement'))
        ..add(const SupportSubjectChanged('Pb'))
        ..add(
          const SupportMessageChanged(
            'Un message suffisamment long pour valider le formulaire',
          ),
        );
      expect(bloc.state.isValid, isFalse);
    });

    test('returns false when message is too short (< 20 chars)', () {
      bloc
        ..add(const SupportCategorySelected('Paiement'))
        ..add(const SupportSubjectChanged('Mon problème'))
        ..add(const SupportMessageChanged('Court'));
      expect(bloc.state.isValid, isFalse);
    });

    blocTest<SupportContactBloc, SupportContactState>(
      'returns true when all fields are valid',
      build: () => bloc,
      act: (b) => b
        ..add(const SupportCategorySelected('Paiement'))
        ..add(const SupportSubjectChanged('Problème remboursement'))
        ..add(
          const SupportMessageChanged(
            'Je n\'ai pas été remboursé suite à l\'annulation de ma commande.',
          ),
        ),
      verify: (b) => expect(b.state.isValid, isTrue),
    );
  });

  group('SupportSubmitRequested', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'emits submitting when state is valid',
      build: () => bloc,
      act: (b) {
        b
          ..add(const SupportCategorySelected('Bug technique'))
          ..add(const SupportSubjectChanged('Problème connexion app'))
          ..add(
            const SupportMessageChanged(
              'L\'application plante au démarrage depuis la mise à jour.',
            ),
          );
        b.add(const SupportSubmitRequested());
      },
      verify: (b) =>
          expect(b.state.submitStatus, SupportSubmitStatus.submitting),
    );

    blocTest<SupportContactBloc, SupportContactState>(
      'does not emit submitting when state is invalid',
      build: () => bloc,
      act: (b) => b.add(const SupportSubmitRequested()),
      expect: () => <SupportContactState>[],
    );
  });

  group('résultat du composeur email', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'ignore un résultat tardif lorsque la soumission n’est plus active',
      build: () => SupportContactBloc(analytics),
      act: (bloc) => bloc.add(const SupportEmailComposerOpened()),
      expect: () => <SupportContactState>[],
    );

    blocTest<SupportContactBloc, SupportContactState>(
      'sort de submitting vers success quand le brouillon est ouvert',
      build: () => SupportContactBloc(analytics),
      seed: () => const SupportContactState(
        category: 'Paiement',
        subject: 'Problème remboursement',
        message: 'Je n\'ai pas reçu mon remboursement depuis plusieurs jours.',
        submitStatus: SupportSubmitStatus.submitting,
      ),
      act: (bloc) => bloc.add(const SupportEmailComposerOpened()),
      expect: () => [
        isA<SupportContactState>().having(
          (state) => state.submitStatus,
          'submitStatus',
          SupportSubmitStatus.success,
        ),
      ],
    );

    blocTest<SupportContactBloc, SupportContactState>(
      'sort de submitting vers error quand aucun client mail ne répond',
      build: () => SupportContactBloc(analytics),
      seed: () => const SupportContactState(
        category: 'Bug technique',
        subject: 'Impossible de contacter le support',
        message:
            'Aucune application mail ne semble installée sur mon appareil.',
        submitStatus: SupportSubmitStatus.submitting,
      ),
      act: (bloc) => bloc.add(
        const SupportEmailComposerFailed(reason: 'mail_client_unavailable'),
      ),
      expect: () => [
        isA<SupportContactState>()
            .having(
              (state) => state.submitStatus,
              'submitStatus',
              SupportSubmitStatus.error,
            )
            .having(
              (state) => state.errorMessage,
              'errorMessage',
              'Impossible d\'ouvrir l\'application Mail.',
            ),
      ],
    );

    test('trace le composeur ouvert sans le sujet ni le message', () async {
      bloc
        ..add(const SupportCategorySelected('Paiement'))
        ..add(const SupportSubjectChanged('Problème remboursement'))
        ..add(
          const SupportMessageChanged(
            'Je n’ai pas reçu mon remboursement depuis plusieurs jours.',
          ),
        )
        ..add(const SupportSubmitRequested())
        ..add(const SupportEmailComposerOpened());
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.supportEmailComposerOpened, {
          'category': 'Paiement',
        }),
      ).called(1);
      verifyNever(
        () => backend.capture(
          AnalyticsEvents.supportEmailComposerOpened,
          any(that: containsPair('subject', any)),
        ),
      );
    });

    test('trace un échec avec un code et sans texte libre', () async {
      bloc
        ..add(const SupportCategorySelected('Bug technique'))
        ..add(const SupportSubjectChanged('Impossible d’ouvrir Mail'))
        ..add(
          const SupportMessageChanged(
            'Aucune application mail ne semble installée sur mon appareil.',
          ),
        )
        ..add(const SupportSubmitRequested())
        ..add(
          const SupportEmailComposerFailed(reason: 'mail_client_unavailable'),
        );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.supportContactFailed, {
          'category': 'Bug technique',
          'reason': 'mail_client_unavailable',
        }),
      ).called(1);
    });
  });
}
