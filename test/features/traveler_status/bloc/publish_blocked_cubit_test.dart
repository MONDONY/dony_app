import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/traveler_status/bloc/publish_blocked_cubit.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements TravelerStatusRepository {}

class MockAnalytics extends Mock implements AnalyticsService {}

const _statusRequired = PublishingEligibility(
  allowed: false,
  reason: PublishingReason.statusRequired,
  limit: 4,
  used: 4,
);

const _pending = PublishingEligibility(
  allowed: false,
  reason: PublishingReason.gpProPending,
  limit: 4,
  used: 4,
);

void main() {
  late MockRepository repository;
  late MockAnalytics analytics;

  setUp(() {
    repository = MockRepository();
    analytics = MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  PublishBlockedCubit build(
    PublishingEligibility initial, {
    String source = 'gate',
  }) => PublishBlockedCubit(initial, repository, analytics, source: source);

  test('l\'état de départ porte l\'éligibilité reçue', () {
    final c = build(_statusRequired);
    expect(c.state.eligibility, _statusRequired);
    expect(c.state.refreshing, isFalse);
    expect(c.state.canPublish, isFalse);
  });

  group('start', () {
    test('trace l\'écran vu avec la raison et la source, rien d\'autre', () {
      build(_statusRequired, source: 'publish_error').start();
      verify(
        () => analytics.logEvent(
          'publish_blocked_shown',
          properties: {'reason': 'STATUS_REQUIRED', 'source': 'publish_error'},
        ),
      ).called(1);
    });
  });

  group('individualDeclared', () {
    blocTest<PublishBlockedCubit, PublishBlockedState>(
      'statut requis : devient « limite atteinte » d\'un particulier',
      build: () => build(_statusRequired),
      act: (c) => c.individualDeclared(),
      expect: () => [
        isA<PublishBlockedState>()
            .having(
              (s) => s.eligibility.reason,
              'reason',
              PublishingReason.limitReached,
            )
            .having(
              (s) => s.eligibility.travelerStatus,
              'status',
              TravelerStatus.individual,
            )
            .having((s) => s.eligibility.limit, 'limit conservée', 4),
      ],
    );

    blocTest<PublishBlockedCubit, PublishBlockedState>(
      'une demande en attente n\'est pas modifiée',
      build: () => build(_pending),
      act: (c) => c.individualDeclared(),
      expect: () => <PublishBlockedState>[],
    );
  });

  group('refresh', () {
    blocTest<PublishBlockedCubit, PublishBlockedState>(
      'demande envoyée : la raison devient « en cours d\'examen »',
      build: () {
        when(
          () => repository.checkEligibility(),
        ).thenAnswer((_) async => (eligibility: _pending, failureCode: null));
        return build(_statusRequired);
      },
      act: (c) => c.refresh(),
      expect: () => [
        isA<PublishBlockedState>().having((s) => s.refreshing, 'r', isTrue),
        isA<PublishBlockedState>()
            .having((s) => s.refreshing, 'r', isFalse)
            .having(
              (s) => s.eligibility.reason,
              'reason',
              PublishingReason.gpProPending,
            ),
      ],
    );

    blocTest<PublishBlockedCubit, PublishBlockedState>(
      'plus de blocage : canPublish est vrai',
      build: () {
        when(() => repository.checkEligibility()).thenAnswer(
          (_) async =>
              (eligibility: PublishingEligibility.ok, failureCode: null),
        );
        return build(_pending);
      },
      act: (c) => c.refresh(),
      verify: (c) => expect(c.state.canPublish, isTrue),
    );

    blocTest<PublishBlockedCubit, PublishBlockedState>(
      'lecture en échec : l\'écran reste bloqué, l\'échec est tracé avec '
      'son code seul',
      build: () {
        when(() => repository.checkEligibility()).thenAnswer(
          (_) async =>
              (eligibility: PublishingEligibility.ok, failureCode: 'OFFLINE'),
        );
        return build(_statusRequired);
      },
      act: (c) => c.refresh(),
      verify: (c) {
        expect(c.state.canPublish, isFalse);
        expect(c.state.eligibility, _statusRequired);
        expect(c.state.refreshing, isFalse);
        verify(
          () => analytics.logEvent(
            'publish_eligibility_failed',
            properties: {'error_code': 'OFFLINE'},
          ),
        ).called(1);
      },
    );

    blocTest<PublishBlockedCubit, PublishBlockedState>(
      'double appel : une seule lecture',
      build: () {
        when(() => repository.checkEligibility()).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return (eligibility: _pending, failureCode: null);
        });
        return build(_statusRequired);
      },
      act: (c) async {
        await Future.wait([c.refresh(), c.refresh()]);
      },
      verify: (_) => verify(() => repository.checkEligibility()).called(1),
    );
  });
}
