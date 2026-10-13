import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/publish_gate/bloc/publish_gate_cubit.dart';
import 'package:dony/features/publish_gate/bloc/publish_gate_state.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';
import 'package:dony/features/publish_gate/data/models/publish_draft_entry.dart';
import 'package:dony/features/publish_gate/data/repositories/publish_commitment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/form_draft_test_doubles.dart';
import 'publish_gate_fixtures.dart';

class _MockCommitments extends Mock implements PublishCommitmentRepository {}

class _MockAnnouncements extends Mock implements AnnouncementRepository {}

class _MockRequests extends Mock implements PackageRequestRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  setUpAll(() => registerFallbackValue(PublishCommitmentRole.traveler));

  late _MockCommitments commitmentRepo;
  late _MockAnnouncements announcements;
  late _MockRequests requests;
  late _MockAnalytics analytics;
  late FormDraftStore store;

  setUp(() {
    commitmentRepo = _MockCommitments();
    announcements = _MockAnnouncements();
    requests = _MockRequests();
    analytics = _MockAnalytics();
    store = testFormDraftStore();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => announcements.getMyAnnouncements()).thenAnswer(
      (_) async =>
          (announcements: [tripFixture(status: 'ACTIVE')], totalElements: 1),
    );
    when(() => requests.findMine(size: any(named: 'size'))).thenAnswer(
      (_) async => PackageRequestPage(
        content: [requestFixture(status: PackageRequestStatus.open)],
        totalElements: 1,
        page: 0,
        size: 50,
      ),
    );
    when(() => commitmentRepo.accept(any(), any())).thenAnswer((_) async {});
  });

  PublishGateCubit build(PublishCommitmentRole role) => PublishGateCubit(
    role: role,
    commitments: commitmentRepo,
    drafts: store,
    announcements: announcements,
    packageRequests: requests,
    analytics: analytics,
  );

  group('start', () {
    test('déjà accepté et vérifié : écran sauté, aucun brouillon', () async {
      when(
        () => commitmentRepo.fetch(),
      ).thenAnswer((_) async => commitments(travelerRequired: false));
      final cubit = build(PublishCommitmentRole.traveler);

      await cubit.start(kycVerified: true);

      expect(cubit.state.status, PublishGateStatus.ready);
      expect(cubit.state.introShown, isFalse);
      expect(cubit.state.drafts, isEmpty);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.publishDraftsSheetShown,
          properties: any(named: 'properties'),
        ),
      );
    });

    test('à accepter : écran des engagements', () async {
      when(() => commitmentRepo.fetch()).thenAnswer((_) async => commitments());
      final cubit = build(PublishCommitmentRole.sender);

      await cubit.start(kycVerified: true);

      expect(cubit.state.status, PublishGateStatus.intro);
      expect(cubit.state.commitmentRequired, isTrue);
      expect(cubit.state.version, '2026-10');
      expect(cubit.state.introShown, isTrue);
    });

    test('accepté mais identité non vérifiée : écran affiché', () async {
      when(
        () => commitmentRepo.fetch(),
      ).thenAnswer((_) async => commitments(travelerRequired: false));
      final cubit = build(PublishCommitmentRole.traveler);

      await cubit.start(kycVerified: false);

      expect(cubit.state.status, PublishGateStatus.intro);
      expect(cubit.state.commitmentRequired, isFalse);
    });

    test(
      'engagements illisibles (hors ligne) : écran, accord requis',
      () async {
        when(
          () => commitmentRepo.fetch(),
        ).thenThrow(const NetworkException('x'));
        final cubit = build(PublishCommitmentRole.traveler);

        await cubit.start(kycVerified: true);

        expect(cubit.state.status, PublishGateStatus.intro);
        expect(cubit.state.commitmentRequired, isTrue);
        expect(cubit.state.version, isNull);
      },
    );
  });

  group('accept', () {
    test('case non cochée : rien n\'est envoyé', () async {
      when(() => commitmentRepo.fetch()).thenAnswer((_) async => commitments());
      final cubit = build(PublishCommitmentRole.traveler);
      await cubit.start(kycVerified: true);

      await cubit.accept();

      verifyNever(() => commitmentRepo.accept(any(), any()));
      expect(cubit.state.status, PublishGateStatus.intro);
    });

    test('cochée : acceptation envoyée, tracée, puis brouillons', () async {
      when(() => commitmentRepo.fetch()).thenAnswer((_) async => commitments());
      final cubit = build(PublishCommitmentRole.traveler);
      await cubit.start(kycVerified: true);

      cubit.setChecked(true);
      await cubit.accept();

      verify(
        () => commitmentRepo.accept(PublishCommitmentRole.traveler, '2026-10'),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.publishCommitmentAccepted,
          properties: {'role': 'traveler'},
        ),
      ).called(1);
      expect(cubit.state.status, PublishGateStatus.ready);
      expect(cubit.state.commitmentRequired, isFalse);
      expect(cubit.state.introShown, isTrue);
    });

    test('version inconnue (lecture ratée) : relue avant l\'envoi', () async {
      var calls = 0;
      when(() => commitmentRepo.fetch()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const NetworkException('x');
        return commitments(version: '2026-11');
      });
      final cubit = build(PublishCommitmentRole.sender);
      await cubit.start(kycVerified: true);

      cubit.setChecked(true);
      await cubit.accept();

      verify(
        () => commitmentRepo.accept(PublishCommitmentRole.sender, '2026-11'),
      ).called(1);
    });

    test(
      'version périmée (409) : case décochée, nouvelle version, erreur',
      () async {
        var calls = 0;
        when(() => commitmentRepo.fetch()).thenAnswer((_) async {
          calls++;
          return commitments(version: calls == 1 ? '2026-10' : '2026-12');
        });
        when(() => commitmentRepo.accept(any(), '2026-10')).thenThrow(
          const ConflictException('x', code: 'publish-commitment-outdated'),
        );
        final cubit = build(PublishCommitmentRole.traveler);
        await cubit.start(kycVerified: true);

        cubit.setChecked(true);
        await cubit.accept();

        expect(cubit.state.status, PublishGateStatus.intro);
        expect(cubit.state.checked, isFalse);
        expect(cubit.state.version, '2026-12');
        expect(cubit.state.error, PublishGateError.outdated);
        expect(cubit.state.errorSeq, 1);
      },
    );

    test('409 puis relecture impossible : version vidée', () async {
      var calls = 0;
      when(() => commitmentRepo.fetch()).thenAnswer((_) async {
        calls++;
        if (calls > 1) throw const NetworkException('x');
        return commitments();
      });
      when(() => commitmentRepo.accept(any(), any())).thenThrow(
        const ConflictException('x', code: 'publish-commitment-outdated'),
      );
      final cubit = build(PublishCommitmentRole.traveler);
      await cubit.start(kycVerified: true);
      cubit.setChecked(true);

      await cubit.accept();

      expect(cubit.state.version, isNull);
      expect(cubit.state.error, PublishGateError.outdated);
    });

    test('autre erreur serveur : écran conservé, erreur', () async {
      when(() => commitmentRepo.fetch()).thenAnswer((_) async => commitments());
      when(
        () => commitmentRepo.accept(any(), any()),
      ).thenThrow(const ServerException('boom'));
      final cubit = build(PublishCommitmentRole.traveler);
      await cubit.start(kycVerified: true);
      cubit.setChecked(true);

      await cubit.accept();

      expect(cubit.state.status, PublishGateStatus.intro);
      expect(cubit.state.checked, isTrue);
      expect(cubit.state.error, PublishGateError.acceptFailed);
    });

    test('back antérieur (404) : on laisse publier, rien de tracé', () async {
      when(() => commitmentRepo.fetch()).thenThrow(const NotFoundException());
      final cubit = build(PublishCommitmentRole.traveler);
      await cubit.start(kycVerified: true);
      cubit.setChecked(true);

      await cubit.accept();

      expect(cubit.state.status, PublishGateStatus.ready);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.publishCommitmentAccepted,
          properties: any(named: 'properties'),
        ),
      );
    });

    test('erreur non typée : écran conservé, erreur', () async {
      when(() => commitmentRepo.fetch()).thenAnswer((_) async => commitments());
      when(
        () => commitmentRepo.accept(any(), any()),
      ).thenThrow(StateError('x'));
      final cubit = build(PublishCommitmentRole.traveler);
      await cubit.start(kycVerified: true);
      cubit.setChecked(true);

      await cubit.accept();

      expect(cubit.state.error, PublishGateError.acceptFailed);
    });

    test(
      'déjà accepté (écran montré pour le KYC) : brouillons directement',
      () async {
        when(
          () => commitmentRepo.fetch(),
        ).thenAnswer((_) async => commitments(travelerRequired: false));
        final cubit = build(PublishCommitmentRole.traveler);
        await cubit.start(kycVerified: false);

        await cubit.accept();

        verifyNever(() => commitmentRepo.accept(any(), any()));
        expect(cubit.state.status, PublishGateStatus.ready);
      },
    );
  });

  group('brouillons', () {
    test(
      'voyageur : brouillon local d\'abord, puis DRAFT serveur récents',
      () async {
        when(
          () => commitmentRepo.fetch(),
        ).thenAnswer((_) async => commitments(travelerRequired: false));
        await store.save(FormDraftKind.trip, {
          'step': 1,
          'departureCity': 'Marseille',
          'arrivalCity': 'Douala',
        });
        when(() => announcements.getMyAnnouncements()).thenAnswer(
          (_) async => (
            announcements: [
              tripFixture(id: 'old', updatedAt: DateTime.utc(2026, 9)),
              tripFixture(id: 'actif', status: 'ACTIVE'),
              for (var i = 0; i < 6; i++)
                tripFixture(
                  id: 'd$i',
                  updatedAt: DateTime.utc(2026, 10, 2 + i),
                ),
            ],
            totalElements: 8,
          ),
        );
        final cubit = build(PublishCommitmentRole.traveler);

        await cubit.start(kycVerified: true);

        final drafts = cubit.state.drafts;
        expect(drafts.first, isA<LocalPublishDraft>());
        expect(drafts.first.departureCity, 'Marseille');
        expect(drafts.first.arrivalCity, 'Douala');
        final server = drafts.skip(1).cast<ServerTripDraft>().toList();
        expect(server, hasLength(PublishGateCubit.maxServerDrafts));
        expect(server.first.announcement.id, 'd5');
        expect(server.first.departureCity, 'Paris');
        expect(server.first.date, DateTime(2026, 11, 20));
        expect(server.map((d) => d.announcement.id), isNot(contains('actif')));
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.publishDraftsSheetShown,
            properties: {'role': 'traveler', 'local': true, 'server_count': 5},
          ),
        ).called(1);
      },
    );

    test('expéditeur : brouillon local et demandes DRAFT', () async {
      when(
        () => commitmentRepo.fetch(),
      ).thenAnswer((_) async => commitments(senderRequired: false));
      await store.save(FormDraftKind.packageRequest, {
        'step': 0,
        'departureCity': 'Paris',
        'desiredDate': '2030-01-02',
      });
      when(() => requests.findMine(size: any(named: 'size'))).thenAnswer(
        (_) async => PackageRequestPage(
          content: [
            requestFixture(id: 'r1'),
            requestFixture(id: 'r2', status: PackageRequestStatus.open),
          ],
          totalElements: 2,
          page: 0,
          size: 50,
        ),
      );
      final cubit = build(PublishCommitmentRole.sender);

      await cubit.start(kycVerified: true);

      final drafts = cubit.state.drafts;
      expect(drafts, hasLength(2));
      final local = drafts.first as LocalPublishDraft;
      expect(local.date, DateTime(2030, 1, 2));
      expect(local.arrivalCity, isNull);
      final server = drafts.last as ServerRequestDraft;
      expect(server.request.id, 'r1');
      expect(server.arrivalCity, 'Abidjan');
      expect(server.date, DateTime(2026, 11, 15));
    });

    test(
      'brouillons serveur indisponibles : liste vide, pas d\'échec',
      () async {
        when(
          () => commitmentRepo.fetch(),
        ).thenAnswer((_) async => commitments(travelerRequired: false));
        when(
          () => announcements.getMyAnnouncements(),
        ).thenThrow(const NetworkException('x'));
        final cubit = build(PublishCommitmentRole.traveler);

        await cubit.start(kycVerified: true);

        expect(cubit.state.status, PublishGateStatus.ready);
        expect(cubit.state.drafts, isEmpty);
      },
    );
  });

  test('trackChoice : choix et ancienneté du brouillon local', () async {
    final cubit = build(PublishCommitmentRole.traveler);
    final local = LocalPublishDraft(
      draft: StoredFormDraft(data: const {'step': 2}, savedAt: DateTime.now()),
    );

    cubit
      ..trackChoice(PublishDraftChoice.local, entry: local)
      ..trackChoice(PublishDraftChoice.createNew);

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.publishDraftChosen,
        properties: {
          'role': 'traveler',
          'choice': 'local',
          'step': 2,
          'age_days': 0,
        },
      ),
    ).called(1);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.publishDraftChosen,
        properties: {'role': 'traveler', 'choice': 'new'},
      ),
    ).called(1);
    expect(local.props, isNotEmpty);
  });

  test('PublishGateState.copyWith garde l\'erreur sans bumpError', () {
    const s = PublishGateState(error: PublishGateError.outdated, errorSeq: 3);
    final next = s.copyWith(checked: true);
    expect(next.error, PublishGateError.outdated);
    expect(next.errorSeq, 3);
    expect(
      s
          .copyWith(error: PublishGateError.acceptFailed, bumpError: true)
          .errorSeq,
      4,
    );
  });
}
