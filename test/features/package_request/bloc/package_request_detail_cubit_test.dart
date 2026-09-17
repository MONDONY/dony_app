import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_cubit.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_state.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_insights.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Requests extends Mock implements PackageRequestRepository {}
class _Announcements extends Mock implements AnnouncementRepository {}
class _Bids extends Mock implements BidRepository {}
class _Analytics extends Mock implements AnalyticsService {}

PackageRequest _req(PackageRequestStatus status) => PackageRequest(
  id: 'pr-1', senderId: 'sender-1', departureCity: 'Divo', arrivalCity: 'Annemasse',
  desiredDate: DateTime(2026, 9, 27), dateToleranceDays: 2, weightKg: 2,
  parcelSize: ParcelSize.small, transportMode: TransportMode.plane,
  status: status, createdAt: DateTime.utc(2026, 9, 17, 6, 25),
);

NegotiationThread _thread(NegotiationThreadStatus s, {String traveler = 'trav-a', String? bidId}) => NegotiationThread(
  id: 't-$traveler', packageRequestId: 'pr-1', travelerId: traveler,
  travelerTravelDate: DateTime(2026, 9, 26), travelerAvailableKg: 8, status: s,
  currentPriceEur: 25, roundsCount: 1, lastActivityAt: DateTime(2026, 9, 17),
  createdAt: DateTime(2026, 9, 17), messages: const [], materializedBidId: bidId,
);

AnnouncementModel _trip(String id, String traveler) => AnnouncementModel(
  id: id, travelerId: traveler, departureCity: 'Divo', arrivalCity: 'Annemasse',
  departureDate: DateTime(2026, 9, 26), availableKg: 8, totalKg: 10, pricePerKg: 7,
  status: 'ACTIVE', createdAt: DateTime(2026, 9), updatedAt: DateTime(2026, 9),
);

DioException _http(int status) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(statusCode: status, requestOptions: RequestOptions(path: '/x')),
);

