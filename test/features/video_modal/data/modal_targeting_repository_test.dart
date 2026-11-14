import 'package:dio/dio.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_local_datasource.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_remote_datasource.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_local_history.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/recording_dio.dart';
import '../video_modal_test_data.dart';

void main() {
  late RecordingApi api;
  late VideoModalLocalDatasource local;
  var now = DateTime(2026, 11, 10, 9, 30);
  String? version = '1.0.6';
  var platform = 'ios';

  VideoModalRepository make() => VideoModalRepository(
    VideoModalRemoteDatasource(api.client),
    local,
    clock: () => now,
    appVersion: () async => version,
    platform: () => platform,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = RecordingApi();
    local = VideoModalLocalDatasource();
    now = DateTime(2026, 11, 10, 9, 30);
    version = '1.0.6';
    platform = 'ios';
  });

  group('requête d\'éligibilité', () {
    test('envoie caps, appVersion et platform', () async {
      api.on('GET', '/video-modals/eligible', <Object?>[]);
      await make().loadEligible(lang: 'fr', realSession: true);
      expect(api.last.queryParameters, {
        'lang': 'fr',
        'caps': 'layout,targeting,moments,everytime',
        'appVersion': '1.0.6',
        'platform': 'ios',
      });
    });

    test('version illisible : appVersion omise, le reste part', () async {
      version = null;
      api.on('GET', '/video-modals/eligible', <Object?>[]);
      await make().loadEligible(lang: 'fr', realSession: true);
      expect(api.last.queryParameters, {
        'lang': 'fr',
        'caps': 'layout,targeting,moments,everytime',
        'platform': 'ios',
      });
    });

    test('lecture de la version en échec : avalée', () async {
      final repo = VideoModalRepository(
        VideoModalRemoteDatasource(api.client),
        local,
        appVersion: () async => throw StateError('plugin absent'),
        platform: () => 'android',
      );
      api.on('GET', '/video-modals/eligible', [campaignJson()]);
      final list = await repo.loadEligible(lang: 'fr', realSession: true);
      expect(list, hasLength(1));
      expect(api.last.queryParameters.containsKey('appVersion'), isFalse);
    });

    test(
      'plateforme et version par défaut (tests : Android, sans plugin)',
      () async {
        final repo = VideoModalRepository(
          VideoModalRemoteDatasource(api.client),
          local,
        );
        api.on('GET', '/video-modals/eligible', <Object?>[]);
        await repo.loadEligible(lang: 'fr', realSession: true);
        expect(api.last.queryParameters['platform'], 'android');
        expect(api.last.queryParameters.containsKey('appVersion'), isFalse);
      },
    );

    test('iOS reconnue par défaut', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final repo = VideoModalRepository(
        VideoModalRemoteDatasource(api.client),
        local,
      );
      api.on('GET', '/video-modals/eligible', <Object?>[]);
      await repo.loadEligible(lang: 'fr', realSession: true);
      expect(api.last.queryParameters['platform'], 'ios');
    });
  });

  group('back ancien (aucun nouveau champ)', () {
    test('compte : liste inchangée, comportement d\'avant', () async {
      api.on('GET', '/video-modals/eligible', [
        campaignJson(id: 'a'),
        infoJson(id: 'b'),
        campaignJson(id: 'plein', displays: 3),
      ]);
      final list = await make().loadEligible(lang: 'fr', realSession: true);
      expect(list.map((c) => c.id), ['a', 'b']);
    });

    test(
      'valeur d\'enum inconnue : la campagne est ignorée, pas les autres',
      () async {
        api.on('GET', '/video-modals/eligible', [
          campaignJson(id: 'a', extra: {'frequency': 'DAILY_AT_NOON'}),
          campaignJson(id: 'b'),
        ]);
        final list = await make().loadEligible(lang: 'fr', realSession: true);
        expect(list.map((c) => c.id), ['b']);
      },
    );
  });

  group('liste triée par priorité', () {
    test('le back peut ne pas trier : l\'app trie', () async {
      api.on('GET', '/video-modals/eligible', [
        campaignJson(id: 'bas'),
        campaignJson(id: 'haut', extra: {'priority': 9}),
      ]);
      final list = await make().loadEligible(lang: 'fr', realSession: true);
      expect(list.map((c) => c.id), ['haut', 'bas']);
    });
  });

  group('compte : fréquences sans plafond local', () {
    test('EVERY_TIME passe même avec displays élevé', () async {
      api.on('GET', '/video-modals/eligible', [
        campaignJson(
          id: 'chaque',
          displays: 40,
          extra: {'frequency': 'EVERY_TIME'},
        ),
      ]);
      final list = await make().loadEligible(lang: 'fr', realSession: true);
      expect(list.map((c) => c.id), ['chaque']);
    });

    test(
      'EVERY_OPEN et EVERY_N_DAYS passent même avec displays élevé',
      () async {
        api.on('GET', '/video-modals/eligible', [
          campaignJson(
            id: 'open',
            displays: 40,
            extra: {'frequency': 'EVERY_OPEN'},
          ),
          campaignJson(
            id: 'days',
            displays: 40,
            extra: {'frequency': 'EVERY_N_DAYS', 'frequencyDays': 3},
          ),
          campaignJson(id: 'once', displays: 1, extra: {'frequency': 'ONCE'}),
        ]);
        final list = await make().loadEligible(lang: 'fr', realSession: true);
        expect(list.map((c) => c.id), ['open', 'days']);
      },
    );
  });

  group('visiteur : règles locales', () {
    final every = {'frequency': 'EVERY_OPEN', 'stopAfterAnswer': false};

    test(
      'deux modals différents le même jour sont tous deux éligibles',
      () async {
        final repo = make();
        api.on('GET', '/video-modals/eligible', [
          campaignJson(id: 'a', extra: every),
          infoJson(id: 'b', extra: every),
        ]);
        await repo.record(
          infoCampaign(id: 'b'),
          VideoModalEventType.shown,
          realSession: false,
        );
        now = DateTime(2026, 11, 10, 23);
        expect(
          (await repo.loadEligible(
            lang: 'fr',
            realSession: false,
          )).map((c) => c.id),
          unorderedEquals(['a', 'b']),
        );
      },
    );

    test('EVERY_N_DAYS : attend la fenêtre', () async {
      final repo = make();
      api.on('GET', '/video-modals/eligible', [
        campaignJson(
          id: 'a',
          extra: {
            'frequency': 'EVERY_N_DAYS',
            'frequencyDays': 3,
            'stopAfterAnswer': false,
          },
        ),
      ]);
      await repo.record(
        campaign(id: 'a'),
        VideoModalEventType.shown,
        realSession: false,
      );
      now = DateTime(2026, 11, 12, 9, 30);
      expect(await repo.loadEligible(lang: 'fr', realSession: false), isEmpty);
      now = DateTime(2026, 11, 13, 9, 30);
      expect(
        await repo.loadEligible(lang: 'fr', realSession: false),
        hasLength(1),
      );
    });

    test('ONCE : une seule fois', () async {
      final repo = make();
      api.on('GET', '/video-modals/eligible', [
        campaignJson(id: 'a', extra: {'frequency': 'ONCE'}),
      ]);
      await repo.record(
        campaign(id: 'a'),
        VideoModalEventType.shown,
        realSession: false,
      );
      now = DateTime(2026, 11, 20);
      expect(await repo.loadEligible(lang: 'fr', realSession: false), isEmpty);
    });

    test('DONT_SHOW_AGAIN : plus jamais cette version', () async {
      final repo = make();
      api.on('GET', '/video-modals/eligible', [
        campaignJson(id: 'a', extra: every),
      ]);
      await repo.record(
        campaign(id: 'a'),
        VideoModalEventType.dontShowAgain,
        realSession: false,
      );
      now = DateTime(2027);
      expect(await repo.loadEligible(lang: 'fr', realSession: false), isEmpty);
      // Une nouvelle version, elle, revient.
      api.on('GET', '/video-modals/eligible', [
        campaignJson(
          id: 'a',
          version: 3,
          extra: {...every, 'audience': 'EVERYONE'},
        ),
      ]);
      expect(
        await repo.loadEligible(lang: 'fr', realSession: false),
        hasLength(1),
      );
    });

    test('stopAfterAnswer faux : une réponse ne bloque pas', () async {
      final repo = make();
      api.on('GET', '/video-modals/eligible', [
        campaignJson(id: 'a', extra: every),
      ]);
      await repo.record(
        campaign(id: 'a'),
        VideoModalEventType.opened,
        realSession: false,
      );
      now = DateTime(2026, 11, 11);
      expect(
        await repo.loadEligible(lang: 'fr', realSession: false),
        hasLength(1),
      );
    });

    test(
      'ancien comportement : une réponse bloque (stopAfterAnswer absent)',
      () async {
        final repo = make();
        api.on('GET', '/video-modals/eligible', [campaignJson(id: 'a')]);
        await repo.record(
          campaign(id: 'a'),
          VideoModalEventType.dismissed,
          realSession: false,
        );
        now = DateTime(2026, 11, 11);
        expect(
          await repo.loadEligible(lang: 'fr', realSession: false),
          isEmpty,
        );
      },
    );

    test(
      'ancien historique stocké (ancien format, clé inconnue) : lu',
      () async {
        SharedPreferences.setMockInitialValues({
          VideoModalLocalDatasource.historyKey:
              '{"c1":{"2":{"displays":1,"status":null}}}',
        });
        api.on('GET', '/video-modals/eligible', [campaignJson()]);
        final list = await make().loadEligible(lang: 'fr', realSession: false);
        expect(list, hasLength(1));
      },
    );

    test('historique enregistré : dernier SHOWN par version', () async {
      final repo = make();
      await repo.record(
        campaign(),
        VideoModalEventType.shown,
        realSession: false,
      );
      final h = await local.readHistory();
      expect(h.recordOf('c1', 2).lastShownAt!.isAtSameMomentAs(now), isTrue);
    });
  });

  group('file d\'événements et synchro à la connexion', () {
    test(
      'DONT_SHOW_AGAIN est mis en file puis envoyé avec son heure',
      () async {
        final repo = make();
        await repo.record(
          campaign(),
          VideoModalEventType.shown,
          realSession: false,
        );
        await repo.record(
          campaign(),
          VideoModalEventType.dontShowAgain,
          realSession: false,
        );
        final pending = await local.readPending();
        expect(pending.map((e) => e.event), [
          VideoModalEventType.shown,
          VideoModalEventType.dontShowAgain,
        ]);
        expect(await repo.syncGuestEvents(), 2);
        expect(api.requests.map((r) => (r.data as Map)['event']), [
          'SHOWN',
          'DONT_SHOW_AGAIN',
        ]);
        expect(await local.readPending(), isEmpty);
        expect((await local.readHistory()).isEmpty, isTrue);
      },
    );

    test('compte : DONT_SHOW_AGAIN part tel quel', () async {
      await make().record(
        campaign(),
        VideoModalEventType.dontShowAgain,
        realSession: true,
      );
      expect(api.last.path, '/video-modals/c1/events');
      expect(api.last.data, {'version': 2, 'event': 'DONT_SHOW_AGAIN'});
    });

    test(
      'back ancien : DONT_SHOW_AGAIN refusé (400), la file continue',
      () async {
        final repo = make();
        await repo.record(
          campaign(),
          VideoModalEventType.dontShowAgain,
          realSession: false,
        );
        await repo.record(
          campaign(),
          VideoModalEventType.opened,
          realSession: false,
        );
        api.on('POST', '/video-modals/c1/events', {'title': 'x'}, status: 400);
        expect(await repo.syncGuestEvents(), 0);
        expect(api.requests, hasLength(2));
        expect(await local.readPending(), isEmpty);
      },
    );

    test('compte : un POST DONT_SHOW_AGAIN en échec est avalé', () async {
      api.adapter.failWith = DioExceptionType.connectionError;
      await expectLater(
        make().record(
          campaign(),
          VideoModalEventType.dontShowAgain,
          realSession: true,
        ),
        completes,
      );
    });

    test('file locale : événement DONT_SHOW_AGAIN relu', () {
      final e = PendingVideoModalEvent(
        campaignId: 'c',
        version: 1,
        event: VideoModalEventType.dontShowAgain,
        occurredAt: DateTime.utc(2026, 11, 10),
      );
      expect(PendingVideoModalEvent.tryParse(e.toJson()), e);
    });
  });
}
