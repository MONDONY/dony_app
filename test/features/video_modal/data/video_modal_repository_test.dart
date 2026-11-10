import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_local_datasource.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_remote_datasource.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_local_history.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/recording_dio.dart';
import '../video_modal_test_data.dart';

void main() {
  late RecordingApi api;
  late VideoModalLocalDatasource local;
  late VideoModalRepository repo;
  final now = DateTime.utc(2026, 11, 10, 9, 30);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = RecordingApi();
    local = VideoModalLocalDatasource();
    repo = VideoModalRepository(
      VideoModalRemoteDatasource(api.client),
      local,
      clock: () => now,
    );
  });

  group('loadEligible', () {
    test(
      'envoie la langue, caps=layout,targeting,moments et la plateforme, sans report Sentry ni relance',
      () async {
        api.on('GET', '/video-modals/eligible', [campaignJson()]);
        final list = await repo.loadEligible(lang: 'en', realSession: true);
        expect(list.single.id, 'c1');
        expect(api.last.queryParameters, {
          'lang': 'en',
          'caps': 'layout,targeting,moments',
          'platform': 'android',
        });
        expect(api.last.extra[ApiClient.skipErrorReportKey], isTrue);
        expect(api.last.extra['skipTransientRetry'], isTrue);
      },
    );

    test('back absent (404) : aucune campagne, aucune erreur', () async {
      api.on('GET', '/video-modals/eligible', {
        'title': 'Not Found',
      }, status: 404);
      expect(await repo.loadEligible(lang: 'fr', realSession: true), isEmpty);
    });

    test('réseau coupé : aucune campagne, aucune erreur', () async {
      api.adapter.failWith = DioExceptionType.connectionError;
      expect(await repo.loadEligible(lang: 'fr', realSession: false), isEmpty);
    });

    test('corps inattendu : aucune campagne', () async {
      api.on('GET', '/video-modals/eligible', {'items': []});
      expect(await repo.loadEligible(lang: 'fr', realSession: true), isEmpty);
    });

    test('écarte une campagne déjà au plafond, même avec un compte', () async {
      api.on('GET', '/video-modals/eligible', [
        campaignJson(id: 'plein', displays: 3),
        campaignJson(id: 'ok'),
      ]);
      final list = await repo.loadEligible(lang: 'fr', realSession: true);
      expect(list.map((c) => c.id), ['ok']);
    });

    test('visiteur : applique son historique local', () async {
      await local.writeHistory(
        const VideoModalLocalHistory().apply(
          'c1',
          2,
          VideoModalEventType.dismissed,
        ),
      );
      api.on('GET', '/video-modals/eligible', [
        campaignJson(),
        campaignJson(id: 'c2'),
      ]);
      final guest = await repo.loadEligible(lang: 'fr', realSession: false);
      expect(guest.map((c) => c.id), ['c2']);
      final account = await repo.loadEligible(lang: 'fr', realSession: true);
      expect(account.map((c) => c.id), ['c1', 'c2']);
    });
  });

  group('record', () {
    test('compte : POST sans occurredAt', () async {
      await repo.record(
        campaign(),
        VideoModalEventType.opened,
        realSession: true,
      );
      expect(api.last.method, 'POST');
      expect(api.last.path, '/video-modals/c1/events');
      expect(api.last.data, {'version': 2, 'event': 'OPENED'});
      expect(await local.readPending(), isEmpty);
    });

    test('compte : un échec du POST est avalé', () async {
      api.on('POST', '/video-modals/c1/events', null, status: 404);
      await expectLater(
        repo.record(campaign(), VideoModalEventType.shown, realSession: true),
        completes,
      );
    });

    test('visiteur : rien sur le réseau, historique et file locale', () async {
      await repo.record(
        campaign(),
        VideoModalEventType.shown,
        realSession: false,
      );
      await repo.record(
        campaign(),
        VideoModalEventType.dismissed,
        realSession: false,
      );
      expect(api.requests, isEmpty);
      final history = await local.readHistory();
      expect(history.recordOf('c1', 2).displays, 1);
      expect(history.recordOf('c1', 2).status, VideoModalEventType.dismissed);
      final pending = await local.readPending();
      expect(pending.map((e) => e.event), [
        VideoModalEventType.shown,
        VideoModalEventType.dismissed,
      ]);
      expect(pending.first.occurredAt, now);
    });

    test('visiteur : stockage illisible remplacé sans planter', () async {
      SharedPreferences.setMockInitialValues({
        VideoModalLocalDatasource.historyKey: '{pas du json',
        VideoModalLocalDatasource.pendingKey: '"pas une liste"',
      });
      await repo.record(
        campaign(),
        VideoModalEventType.shown,
        realSession: false,
      );
      expect(await local.readPending(), hasLength(1));
    });

    test('visiteur : une écriture en échec est avalée', () async {
      final broken = VideoModalRepository(
        VideoModalRemoteDatasource(api.client),
        VideoModalLocalDatasource(prefs: () => Future.error(StateError('x'))),
      );
      await expectLater(
        broken.record(
          campaign(),
          VideoModalEventType.shown,
          realSession: false,
        ),
        completes,
      );
      expect(
        await broken.loadEligible(lang: 'fr', realSession: false),
        isEmpty,
      );
      expect(await broken.syncGuestEvents(), 0);
    });
  });

  group('syncGuestEvents', () {
    Future<void> seed() async {
      await repo.record(
        campaign(),
        VideoModalEventType.shown,
        realSession: false,
      );
      await repo.record(
        campaign(),
        VideoModalEventType.opened,
        realSession: false,
      );
    }

    test('envoie dans l\'ordre avec occurredAt, puis efface tout', () async {
      await seed();
      expect(await repo.syncGuestEvents(), 2);
      expect(api.requests.map((r) => r.data), [
        {
          'version': 2,
          'event': 'SHOWN',
          'occurredAt': '2026-11-10T09:30:00.000Z',
        },
        {
          'version': 2,
          'event': 'OPENED',
          'occurredAt': '2026-11-10T09:30:00.000Z',
        },
      ]);
      expect(await local.readPending(), isEmpty);
      expect((await local.readHistory()).isEmpty, isTrue);
    });

    test('campagne inconnue (404) : ligne abandonnée, la suite part', () async {
      await seed();
      api.on('POST', '/video-modals/c1/events', {'title': 'x'}, status: 404);
      expect(await repo.syncGuestEvents(), 0);
      expect(api.requests, hasLength(2));
      expect(await local.readPending(), isEmpty);
    });

    test('réseau coupé : tout est gardé pour la prochaine connexion', () async {
      await seed();
      api.adapter.failWith = DioExceptionType.connectionTimeout;
      expect(await repo.syncGuestEvents(), 0);
      expect(await local.readPending(), hasLength(2));
      expect((await local.readHistory()).isEmpty, isFalse);
    });

    test('5xx : arrêt, le reste est gardé', () async {
      await seed();
      api.on('POST', '/video-modals/c1/events', null, status: 503);
      expect(await repo.syncGuestEvents(), 0);
      expect(await local.readPending(), hasLength(2));
    });

    test('erreur inattendue : le reste est gardé', () async {
      await seed();
      final failing = VideoModalRepository(_ThrowingRemote(), local);
      expect(await failing.syncGuestEvents(), 0);
      expect(await local.readPending(), hasLength(2));
    });

    test('rien en attente : historique effacé, aucun appel', () async {
      await local.writeHistory(
        const VideoModalLocalHistory().apply(
          'c1',
          1,
          VideoModalEventType.shown,
        ),
      );
      expect(await repo.syncGuestEvents(), 0);
      expect(api.requests, isEmpty);
      expect((await local.readHistory()).isEmpty, isTrue);
    });
  });
}

class _ThrowingRemote implements VideoModalRemoteDatasource {
  @override
  Future<Object?> fetchEligible(
    String lang, {
    String? appVersion,
    String? platform,
  }) => throw StateError('x');

  @override
  Future<void> postEvent(
    String campaignId, {
    required int version,
    required String event,
    DateTime? occurredAt,
  }) => throw StateError('x');
}