void main() {
  late _Requests requests;
  late _Announcements announcements;
  late _Bids bids;
  late _Analytics analytics;

  PackageRequestDetailCubit build() =>
      PackageRequestDetailCubit(requests, announcements, bids, analytics, requestId: 'pr-1');

  void stubSearch(List<AnnouncementModel> trips) => when(() => announcements.searchAnnouncements(
    departureCity: any(named: 'departureCity'),
    arrivalCity: any(named: 'arrivalCity'),
    departureDateFrom: any(named: 'departureDateFrom'),
    departureDateTo: any(named: 'departureDateTo'),
    minAvailableKg: any(named: 'minAvailableKg'),
  )).thenAnswer((_) async => trips);

  setUp(() {
    requests = _Requests();
    announcements = _Announcements();
    bids = _Bids();
    analytics = _Analytics();
    when(() => analytics.logEvent(any(), properties: any(named: 'properties'))).thenAnswer((_) async {});
    when(() => requests.getById('pr-1')).thenAnswer((_) async => _req(PackageRequestStatus.open));
    when(() => requests.listThreadsForRequest('pr-1')).thenAnswer((_) async => const []);
    when(() => requests.getInsights('pr-1')).thenAnswer((_) async =>
        const PackageRequestInsights(viewCount: 14, invitedAnnouncementIds: {'a-1'}));
    stubSearch([_trip('a-1', 'trav-a'), _trip('a-2', 'trav-b'), _trip('own', 'sender-1')]);
  });

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'load : demande publiée, voyageurs sur l axe filtrés, vues et invités',
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const PackageRequestDetailLoading(),
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.screenCase, 'case', RequestScreenCase.noOffers)
          .having((s) => s.insights?.viewCount, 'views', 14)
          .having((s) => s.compatibleTrips!.map((t) => t.id), 'trips', ['a-1', 'a-2'])
          .having((s) => s.invitedAnnouncementIds, 'invited', {'a-1'})
          .having((s) => s.invitationsSupported, 'supported', isTrue),
    ],
    verify: (_) => verify(() => announcements.searchAnnouncements(
      departureCity: 'Divo',
      arrivalCity: 'Annemasse',
      departureDateFrom: DateTime(2026, 9, 25),
      departureDateTo: DateTime(2026, 9, 29),
      minAvailableKg: 2,
    )).called(1),
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'load : les voyageurs ayant déjà un fil sont exclus',
    build: build,
    setUp: () => when(() => requests.listThreadsForRequest('pr-1'))
        .thenAnswer((_) async => [_thread(NegotiationThreadStatus.rejected)]),
    act: (c) => c.load(),
    skip: 1,
    expect: () => [
      isA<PackageRequestDetailLoaded>().having((s) => s.compatibleTrips!.map((t) => t.id), 'trips', ['a-2']),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'load : back sans insights ni recherche utilisable reste affichable',
    build: build,
    setUp: () {
      when(() => requests.getInsights('pr-1')).thenAnswer((_) async => null);
      when(() => announcements.searchAnnouncements(
        departureCity: any(named: 'departureCity'), arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'), departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
      )).thenThrow(_http(500));
    },
    act: (c) => c.load(),
    skip: 1,
    expect: () => [
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.insights, 'insights', isNull)
          .having((s) => s.invitationsSupported, 'supported', isFalse)
          .having((s) => s.compatibleTrips, 'trips', isNull)
          .having((s) => s.screenCase, 'case', RequestScreenCase.noOffers),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'load : acceptée, le bid matérialisé est chargé',
    build: build,
    setUp: () {
      when(() => requests.getById('pr-1')).thenAnswer((_) async => _req(PackageRequestStatus.accepted));
      when(() => requests.listThreadsForRequest('pr-1')).thenAnswer((_) async =>
          [_thread(NegotiationThreadStatus.accepted, bidId: 'bid-1')]);
      when(() => bids.getBidById('bid-1')).thenAnswer((_) async => BidModel(
        id: 'bid-1', announcementId: 'a', senderId: 'sender-1', weightKg: 2, status: 'COMPLETED',
        createdAt: DateTime(2026, 9), updatedAt: DateTime(2026, 9)));
    },
    act: (c) => c.load(),
    skip: 1,
    expect: () => [
      isA<PackageRequestDetailLoaded>().having((s) => s.screenCase, 'case', RequestScreenCase.delivered),
    ],
    verify: (_) => verifyNever(() => announcements.searchAnnouncements(
      departureCity: any(named: 'departureCity'), arrivalCity: any(named: 'arrivalCity'),
      departureDateFrom: any(named: 'departureDateFrom'), departureDateTo: any(named: 'departureDateTo'),
      minAvailableKg: any(named: 'minAvailableKg'))),
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'load : échec de la demande → erreur',
    build: build,
    setUp: () => when(() => requests.getById('pr-1')).thenThrow(_http(500)),
    act: (c) => c.load(),
    expect: () => [const PackageRequestDetailLoading(), const PackageRequestDetailError()],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'load : 404 au premier chargement (demande annulée/supprimée) → erreur notFound',
    build: build,
    setUp: () => when(() => requests.getById('pr-1')).thenThrow(_http(404)),
    act: (c) => c.load(),
    expect: () => [
      const PackageRequestDetailLoading(),
      const PackageRequestDetailError(notFound: true),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'cancel : état annulé local, analytics',
    build: build,
    setUp: () => when(() => requests.cancel('pr-1')).thenAnswer((_) async {}),
    act: (c) async {
      await c.load();
      await c.cancel();
    },
    skip: 2,
    expect: () => [
      isA<PackageRequestDetailLoaded>().having((s) => s.actionInFlight, 'busy', isTrue),
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.screenCase, 'case', RequestScreenCase.cancelled)
          .having((s) => s.actionInFlight, 'busy', isFalse),
    ],
    verify: (_) => verify(() => analytics.logEvent(AnalyticsEvents.packageRequestCancelled)).called(1),
  );

  test(
    'load après cancel : soft-delete → aucun appel getById, aucun nouvel état '
    '(sinon un rafraîchissement produirait une fausse erreur 404)',
    () async {
      when(() => requests.cancel('pr-1')).thenAnswer((_) async {});
      final c = build();
      await c.load();
      await c.cancel();
      final stateAfterCancel = c.state;

      await c.load();

      expect(c.state, same(stateAfterCancel));
      verify(() => requests.getById('pr-1')).called(1);
      await c.close();
    },
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'cancel en échec : notice actionFailed, pas d état annulé',
    build: build,
    setUp: () => when(() => requests.cancel('pr-1')).thenThrow(_http(409)),
    act: (c) async {
      await c.load();
      await c.cancel();
    },
    skip: 3,
    expect: () => [
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.screenCase, 'case', RequestScreenCase.noOffers)
          .having((s) => s.notice?.kind, 'notice', RequestDetailNoticeKind.actionFailed),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'publish : recharge et trace',
    build: build,
    setUp: () {
      when(() => requests.getById('pr-1')).thenAnswer((_) async => _req(PackageRequestStatus.draft));
      when(() => requests.publish('pr-1')).thenAnswer((_) async => _req(PackageRequestStatus.open));
    },
    act: (c) async {
      await c.load();
      await c.publish();
    },
    verify: (cubit) {
      verify(() => requests.publish('pr-1')).called(1);
      verify(() => analytics.logEvent(AnalyticsEvents.packageRequestPublished)).called(1);
      verify(() => requests.getById('pr-1')).called(2);
      expect(cubit.state,
          isA<PackageRequestDetailLoaded>().having((s) => s.actionInFlight, 'busy', isFalse));
    },
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'publish réussi puis rechargement en échec : actionInFlight repasse à false avec une notice',
    build: build,
    setUp: () {
      var getCalls = 0;
      when(() => requests.getById('pr-1')).thenAnswer((_) async {
        getCalls++;
        if (getCalls == 1) return _req(PackageRequestStatus.draft);
        throw _http(500);
      });
      when(() => requests.publish('pr-1')).thenAnswer((_) async => _req(PackageRequestStatus.open));
    },
    act: (c) async {
      await c.load();
      await c.publish();
    },
    skip: 3,
    expect: () => [
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.actionInFlight, 'busy', isFalse)
          .having((s) => s.notice?.kind, 'notice', RequestDetailNoticeKind.actionFailed),
    ],
  );

  test('invite et cancel entrelacés : l état relu après chaque await, pas l état capturé avant', () async {
    final inviteCompleter = Completer<InvitationOutcome>();
    final cancelCompleter = Completer<void>();
    when(() => requests.inviteTraveler('pr-1', 'a-2')).thenAnswer((_) => inviteCompleter.future);
    when(() => requests.cancel('pr-1')).thenAnswer((_) => cancelCompleter.future);

    final c = build();
    await c.load();

    final invitePending = c.invite('a-2');
    final cancelPending = c.cancel();

    inviteCompleter.complete(InvitationOutcome.sent);
    await invitePending;

    cancelCompleter.complete();
    await cancelPending;

    final state = c.state as PackageRequestDetailLoaded;
    expect(state.cancelledLocally, isTrue);
    expect(state.invitingAnnouncementIds, isEmpty);
    expect(state.invitedAnnouncementIds, contains('a-2'));

    await c.close();
  });

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'invite : envoi réussi → invité + notice',
    build: build,
    setUp: () => when(() => requests.inviteTraveler('pr-1', 'a-2')).thenAnswer((_) async => InvitationOutcome.sent),
    act: (c) async {
      await c.load();
      await c.invite('a-2');
    },
    skip: 2,
    expect: () => [
      isA<PackageRequestDetailLoaded>().having((s) => s.invitingAnnouncementIds, 'inviting', {'a-2'}),
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.invitingAnnouncementIds, 'inviting', isEmpty)
          .having((s) => s.invitedAnnouncementIds, 'invited', {'a-1', 'a-2'})
          .having((s) => s.notice?.kind, 'notice', RequestDetailNoticeKind.invitationSent),
    ],
    verify: (_) => verify(() => analytics.logEvent(AnalyticsEvents.packageRequestTravelerInvited,
        properties: {'outcome': 'sent'})).called(1),
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'invite : 404 après insights KO (ancien back) → invitations masquées',
    build: build,
    setUp: () {
      when(() => requests.getInsights('pr-1')).thenAnswer((_) async => null);
      when(() => requests.inviteTraveler('pr-1', 'a-2')).thenAnswer((_) async => InvitationOutcome.notFound);
    },
    act: (c) async {
      await c.load();
      await c.invite('a-2');
    },
    skip: 3,
    expect: () => [
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.invitationsSupported, 'supported', isFalse)
          .having((s) => s.notice, 'notice', isNull),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'invite : 404 après insights OK (back à jour) → trajet disparu, notice invitationRefused',
    build: build,
    // setUp par défaut : getInsights répond déjà (invitationsSupported=true).
    setUp: () => when(() => requests.inviteTraveler('pr-1', 'a-2')).thenAnswer((_) async => InvitationOutcome.notFound),
    act: (c) async {
      await c.load();
      await c.invite('a-2');
    },
    skip: 3,
    expect: () => [
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.invitationsSupported, 'supported', isTrue)
          .having((s) => s.notice?.kind, 'notice', RequestDetailNoticeKind.invitationRefused),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'invite : 409 request/not-invitable → notice dédiée',
    build: build,
    setUp: () => when(() => requests.inviteTraveler('pr-1', 'a-2')).thenAnswer((_) async => InvitationOutcome.notInvitable),
    act: (c) async {
      await c.load();
      await c.invite('a-2');
    },
    skip: 3,
    expect: () => [
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.invitingAnnouncementIds, 'inviting', isEmpty)
          .having((s) => s.notice?.kind, 'notice', RequestDetailNoticeKind.invitationNotInvitable),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'invite : 422 limite atteinte → notice dédiée',
    build: build,
    setUp: () => when(() => requests.inviteTraveler('pr-1', 'a-2')).thenAnswer((_) async => InvitationOutcome.limitReached),
    act: (c) async {
      await c.load();
      await c.invite('a-2');
    },
    skip: 3,
    expect: () => [
      isA<PackageRequestDetailLoaded>().having((s) => s.notice?.kind, 'notice', RequestDetailNoticeKind.invitationLimitReached),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'invite : 422 générique (autre raison) → notice invitationRefused',
    build: build,
    setUp: () => when(() => requests.inviteTraveler('pr-1', 'a-2')).thenThrow(_http(422)),
    act: (c) async {
      await c.load();
      await c.invite('a-2');
    },
    skip: 3,
    expect: () => [
      isA<PackageRequestDetailLoaded>().having((s) => s.notice?.kind, 'notice', RequestDetailNoticeKind.invitationRefused),
    ],
  );

  blocTest<PackageRequestDetailCubit, PackageRequestDetailState>(
    'invite : exception non-Dio → id retiré + notice actionFailed',
    build: build,
    setUp: () => when(() => requests.inviteTraveler('pr-1', 'a-2')).thenThrow(Exception('boom')),
    act: (c) async {
      await c.load();
      await c.invite('a-2');
    },
    skip: 3,
    expect: () => [
      isA<PackageRequestDetailLoaded>()
          .having((s) => s.invitingAnnouncementIds, 'inviting', isEmpty)
          .having((s) => s.notice?.kind, 'notice', RequestDetailNoticeKind.actionFailed),
    ],
  );

  test('traces sans état', () async {
    final c = build();
    c.trackShared();
    c.trackMenuOpened();
    c.trackDuplicateStarted('republish');
    verify(() => analytics.logEvent(AnalyticsEvents.packageRequestShared)).called(1);
    verify(() => analytics.logEvent(AnalyticsEvents.packageRequestMenuOpened)).called(1);
    verify(() => analytics.logEvent(AnalyticsEvents.packageRequestDuplicateStarted,
        properties: {'source': 'republish'})).called(1);
    await c.close();
  });
}
